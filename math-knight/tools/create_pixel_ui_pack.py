import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites", "ui")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Color Palettes
GOLD_LIGHT = (255, 225, 90, 255)
GOLD_MID = (220, 170, 35, 255)
GOLD_DARK = (145, 100, 15, 255)
GOLD_SHADOW = (80, 50, 8, 255)

STONE_DARK = (20, 16, 28, 255)
STONE_MID = (32, 26, 44, 255)
STONE_LIGHT = (55, 46, 75, 255)
STONE_BORDER = (75, 65, 95, 255)

RUBY_RED = (235, 55, 75, 255)
SAPPHIRE_BLUE = (45, 140, 245, 255)
EMERALD_GREEN = (40, 215, 120, 255)
AMETHYST_PURPLE = (185, 75, 245, 255)
CYAN_GLOW = (60, 230, 245, 255)

def save_img(img: Image.Image, name: str):
    path = os.path.join(OUTPUT_DIR, f"{name}.png")
    img.save(path, format="PNG")
    print(f"Generated pixel asset: {path} ({img.size[0]}x{img.size[1]})")

# 1. RPG Menu Frame (9-Patch Sliceable 64x64)
def create_rpg_menu_frame():
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Base dark fill
    draw.rectangle([2, 2, w-3, h-3], fill=(16, 13, 24, 235))
    
    # Inner subtle border
    draw.rectangle([4, 4, w-5, h-5], outline=(42, 34, 58, 255))
    
    # Outer dark outline
    draw.rectangle([1, 1, w-2, h-2], outline=(10, 8, 14, 255))
    
    # Gilded Gold Border (2px)
    draw.rectangle([2, 2, w-3, h-3], outline=GOLD_MID)
    draw.rectangle([3, 3, w-4, h-4], outline=GOLD_DARK)
    
    # Corner rivets / gems (gilded accents)
    corners = [(2, 2), (w-6, 2), (2, h-6), (w-6, h-6)]
    for cx, cy in corners:
        draw.rectangle([cx, cy, cx+3, cy+3], fill=GOLD_LIGHT)
        draw.point((cx+1, cy+1), fill=(255, 255, 255, 255))
        draw.rectangle([cx, cy, cx+3, cy+3], outline=GOLD_SHADOW)
        
    save_img(img, "rpg_menu_frame")

# 2. Slot Frame Box (Normal & Active) (48x48)
def create_slot_frames():
    for active in [False, True]:
        w, h = 48, 48
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Outer dark shadow
        draw.rectangle([1, 1, w-2, h-2], outline=(12, 10, 18, 255))
        
        # Velvet inner fill
        draw.rectangle([3, 3, w-4, h-4], fill=(18, 14, 26, 240) if not active else (30, 24, 45, 245))
        
        # Inset shadow (top & left dark, bottom & right light)
        draw.line([(3, 3), (w-4, 3)], fill=(10, 8, 14, 255))
        draw.line([(3, 3), (3, h-4)], fill=(10, 8, 14, 255))
        draw.line([(3, h-4), (w-4, h-4)], fill=(45, 38, 62, 255))
        draw.line([(w-4, 3), (w-4, h-4)], fill=(45, 38, 62, 255))
        
        # Border
        b_col = GOLD_LIGHT if active else (70, 60, 85, 255)
        b_mid = GOLD_MID if active else (50, 42, 65, 255)
        draw.rectangle([2, 2, w-3, h-3], outline=b_col)
        draw.rectangle([3, 3, w-4, h-4], outline=b_mid)
        
        # Corner studs
        for cx, cy in [(2, 2), (w-5, 2), (2, h-5), (w-5, h-5)]:
            draw.rectangle([cx, cy, cx+2, cy+2], fill=GOLD_LIGHT if active else (110, 95, 135, 255))
            
        save_img(img, "slot_frame_active" if active else "slot_frame_box")

