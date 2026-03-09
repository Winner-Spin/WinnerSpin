from PIL import Image
import sys

def process_perfect_button(in_path, out_path):
    img = Image.open(in_path).convert("RGBA")
    data = img.load()
    width, height = img.size
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = data[x, y]
            
            # Remove solid white/light background
            if r > 240 and g > 240 and b > 240:
                data[x, y] = (0, 0, 0, 0)
            # Clean up white fringe/anti-aliasing near the edges
            elif r > 210 and g > 210 and b > 210:
                if y < 15 or y > height - 15 or x < 15 or x > width - 15:
                    data[x, y] = (r, g, b, max(0, int(a * 0.2)))
                
    # Calculate bounding box
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    
    for y in range(height):
        for x in range(width):
            if data[x, y][3] > 10: 
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                
    if min_x <= max_x and min_y <= max_y:
        # Extra 2 pixel tight crop to ensure no white edges
        cropped = img.crop((min_x + 2, min_y + 2, max_x - 1, max_y - 1)) 
        cropped.save(out_path, "PNG")
        print(f"Processed perfect user image: {out_path}")
    else:
        print("Image completely empty.")

if __name__ == "__main__":
    process_perfect_button(sys.argv[1], sys.argv[2])
