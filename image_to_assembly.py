from scipy.stats import mode
from itertools import product
import cv2
import numpy as np
from PIL import Image

label = 'GAME_OVER'
column_increment = 4
row_increment = 1024
by = "row"      # 'row' or 'column'
by_inverse = "column"


def image_to_rgb_hex(img):
    """Return new <img> where each location in the image array is now its RGB
    value in hexadecimal.
    """
    array = np.asarray(img, dtype='uint32')
    decimal_rgb_values = (array[:, :, 0]<<16) + (array[:, :, 1]<<8) + array[:, :, 2]

    # Convert decimal RGB values to hexadecimal
    to_hex = np.vectorize(lambda x: hex(x))

    return to_hex(decimal_rgb_values)


def extend_rgb_hex(hex_color):
    """If hex_color is less than 32 bits, zero extend. Else, return the input.
    """
    if len(str(hex_color)) != 8:
        lacks = abs(len(str(hex_color)) - 8)                       # how many zeroes to add
        return hex_color.replace("0x", f"0x{'0' * lacks}")

    return hex_color


def create_assembly_indices(img_path: str, img_shape: tuple, skip_background=True):
    """Return tuple of:
        - dictionary containing <by> index to (hex_color, (start_idx, end_idx))
        - string containing most frequent hex color
    """
    global column_increment, row_increment, by
    # Load image
    img = np.array(Image.open(img_path))

    # Resize image if over img_shape
    if img.shape[0] > img_shape[0] or img.shape[1] > img_shape[1]:
        img = cv2.resize(img, (img_shape[1], img_shape[0]), interpolation=cv2.INTER_AREA)

    # Make dark pixels black
    img[img < 20] = 0

    # Image to RGB Hexadecimal Values
    hex_image = image_to_rgb_hex(img)

    # Get Most Frequent Color       # set as the background
    background = mode(hex_image.flatten())[0][0]

    # Dictionary to store index <value> to (color, (start_idx, end_idx)) mapping
    index_info = {}
    foreground_starts = None        # index for <by> where foreground starts

    # Paint in by rows
    if by == "row":
        for j in range(img_shape[0]):
            index_info[j] = find_consecutive_colors(hex_image[j, :])
    else:
        # Paint in by columns.
        for i in range(img_shape[1]):
            index_info[i] = find_consecutive_colors(hex_image[:, i])
            # TODO: Skip if all pixels in column is background
            # if skip_background:
            #     if all(hex_image[:, i] == background):
            #         continue
            #     elif not all(hex_image[:, i] == background) and foreground_starts is None:
            #         foreground_starts = i
            #     # Calculate current pixel address offset from start of foreground.
            #     curr_offset = str(((i - foreground_starts[1]) * column_increment) + ((j - foreground_starts[0]) * row_increment))
            #     address_offsets.append(curr_offset)
    return index_info, background


def find_consecutive_colors(x):
    """Given array of hex colors in string format (e.g. '0xFFFFFF'), return tuple
    of two lists.
        - List containing the HEX color
        - List of tuples with starting and ending row/column indices
    """
    # Accumulators
    colors = []
    indices = []
    prev_color = None
    start_idx = None
    end_idx = None

    for i in range(len(x)):
        # If old color
        if x[i] == prev_color:
            end_idx += 1
            continue

        # If new color, save previous color stretch info
        if prev_color is not None:
            colors.append(extend_rgb_hex(prev_color))
            indices.append((start_idx, end_idx))

        # Set up
        start_idx = i
        end_idx = i + 1             # NOTE: End index is exclusive
        prev_color = x[i]

        # Save color for last iteration
        if i == len(x) - 1:
            # If hex color is not 32 bits, zero extend hex value
            colors.append(prev_color)

            indices.append((start_idx, end_idx))

    return colors, indices


def create_paint_block(color_lst: list, idx_tuple_lst: list, ignore_hex_value=None):
    paint_block = """"""
    for i in range(len(color_lst)):
        paint_block += create_paint_segment(color_lst[i],
                                            idx_tuple_lst[i][0],
                                            idx_tuple_lst[i][1],
                                            ignore_hex_value)
    return paint_block


# HELPER FUNCTION for create_paint_block
def create_paint_segment(hex_color: str, start_idx: int, end_idx: int, ignore_hex_value=None) -> list:
    """Return assembly code for painting in <colors> at <address_offsets>

    ==Assumptions==:
        - $t1 holds color value
        - $t4 holds starting index for slicing along <by_inverse>
        - $t5 holds exclusive end index for slicing along <by_inverse>
    """
    global by, by_inverse, label, column_increment, row_increment
    if by == "row":
        start_idx_address = start_idx * column_increment
        end_idx_address = end_idx * column_increment
    else:
        start_idx_address = start_idx * row_increment
        end_idx_address = end_idx * row_increment

    base_code = \
