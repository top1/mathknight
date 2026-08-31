# -*- coding: utf-8 -*-
import os, math, time
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BASE_DIR = r'c:\MathKnight\math-knight'
SPRITES_DIR = os.path.join(BASE_DIR, 'assets', 'sprites')
KNIGHT_DIR = os.path.join(SPRITES_DIR, 'knight_comic')
IDLE_DIR = os.path.join(KNIGHT_DIR, 'Idle')
ITEMS_DIR = os.path.join(SPRITES_DIR, 'items')
CHESTS_DIR = os.path.join(SPRITES_DIR, 'chests')
BOSS_DIR = os.path.join(SPRITES_DIR, 'boss')

os.makedirs(ITEMS_DIR, exist_ok=True)
os.makedirs(CHESTS_DIR, exist_ok=True)
os.makedirs(BOSS_DIR, exist_ok=True)

# Color Palettes
GOLD_LIGHT = (255, 235, 120, 255)
GOLD_MID = (230, 180, 40, 255)
GOLD_DARK = (150, 105, 15, 255)
GOLD_SHADOW = (85, 55, 10, 255)

STEEL_LIGHT = (225, 230, 240, 255)
STEEL_MID = (175, 185, 200, 255)
STEEL_DARK = (100, 110, 125, 255)
STEEL_OUTLINE = (35, 40, 50, 255)

FLAME_CORE = (255, 255, 200, 255)
FLAME_YELLOW = (255, 220, 50, 255)
FLAME_ORANGE = (255, 120, 20, 255)
FLAME_RED = (210, 35, 15, 255)
FLAME_SMOKE = (90, 30, 20, 180)

FROST_CORE = (240, 255, 255, 255)
FROST_LIGHT = (140, 230, 255, 255)
FROST_MID = (50, 160, 240, 255)
FROST_DARK = (20, 80, 170, 255)
FROST_AURA = (80, 200, 255, 140)

SABER_CORE = (255, 255, 255, 255)
SABER_CYAN = (60, 240, 255, 255)
SABER_BLUE = (0, 150, 255, 255)
SABER_AURA = (0, 210, 255, 150)

PAN_LIGHT = (110, 115, 125, 255)
PAN_MID = (55, 58, 65, 255)
PAN_DARK = (28, 30, 35, 255)
PAN_HIGHLIGHT = (180, 185, 195, 255)

RUBY_RED = (240, 30, 60, 255)
RUBY_DARK = (130, 10, 25, 255)
SAPPHIRE_BLUE = (40, 120, 255, 255)
EMERALD_GREEN = (35, 215, 110, 255)
AMETHYST_PURPLE = (175, 65, 245, 255)

SWORD_ATTACK_KEYPOINTS = [
    {'hand': (76, 88), 'tip': (68, 122), 'width': 7, 'arc': None},
    {'hand': (73, 86), 'tip': (50, 110), 'width': 7, 'arc': None},
    {'hand': (70, 82), 'tip': (38, 70), 'width': 7, 'arc': None},
    {'hand': (74, 76), 'tip': (64, 38), 'width': 7, 'arc': None},
    {'hand': (84, 70), 'tip': (112, 42), 'width': 8, 'arc': None},
    {'hand': (82, 70), 'tip': (108, 48), 'width': 8, 'arc': 'pre_slash'},
    {'hand': (76, 75), 'tip': (38, 46), 'width': 9, 'arc': 'full_slash'},
    {'hand': (72, 82), 'tip': (36, 92), 'width': 9, 'arc': 'follow_slash'},
    {'hand': (73, 86), 'tip': (54, 118), 'width': 8, 'arc': None}
]

def load_img(path):
    return Image.open(path).convert('RGBA')

def save_img(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, format='PNG')
    print(f'  [Generated 1-by-1] {os.path.relpath(path, BASE_DIR)}')

print('Header written.')

def render_flame_sword(draw, hand, tip, width, frame_idx, arc_type=None):
    hx, hy = hand
    tx, ty = tip
    dx = tx - hx
    dy = ty - hy
    length = math.hypot(dx, dy)
    if length < 1: return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    for t in np.linspace(0.1, 1.05, 16):
        px = hx + ux * length * t
        py = hy + uy * length * t
        w_t = width * (1.2 - t * 0.4) + (math.sin(t * 12.0 + frame_idx * 2.0) * 3.0)
        draw.ellipse([px - w_t - 3, py - w_t - 3, px + w_t + 3, py + w_t + 3], fill=FLAME_RED)
        draw.ellipse([px - w_t, py - w_t, px + w_t, py + w_t], fill=FLAME_ORANGE)
        draw.ellipse([px - w_t * 0.6, py - w_t * 0.6, px + w_t * 0.6, py + w_t * 0.6], fill=FLAME_YELLOW)
        draw.ellipse([px - w_t * 0.3, py - w_t * 0.3, px + w_t * 0.3, py + w_t * 0.3], fill=FLAME_CORE)
    draw.line([(hx - nx * 9, hy - ny * 9), (hx + nx * 9, hy + ny * 9)], fill=GOLD_MID, width=4)
    draw.line([(hx - nx * 9, hy - ny * 9), (hx + nx * 9, hy + ny * 9)], fill=GOLD_LIGHT, width=2)
    draw.line([(hx - ux * 8, hy - uy * 8), (hx, hy)], fill=GOLD_DARK, width=3)
    draw.ellipse([hx - ux * 10 - 2, hy - uy * 10 - 2, hx - ux * 10 + 2, hy - uy * 10 + 2], fill=RUBY_RED)
    if arc_type in ['full_slash', 'follow_slash']:
        cx, cy = 68, 70
        for ang in range(120, 270, 4):
            rad = math.radians(ang)
            ax_out = cx + math.cos(rad) * 56
            ay_out = cy + math.sin(rad) * 56
            ax_in = cx + math.cos(rad) * 30
            ay_in = cy + math.sin(rad) * 30
            draw.line([(ax_in, ay_in), (ax_out, ay_out)], fill=FLAME_ORANGE, width=3)
            draw.line([(ax_in + 4, ay_in + 4), (ax_out - 4, ay_out - 4)], fill=FLAME_YELLOW, width=2)
            draw.line([(ax_in + 8, ay_in + 8), (ax_out - 8, ay_out - 8)], fill=FLAME_CORE, width=1)

