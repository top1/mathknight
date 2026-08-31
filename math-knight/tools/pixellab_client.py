import urllib.request
import json
import time
import os
import sys

API_KEY = "986cf6b7-7da0-42a7-901c-0c6e0ef34d66"
URL = "https://api.pixellab.ai/mcp"

def call_mcp_tool(tool_name: str, arguments: dict):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": int(time.time()),
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        }
    }
    req = urllib.request.Request(URL, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    with urllib.request.urlopen(req) as response:
        raw = response.read().decode("utf-8")
        for line in raw.split("\n"):
            if line.startswith("data:"):
                return json.loads(line[5:].strip())
    return None

def download_character(cid: str, out_dir: str = "assets/sprites/knight_comic"):
    os.makedirs(out_dir, exist_ok=True)
    while True:
        res = call_mcp_tool("get_character", {"character_id": cid, "include_preview": True})
        if not res or "result" not in res:
            print("No response, retrying...")
            time.sleep(5)
            continue
        content = res["result"]["content"]
        text_info = ""
        for c in content:
            if c.get("type") == "text":
                text_info += c.get("text", "")
        
        print("Status update:\n", text_info[:300])
        
        if "status: completed" in text_info.lower():
            # Check for images in content
            img_count = 0
            artifact_dir = r"C:\Users\tofte\.gemini\antigravity\brain\e1128133-562a-43fe-9743-12076d99c88c"
            for c in content:
                if c.get("type") == "image":
                    import base64
                    data = c.get("data")
                    img_path = os.path.join(out_dir, f"preview_{img_count}.png")
                    with open(img_path, "wb") as f:
                        f.write(base64.b64decode(data))
                    print(f"Saved image to: {img_path}")
                    
                    # Also save to artifact directory
                    art_path = os.path.join(artifact_dir, f"knight_comic_preview.png")
                    with open(art_path, "wb") as f:
                        f.write(base64.b64decode(data))
                    print(f"Saved artifact preview to: {art_path}")
                    img_count += 1
            print("Character generation completed!")
            print(text_info)
            break
        elif "status: failed" in text_info.lower() or "error" in text_info.lower():
            print("Character generation failed:", text_info)
            break
        else:
            print("Still processing, waiting 15s...")
            time.sleep(15)

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "create"
    if action == "create":
        res = call_mcp_tool("create_character", {
            "name": "Comic Knight",
            "description": "A valiant heroic comic knight in gleaming polished silver plate armor with blue cloth accents, a closed knight helmet with golden visor slit, royal blue feather plume on the helmet, steel pauldrons and gauntlets, carrying a sharp medieval steel sword. Clean colorful comic fantasy style with bold pixel art outlines.",
            "mode": "standard",
            "size": 92,
            "n_directions": 4,
            "view": "side",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail",
            "proportions": json.dumps({"type": "preset", "name": "cartoon"})
        })
        print(json.dumps(res, indent=2))
    elif action == "get":
        cid = sys.argv[2]
        res = call_mcp_tool("get_character", {"character_id": cid})
        print(json.dumps(res, indent=2))
    elif action == "wait":
        cid = sys.argv[2]
        download_character(cid)
