import cv2
from scipy.stats import mode



def paint_assembly_code(img_path: str, img_shape: tuple, base_address: int):
    img = cv2.imread(img_path)
    
    # Resize Image
    resized_img = cv2.resize(img, (img_shape), interpolation="bilinear")
    
    # Image to RGB Hexadecimal Values
    image_to_rgb_hex()
    
    # Get Most Frequent Color       # set as the background
    background = mode(resized_img.flatten())[0][0]
    
    

def image_to_rgb_hex(img):
    array = np.asarray(array, dtype='uint32')
    return hex((array[:, :, 0]<<16) + (array[:, :, 1]<<8) + array[:, :, 2])




if __name__ == "__main__":
    img_path = "C:/Users/Hua/Pictures/Desktop Wallpapers/family of dog.png"
    