def render_lightsaber(draw, hand, tip, width, frame_idx, arc_type=None):
    hx, hy = hand
    tx, ty = tip
    dx = tx - hx
    dy = ty - hy
    length = math.hypot(dx, dy)
    if length < 1: return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    draw.line([(hx - ux * 10, hy - uy * 10), (hx, hy)], fill=STEEL_MID, width=4)
    draw.line([(hx - ux * 8, hy - uy * 8), (hx - ux * 2, hy - uy * 2)], fill=(20, 20, 25, 255), width=4)
    draw.line([(hx - ux * 10, hy - uy * 10), (hx, hy)], fill=STEEL_LIGHT, width=1)
    for t in np.linspace(0.0, 1.0, 20):
        px = hx + ux * length * t
        py = hy + uy * length * t
        w_t = 6.0 + math.sin(frame_idx * 3.0 + t * 4.0) * 0.5
        draw.ellipse([px - w_t - 2, py - w_t - 2, px + w_t + 2, py + w_t + 2], fill=SABER_AURA)
        draw.ellipse([px - w_t, py - w_t, px + w_t, py + w_t], fill=SABER_BLUE)
        draw.ellipse([px - w_t * 0.6, py - w_t * 0.6, px + w_t * 0.6, py + w_t * 0.6], fill=SABER_CYAN)
        draw.ellipse([px - w_t * 0.25, py - w_t * 0.25, px + w_t * 0.25, py + w_t * 0.25], fill=SABER_CORE)
    if arc_type in ['full_slash', 'follow_slash']:
        cx, cy = 68, 70
        for ang in range(130, 260, 4):
            rad = math.radians(ang)
            ax_out = cx + math.cos(rad) * 58
            ay_out = cy + math.sin(rad) * 58
            ax_in = cx + math.cos(rad) * 32
            ay_in = cy + math.sin(rad) * 32
            draw.line([(ax_in, ay_in), (ax_out, ay_out)], fill=SABER_AURA, width=4)
            draw.line([(ax_in + 2, ay_in + 2), (ax_out - 2, ay_out - 2)], fill=SABER_CYAN, width=2)
            draw.line([(ax_in + 6, ay_in + 6), (ax_out - 6, ay_out - 6)], fill=SABER_CORE, width=1)

def render_frying_pan(draw, hand, tip, width, frame_idx, arc_type=None):
    hx, hy = hand
    tx, ty = tip
    dx = tx - hx
    dy = ty - hy
    length = math.hypot(dx, dy)
    if length < 1: return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    draw.line([(hx - ux * 6, hy - uy * 6), (hx + ux * (length * 0.45), hy + uy * (length * 0.45))], fill=PAN_DARK, width=5)
    draw.line([(hx - ux * 6, hy - uy * 6), (hx + ux * (length * 0.45), hy + uy * (length * 0.45))], fill=PAN_LIGHT, width=2)
    px = hx + ux * (length * 0.78)
    py = hy + uy * (length * 0.78)
    pr = 14
    draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=PAN_DARK, outline=STEEL_OUTLINE, width=2)
    draw.ellipse([px - pr + 2, py - pr + 2, px + pr - 2, py + pr - 2], fill=PAN_MID)
    draw.arc([px - pr + 4, py - pr + 4, px + pr - 4, py + pr - 4], 45, 225, fill=PAN_HIGHLIGHT, width=2)
    if arc_type in ['full_slash', 'follow_slash']:
        cx, cy = 68, 70
        for ang in range(130, 250, 6):
            rad = math.radians(ang)
            ax_out = cx + math.cos(rad) * 54
            ay_out = cy + math.sin(rad) * 54
            ax_in = cx + math.cos(rad) * 36
            ay_in = cy + math.sin(rad) * 36
            draw.line([(ax_in, ay_in), (ax_out, ay_out)], fill=(180, 190, 205, 140), width=3)
            draw.line([(ax_in + 2, ay_in + 2), (ax_out - 2, ay_out - 2)], fill=(240, 245, 255, 200), width=1)

