from scipy.stats import mode
from itertools import product
import cv2
import numpy as np

column_increment = 4
row_increment = 1024


def paint_assembly_code(img_path: str, img_shape: tuple, label: str):
    global column_increment, row_increment
    # Load image
    img = cv2.imread(img_path)
    # Resize image if over img_shape
    if img.shape[0] > img_shape[0] or img.shape[1] > img_shape[1]:
        img = cv2.resize(img, img_shape, interpolation=cv2.INTER_AREA)

    # Image to RGB Hexadecimal Values
    hex_image = image_to_rgb_hex(img)

    # Get Most Frequent Color       # set as the background
    background = mode(hex_image.flatten())[0][0]

    # Loop through rows and columns to hard code pixel values
    # i = column values
    # j = row values
    address_offsets = []    # as string
    colors = []             # as string
    foreground_starts = None
    for j in range(img_shape[0]):
        for i in range(img_shape[1]):
            # If pixel is in the foreground
            if hex_image[j, i] != background:
                if foreground_starts is None:   # Get start of foreground
                    foreground_starts = (j, i)

                # Calculate current pixel address offset from start of foreground.
                curr_offset = str(((i - foreground_starts[1]) * column_increment) + ((j - foreground_starts[0]) * row_increment))
                address_offsets.append(curr_offset)

                # Current pixel RGB color in hex
                curr_color = str(hex_image[j, i])
                # If not 32 bits, zero extend hex value
                if len(str(hex_image[j, i])) != 8:
                    lacks = len(str(hex_image[j, i])) - 8                       # how many zeroes to add
                    curr_color = curr_color.replace("0x", f"0x{'0' * lacks}")
                colors.append(curr_color)

    import multiprocessing
    a_pool = multiprocessing.Pool(3)
    paint = a_pool.starmap(create_assembly_code, zip(address_offsets, colors))

    return paint


def create_assembly_code(address_offset, color) -> list:
    """Return assembly code for painting in <colors> at <address_offsets>

    ==Assumptions==:
        - $a0 stores base address for object
        - $a1 stores boolean whether to paint in color or not
        - $t1 is used to hold paint value
        - $t2 is used to store temporary memory address
    """
    base_code = f"""    # Update pixel color
    addi $t1, $0, {color}	\t# change current color to dark gray
    check_color			        # updates color (in $t1) according to func. param. $a1
	add $t2, $0, $0				# reinitialize temporary address store
	addi $t2, $a0, {address_offset}		# add address offset to base address
    sw $t1, ($t2)				# paint pixel value
    """
    base_code = f"    setup_object_paint ({color}, {address_offset})"

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



if __name__ == "__main__":
    img_path = "D:\\Stan\\Pictures\\My stuff\\1st Year UofT/Ryerson Application (Illustration).jpg"
    codes = paint_assembly_code(img_path, (256, 256), 'PAINT_OBJECT')
    label = 'PAINT_OBJECT'

    paint = '\n'.join(codes)
    if len(codes) < 20:
        print(f"""{label}:
            {paint}
        """)

