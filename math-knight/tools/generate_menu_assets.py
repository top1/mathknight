import urllib.request
import json
import time
import os
import base64
import sys

API_KEY = "986cf6b7-7da0-42a7-901c-0c6e0ef34d66"
URL = "https://api.pixellab.ai/mcp"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites", "ui")

def call_mcp_tool(tool_name: str, arguments: dict):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": int(time.time() * 1000) % 1000000,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        }
    }
    req = urllib.request.Request(URL, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            for line in raw.split("\n"):
                if line.startswith("data:"):
                    return json.loads(line[5:].strip())
    except Exception as e:
        print(f"Error calling {tool_name}: {e}")
    return None

def download_image_from_url(img_url: str, output_path: str):
    headers = {"User-Agent": "Mozilla/5.0"}
    req = urllib.request.Request(img_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        with open(output_path, "wb") as f:
            f.write(resp.read())
    print(f"Saved: {output_path}")

def generate_ui_panel(name: str, desc: str, width: int = 256, height: int = 256, color_palette: str = "dark obsidian and gold trim"):
    print(f"\n[PixelLab] Starting UI Panel: '{name}' ({width}x{height})...")
    res = call_mcp_tool("create_ui_asset", {
        "name": name,
        "description": desc,
        "width": width,
        "height": height,
        "color_palette": color_palette,
        "no_background": True
    })
    
    if not res or "result" not in res:
        print("Failed to queue UI asset:", res)
        return None
        
    text_content = ""
    for c in res["result"].get("content", []):
        if c.get("type") == "text":
            text_content += c.get("text", "")
            
    print("Queue response:", text_content[:200])
    
    # Extract ui_asset_id
    import re
    match = re.search(r'([0-9a-fA-F-]{36})', text_content)
    if not match:
        print("Could not find asset UUID in response")
        return None
        
    asset_id = match.group(1)
    print(f"Asset ID: {asset_id}. Polling until completed...")
    
    out_file = os.path.join(OUTPUT_DIR, f"{name}.png")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    while True:
        poll_res = call_mcp_tool("get_ui_asset", {"ui_asset_id": asset_id, "include_preview": True})
        if not poll_res or "result" not in poll_res:
            time.sleep(6)
            continue
            
        content = poll_res["result"].get("content", [])
        status_text = ""
        for c in content:
            if c.get("type") == "text":
                status_text += c.get("text", "")
                
        if "completed" in status_text.lower() or "status: completed" in status_text.lower():
            # Check for base64 image or url
            saved = False
            for c in content:
                if c.get("type") == "image":
                    b64_data = c.get("data")
                    with open(out_file, "wb") as f:
                        f.write(base64.b64decode(b64_data))
                    print(f"Successfully generated and saved: {out_file}")
                    saved = True
                    break
            if not saved:
                url_match = re.search(r'https://[^\s\)\"\'<>]+(?:\.png|\.jpg)', status_text)
                if url_match:
                    download_image_from_url(url_match.group(0), out_file)
                    saved = True
            if saved:
                return out_file
            print("Status completed but no image extracted. Text:", status_text)
            break
        elif "failed" in status_text.lower() or "error" in status_text.lower():
            print(f"Generation failed for {name}: {status_text}")
            break
        else:
            print(f"Processing '{name}'... waiting 6s")
            time.sleep(6)
            
    return None

def generate_pixel_object(name: str, prompt: str, size: int = 64):
    print(f"\n[PixelLab] Starting Map/Object Icon: '{name}' ({size}x{size})...")
    res = call_mcp_tool("create_map_object", {
        "name": name,
        "description": prompt,
        "size": size,
        "detail": "medium detail",
        "outline": "single color black outline"
    })
    
    if not res or "result" not in res:
        print("Failed to queue object:", res)
        return None
        
    text_content = ""
    for c in res["result"].get("content", []):
        if c.get("type") == "text":
            text_content += c.get("text", "")
            
    print("Queue response:", text_content[:200])
    
    import re
    match = re.search(r'([0-9a-fA-F-]{36})', text_content)
    if not match:
        print("Could not find object UUID in response")
        return None
        
    object_id = match.group(1)
    print(f"Object ID: {object_id}. Polling until completed...")
    
    out_file = os.path.join(OUTPUT_DIR, f"{name}.png")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    while True:
        poll_res = call_mcp_tool("get_map_object", {"object_id": object_id})
        if not poll_res or "result" not in poll_res:
            time.sleep(6)
            continue
            
        content = poll_res["result"].get("content", [])
        status_text = ""
        for c in content:
            if c.get("type") == "text":
                status_text += c.get("text", "")
                
        if "completed" in status_text.lower() or "status: completed" in status_text.lower():
            saved = False
            for c in content:
                if c.get("type") == "image":
                    b64_data = c.get("data")
                    with open(out_file, "wb") as f:
                        f.write(base64.b64decode(b64_data))
                    print(f"Successfully generated and saved: {out_file}")
                    saved = True
                    break
            if not saved:
                url_match = re.search(r'https://[^\s\)\"\'<>]+(?:\.png|\.jpg)', status_text)
                if url_match:
                    download_image_from_url(url_match.group(0), out_file)
                    saved = True
            if saved:
                return out_file
            print("Status completed but no image extracted. Text:", status_text)
            break
        elif "failed" in status_text.lower() or "error" in status_text.lower():
            print(f"Generation failed for {name}: {status_text}")
            break
        else:
            print(f"Processing '{name}'... waiting 6s")
            time.sleep(6)
            
    return None

def run_sequential_pipeline():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Starting sequential PixelLab UI pipeline -> Output: {OUTPUT_DIR}")
    
    # 1. Title / Splash Art Banner (16:9, e.g. 512x288)
    generate_ui_panel(
        "title_banner_art",
        "Epic pixel art fantasy RPG title crest banner with crossed swords, golden filigree, glowing blue crystals and dark obsidian stone backdrop",
        512, 288,
        "royal blue, dark violet, gold and steel"
    )
    
    # 2. Loading Screen Art (16:9, e.g. 512x288)
    generate_ui_panel(
        "loading_screen_art",
        "Atmospheric pixel art fantasy RPG dungeon gate with glowing magical mathematical runes, torches and stone archway",
        512, 288,
        "deep purple, warm torchlight orange, cyan rune glow"
    )
    
    # 3. Main RPG Menu Frame / 9-Patch Panel (256x256)
    generate_ui_panel(
        "rpg_menu_frame",
        "Ornate dark fantasy pixel art RPG dialog window panel with gilded golden borders, corner rivets and deep obsidian background",
        256, 256,
        "gold, bronze, obsidian slate"
    )
    
    # 4. Inventory / Equipment Slot Box (192x192)
    generate_ui_panel(
        "slot_frame_box",
        "Square pixel art RPG equipment slot container with metallic beveled border, dark padded velvet interior and subtle highlight",
        192, 192,
        "steel silver, deep indigo velvet"
    )
    
    # 5. Character Pedestal / Preview Dais (64x64)
    generate_pixel_object(
        "knight_pedestal",
        "An ornate circular stone and gold RPG champion pedestal dais seen from front slight angle, glowing magical rune rim",
        64
    )
    
    # 6. Stat Icons (48x48)
    stat_prompts = [
        ("icon_strength", "A glowing ruby red enchanted knight broadsword icon for RPG strength attribute, clean pixel art"),
        ("icon_endurance", "A glowing crimson red vitality heart gem with golden wings for RPG endurance HP attribute, clean pixel art"),
        ("icon_defense", "A heavy steel and sapphire blue fortress tower shield icon for RPG defense armor attribute, clean pixel art"),
        ("icon_agility", "A swift glowing emerald green winged boot Hermes shoe icon for RPG agility speed attribute, clean pixel art"),
        ("icon_wisdom", "A glowing amethyst purple floating magical arcane spellbook and orb icon for RPG wisdom intelligence attribute, clean pixel art")
    ]
    
    for name, prompt in stat_prompts:
        generate_pixel_object(name, prompt, 48)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        item = sys.argv[1]
        if item == "banner":
            generate_ui_panel("title_banner_art", "Epic pixel art fantasy RPG title crest banner with crossed swords, golden filigree, glowing blue crystals and dark obsidian stone backdrop", 512, 288)
        elif item == "loading":
            generate_ui_panel("loading_screen_art", "Atmospheric pixel art fantasy RPG dungeon gate with glowing magical mathematical runes, torches and stone archway", 512, 288)
        elif item == "frame":
            generate_ui_panel("rpg_menu_frame", "Ornate dark fantasy pixel art RPG dialog window panel with gilded golden borders, corner rivets and deep obsidian background", 256, 256)
        elif item == "slot":
            generate_ui_panel("slot_frame_box", "Square pixel art RPG equipment slot container with metallic beveled border, dark padded velvet interior and subtle highlight", 192, 192)
        elif item == "pedestal":
            generate_pixel_object("knight_pedestal", "An ornate circular stone and gold RPG champion pedestal dais seen from front slight angle", 64)
        elif item == "stats":
            for n, p in [("icon_strength", "A glowing ruby red knight broadsword icon"), ("icon_endurance", "A glowing crimson vitality heart gem"), ("icon_defense", "A heavy steel fortress tower shield icon"), ("icon_agility", "A swift glowing emerald winged boot icon"), ("icon_wisdom", "A glowing amethyst purple floating magical arcane spellbook icon")]:
                generate_pixel_object(n, p, 48)
    else:
        run_sequential_pipeline()
