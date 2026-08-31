import urllib.request
import json
import time
import zipfile
import io
import os

API_KEY = "986cf6b7-7da0-42a7-901c-0c6e0ef34d66"
URL = "https://api.pixellab.ai/mcp"
BASE_CID = "11da89e5-a71b-43fe-8aa6-3235163576c7"

REMAINING_STATES = [
    ("Frost Sword", "Replace the steel sword with a glowing icy crystalline light-blue frost blade with cold energy"),
    ("Golden Sword", "Replace the steel sword with an ornate shining royal golden broadsword with ruby gemstones"),
    ("Viking Helmet", "Replace the knight helmet with a steel viking helmet with two curved white horns"),
    ("King Crown", "Add an ornate glowing golden royal king crown with rubies and sapphires on the helmet"),
    ("Wizard Hat", "Replace the blue plume with a tall pointed magical dark purple wizard hat with gold stars"),
    ("Jester Hat", "Replace the blue plume with a colorful pink and green 3-pointed jester fool cap with bells"),
    ("Propeller Hat", "Add a funny colorful spinning red yellow and blue propeller beanie hat on top of the helmet")
]

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
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read().decode("utf-8")
            for line in raw.split("\n"):
                if line.startswith("data:"):
                    return json.loads(line[5:].strip())
    except Exception as e:
        print(f"Error calling {tool_name}:", e)
    return None

def get_character_info(cid: str):
    res = call_mcp_tool("get_character", {"character_id": cid, "include_preview": False})
    if not res or "result" not in res:
        return ""
    text = ""
    for c in res["result"]["content"]:
        if c.get("type") == "text":
            text += c.get("text", "")
    return text

def download_bundle(cid: str, dest_dir: str):
    url = f"https://api.pixellab.ai/mcp/characters/{cid}/download"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read()
            with zipfile.ZipFile(io.BytesIO(content)) as z:
                z.extractall(dest_dir)
            print(f"Successfully downloaded and extracted bundle to {dest_dir}")
            return True
    except Exception as e:
        print("Download error:", e)
        return False

def run_pipeline():
    # 1. Wait for currently pending jobs on BASE_CID
    print("Checking initial status of BASE_CID...")
    queued_remaining = list(REMAINING_STATES)
    
    while True:
        info = get_character_info(BASE_CID)
        print("--- Character Status ---")
        lines = info.split("\n")
        for line in lines[:15]:
            print(line)
            
        has_pending_jobs = "pending jobs" in info.lower() or "creating" in info.lower()
        has_pending_states = "pending" in info.lower()
        
        # Try queueing one state if available
        if queued_remaining:
            name, edit = queued_remaining[0]
            print(f"Attempting to queue state: {name}...")
            res = call_mcp_tool("create_character_state", {
                "character_id": BASE_CID,
                "state_name": name,
                "edit_description": edit,
                "use_color_palette_from_reference": False
            })
            if res and "error" not in res and not res.get("result", {}).get("isError", False):
                print(f"Successfully queued state: {name}!")
                queued_remaining.pop(0)
            else:
                err = res.get("result", {}).get("content", [{}])[0].get("text", "") if res else "Unknown error"
                print(f"Could not queue yet ({err}). Waiting...")
        
        # If all states queued and no pending jobs, download and finish!
        if not queued_remaining and not has_pending_jobs and not has_pending_states:
            print("All states and animations completed! Downloading final bundle...")
            ws_dir = r"c:\MathKnight\math-knight\assets\sprites\knight_comic"
            art_dir = r"C:\Users\tofte\.gemini\antigravity\brain\e1128133-562a-43fe-9743-12076d99c88c\knight_comic"
            os.makedirs(ws_dir, exist_ok=True)
            os.makedirs(art_dir, exist_ok=True)
            download_bundle(BASE_CID, ws_dir)
            download_bundle(BASE_CID, art_dir)
            break
            
        time.sleep(15)

if __name__ == "__main__":
    run_pipeline()
