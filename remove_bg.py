import urllib.request
import os

from PIL import Image

def remove_black_background(image_path, output_path, tolerance=30):
    img = Image.open(image_path).convert("RGBA")
    datas = img.getdata()
    
    newData = []
    for item in datas:
        # Check if the pixel is black or very dark
        if item[0] < tolerance and item[1] < tolerance and item[2] < tolerance:
            newData.append((255, 255, 255, 0)) # transparent
        else:
            newData.append(item)
            
    img.putdata(newData)
    img.save(output_path, "PNG")

if __name__ == "__main__":
    import sys
    remove_black_background(sys.argv[1], sys.argv[2])