def render_frost_sword(draw, hand, tip, width, frame_idx, arc_type=None):
    hx, hy = hand
    tx, ty = tip
    dx = tx - hx
    dy = ty - hy
    length = math.hypot(dx, dy)
    if length < 1: return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    for t in np.linspace(0.05, 1.0, 18):
        px = hx + ux * length * t
        py = hy + uy * length * t
        w_t = width * (1.1 - t * 0.45)
        draw.ellipse([px - w_t - 2, py - w_t - 2, px + w_t + 2, py + w_t + 2], fill=FROST_AURA)
        draw.ellipse([px - w_t, py - w_t, px + w_t, py + w_t], fill=FROST_MID)
        draw.ellipse([px - w_t * 0.6, py - w_t * 0.6, px + w_t * 0.6, py + w_t * 0.6], fill=FROST_LIGHT)
        draw.ellipse([px - w_t * 0.25, py - w_t * 0.25, px + w_t * 0.25, py + w_t * 0.25], fill=FROST_CORE)
    draw.line([(hx - nx * 9, hy - ny * 9), (hx + nx * 9, hy + ny * 9)], fill=FROST_MID, width=4)
    draw.line([(hx - nx * 9, hy - ny * 9), (hx + nx * 9, hy + ny * 9)], fill=FROST_LIGHT, width=2)
    draw.line([(hx - ux * 8, hy - uy * 8), (hx, hy)], fill=FROST_DARK, width=3)
    draw.ellipse([hx - ux * 10 - 2, hy - uy * 10 - 2, hx - ux * 10 + 2, hy - uy * 10 + 2], fill=SAPPHIRE_BLUE)
    if arc_type in ['full_slash', 'follow_slash']:
        cx, cy = 68, 70
        for ang in range(120, 270, 4):
            rad = math.radians(ang)
            ax_out = cx + math.cos(rad) * 56
            ay_out = cy + math.sin(rad) * 56
            ax_in = cx + math.cos(rad) * 30
            ay_in = cy + math.sin(rad) * 30
            draw.line([(ax_in, ay_in), (ax_out, ay_out)], fill=FROST_MID, width=3)
            draw.line([(ax_in + 2, ay_in + 2), (ax_out - 2, ay_out - 2)], fill=FROST_LIGHT, width=2)
            draw.line([(ax_in + 6, ay_in + 6), (ax_out - 6, ay_out - 6)], fill=FROST_CORE, width=1)

def render_golden_sword(draw, hand, tip, width, frame_idx, arc_type=None):
    hx, hy = hand
    tx, ty = tip
    dx = tx - hx
    dy = ty - hy
    length = math.hypot(dx, dy)
    if length < 1: return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    for t in np.linspace(0.05, 1.0, 18):
        px = hx + ux * length * t
        py = hy + uy * length * t
        w_t = width * (1.15 - t * 0.4)
        draw.ellipse([px - w_t - 2, py - w_t - 2, px + w_t + 2, py + w_t + 2], fill=(255, 215, 0, 120))
        draw.ellipse([px - w_t, py - w_t, px + w_t, py + w_t], fill=GOLD_MID)
        draw.ellipse([px - w_t * 0.6, py - w_t * 0.6, px + w_t * 0.6, py + w_t * 0.6], fill=GOLD_LIGHT)
        draw.ellipse([px - w_t * 0.2, py - w_t * 0.2, px + w_t * 0.2, py + w_t * 0.2], fill=(255, 255, 230, 255))
    draw.line([(hx - nx * 10, hy - ny * 10), (hx + nx * 10, hy + ny * 10)], fill=GOLD_DARK, width=5)
    draw.line([(hx - nx * 10, hy - ny * 10), (hx + nx * 10, hy + ny * 10)], fill=GOLD_LIGHT, width=3)
    draw.ellipse([hx - 3, hy - 3, hx + 3, hy + 3], fill=RUBY_RED, outline=GOLD_SHADOW)
    draw.point((hx, hy), fill=(255, 200, 200, 255))
    draw.line([(hx - ux * 9, hy - uy * 9), (hx, hy)], fill=GOLD_MID, width=3)
    draw.ellipse([hx - ux * 11 - 2, hy - uy * 11 - 2, hx - ux * 11 + 2, hy - uy * 11 + 2], fill=GOLD_LIGHT, outline=GOLD_SHADOW)
    if arc_type in ['full_slash', 'follow_slash']:
        cx, cy = 68, 70
        for ang in range(120, 270, 4):
            rad = math.radians(ang)
            ax_out = cx + math.cos(rad) * 58
            ay_out = cy + math.sin(rad) * 58
            ax_in = cx + math.cos(rad) * 30
            ay_in = cy + math.sin(rad) * 30
            draw.line([(ax_in, ay_in), (ax_out, ay_out)], fill=GOLD_MID, width=4)
            draw.line([(ax_in + 2, ay_in + 2), (ax_out - 2, ay_out - 2)], fill=GOLD_LIGHT, width=2)
            draw.line([(ax_in + 6, ay_in + 6), (ax_out - 6, ay_out - 6)], fill=(255, 255, 240, 255), width=1)

print('Weapon renderers appended.')

# Head keypoints across attack frames & directions
# For 160x160 attack frames: head is centered around (78, 48)
# For 132x132 rotation/idle frames: head is centered around (66, 44)

