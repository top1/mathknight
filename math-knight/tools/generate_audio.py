"""
Google AI Audio & Music Generation Helper Script for MathKnight
Supports generating background music (Lyria) and audio/speech (Gemini) using the Google GenAI SDK.

Usage:
  python tools/generate_audio.py --type music --prompt "TRON Legacy synthwave loop 124 BPM" --out assets/audio/bgm_battle.mp3
  python tools/generate_audio.py --type speech --prompt "Critical Strike!" --voice Puck --out assets/audio/critical.wav
"""

import argparse
import base64
import os
import sys

def get_client(api_key: str = None):
    from google import genai
    key = api_key or os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ValueError("GEMINI_API_KEY environment variable or --api-key argument is required.")
    return genai.Client(api_key=key)

def generate_music(prompt: str, output_path: str, model: str = "lyria-3-clip-preview"):
    client = get_client()
    print(f"Generating music using model: {model}...")
    print(f"Prompt: {prompt}")
    
    try:
        interaction = client.interactions.create(
            model=model,
            input=prompt
        )

        if hasattr(interaction, "output_audio") and interaction.output_audio and interaction.output_audio.data:
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(interaction.output_audio.data))
            print(f"Successfully saved music to: {output_path}")
            return True
        else:
            print("No audio data returned in response.", file=sys.stderr)
            return False
    except Exception as e:
        print(f"Error during music generation: {e}", file=sys.stderr)
        return False

def generate_speech(prompt: str, output_path: str, voice: str = "Puck", model: str = "gemini-2.5-flash-preview-tts"):
    from google.genai import types

    print(f"Generating speech/voice using model: {model} (Voice: {voice})...")
    client = get_client()

    try:
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
            return False
        return True
    except Exception as e:
        print(f"Error during speech generation: {e}", file=sys.stderr)
        return False

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
        model = args.model or "gemini-2.5-flash-preview-tts"
        generate_speech(args.prompt, args.out, args.voice, model)

if __name__ == "__main__":
    main()
