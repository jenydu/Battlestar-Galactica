from scipy.stats import mode
from itertools import product
import cv2
import numpy as np

label = 'GAME_OVER'
column_increment = 4
row_increment = 1024
by = "row"      # 'row' or 'column'
by_inverse = "column"


def paint_assembly_code(img_path: str, img_shape: tuple, skip_background=True):
    """Return tuple of:
        - dictionary containing <by> index to (hex_color, (start_idx, end_idx))
        - string containing most frequent hex color
    """
    global column_increment, row_increment, by
    # Load image
    img = cv2.imread(img_path)

    # Resize image if over img_shape
    if img.shape[0] > img_shape[0] or img.shape[1] > img_shape[1]:
        img = cv2.resize(img, img_shape, interpolation=cv2.INTER_AREA)

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
            index_info[j] = find_same_color_stretch(hex_image[j, :])
    else:
        # Paint in by columns.
        for i in range(img_shape[1]):
            index_info[i] = find_same_color_stretch(hex_image[:, i])
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


def find_same_color_stretch(x):
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


def create_conditional_code(hex_color: str, start_idx: int, end_idx: int, ignore_hex_value = None) -> list:
    global by, by_inverse, label
    """Return assembly code for painting in <colors> at <address_offsets>

    ==Assumptions==:
        - $t1 holds color value
        - $t4 holds starting index for slicing along <by_inverse>
        - $t5 holds exclusive end index for slicing along <by_inverse>
    """
    if by == "row":
        start_idx_address = start_idx * column_increment
        end_idx_address = end_idx * column_increment
    else:
        start_idx_address = start_idx * row_increment
        end_idx_address = end_idx * row_increment


    base_code = \
        f"""
\t\t\t\t\t\taddi $t1, $0, {hex_color}		# change current color
\t\t\t\t\t\taddi $t4, $0, {start_idx_address}		    # paint starting from {by_inverse} ___
\t\t\t\t\t\taddi $t5, $0, {end_idx_address}		    # ending at {by_inverse} ___
\t\t\t\t\t\tjal LOOP_{label.upper()}_{by.upper()}		# paint in {by}
"""
    return base_code



def create_paint_code(hex_color: str, start_idx: int, end_idx: int, ignore_hex_value = None) -> list:
    global by, by_inverse, label
    """Return assembly code for painting in <colors> at <address_offsets>

    ==Assumptions==:
        - $t1 holds color value
        - $t4 holds starting index for slicing along <by_inverse>
        - $t5 holds exclusive end index for slicing along <by_inverse>
    """
    if by == "row":
        start_idx_address = start_idx * column_increment
        end_idx_address = end_idx * column_increment
    else:
        start_idx_address = start_idx * row_increment
        end_idx_address = end_idx * row_increment


    base_code = \
f"""
\t\t\t\t\t\taddi $t1, $0, {hex_color}		# change current color
\t\t\t\t\t\taddi $t4, $0, {start_idx_address}		    # paint starting from {by_inverse} ___
\t\t\t\t\t\taddi $t5, $0, {end_idx_address}		    # ending at {by_inverse} ___
\t\t\t\t\t\tjal LOOP_{label.upper()}_{by.upper()}		# paint in {by}
"""
    return base_code


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
        lacks = len(str(hex_color)) - 8                       # how many zeroes to add
        return hex_color.replace("0x", f"0x{'0' * lacks}")

    return hex_color


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

\t\tLOOP_{label.upper()}_{by_inverse.upper()}: bge $t3, {by_inverse}_max, EXIT_{label.upper()}_PAINT
\t\t\t\t# Boolean Expressions: Paint in based on {by_inverse} index
	    	
\t\t\t\t{label.upper()}_COND:
		
"""
conditional_code = \
f"""
"""

paint_code = \
f"""
\t\t\t\t{label.upper()}_{by.upper()}_<VALUE>:
"""

end_code = \
f"""
    	UPDATE_{label.upper()}_{by_inverse.upper()}:				# Update {by_inverse} value
    	    	addi $t3, $t3, {by_inverse}_increment		# add 4 bits (1 byte) to refer to memory address for next row
	        	j LOOP_{label.upper()}_{by_inverse.upper()}

    	# EXIT FUNCTION
       	EXIT_{label.upper()}_PAINT:
        		# Restore $t registers
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

    	# FOR LOOP: (through {by})
    	# Paints in {by} from $t4 to $t5 at some {by_inverse}
    	LOOP_{label.upper()}_{by.upper()}: bge $t4, $t5, EXIT_LOOP_{label}_ROWS	# branch to UPDATE_{label}_COL; if {by} index >= last {by} index to paint
        		addi $t2, $0, base_address			# Reinitialize t2; temporary address store
        		add $t2, $t2, $t3				# update to specific {by_inverse} from base address
        		add $t2, $t2, $t4				# update to specific {by}
        		sw $t1, ($t2)					# paint in value

        		# Updates for loop index
        		addi $t4, $t4, {by}_increment			# t4 += {by}_increment
        		j LOOP_{label}_{by.upper()}				# repeats LOOP_{label}_{by.upper()}
	    EXIT_LOOP_{label}_{by.upper()}:
		        jr $ra
"""

if __name__ == "__main__":
    img_path = "C:/Users/Stanley/OneDrive - University of Toronto/UofT/3rd Year/Summer 2021/CSC258/Assignment/game_over.jpg"
    index_info, background = paint_assembly_code(img_path, (256, 256))

    for n in index_info:
        info = index_info[n]


        paint_code += create_paint_code(info[0], info[1][0], info[1][1])