# 3. Gilded Gold Button (9-Patch Sliceable 48x24)
def create_gold_button():
    for state, bg_col, edge_col in [
        ("button_gold_normal", (225, 170, 30, 255), GOLD_LIGHT),
        ("button_gold_hover", (250, 195, 45, 255), (255, 240, 140, 255)),
        ("button_gold_pressed", (180, 130, 15, 255), GOLD_DARK)
    ]:
        w, h = 48, 24
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Dark drop shadow outline
        draw.rectangle([1, 1, w-2, h-2], outline=(15, 10, 5, 255))
        draw.rectangle([2, 2, w-3, h-3], fill=bg_col)
        
        # Top bevel highlight
        draw.line([(3, 3), (w-4, 3)], fill=edge_col)
        draw.line([(3, 4), (w-4, 4)], fill=edge_col)
        
        # Bottom bevel shade
        draw.line([(3, h-4), (w-4, h-4)], fill=GOLD_SHADOW)
        draw.line([(3, h-5), (w-4, h-5)], fill=GOLD_SHADOW)
        
        # Corner brackets
        for cx, cy in [(2, 2), (w-4, 2), (2, h-4), (w-4, h-4)]:
            draw.point((cx, cy), fill=(255, 255, 255, 255))
            
        save_img(img, state)

# 4. Character Pedestal / Dais (96x48)
def create_knight_pedestal():
    w, h = 96, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = w // 2, 26
    rx, ry = 42, 14
    
    # Shadow underneath
    draw.ellipse([cx - rx - 2, cy - ry + 10, cx + rx + 2, cy + ry + 16], fill=(5, 4, 8, 140))
    
    # Stone lower cylinder
    for y_offset in range(12, 0, -1):
        shade = int(25 + (12 - y_offset) * 3)
        draw.ellipse([cx - rx, cy - ry + y_offset, cx + rx, cy + ry + y_offset], fill=(shade, shade - 4, shade + 8, 255))
        # Gold side trim
        draw.arc([cx - rx, cy - ry + y_offset, cx + rx, cy + ry + y_offset], 0, 180, fill=GOLD_DARK)
        
    # Top Stone Disc
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(45, 38, 58, 255), outline=GOLD_MID)
    # Inner rune ring
    draw.ellipse([cx - rx + 6, cy - ry + 2, cx + rx - 6, cy + ry - 2], outline=(75, 60, 95, 255))
    draw.ellipse([cx - rx + 14, cy - ry + 5, cx + rx - 14, cy + ry - 5], fill=(30, 24, 40, 255), outline=CYAN_GLOW)
    
    # Center magic star runes
    draw.line([(cx - 10, cy), (cx + 10, cy)], fill=CYAN_GLOW)
    draw.line([(cx, cy - 4), (cx, cy + 4)], fill=CYAN_GLOW)
    
    save_img(img, "knight_pedestal")

# 5. Stat Icons (48x48)
def create_stat_icons():
    # A) Strength: Glowing Ruby Sword
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, 43, 43], fill=(35, 15, 20, 220), outline=RUBY_RED)
    # Sword blade diagonal
    for i in range(16):
        x = 16 + i
        y = 32 - i
        d.line([(x-1, y-1), (x+2, y+2)], fill=(255, 220, 225, 255))
        d.point((x, y), fill=RUBY_RED)
    # Crossguard & hilt
    d.line([(14, 30), (22, 38)], fill=GOLD_LIGHT, width=2)
    d.line([(12, 34), (16, 38)], fill=GOLD_MID, width=2)
    d.point((10, 40), fill=RUBY_RED)
    save_img(img, "icon_strength")

    # B) Endurance: Glowing Crimson Winged Heart
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, 43, 43], fill=(35, 12, 18, 220), outline=(255, 80, 100, 255))
    # Heart shape
    d.polygon([(24, 36), (12, 22), (15, 14), (21, 14), (24, 18), (27, 14), (33, 14), (36, 22)], fill=(245, 45, 75, 255))
    d.polygon([(24, 33), (15, 22), (17, 16), (21, 16), (24, 19), (27, 16), (31, 16), (33, 22)], fill=(255, 110, 135, 255))
    d.point((18, 18), fill=(255, 255, 255, 255))
    save_img(img, "icon_endurance")

    # C) Defense: Sapphire Tower Shield
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, 43, 43], fill=(12, 22, 40, 220), outline=SAPPHIRE_BLUE)
    # Shield shape
    d.polygon([(14, 14), (34, 14), (34, 26), (24, 38), (14, 26)], fill=(30, 95, 190, 255), outline=GOLD_LIGHT)
    d.polygon([(18, 17), (30, 17), (30, 24), (24, 33), (18, 24)], fill=(65, 160, 255, 255))
    # Cross on shield
    d.line([(24, 18), (24, 30)], fill=GOLD_LIGHT, width=2)
    d.line([(19, 22), (29, 22)], fill=GOLD_LIGHT, width=2)
    save_img(img, "icon_defense")

    # D) Agility: Emerald Winged Boot
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, 43, 43], fill=(10, 32, 22, 220), outline=EMERALD_GREEN)
    # Boot shape
    d.polygon([(18, 14), (26, 14), (26, 26), (34, 28), (34, 34), (16, 34), (16, 26), (18, 26)], fill=(25, 160, 85, 255), outline=GOLD_MID)
    d.polygon([(20, 16), (24, 16), (24, 26), (32, 28), (32, 32), (18, 32), (18, 26), (20, 26)], fill=(50, 215, 120, 255))
    # Wing feathers
    d.polygon([(14, 16), (22, 20), (12, 24)], fill=(210, 255, 230, 255))
    d.polygon([(10, 20), (18, 23), (8, 27)], fill=(160, 245, 195, 255))
    save_img(img, "icon_agility")

    # E) Wisdom: Amethyst Arcane Spellbook & Orb
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, 43, 43], fill=(30, 14, 42, 220), outline=AMETHYST_PURPLE)
    # Open spellbook
    d.polygon([(12, 22), (24, 26), (36, 22), (36, 34), (24, 38), (12, 34)], fill=(130, 45, 185, 255), outline=GOLD_LIGHT)
    d.polygon([(14, 23), (23, 26), (23, 35), (14, 32)], fill=(235, 225, 250, 255))
    d.polygon([(25, 26), (34, 23), (34, 32), (25, 35)], fill=(235, 225, 250, 255))
    # Glowing arcane floating orb above
    d.ellipse([20, 12, 28, 20], fill=(225, 140, 255, 255), outline=(255, 255, 255, 255))
    save_img(img, "icon_wisdom")

