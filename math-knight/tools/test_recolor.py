import os
import glob
import numpy as np
from PIL import Image

def transform_knight_image(img: Image.Image, dark_armor_too: bool = False) -> Image.Image:
    """
    Transforms knight sprite:
    - Blue cape / plume / cloth -> Royal Purple palette
    - Helmet (Y in head region) -> Dark Gray / Matte Black metallic palette
    - Visor slit / gold trim -> Enhanced radiant gold
    """
    arr = np.array(img, dtype=np.float32)
    h, w, c = arr.shape
    
    # Work on a copy
    out = arr.copy()
    
    # We define color distance or HSV based color detection
    # 1. Detect BLUE cloth/cape/plume pixels across the entire sprite
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    
    # Non-transparent pixels
    visible = a > 10
    
    # Blue detection: Blue is notably higher than Red, or specific blue RGBs
    # In the sprite, blues have low red (<= 40), low/med green (<= 110), and high blue (>= 60)
    # or r < 50, b > r + 25, b > g
    is_blue_cloth = visible & (b > r + 15) & (b > 15) & (r < 100)
    
    # Let's map blue intensity to rich purple palette
    # Calculate luminance / intensity of the blue
    blue_brightness = (r * 0.2 + g * 0.4 + b * 0.8) / 255.0
    
    # Royal Purple Gradient (Shadow to Highlight)
    # Deep shadow: (45, 10, 75)
    # Dark mid: (85, 20, 140)
    # Vibrant purple: (135, 35, 210)
    # Highlight: (185, 75, 245)
    # Max highlight: (225, 140, 255)
    
    purple_r = np.clip(35 + blue_brightness * 180, 0, 255)
    purple_g = np.clip(5 + blue_brightness * 110 - 20, 0, 255)
    purple_b = np.clip(65 + blue_brightness * 190, 0, 255)
    
    out[is_blue_cloth, 0] = purple_r[is_blue_cloth]
    out[is_blue_cloth, 1] = purple_g[is_blue_cloth]
    out[is_blue_cloth, 2] = purple_b[is_blue_cloth]
    
    # 2. Detect HELMET region
    # Head area is generally Y from top of visible pixels to ~54
    y_indices, x_indices = np.where(visible)
    if len(y_indices) > 0:
        top_y = y_indices.min()
        # Head / Helmet region spans top_y to top_y + 44
        head_bottom = top_y + 44
        
        # Create head mask
        head_mask = np.zeros((h, w), dtype=bool)
        head_mask[top_y:head_bottom, :] = True
        
        # Silver / Gray metals in head region (not outline, not gold visor, not blue cloth)
        # Silver colors have r ~ g ~ b (std < 15) and brightness > 60 and < 255
        rgb_mean = (r + g + b) / 3.0
        rgb_std = np.std(arr[:, :, :3], axis=2)
        
        is_gold_visor = visible & (r > 160) & (g > 110) & (b < 100)
        is_black_outline = visible & (rgb_mean < 35)
        
        is_head_silver = visible & head_mask & ~is_blue_cloth & ~is_gold_visor & ~is_black_outline & (rgb_std < 22)
        
        # Transform silver helmet to dark gray / black metallic
        # Silver brightness ranges from ~100 to 250
        # We remap to dark steel / black: 30 to 110
        norm_silver = (rgb_mean - 60.0) / 195.0
        norm_silver = np.clip(norm_silver, 0.0, 1.0)
        
        # Dark metallic gradient:
        # Dark shadow: (28, 28, 35)
        # Mid tone: (55, 55, 68)
        # Highlight: (95, 98, 115)
        # Specular glint: (140, 145, 165)
        dark_r = 24.0 + (norm_silver ** 1.3) * 115.0
        dark_g = 25.0 + (norm_silver ** 1.3) * 120.0
        dark_b = 32.0 + (norm_silver ** 1.3) * 135.0
        
        out[is_head_silver, 0] = dark_r[is_head_silver]
        out[is_head_silver, 1] = dark_g[is_head_silver]
        out[is_head_silver, 2] = dark_b[is_head_silver]
        
        # If dark_armor_too is requested, also do body armor
        if dark_armor_too:
            body_mask = np.zeros((h, w), dtype=bool)
            body_mask[head_bottom:, :] = True
            is_body_silver = visible & body_mask & ~is_blue_cloth & ~is_gold_visor & ~is_black_outline & (rgb_std < 22)
            out[is_body_silver, 0] = dark_r[is_body_silver]
            out[is_body_silver, 1] = dark_g[is_body_silver]
            out[is_body_silver, 2] = dark_b[is_body_silver]

    return Image.fromarray(np.uint8(np.clip(out, 0, 255)))

if __name__ == "__main__":
    src_west = r"c:\MathKnight\math-knight\assets\sprites\knight_comic\Idle\rotations\west.png"
    img = Image.open(src_west)
    res1 = transform_knight_image(img, dark_armor_too=False)
    res1.save(r"c:\MathKnight\preview_redesign_dark_helm.png")
    
    res2 = transform_knight_image(img, dark_armor_too=True)
    res2.save(r"c:\MathKnight\preview_redesign_full_dark.png")
    
    print("Saved preview_redesign_dark_helm.png and preview_redesign_full_dark.png")