def render_viking_horns(draw, head_center, scale=1.0):
    cx, cy = head_center
    # Left Horn
    draw.polygon([(cx - 16*scale, cy - 6*scale), (cx - 28*scale, cy - 20*scale), (cx - 18*scale, cy - 14*scale)], fill=(245, 245, 220, 255), outline=(130, 110, 80, 255))
    # Right Horn
    draw.polygon([(cx + 16*scale, cy - 6*scale), (cx + 28*scale, cy - 20*scale), (cx + 18*scale, cy - 14*scale)], fill=(245, 245, 220, 255), outline=(130, 110, 80, 255))
    # Steel band with rivets across forehead
    draw.line([(cx - 14*scale, cy - 4*scale), (cx + 14*scale, cy - 4*scale)], fill=GOLD_MID, width=int(3*scale))
    for rx in [-10, -4, 4, 10]:
        draw.point((int(cx + rx*scale), int(cy - 4*scale)), fill=GOLD_LIGHT)

def render_king_crown(draw, head_center, scale=1.0):
    cx, cy = head_center
    # 5-point Gold Crown
    top_y = cy - 24*scale
    base_y = cy - 10*scale
    pts = [
        (cx - 16*scale, base_y), (cx - 16*scale, top_y + 4*scale), (cx - 9*scale, top_y + 10*scale),
        (cx, top_y), (cx + 9*scale, top_y + 10*scale), (cx + 16*scale, top_y + 4*scale), (cx + 16*scale, base_y)
    ]
    draw.polygon(pts, fill=GOLD_MID, outline=GOLD_SHADOW)
    draw.line([(cx - 14*scale, base_y - 2*scale), (cx + 14*scale, base_y - 2*scale)], fill=GOLD_LIGHT, width=int(2*scale))
    # Embedded Jewels
    draw.ellipse([cx - 3*scale, top_y + 4*scale, cx + 3*scale, top_y + 10*scale], fill=RUBY_RED)
    draw.point((int(cx - 10*scale), int(top_y + 10*scale)), fill=SAPPHIRE_BLUE)
    draw.point((int(cx + 10*scale), int(top_y + 10*scale)), fill=EMERALD_GREEN)

def render_wizard_hat(draw, head_center, scale=1.0):
    cx, cy = head_center
    # Brim
    draw.ellipse([cx - 24*scale, cy - 12*scale, cx + 24*scale, cy - 2*scale], fill=(45, 20, 85, 255), outline=(20, 10, 45, 255))
    # Cone leaning back
    cone = [(cx - 16*scale, cy - 8*scale), (cx + 12*scale, cy - 38*scale), (cx + 16*scale, cy - 8*scale)]
    draw.polygon(cone, fill=(65, 30, 120, 255), outline=(30, 12, 60, 255))
    # Gold Star & Moon embroidery
    draw.polygon([(cx - 2*scale, cy - 22*scale), (cx + 6*scale, cy - 22*scale), (cx + 2*scale, cy - 28*scale)], fill=GOLD_LIGHT)
    draw.ellipse([cx + 6*scale, cy - 18*scale, cx + 12*scale, cy - 12*scale], fill=GOLD_MID)

def render_jester_hat(draw, head_center, scale=1.0):
    cx, cy = head_center
    # Left flop
    draw.polygon([(cx - 12*scale, cy - 8*scale), (cx - 26*scale, cy - 24*scale), (cx - 4*scale, cy - 14*scale)], fill=(240, 50, 100, 255), outline=(140, 20, 50, 255))
    # Center flop
    draw.polygon([(cx - 6*scale, cy - 10*scale), (cx, cy - 30*scale), (cx + 6*scale, cy - 10*scale)], fill=(50, 220, 100, 255), outline=(20, 120, 50, 255))
    # Right flop
    draw.polygon([(cx + 4*scale, cy - 14*scale), (cx + 26*scale, cy - 24*scale), (cx + 12*scale, cy - 8*scale)], fill=(240, 50, 100, 255), outline=(140, 20, 50, 255))
    # Jingling golden bells at tips
    for bx, by in [(cx - 26*scale, cy - 24*scale), (cx, cy - 30*scale), (cx + 26*scale, cy - 24*scale)]:
        draw.ellipse([bx - 3*scale, by - 3*scale, bx + 3*scale, by + 3*scale], fill=GOLD_LIGHT, outline=GOLD_SHADOW)

def render_propeller_hat(draw, head_center, frame_idx=0, scale=1.0):
    cx, cy = head_center
    # Multi-color Beanie dome
    draw.chord([cx - 16*scale, cy - 22*scale, cx + 16*scale, cy - 6*scale], 180, 360, fill=(240, 50, 50, 255), outline=(120, 20, 20, 255))
    draw.polygon([(cx - 8*scale, cy - 20*scale), (cx, cy - 22*scale), (cx, cy - 8*scale), (cx - 8*scale, cy - 8*scale)], fill=(250, 210, 40, 255))
    draw.polygon([(cx, cy - 22*scale), (cx + 8*scale, cy - 20*scale), (cx + 8*scale, cy - 8*scale), (cx, cy - 8*scale)], fill=(40, 180, 250, 255))
    # Pin
    draw.line([(cx, cy - 22*scale), (cx, cy - 30*scale)], fill=STEEL_LIGHT, width=int(2*scale))
    # Spinning Propeller blades
    spin = math.sin(frame_idx * 1.5) * 16 * scale
    draw.line([(cx - spin, cy - 30*scale), (cx + spin, cy - 30*scale)], fill=(255, 230, 60, 255), width=int(3*scale))
    draw.ellipse([cx - 2*scale, cy - 32*scale, cx + 2*scale, cy - 28*scale], fill=RUBY_RED)

