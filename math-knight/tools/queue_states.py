import urllib.request
import json
import time

API_KEY = "986cf6b7-7da0-42a7-901c-0c6e0ef34d66"
URL = "https://api.pixellab.ai/mcp"
BASE_CID = "11da89e5-a71b-43fe-8aa6-3235163576c7"

STATES = [
    ("Lightsaber", "Replace the steel sword with a glowing neon cyan-blue plasma lightsaber blade with bright energy glow"),
    ("Frying Pan", "Replace the sword with a heavy cast-iron black medieval frying pan held firmly in hand"),
    ("Flame Sword", "Replace the steel sword with a blazing fire sword with bright orange and yellow flames"),
    ("Frost Sword", "Replace the steel sword with a glowing icy crystalline light-blue frost blade"),
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
    with urllib.request.urlopen(req) as response:
        raw = response.read().decode("utf-8")
        for line in raw.split("\n"):
            if line.startswith("data:"):
                return json.loads(line[5:].strip())
    return None

if __name__ == "__main__":
    for name, edit in STATES:
        print(f"Queueing state: {name}...")
        res = call_mcp_tool("create_character_state", {
            "character_id": BASE_CID,
            "state_name": name,
            "edit_description": edit,
            "use_color_palette_from_reference": False
        })
        print(json.dumps(res, indent=2))
        time.sleep(1)
