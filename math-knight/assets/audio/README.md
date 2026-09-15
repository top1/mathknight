# MathKnight Audio Assets (TRON / Cyber-Knight Edition)

This directory contains the driving, super-harmonic background music (BGM), sound effects (SFX), and victory fanfares for **MathKnight**.

All assets are managed and dynamically synthesized / loaded by [`res://scripts/autoload/AudioManager.gd`](../scripts/autoload/AudioManager.gd) and can also be generated via Google AI Studio / Gemini SDK via [`res://tools/generate_audio.py`](../tools/generate_audio.py).

## 🎵 Background Music Tracks (Soundtrack)
The game uses 6 dedicated thematic orchestral / fantasy music tracks:

1. **`MENUE1_Tomes_and_Tally.mp3`** (*"Tomes and Tally"*)
   - **Used for**: Title Screen (`title`), Main Menu (`menu`), Stage Select Screen (`stage_select`)
   - **Mood**: Scholarly, welcoming, adventurous theme for preparation and level selection.

2. **`MENU2_Sunlight_on_Parchment.mp3`** (*"Sunlight on Parchment"*)
   - **Used for**: Run Map (`map`), Merchant Shop (`shop`), Rest Site / Tavern (`menu_tavern`), Cosmetic Inventory
   - **Mood**: Warm, exploratory parchment-map ambiance and cozy merchant trading atmosphere.

3. **`ACTION1_A_Gambit_in_the_Courtyard.mp3`** (*"A Gambit in the Courtyard"*)
   - **Used for**: Standard Battles (`battle`), Skirmishes (`battle_skirmish`), Arithmetic Arena (`battle_addition`, `battle_subtraction`, `battle_multiplication`)
   - **Mood**: Spirited, rhythmic courtyard combat theme with dynamic drive.

4. **`ACTION2_The_Fencing_Master_s_Gambit.mp3`** (*"The Fencing Master's Gambit"*)
   - **Used for**: Boss Encounters (`boss`), Elite Duels (`elite`), Speed Sprints (`battle_speed`), Mixed Operations (`battle_mixed`)
   - **Mood**: High-tempo, intense, virtuosic swordplay duel theme.

5. **`CRAFTING_SMITHING_Steel_Beneath_The_Hearth.mp3`** (*"Steel Beneath The Hearth"*)
   - **Used for**: Blacksmith Forge (`battle_forge`, `crafting`, `forge`), Result-to-Equation Mode
   - **Mood**: Resonant, rhythmic, industrious forge and smithing cadence.

6. **`PUZZLE_The_Scholar_s_Gambit.mp3`** (*"The Scholar's Gambit"*)
   - **Used for**: Puzzle minigames (`puzzle`), Siege Gate Maze, Multi-Op Equation Chain (`battle_chain`), Division (`battle_division`)
   - **Mood**: Contemplative, intricate, cerebral puzzle-solving theme.

7. **`CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3`** (*"The Lathe's Morning"*)
   - **Used for**: Medieval Village Hub (`village`, `town`, `castle_town`), Royal Bakery (`bakery`), Timber Sawmill (`lumber`), Success celebrations
   - **Mood**: Uplifting, pastoral medieval village craftsmanship and victory theme.

### Jingles
- **`jingle_victory.wav`**: Ascending victory fanfare.
- **`jingle_stage_clear.wav`**: Stage clear stinger.
- **`jingle_game_over.wav`**: Game over sequence.

## 🔊 Sound Effects (SFX)
- **`sfx_bubble_pop.wav`**: Laser-chirp bubble pop with fast downward FM pitch sweep and crisp transient.
- **`sfx_sword_slash.wav`**: Plasma blade swing with resonant filtered white noise sweep.
- **`sfx_correct.wav`**: Sparkling major 9th cyber chime (C6-E6-G6-B6) with shimmering harmonics (pitch scales dynamically with streak).
- **`sfx_wrong.wav`**: Low digitized dual-detuned sawtooth glitch error buzz.
- **`sfx_coin.wav`**: Crisp arcade digital coin pickup with high-frequency harmonic sheen.
- **`sfx_diamond.wav`**: Sparkling holographic gem pickup with cascading neon arpeggio and vibrato.
- **`sfx_click.wav`**: Snappy cybernetic UI button click.
- **`sfx_levelup.wav`**: Triumphant ascending neon chord sweep with rich supersaw sustain.
- **`sfx_chest_open.wav`**: Digital matrix unlock chirp and holographic opening chime.
- **`sfx_chest_break.wav`**: Cyber de-rez crunch and low plasma discharge.