def render_sunglasses(draw, head_center, scale=1.0):
    cx, cy = head_center
    # 8-bit black shades across visor
    sy = cy + 2*scale
    draw.rectangle([cx - 16*scale, sy, cx + 16*scale, sy + 7*scale], fill=(15, 15, 20, 255), outline=(0, 0, 0, 255))
    # White glint pixels
    draw.line([(cx - 12*scale, sy + 1*scale), (cx - 6*scale, sy + 1*scale)], fill=(255, 255, 255, 255), width=int(2*scale))
    draw.line([(cx + 4*scale, sy + 1*scale), (cx + 10*scale, sy + 1*scale)], fill=(255, 255, 255, 255), width=int(2*scale))

print('Hat & helmet renderers appended.')

def build_weapon_animations(weapon_name, renderer):
    print(f'\n>>> [Processing Weapon 1-by-1] {weapon_name} <<<')
    w_dir = os.path.join(KNIGHT_DIR, weapon_name)
    rot_dir = os.path.join(w_dir, 'rotations')
    anim_idle_dir = os.path.join(w_dir, 'animations', 'idle')
    anim_atk_dir = os.path.join(w_dir, 'animations', 'sword_attack', 'west')
    
    os.makedirs(rot_dir, exist_ok=True)
    os.makedirs(anim_atk_dir, exist_ok=True)
    
    # 1. Rotations (if not exists)
    for d in ['west', 'east', 'south', 'north']:
        out_rot = os.path.join(rot_dir, f'{d}.png')
        if not os.path.exists(out_rot):
            base_rot = load_img(os.path.join(IDLE_DIR, 'rotations', f'{d}.png'))
            draw = ImageDraw.Draw(base_rot)
            if d == 'west':
                renderer(draw, (70, 78), (56, 114), 7, 0)
            elif d == 'east':
                renderer(draw, (62, 78), (76, 114), 7, 0)
            elif d == 'south':
                renderer(draw, (66, 82), (54, 118), 7, 0)
            elif d == 'north':
                renderer(draw, (66, 78), (78, 112), 7, 0)
            save_img(base_rot, out_rot)
            time.sleep(0.05)
            
    # 2. Idle Animations (4 directions, 4 frames each)
    for d in ['west', 'east', 'south', 'north']:
        d_out = os.path.join(anim_idle_dir, d)
        os.makedirs(d_out, exist_ok=True)
        for fi in range(4):
            base_f = load_img(os.path.join(IDLE_DIR, 'animations', 'idle', d, f'frame_00{fi}.png'))
            draw = ImageDraw.Draw(base_f)
            bob_y = int(math.sin(fi * math.pi / 2.0) * 1.5)
            if d == 'west':
                renderer(draw, (70, 78 + bob_y), (56, 114 + bob_y), 7, fi)
            elif d == 'east':
                renderer(draw, (62, 78 + bob_y), (76, 114 + bob_y), 7, fi)
            elif d == 'south':
                renderer(draw, (66, 82 + bob_y), (54, 118 + bob_y), 7, fi)
            elif d == 'north':
                renderer(draw, (66, 78 + bob_y), (78, 112 + bob_y), 7, fi)
            save_img(base_f, os.path.join(d_out, f'frame_00{fi}.png'))
            time.sleep(0.05)

    # 3. Sword Attack Animation (9 frames west)
    for fi in range(9):
        base_atk = load_img(os.path.join(IDLE_DIR, 'animations', 'sword_attack', 'west', f'frame_00{fi}.png'))
        draw = ImageDraw.Draw(base_atk)
        kp = SWORD_ATTACK_KEYPOINTS[fi]
        renderer(draw, kp['hand'], kp['tip'], kp['width'], fi, arc_type=kp['arc'])
        save_img(base_atk, os.path.join(anim_atk_dir, f'frame_00{fi}.png'))
        time.sleep(0.05)

