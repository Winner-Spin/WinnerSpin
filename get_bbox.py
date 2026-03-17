from PIL import Image

def get_real_bbox(img_path):
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    min_x, min_y, max_x, max_y = w, h, 0, 0
    data = img.load()
    found = False
    for y in range(h):
        for x in range(w):
            if data[x, y][3] > 10: # alpha threshold
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                found = True
    if found:
        print(f"Real bbox: ({min_x}, {min_y}, {max_x}, {max_y})")
        print(f"Real size: {max_x-min_x}x{max_y-min_y}")
        # Crop and save it
        cropped = img.crop((min_x, min_y, max_x, max_y))
        cropped.save("lib/images/login_screen/email_button1_cropped.png")
        print("Cropped image saved.")
    else:
        print("No solid pixels found.")

get_real_bbox("lib/images/login_screen/email_button1.png")
