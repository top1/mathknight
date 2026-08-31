import urllib.request
import json
import time
import os
import base64
import zipfile
import io

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

def create_redesigned_knight():
    description = (
        "A heroic comic knight in polished steel plate armor with a flowing royal purple cape and purple cloth tunic accents. "
        "Wearing a dark gray and matte black closed knight helmet with glowing gold visor slit and a dark purple feather plume on top. "
        "Carrying a sharp medieval steel sword. Clean colorful comic fantasy style with bold pixel art outlines."
    )
    print("Sending create_character request...")
    res = call_mcp_tool("create_character", {
        "name": "Dark Helm Purple Cape Knight",
        "description": description,
        "mode": "standard",
        "size": 92,
        "n_directions": 4,
        "view": "side",
        "outline": "single color black outline",
        "shading": "medium shading",
        "detail": "medium detail",
        "proportions": json.dumps({"type": "preset", "name": "cartoon"})
    })
    print("Response:", json.dumps(res, indent=2))
    return res

if __name__ == "__main__":
    create_redesigned_knight()