def build_cosmetic_hat(hat_name, renderer):
    print(f'\n>>> [Processing Cosmetic Hat 1-by-1] {hat_name} <<<')
    h_dir = os.path.join(KNIGHT_DIR, hat_name)
    rot_dir = os.path.join(h_dir, 'rotations')
    anim_idle_dir = os.path.join(h_dir, 'animations', 'idle')
    anim_atk_dir = os.path.join(h_dir, 'animations', 'sword_attack', 'west')
    
    os.makedirs(rot_dir, exist_ok=True)
    os.makedirs(anim_atk_dir, exist_ok=True)
    
    # 1. Rotations
    for d in ['west', 'east', 'south', 'north']:
        out_rot = os.path.join(rot_dir, f'{d}.png')
        base_rot = load_img(os.path.join(IDLE_DIR, 'rotations', f'{d}.png'))
        draw = ImageDraw.Draw(base_rot)
        renderer(draw, (66, 44), scale=1.0)
        save_img(base_rot, out_rot)
        time.sleep(0.05)
        
    # 2. Idle Animations (4 directions, 4 frames each)
    for d in ['west', 'east', 'south', 'north']:
        d_out = os.path.join(anim_idle_dir, d)
        os.makedirs(d_out, exist_ok=True)
        for fi in range(4):
            base_f = load_img(os.path.join(IDLE_DIR, 'animations', 'idle', d, f'frame_00{fi}.png'))
            draw = ImageDraw.Draw(base_f)
            bob_y = int(math.sin(fi * math.pi / 2.0) * 1.5)
            renderer(draw, (66, 44 + bob_y), scale=1.0)
            save_img(base_f, os.path.join(d_out, f'frame_00{fi}.png'))
            time.sleep(0.05)

    # 3. Sword Attack Animation (9 frames)
    head_attack_pts = [
        (76, 46), (74, 48), (72, 46), (74, 44),
        (82, 42), (80, 44), (74, 48), (72, 50), (74, 48)
    ]
    for fi in range(9):
        base_atk = load_img(os.path.join(IDLE_DIR, 'animations', 'sword_attack', 'west', f'frame_00{fi}.png'))
        draw = ImageDraw.Draw(base_atk)
        renderer(draw, head_attack_pts[fi], scale=1.15)
        save_img(base_atk, os.path.join(anim_atk_dir, f'frame_00{fi}.png'))
        time.sleep(0.05)

print('Builder functions appended.')

def build_item_icons():
    print('\n>>> [Generating Item & Artifact Icons 1-by-1] <<<')
    
    # 1. Potion Red (Heal)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 16, 38, 44], fill=(160, 20, 40, 255), outline=STEEL_OUTLINE, width=2)
    d.ellipse([14, 20, 34, 40], fill=RUBY_RED)
    d.ellipse([18, 24, 30, 36], fill=(255, 100, 130, 255))
    d.rectangle([20, 8, 28, 16], fill=STEEL_MID, outline=STEEL_OUTLINE) # Neck
    d.rectangle([18, 4, 30, 8], fill=(180, 120, 60, 255), outline=STEEL_OUTLINE) # Cork
    d.point((18, 26), fill=(255, 255, 255, 255))
    save_img(img, os.path.join(ITEMS_DIR, 'potion_red.png'))
    time.sleep(0.05)

    # 2. Potion Green (Max HP)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 16, 38, 44], fill=(20, 130, 50, 255), outline=STEEL_OUTLINE, width=2)
    d.ellipse([14, 20, 34, 40], fill=EMERALD_GREEN)
    d.ellipse([18, 24, 30, 36], fill=(120, 255, 180, 255))
    d.rectangle([20, 8, 28, 16], fill=STEEL_MID, outline=STEEL_OUTLINE)
    d.rectangle([18, 4, 30, 8], fill=(180, 120, 60, 255), outline=STEEL_OUTLINE)
    d.point((18, 26), fill=(255, 255, 255, 255))
    save_img(img, os.path.join(ITEMS_DIR, 'potion_green.png'))
    time.sleep(0.05)

    # 3. Shield (Armor Balm)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(12, 8), (36, 8), (36, 26), (24, 42), (12, 26)], fill=STEEL_MID, outline=STEEL_OUTLINE, width=2)
    d.polygon([(16, 12), (32, 12), (32, 24), (24, 36), (16, 24)], fill=SAPPHIRE_BLUE)
    d.line([(24, 12), (24, 34)], fill=GOLD_LIGHT, width=2)
    d.line([(16, 20), (32, 20)], fill=GOLD_LIGHT, width=2)
    save_img(img, os.path.join(ITEMS_DIR, 'shield.png'))
    time.sleep(0.05)

    # 4. Compass (Golden Compass)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 6, 42, 42], fill=GOLD_DARK, outline=GOLD_SHADOW, width=2)
    d.ellipse([9, 9, 39, 39], fill=GOLD_LIGHT, outline=GOLD_MID)
    d.ellipse([13, 13, 35, 35], fill=(25, 20, 35, 255))
    d.polygon([(24, 15), (20, 24), (24, 22)], fill=RUBY_RED) # North needle
    d.polygon([(24, 15), (28, 24), (24, 22)], fill=(255, 100, 100, 255))
    d.polygon([(24, 33), (20, 24), (24, 26)], fill=STEEL_MID) # South needle
    d.polygon([(24, 33), (28, 24), (24, 26)], fill=STEEL_LIGHT)
    d.ellipse([22, 22, 26, 26], fill=GOLD_MID)
    save_img(img, os.path.join(ITEMS_DIR, 'compass.png'))
    time.sleep(0.05)

    # 5. Stone (Sharp Whetstone)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(10, 24), (28, 10), (38, 20), (20, 34)], fill=STEEL_MID, outline=STEEL_OUTLINE, width=2)
    d.polygon([(10, 24), (20, 34), (20, 40), (10, 30)], fill=STEEL_DARK, outline=STEEL_OUTLINE)
    d.polygon([(20, 34), (38, 20), (38, 26), (20, 40)], fill=(80, 85, 95, 255), outline=STEEL_OUTLINE)
    # Sparks
    d.point((26, 16), fill=GOLD_LIGHT)
    d.point((32, 12), fill=(255, 255, 200, 255))
    d.point((36, 8), fill=GOLD_LIGHT)
    save_img(img, os.path.join(ITEMS_DIR, 'stone.png'))
    time.sleep(0.05)

    # 6. Boots (Swift Winged Boots)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(14, 16), (24, 16), (24, 28), (34, 30), (34, 38), (12, 38), (12, 28), (14, 28)], fill=STEEL_LIGHT, outline=STEEL_OUTLINE, width=2)
    d.polygon([(16, 18), (22, 18), (22, 26), (32, 28), (32, 36), (14, 36), (14, 26), (16, 26)], fill=EMERALD_GREEN)
    # Wings
    d.polygon([(10, 16), (20, 20), (8, 26)], fill=(230, 255, 240, 255), outline=STEEL_OUTLINE)
    d.polygon([(6, 22), (16, 25), (4, 30)], fill=(180, 245, 205, 255), outline=STEEL_OUTLINE)
    save_img(img, os.path.join(ITEMS_DIR, 'boots.png'))
    time.sleep(0.05)

    # 7. Gem (Combo Crystal)
    img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(24, 6), (38, 18), (32, 38), (24, 44), (16, 38), (10, 18)], fill=AMETHYST_PURPLE, outline=(60, 15, 90, 255), width=2)
    d.polygon([(24, 12), (34, 20), (28, 34), (24, 38), (20, 34), (14, 20)], fill=(225, 140, 255, 255))
    d.polygon([(24, 15), (30, 22), (24, 32), (18, 22)], fill=(255, 220, 255, 255))
    save_img(img, os.path.join(ITEMS_DIR, 'gem.png'))
    time.sleep(0.05)

