from PIL import Image, ImageDraw
import sys

def make_circle(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    
    # Create mask
    mask = Image.new('L', img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0) + img.size, fill=255)
    
    # Apply mask
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask=mask)
    
    out.save(output_path)

if __name__ == "__main__":
    make_circle('/home/abdelwahed/babysleeper/assets/icon.png', '/home/abdelwahed/babysleeper/assets/icon_circle.png')