# 6. Mode Icons (32x32)
def create_mode_icons():
    # Mode 1: Rechen-Schlag (Sword + Equals)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(8, 24), (24, 8)], fill=RUBY_RED, width=3)
    d.line([(9, 23), (23, 9)], fill=(255, 255, 255, 255), width=1)
    d.line([(6, 18), (12, 24)], fill=GOLD_LIGHT, width=2)
    d.line([(18, 20), (28, 20)], fill=CYAN_GLOW, width=2)
    d.line([(18, 24), (28, 24)], fill=CYAN_GLOW, width=2)
    save_img(img, "icon_mode_strike")

    # Mode 2: Zahlen-Schmiede (Anvil + Spark)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 16), (26, 16), (22, 22), (18, 22), (20, 26), (12, 26), (14, 22), (10, 22)], fill=(120, 125, 145, 255), outline=GOLD_MID)
    # Hammer / spark hitting
    d.line([(14, 8), (22, 14)], fill=GOLD_LIGHT, width=3)
    d.point((16, 15), fill=(255, 255, 255, 255))
    d.point((17, 13), fill=GOLD_LIGHT)
    save_img(img, "icon_mode_forge")

    # Mode 3: Meister-Kette (Chain links)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 10, 18, 22], outline=GOLD_LIGHT, width=2)
    d.ellipse([14, 10, 26, 22], outline=CYAN_GLOW, width=2)
    save_img(img, "icon_mode_chain")

