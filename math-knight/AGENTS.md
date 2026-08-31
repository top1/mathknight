# Project Configuration & Agent Guidelines

## Godot Executable Location
The Godot executable is located at:
```
C:\GoDot\Godot_v4.5.1-stable_win64_console.exe
```

> **CRITICAL FOR AGENTS:**
> Always use this exact executable path directly when running Godot commands, headless scripts, builds, tests, or exports.
> **DO NOT** search the filesystem, registry, or PATH for the Godot binary.

## Common CLI Usage
- **Launch Project:**
  ```powershell
  & "C:\GoDot\Godot_v4.5.1-stable_win64_console.exe" --path "c:\MathKnight\math-knight"
  ```
- **Headless Mode:**
  ```powershell
  & "C:\GoDot\Godot_v4.5.1-stable_win64_console.exe" --headless --path "c:\MathKnight\math-knight"
  ```
- **Run Standalone GDScript:**
  ```powershell
  & "C:\GoDot\Godot_v4.5.1-stable_win64_console.exe" --headless --path "c:\MathKnight\math-knight" -s <script_path>
  ```