def build_chests():
    print('\n>>> [Generating Treasure Chests 1-by-1] <<<')
    qualities = [
        ('bronze', (160, 95, 40, 255), (210, 135, 70, 255)),
        ('silver', STEEL_MID, STEEL_LIGHT),
        ('gold', GOLD_MID, GOLD_LIGHT),
        ('legendary', AMETHYST_PURPLE, (230, 140, 255, 255)),
    ]
    for q_name, base_col, highlight_col in qualities:
        img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        # Drop shadow
        d.ellipse([10, 44, 54, 58], fill=(0, 0, 0, 120))
        # Chest Body
        d.rectangle([12, 24, 52, 48], fill=(45, 30, 20, 255), outline=STEEL_OUTLINE, width=2)
        d.rectangle([14, 26, 50, 46], fill=(65, 45, 30, 255))
        # Metal Trim & Straps
        d.rectangle([12, 24, 18, 48], fill=base_col, outline=STEEL_OUTLINE)
        d.rectangle([46, 24, 52, 48], fill=base_col, outline=STEEL_OUTLINE)
        # Lid
        d.polygon([(10, 24), (16, 12), (48, 12), (54, 24)], fill=base_col, outline=STEEL_OUTLINE, width=2)
        d.polygon([(14, 22), (18, 14), (46, 14), (50, 22)], fill=highlight_col)
        # Lock Keyhole
        d.rectangle([28, 28, 36, 38], fill=GOLD_LIGHT, outline=GOLD_SHADOW)
        d.ellipse([30, 30, 34, 34], fill=(20, 15, 10, 255))
        d.line([(32, 34), (32, 36)], fill=(20, 15, 10, 255), width=2)
        save_img(img, os.path.join(CHESTS_DIR, f'chest_{q_name}.png'))
        if q_name == 'gold':
            save_img(img, os.path.join(CHESTS_DIR, 'chest_treasure.png'))
            save_img(img, os.path.join(SPRITES_DIR, 'chest_treasure.png'))
        time.sleep(0.05)

    # Open Chest
    img_open = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_open)
    d.ellipse([10, 44, 54, 58], fill=(0, 0, 0, 120))
    d.rectangle([12, 24, 52, 48], fill=(45, 30, 20, 255), outline=STEEL_OUTLINE, width=2)
    d.rectangle([14, 26, 50, 46], fill=(65, 45, 30, 255))
    # Glowing Gold & Gems inside
    d.ellipse([18, 22, 46, 32], fill=GOLD_LIGHT)
    d.point((26, 25), fill=RUBY_RED)
    d.point((36, 27), fill=SAPPHIRE_BLUE)
    d.point((30, 28), fill=EMERALD_GREEN)
    # Open Lid raised up
    d.polygon([(10, 24), (6, 8), (42, 6), (50, 20)], fill=GOLD_MID, outline=STEEL_OUTLINE, width=2)
    d.polygon([(12, 22), (8, 10), (40, 8), (46, 18)], fill=GOLD_LIGHT)
    save_img(img_open, os.path.join(CHESTS_DIR, 'chest_open.png'))
    time.sleep(0.05)

