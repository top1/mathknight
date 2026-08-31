# Google AI Audio & Music Generation Guide for MathKnight

This document provides step-by-step instructions and technical references for developers and AI agents to generate background music (BGM) and sound effects (SFX) using **Google AI Pro**, **Google AI Studio**, and the **Gemini / Lyria APIs**.

---

## 1. Google Account & Credits Breakdown

### How Google AI Pro & Google AI Studio Work
| Plan / Platform | How It Works | Audio/Music Capabilities |
| :--- | :--- | :--- |
| **Google AI Pro / Ultra Subscription** | Consumer tier (Gemini Advanced). Provides higher quota limits in Google AI Studio and monthly Google Cloud credit allowances (often $10–$20/month depending on plan/region). | Access to Gemini Web UI, MusicFX sandbox, and higher API rate limits. |
| **Google AI Studio (aistudio.google.com)** | Developer prototyping suite. Free tier allows generous rate limits; linking a Cloud Billing account lets you use your monthly credits for pay-as-you-go API calls. | Direct access to **Lyria 3**, Gemini Audio generation, and API key generation. |
| **Google Cloud / Vertex AI** | Full enterprise API backend. Accepts Google Cloud monthly credits. | Production-grade access to Lyria & Gemini Audio endpoints. |

> [!TIP]
> **API Key Setup**: Get your API key from [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey). Set it as an environment variable:
> ```bash
> set GEMINI_API_KEY="your_api_key_here"
> ```

---

## 2. Music Generation with Google DeepMind's Lyria

Google’s primary AI music generation model family is **Lyria 3**, integrated into Google AI Studio and the Gemini SDK (`google-genai`).

### Lyria Models
- **`lyria-3-clip-preview`**: Best for game loops, 15-30 second theme clips, stage victory jingles, and background tracks.
- **`lyria-3-pro-preview`**: Generates full-length structured compositions (up to ~3 minutes) with distinct sections (intro, verse, chorus, outro).
- **`lyria-realtime`**: Low-latency WebSocket streaming for dynamic, interactive background music.

### Python API Example (Music Generation)
```python
import base64
from google import genai

client = genai.Client()

# Generate a 30s upbeat medieval synth-orchestral background track for MathKnight
interaction = client.interactions.create(
    model="lyria-3-clip-preview",
    input="An energetic medieval fantasy chip-tune combined with orchestral strings and punchy drums. Upbeat 130 BPM, looping video game background music for a knight slashing math bubbles."
)

if interaction.output_audio:
    with open("assets/audio/bgm_gameplay.mp3", "wb") as f:
        f.write(base64.b64decode(interaction.output_audio.data))
    print("Music saved successfully!")
```

---

## 3. Sound Effects (SFX) & Speech Generation

### Option A: Gemini Multimodal Audio & Text-to-Speech (TTS)
Gemini 2.0 / 2.5 models support native audio output and speech synthesis with custom voice tones (e.g., knight announcer, combo streaks: "Double Slash!", "Critical Math!").

```python
from google import genai
from google.genai import types

client = genai.Client()

response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents="Say with an enthusiastic heroic knight voice: 'Combo Streak! Triple Bubble Slashed!'",
    config=types.GenerateContentConfig(
        response_modalities=["AUDIO"],
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Puck")
            )
        )
    )
)

for part in response.candidates[0].content.parts:
    if part.inline_data:
        with open("assets/audio/voice_combo.wav", "wb") as f:
            f.write(part.inline_data.data)
```

### Option B: Retro & Game Sound Effect Generators (SFX)
For 8-bit / 16-bit arcade sound effects (bubble pops, sword swooshes, coin chimes):
- **jsfxr / sfxr / Bfxr**: Instant procedural sound generation for Godot.
- **ElevenLabs / AudioCraft**: For realistic foley sound effects via API.

---

## 4. MCP Server Integration (Model Context Protocol)

You can connect AI agents (Antigravity, Claude, Cursor) directly to audio generation tools via MCP:

### Example MCP Configuration (`mcp_config.json`)
```json
{
  "mcpServers": {
    "gemini-audio": {
      "command": "npx",
      "args": ["-y", "gemini-gen-mcp"],
      "env": {
        "GEMINI_API_KEY": "YOUR_GEMINI_API_KEY"
      }
    }
  }
}
```

When configured, the agent can call audio generation tools directly with prompts like:
> *"Generate a 15-second triumphant victory fanfare in MP3 format and save it to `math-knight/assets/audio/victory.mp3`"*.

---

## 5. Ready-to-Use Audio Prompts for MathKnight

| Audio Asset | Suggested Model | Recommended Prompt |
| :--- | :--- | :--- |
| **Main Menu BGM** | `lyria-3-clip-preview` | *"Charming medieval tavern fantasy theme with acoustic lutes, light percussion, and playful flute melody. Relaxing and whimsical. 100 BPM loop."* |
| **Battle / Bubble Slashing BGM** | `lyria-3-clip-preview` | *"High-energy heroic arcade battle music. 135 BPM, blend of orchestral strings, driving electronic beat, and chip-tune synth arpeggios. Action-packed and motivating."* |
| **Boss / Speed Rush BGM** | `lyria-3-clip-preview` | *"Fast-paced intense medieval boss fight theme. 150 BPM, dramatic brass stabs, heavy war drums, fast electric violin runs."* |
| **Victory Fanfare** | `lyria-3-clip-preview` | *"Short 6-second triumphant victory fanfare with brass trumpets and sparkling chimes. Celebratory and bright."* |
| **Heroic Announcer Voice** | Gemini 2.5 Audio / TTS | *"Announce enthusiastically: 'Equation Solved! Quest Complete!'"* |

---

## 6. How Agents Should Use This Workflow

When an agent needs to add audio assets to MathKnight:
1. Ensure the `math-knight/assets/audio/` directory exists.
2. Check if `GEMINI_API_KEY` is present in the environment or user configuration.
3. Run the helper script `math-knight/tools/generate_audio.py` or invoke the Gemini / Lyria API directly.
4. Import the resulting `.mp3` or `.wav` into Godot using standard `AudioStreamPlayer2D` or `AudioStreamPlayer`.
