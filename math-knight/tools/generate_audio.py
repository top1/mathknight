"""
Google AI Audio & Music Generation Helper Script for MathKnight
Supports generating background music (Lyria) and audio/speech (Gemini) using the Google GenAI SDK.

Usage:
  python tools/generate_audio.py --type music --prompt "Medieval tavern lute upbeat loop" --out assets/audio/tavern.mp3
  python tools/generate_audio.py --type speech --prompt "Critical Strike!" --voice Puck --out assets/audio/critical.wav
"""

import argparse
import base64
import os
import sys

def generate_music(prompt: str, output_path: str, model: str = "lyria-3-clip-preview"):
    from google import genai
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        print("Set it using: $env:GEMINI_API_KEY='your_key' (PowerShell) or export GEMINI_API_KEY='your_key'", file=sys.stderr)
        sys.exit(1)

    print(f"Generating music using model: {model}...")
    print(f"Prompt: {prompt}")
    
    client = genai.Client(api_key=api_key)
    interaction = client.interactions.create(
        model=model,
        input=prompt
    )

    if interaction.output_audio and interaction.output_audio.data:
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with open(output_path, "wb") as f:
            f.write(base64.b64decode(interaction.output_audio.data))
        print(f"Successfully saved music to: {output_path}")
    else:
        print("No audio data returned in response.", file=sys.stderr)

def generate_speech(prompt: str, output_path: str, voice: str = "Puck", model: str = "gemini-2.5-flash"):
    from google import genai
    from google.genai import types

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    print(f"Generating speech/voice using model: {model} (Voice: {voice})...")
    client = genai.Client(api_key=api_key)

    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=voice)
                )
            )
        )
    )

    saved = False
    for candidate in response.candidates:
        for part in candidate.content.parts:
            if part.inline_data and part.inline_data.data:
                os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
                with open(output_path, "wb") as f:
                    f.write(part.inline_data.data)
                print(f"Successfully saved speech to: {output_path}")
                saved = True
                break

    if not saved:
        print("No audio inline data returned in response.", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Generate music and audio using Google AI")
    parser.add_argument("--type", choices=["music", "speech"], required=True, help="Type of generation")
    parser.add_argument("--prompt", required=True, help="Description or text to generate")
    parser.add_argument("--out", required=True, help="Target file path (e.g. assets/audio/bgm.mp3)")
    parser.add_argument("--model", default=None, help="Model override")
    parser.add_argument("--voice", default="Puck", help="Voice name for speech (e.g. Puck, Aoede, Kore, Fenrir)")

    args = parser.parse_args()

    if args.type == "music":
        model = args.model or "lyria-3-clip-preview"
        generate_music(args.prompt, args.out, model)
    elif args.type == "speech":
        model = args.model or "gemini-2.5-flash"
        generate_speech(args.prompt, args.out, args.voice, model)

if __name__ == "__main__":
    main()