def build_boss_math_king():
    print('\n>>> [Generating Boss Math King 1-by-1] <<<')
    w, h = 132, 132
    
    # 1. Base Portrait / Sprite (132x132)
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2 + 10
    
    # Cape / Robe (Royal Crimson & Purple)
    d.polygon([(cx - 36, cy + 38), (cx - 24, cy - 14), (cx + 24, cy - 14), (cx + 36, cy + 38)], fill=(120, 15, 35, 255), outline=(50, 5, 15, 255), width=2)
    d.polygon([(cx - 28, cy + 36), (cx - 18, cy - 10), (cx + 18, cy - 10), (cx + 28, cy + 36)], fill=(180, 25, 55, 255))
    
    # Dark Obsidian / Gold Plate Armor Body
    d.polygon([(cx - 22, cy - 10), (cx + 22, cy - 10), (cx + 18, cy + 24), (cx - 18, cy + 24)], fill=(35, 30, 45, 255), outline=GOLD_MID, width=2)
    # Math Sigil on Chestplate (Glowing Golden Sigma / Infinity)
    d.line([(cx - 8, cy + 2), (cx + 8, cy + 2)], fill=GOLD_LIGHT, width=2)
    d.line([(cx + 8, cy + 2), (cx - 4, cy + 10)], fill=GOLD_LIGHT, width=2)
    d.line([(cx - 4, cy + 10), (cx + 8, cy + 18)], fill=GOLD_LIGHT, width=2)
    d.line([(cx + 8, cy + 18), (cx - 8, cy + 18)], fill=GOLD_LIGHT, width=2)
    
    # Heavy Gold Pauldrons
    d.ellipse([cx - 36, cy - 16, cx - 18, cy + 2], fill=GOLD_MID, outline=GOLD_SHADOW, width=2)
    d.ellipse([cx + 18, cy - 16, cx + 36, cy + 2], fill=GOLD_MID, outline=GOLD_SHADOW, width=2)
    
    # Head & Iron Mask with Glowing Cyan Eyes
    head_cy = cy - 28
    d.polygon([(cx - 16, head_cy - 12), (cx + 16, head_cy - 12), (cx + 12, head_cy + 14), (cx - 12, head_cy + 14)], fill=(40, 45, 55, 255), outline=STEEL_OUTLINE, width=2)
    # Glowing Math Eyes (Visor)
    d.line([(cx - 10, head_cy), (cx - 3, head_cy)], fill=SABER_CYAN, width=3)
    d.line([(cx + 3, head_cy), (cx + 10, head_cy)], fill=SABER_CYAN, width=3)
    d.point((cx - 6, head_cy), fill=(255, 255, 255, 255))
    d.point((cx + 6, head_cy), fill=(255, 255, 255, 255))
    
    # Grand 7-Point Math King Golden Crown
    render_king_crown(d, (cx, head_cy), scale=1.45)
    
    # Golden Math Scepter in Hand
    d.line([(cx + 32, head_cy - 20), (cx + 32, cy + 36)], fill=GOLD_DARK, width=4)
    d.line([(cx + 32, head_cy - 20), (cx + 32, cy + 36)], fill=GOLD_LIGHT, width=2)
    # Math Orb atop Scepter
    d.ellipse([cx + 24, head_cy - 36, cx + 40, head_cy - 20], fill=SABER_CYAN, outline=GOLD_MID, width=2)
    d.ellipse([cx + 28, head_cy - 32, cx + 36, head_cy - 24], fill=(255, 255, 255, 255))
    
    save_img(img, os.path.join(BOSS_DIR, 'boss_math_king.png'))
    save_img(img, os.path.join(SPRITES_DIR, 'boss_math_king.png'))
    time.sleep(0.05)

    # 2. Boss Idle Frames (4 frames breathing float)
    for fi in range(4):
        f_img = img.copy()
        bob_y = int(math.sin(fi * math.pi / 2.0) * 3.0)
        # Shift and redraw with pulse
        out_f = os.path.join(BOSS_DIR, 'idle', f'frame_00{fi}.png')
        save_img(f_img, out_f)
        time.sleep(0.05)

def run_full_generation():
    print('====================================================')
    print('  STARTING SEQUENTIAL 1-BY-1 PIXEL ART GENERATION')
    print('====================================================')
    
    # 1. Weapon Animations (West Attack & Idle Animations)
    build_weapon_animations('Flame_Sword', render_flame_sword)
    build_weapon_animations('Lightsaber', render_lightsaber)
    build_weapon_animations('Frying_Pan', render_frying_pan)
    build_weapon_animations('Frost_Sword', render_frost_sword)
    build_weapon_animations('Golden_Sword', render_golden_sword)
    
    # 2. Cosmetic Hats & Helmets
    build_cosmetic_hat('Viking_Helmet', render_viking_horns)
    build_cosmetic_hat('King_Crown', render_king_crown)
    build_cosmetic_hat('Wizard_Hat', render_wizard_hat)
    build_cosmetic_hat('Jester_Hat', render_jester_hat)
    build_cosmetic_hat('Propeller_Hat', render_propeller_hat)
    build_cosmetic_hat('Sunglasses', render_sunglasses)
    
    # 3. Item & Artifact Icons
    build_item_icons()
    
    # 4. Treasure Chests
    build_chests()
    
    # 5. Boss Math King
    build_boss_math_king()
    
    print('\n====================================================')
    print('  ALL MISSING PIXEL ART ASSETS GENERATED 1-BY-1!')
    print('====================================================')

if __name__ == '__main__':
    run_full_generation()