f"""
\t\t\t\t\t\taddi $t1, $0, {extend_rgb_hex(hex_color)}		# change current color
\t\t\t\t\t\taddi $t4, $0, {start_idx_address}		    # paint starting from {by_inverse} ___
\t\t\t\t\t\taddi $t5, $0, {end_idx_address}		    # ending at {by_inverse} ___
\t\t\t\t\t\tjal LOOP_{label.upper()}_{by_inverse.upper()}		# paint in
"""
    return base_code


def from_assembly_idx_to_conditionals(index_info):
    """Loop through <index_info> keys to create conditional branch
    statements when looping over <by> in Assembly.
    """
    global by, by_inverse, label, column_increment, row_increment
    if by == "row":
        increment = row_increment
    else:
        increment = column_increment

    cond_code = f"""\t\t\t\t{label.upper()}_COND:
"""

    for idx in index_info:
        # Skip constant arrays
        curr_info = index_info[idx]
        if len(curr_info[0]) == 0 and len(curr_info[1]) == 0:
            continue

        cond_code += \
f"""\t\t\t\t\t\tbeq $t3, {idx * increment}, {label.upper()}_{by.upper()}_{idx}
"""
    return cond_code


def from_assembly_idx_to_paint_settings(index_info, ignore_color=None):
    """Loop through <index_info> keys and values to create labels for paint
    settings when looping over <by> in Assembly.
    """
    paint_code = ""
    for idx in index_info:
        # Skip constant arrays
        curr_info = index_info[idx]
        if len(curr_info[0]) == 0 and len(curr_info[1]) == 0:
            continue

        paint_code += f"\t\t\t\t{label.upper()}_{by.upper()}_{idx}:"
        paint_code += create_paint_block(index_info[idx][0],
                                        index_info[idx][1],
                                        ignore_color)
        paint_code += f"\n\t\t\t\t\t\tj UPDATE_{label.upper()}_{by.upper()}\n"
    return paint_code


def create_assembly_code(img_path: str, img_shape: tuple):
    global by, by_inverse, label, column_increment, row_increment

    index_info, background = create_assembly_indices(img_path, img_shape)

    start_code = \
f"""
PAINT_{label}:
	    # Push $ra registers to stack
	    push_reg_to_stack ($ra)
    
	    # Initialize registers
	    add $t1, $0, $0				# initialize current color to black
	    add $t2, $0, $0				# holds temporary memory address
	    add $t3, $0, $0				# 'column for loop' indexer
	    add $t4, $0, $0				# 'row for loop' indexer
	    add $t5, $0, $0				# last row index to paint in

\t\tLOOP_{label.upper()}_{by.upper()}: bge $t3, {by}_max, EXIT_PAINT_{label.upper()}
\t\t\t\t# Boolean Expressions: Paint in based on {by} index
"""

    cond_code = from_assembly_idx_to_conditionals(index_info)

    paint_code = from_assembly_idx_to_paint_settings(index_info, None)

    end_code = \
f"""
    	UPDATE_{label.upper()}_{by.upper()}:				# Update {by} value
    	    	addi $t3, $t3, {by}_increment
	        	j LOOP_{label.upper()}_{by.upper()}

    	# FOR LOOP: (through {by_inverse})
    	# Paints in {by_inverse} from $t4 to $t5 at some {by}
    	LOOP_{label.upper()}_{by_inverse.upper()}: bge $t4, $t5, EXIT_LOOP_{label}_{by_inverse.upper()}	# branch to UPDATE_{label}_COL; if {by_inverse} index >= last {by_inverse} index to paint
        		addi $t2, $0, base_address			# Reinitialize t2; temporary address store
        		add $t2, $t2, $t3				# update to specific {by} from base address
        		add $t2, $t2, $t4				# update to specific {by_inverse}
        		sw $t1, ($t2)					# paint in value

        		# Updates for loop index
        		addi $t4, $t4, {by_inverse}_increment			# t4 += {by}_increment
        		j LOOP_{label}_{by_inverse.upper()}				# repeats LOOP_{label}_{by.upper()}
	    EXIT_LOOP_{label}_{by_inverse.upper()}:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_{label.upper()}:
        		# Restore $t registers
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
"""

    full_code = start_code + cond_code + paint_code + end_code

    # Save produced code to text file
    with open("C:/Users/Stanley/OneDrive - University of Toronto/UofT/3rd Year/Summer 2021/CSC258/Assignment/produced_code.txt", "w+") as f:
        f.write(full_code)

    return full_code



if __name__ == "__main__":
    img_path = "C:/Users/Stanley/OneDrive - University of Toronto/UofT/3rd Year/Summer 2021/CSC258/Assignment/game_over.png"
    img_shape = (66, 350)       # row, column

    create_assembly_code(img_path, img_shape)