# 7. Start / Title Banner Art & Loading Screen Backdrop (480x270 pixel art 16:9 canvas)
def create_banners():
    # Title Crest Banner (480x160)
    w, h = 480, 160
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Outer Ornate Plaque
    plaque = [(20, 20), (w-20, 20), (w-10, 35), (w-10, h-35), (w-20, h-20), (20, h-20), (10, h-35), (10, 35)]
    d.polygon(plaque, fill=(18, 14, 26, 245), outline=GOLD_DARK)
    inner_plaque = [(24, 24), (w-24, 24), (w-14, 37), (w-14, h-37), (w-24, h-24), (24, h-24), (14, h-37), (14, 37)]
    d.polygon(inner_plaque, fill=(28, 22, 40, 245), outline=GOLD_MID)
    
    # Corner Gold Filigree
    for cx, cy in [(24, 24), (w-36, 24), (24, h-36), (w-36, h-36)]:
        d.rectangle([cx, cy, cx+12, cy+12], outline=GOLD_LIGHT)
        d.point((cx+6, cy+6), fill=RUBY_RED)
        
    # Crossed broadswords behind center
    mid_x, mid_y = w // 2, h // 2
    d.line([(mid_x - 70, mid_y - 35), (mid_x + 70, mid_y + 35)], fill=(180, 195, 220, 200), width=4)
    d.line([(mid_x - 70, mid_y + 35), (mid_x + 70, mid_y - 35)], fill=(180, 195, 220, 200), width=4)
    
    # Glowing Shield / Crest Centerpiece
    d.polygon([(mid_x - 30, mid_y - 30), (mid_x + 30, mid_y - 30), (mid_x + 24, mid_y + 15), (mid_x, mid_y + 36), (mid_x - 24, mid_y + 15)], fill=(18, 35, 70, 255), outline=GOLD_LIGHT)
    d.polygon([(mid_x - 24, mid_y - 26), (mid_x + 24, mid_y - 26), (mid_x + 18, mid_y + 12), (mid_x, mid_y + 30), (mid_x - 18, mid_y + 12)], fill=(32, 65, 130, 255))
    
    # Crown above shield
    d.polygon([(mid_x - 20, mid_y - 32), (mid_x - 16, mid_y - 44), (mid_x - 8, mid_y - 36), (mid_x, mid_y - 48), (mid_x + 8, mid_y - 36), (mid_x + 16, mid_y - 44), (mid_x + 20, mid_y - 32)], fill=GOLD_LIGHT, outline=GOLD_SHADOW)
    d.point((mid_x, mid_y - 42), fill=RUBY_RED)
    d.point((mid_x - 12, mid_y - 38), fill=CYAN_GLOW)
    d.point((mid_x + 12, mid_y - 38), fill=CYAN_GLOW)
    
    save_img(img, "title_banner_art")

    # Loading Screen Dungeon Gate / Ancient Math Portal (480x270)
    w, h = 480, 270
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    
    # Deep gradient background
    for y in range(h):
        ratio = y / float(h)
        r = int(10 + ratio * 15)
        g = int(8 + ratio * 10)
        b = int(22 + ratio * 28)
        d.line([(0, y), (w, y)], fill=(r, g, b, 255))
        
    # Ancient Stone Archway in center
    cx, cy = w // 2, h // 2 + 10
    arch_w, arch_h = 160, 180
    
    # Torches on sides
    for tx in [cx - arch_w - 20, cx + arch_w + 20]:
        # Sconce
        d.rectangle([tx - 4, cy - 20, tx + 4, cy + 10], fill=(60, 50, 40, 255), outline=(30, 25, 20, 255))
        # Flame glow
        d.ellipse([tx - 12, cy - 35, tx + 12, cy - 15], fill=(255, 140, 30, 180))
        d.ellipse([tx - 6, cy - 32, tx + 6, cy - 18], fill=(255, 240, 120, 255))
        
    # Stone pillars
    d.rectangle([cx - arch_w, cy - arch_h // 2, cx - arch_w + 32, cy + arch_h // 2 + 20], fill=(45, 38, 55, 255), outline=STONE_BORDER)
    d.rectangle([cx + arch_w - 32, cy - arch_h // 2, cx + arch_w, cy + arch_h // 2 + 20], fill=(45, 38, 55, 255), outline=STONE_BORDER)
    # Arch Curve
    d.arc([cx - arch_w, cy - arch_h // 2 - 30, cx + arch_w, cy + arch_h // 2], 180, 360, fill=GOLD_MID, width=12)
    
    # Glowing Math Portal vortex inside
    d.ellipse([cx - arch_w + 36, cy - arch_h // 2 + 10, cx + arch_w - 36, cy + arch_h // 2 + 10], fill=(25, 18, 50, 255), outline=CYAN_GLOW)
    d.ellipse([cx - 80, cy - 60, cx + 80, cy + 70], fill=(45, 25, 95, 255), outline=(120, 60, 220, 255))
    d.ellipse([cx - 45, cy - 35, cx + 45, cy + 45], fill=(70, 45, 140, 255), outline=CYAN_GLOW)
    d.ellipse([cx - 18, cy - 12, cx + 18, cy + 20], fill=(160, 230, 255, 255))
    
    save_img(img, "loading_screen_art")

if __name__ == "__main__":
    create_rpg_menu_frame()
    create_slot_frames()
    create_gold_button()
    create_knight_pedestal()
    create_stat_icons()
    create_mode_icons()
    create_banners()
    print("\nAll Pixel-Art UI assets generated successfully!")
