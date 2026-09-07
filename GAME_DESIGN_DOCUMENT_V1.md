# ⚔️ MathKnight — Game Design Document V1

> *"A brave little knight. A world of monsters. And the only weapon that truly matters: your mind."*

---

## 1. Vision Statement

MathKnight is a **medieval adventure game disguised as math training**. The player is a cute, determined comic-book knight who explores a hand-drawn fantasy world, battles monsters with the power of arithmetic, forges legendary weapons at the anvil, chops wood in the lumber yard, and embarks on quests across a living kingdom — all powered by math.

The game should feel like **a Saturday morning cartoon you get to play in**. Every tap, every correct answer, every sword swing should feel *juicy* and satisfying. But underneath the fun, the real engine is **building and reinforcing math skills** through repetition wrapped in variety.

### The Golden Rule
> **Fun first. Learning always. Addiction never.**

The game uses natural session boundaries, run-based structure, and honest progression to create a rhythm that says: *"That was a great run. Come back tomorrow and you'll be even stronger."* — not *"Just one more..."*

---

## 2. Design Pillars

### 🎮 Pillar 1: It's a GAME, Not a Quiz
Every math problem is embedded in a gameplay moment — a sword clash, a hammer strike, a saw cut. The player never sees a "test." They see a monster charging at them, an anvil glowing red-hot, a log that needs splitting. The math IS the action.

### 🍬 Pillar 2: Juicy, Not Addicting
- **Juicy:** Screen shake, particle bursts, satisfying sound design, animated reactions, combo flames, gold coin showers, victory fanfares.
- **Not Addicting:** No infinite scrolling, no gacha/lootbox manipulation, no FOMO timers, no pay-to-win. Runs have clear beginnings and endings. Daily bonuses are gentle nudges, not punishment for missing days.

### 🧠 Pillar 3: A Little Bit of Work
The game should feel *slightly* effortful — like a workout that's enjoyable but you know you're getting stronger. The satisfaction comes from **noticing your own improvement**: faster answers, harder stages cleared, higher combos. The "work" feeling is a feature, not a bug.

### 🏰 Pillar 4: A Coherent World
Everything — enemies, locations, activities, UI — belongs to the same **cute-but-slightly-dangerous medieval comic world**. A skeleton isn't just an enemy type; it's a bony troublemaker with a crooked grin and a rusty sword. The blacksmith isn't just a mini-game; it's a soot-covered dwarf who grunts approvingly when you nail the timing.

---

## 3. Art Direction

### 3.1 Style: Comic Cartoon Medieval

> [!IMPORTANT]
> **Major shift from current codebase.** The existing matrix/ASCII art style is being retired. The new direction is a cohesive **hand-drawn comic-cartoon aesthetic** with clean outlines, expressive characters, and warm fantasy colors.

| Attribute | Direction |
|-----------|-----------|
| **Rendering** | 2D sprite-based, clean outlines (2-3px black), cel-shaded fills |
| **Proportions** | Chibi / super-deformed (big heads, small bodies, ~3 heads tall) |
| **Color Palette** | Warm earth tones + jewel-tone accents (emerald, ruby, sapphire, gold) |
| **Tone** | Cute and playful, but with a hint of real danger — think *Castle Crashers* meets *Slay the Spire* kid-friendly edition |
| **Animation** | Snappy squash-and-stretch, exaggerated anticipation frames, juicy hit-stops |
| **UI** | Parchment textures, wooden frames, hand-lettered headers, wax seal buttons |

### 3.2 The Knight (Player Character)

The knight is the player's avatar and should be **instantly lovable**.

- **Design:** Round helmet with a T-visor (eyes visible behind the slit), bouncing blue-feather plume, small armored body, oversized sword
- **Expressions:** Eyes widen on correct answers, squint in determination during combos, spiral-eyes when hit, star-eyes on critical hits
- **Idle:** Gentle bounce, occasional sword polish, helmet adjustment, plume sways with movement
- **Personality:** Brave, a little clumsy, always gets back up. Never speaks — expresses everything through animation, emotes, and **comic onomatopoeia speech bubbles** ("HIYAA!", "OOF!", "HA!")

### 3.3 Enemy Bestiary (Initial Roster)

Each enemy archetype should feel distinct, funny, and *slightly* threatening.

| Enemy | Visual Concept | Personality | Math Association |
|-------|---------------|-------------|-----------------|
| **Goblin** | Small green troublemaker, oversized ears, mischievous grin, carries a stolen coin purse | Sneaky, fast, annoying | Addition (basic, quick problems) |
| **Skeleton** | Bony warrior, one eye socket glows, jaw sometimes falls off mid-fight | Bumbling, persistent | Subtraction (taking away bones!) |
| **Orc** | Big, green, muscular, tiny brain, comically huge club | Strong but slow, confused expression | Multiplication (big numbers, heavy hits) |
| **Dark Mage** | Hooded figure, glowing eyes, floating spell book, dramatic hand gestures | Mysterious, theatrical | Division (splitting magic) |
| **Slime** | Adorable blob with a face, wobbles and jiggles, splits into smaller slimes | Cute, harmless-looking but persistent | Mixed operations |
| **Armored Knight** | Rival knight in dark armor, mirror of the player | Honorable rival, salutes before combat | Elite — harder versions of any operation |
| **Rogue Squire** | Hedge knight in mismatched armor, tries too hard to look scary | Wannabe villain, overly dramatic | Multi-step order of operations |
| **Ogre Gatekeeper** | Massive, gate-blocking brute with a tiny key around his neck | Stubborn, immovable | Elite — huge HP pool, endurance test |

**Named World Bosses:**

| Boss | Visual Concept | Math Theme |
|------|---------------|------------|
| **Gorg the Great-Divider** | Giant forest troll with a tree-trunk cleaver, mossy beard | Division duels — splits his own HP bar into segments the player must calculate |
| **Baron Von Fraction** | Armored colossus whose plate armor shatters in fractional pieces (¼, ½, ¾) | Fractions — armor plates break off in fractions, player must calculate remaining defense |
| **The Dragon of Primes** | Ancient dragon atop Mount Numerus, scales glow with prime numbers | Prime numbers — vulnerable only to prime factor strikes, immune to composite answers |

### 3.4 World Locations (Visual Themes)

| Location | Visual Mood | Activities Available |
|----------|-------------|---------------------|
| **The Village Square** | Cozy, warm, market stalls, fountain | Hub — access all activities, daily quests |
| **The Dark Forest** | Spooky trees with eyes, fireflies, fog | Combat runs (addition, subtraction) |
| **The Mountain Pass** | Rocky, windy, precarious bridges | Combat runs (multiplication, division) |
| **The Blacksmith's Forge** | Glowing forge, sparks, soot, anvil | Blacksmithing mini-game |
| **The Lumber Yard** | Stacked logs, sawdust, pine trees | Wood cutting mini-game |
| **The Castle Arena** | Tournament grounds, banners, crowd | Challenge modes, daily tournaments |
| **The Ancient Library** | Dusty scrolls, floating candles, star maps | Geometry / advanced math (future) |
| **The Dragon's Lair** | Volcanic cave, treasure piles, lava | Boss encounters |

---

## 4. Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    THE SESSION LOOP                          │
│                                                             │
│   Village Hub                                               │
│     │                                                       │
│     ├──▶ Pick an Activity                                   │
│     │     ├── ⚔️  Combat Run (main progression)             │
│     │     ├── 🔨 Blacksmithing (upgrade weapons)            │
│     │     ├── 🪓  Wood Cutting (division practice)          │
│     │     ├── 🏰 Arena Challenge (daily/weekly)             │
│     │     ├── 📜 Quest Board (themed objectives)            │
│     │     └── 🛒 Merchant (spend gold)                      │
│     │                                                       │
│     ├──▶ Play Activity                                      │
│     │     └── Math problems embedded in gameplay            │
│     │                                                       │
│     ├──▶ Earn Rewards                                       │
│     │     ├── Gold (universal currency)                     │
│     │     ├── XP (knight level)                             │
│     │     ├── Materials (crafting / upgrading)              │
│     │     └── Reputation (unlock new areas)                 │
│     │                                                       │
│     └──▶ Return to Village                                  │
│           ├── Spend gold at shops                           │
│           ├── Level up & allocate stats                     │
│           └── Prepare for next session                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 Session Design (Anti-Addiction)

- A **combat run** is 5–12 minutes (10 stages, each stage is 3–4 waves of ~30s each)
- Mini-games (**blacksmithing, wood cutting**) are 2–5 minutes each
- After a run completes (win or lose), the game naturally lands back at the **Village Hub** — a calm resting space with no urgency
- **Daily quest board** refreshes once per day with 3 quests — completable in ~15 minutes total. Rewards are nice-to-have, not essential
- **No energy systems**, no wait timers, no "watch an ad to continue"
- Gentle session-end suggestion after ~30 minutes: *"The knight yawns... Maybe time for a rest, hero?"*

---

## 5. Combat System (Detailed)

### 5.1 Overview

Combat is the **primary activity** and the most polished experience. The knight stands on the right side of a side-scrolling battlefield. Enemies approach from the left, each carrying a math problem.

> [!IMPORTANT]
> **Key change from current version:** Enemies are no longer instant-killed on correct answer. Instead, the knight **deals damage based on stats**, and enemies have **HP bars**. This creates a more game-like tactical feel.

### 5.2 Combat Flow

```
Enemy Approaches → Problem Displayed → Player Inputs Answer
                                              │
                                    ┌─────────┴─────────┐
                                    ▼                     ▼
                              ✅ CORRECT               ❌ WRONG
                                    │                     │
                              Knight Attacks         Enemy Attacks
                              (Damage = ATK          (Damage = Enemy ATK
                               × speed bonus          - Knight Armor)
                               × combo mult)              │
                                    │                     │
                              Enemy HP reduced       Knight HP reduced
                                    │                     │
                              Enemy HP ≤ 0?          Knight HP ≤ 0?
                                    │                     │
                              ✅ Defeated             Run Ends
                              → Next Enemy           (NOT game over —
                              → Gold + XP drop        just this run)
```

### 5.3 Damage Formula

```
Knight Attack Damage:
  base_damage = weapon_damage + (strength * 0.5)
  speed_bonus = clamp(1.0 + (time_limit - answer_time) * 0.1, 1.0, 2.0)
  combo_bonus = 1.0 + (combo_streak * 0.15)
  critical = (random() < crit_chance) ? 2.0 : 1.0
  
  TOTAL = base_damage * speed_bonus * combo_bonus * critical

Enemy Attack Damage (on wrong answer OR timeout):
  raw_damage = enemy_attack_power
  mitigated = max(1, raw_damage - knight_armor)
  dodged = (random() < dodge_chance) ? true : false
  
  FINAL = dodged ? 0 : mitigated
```

### 5.4 Enemy HP Scaling

| Enemy Type | Base HP | Per-Stage Scaling | Notes |
|-----------|---------|-------------------|-------|
| Goblin | 1–2 | +0.5 per stage | Dies fast, comes in groups |
| Skeleton | 2–3 | +0.5 per stage | Medium, steady |
| Orc | 4–6 | +1 per stage | Tanky, fewer per wave |
| Dark Mage | 2–3 | +0.5 per stage | Low HP, but high attack |
| Slime | 1 | — | Splits into 2 mini-slimes on death |
| Armored Knight | 5–8 | +1.5 per stage | Elite, carries shield (blocks first hit) |
| Boss | 15–50 | Per phase | Multi-phase, telegraphed specials |

### 5.5 Answer Speed Rewards

The game rewards **fast AND accurate** answers without punishing slower players:

| Answer Time | Feedback | Bonus |
|-------------|----------|-------|
| < 2 seconds | ⚡ "BLITZ!" | 2× damage, bonus gold |
| 2–5 seconds | ✨ "SCHNELL!" | 1.5× damage |
| 5–10 seconds | ✅ "GUT!" | 1× damage (normal) |
| > 10 seconds | ⏰ "KNAPP!" | 1× damage, enemy inches closer |
| Timeout (15s) | 💥 Enemy attacks | Knight takes damage |

### 5.6 Combo System

Consecutive correct answers build a **combo counter**:

- **Combo 3:** Sword glows faintly, "+15% damage" text flash
- **Combo 5:** Sword engulfed in flame/frost/lightning (based on weapon), screen edge vignette color shift
- **Combo 10:** **RITTER-RASEREI!** (Knight Frenzy) — screen shake, particle explosion, 2× damage for next 3 hits, guaranteed gold drop
- **Combo 15+:** Sustained frenzy, each additional combo adds +5% damage
- **Any wrong answer:** Combo resets to 0 with a visible "chain break" crack effect

### 5.7 Comic Onomatopoeia System *(Learned from V2)*

Floating comic-style text banners pop up during combat for maximum juice:

| Trigger | Comic Text | Visual |
|---------|-----------|--------|
| Correct answer (normal) | "THWACK!" | White text, small pop |
| Fast correct (< 2s) | "BLITZ!" / "POW!" | Yellow flash, bigger pop |
| Critical hit | "KRRRANG!" | Screen-wide, chromatic aberration burst |
| Combo 5+ | "CLEAVE!" | Fiery text, trails |
| Combo 10+ | "RITTER-RASEREI!" | Massive banner, screen shake |
| Wrong answer | "CLONK!" | Dull grey, small |
| Enemy defeated | "POOF!" / "DIVIDED!" / "CURSE THY MATH!" | Floats upward from enemy corpse |
| Dodge successful | "WHOOSH!" | Speed lines, puff of dust |
| Shield block | "CLANG!" | Metallic flash |

These use a **comic speech bubble** visual style — bold outlined text with jagged burst borders, exactly like comic book impact effects.

### 5.8 Run Structure

A combat run consists of **10 stages + 1 boss stage**:

```
Stages 1–3:    Goblin Forest     (Addition/Subtraction, Easy)
Stages 4–6:    Mountain Pass     (Multiplication/Division, Medium)
Stages 7–9:    Dark Fortress     (Mixed Operations, Hard)
Stage 10:      Gauntlet          (All Operations, Hard, Elite enemies)
Stage 11:      Boss Lair         (Multi-phase Boss Fight)
```

Each stage has **3–4 waves** of 4–6 enemies.

Between stages, the player visits the **Camp** (evolved StageRewardHub):
- Heal at the campfire (free partial heal)
- Visit the traveling merchant (spend run gold)
- Open collected chests (math lock-picking mini-game)
- View current knight stats and artifacts

### 5.9 Death & Failure

> [!NOTE]
> **There is no permanent death.** The knight never truly dies. When HP reaches 0, the run **ends early**.

- The knight falls to one knee, helmet tilts forward — an **honorable retreat** animation (dramatic but not scary)
- "The knight retreats to fight another day..."
- **You keep:** All XP earned, **all gold earned** (100% — no penalty), completed quest progress, unlocked recipes and chest discoveries
- **You lose:** Remaining stages' rewards, unopened chests downgrade one tier, potential boss loot
- The incentive to survive is **better rewards**, not fear of losing everything
- *(Design note from V2: "Non-punitive rogue-lite. If a run ends, the knight retains all gold, XP, materials, and discoveries." — keeping failure gentle is critical for a math-learning game where wrong answers are part of the learning process.)*

---

## 6. Mini-Games & Activities

### 6.1 ⚒️ The Blacksmith's Forge

> *"Iron glows. Hammer falls. Numbers decide the blade's fate."*

**Math Focus:** All operations (configurable), answer selection under time pressure  
**Session Length:** 3–5 minutes  
**Reward:** Temporary weapon damage buff for next combat run, chance for permanent weapon upgrade materials

#### Gameplay

```
┌────────────────────────────────────────┐
│           THE FORGING PROCESS          │
│                                        │
│  1. Choose a weapon recipe             │
│     (material cost + difficulty level) │
│                                        │
│  2. HEATING PHASE                      │
│     - Sword sits in forge coals        │
│     - Color shifts: grey → orange →    │
│       yellow → WHITE HOT               │
│     - Timing indicator shows the       │
│       "sweet spot" temperature zone    │
│     - Player taps when in the zone     │
│                                        │
│  3. HAMMERING PHASE (main math loop)   │
│     ┌──────────────────────────┐       │
│     │ Problem: 7 × 8 = ?      │       │
│     │                          │       │
│     │ [52] [56] [54] [63]     │       │
│     │                          │       │
│     │  ♪ clink..clink..CLANG! ♪│       │
│     │     ████████████         │       │
│     │     █ RHYTHM BAR █       │       │
│     │     ████████████         │       │
│     └──────────────────────────┘       │
│     - The hammer swings in a steady    │
│       4/4 MUSICAL CADENCE synced to    │
│       the forge BGM (clink..clink..    │
│       CLANG! — the music IS the timer) │
│     - 4 answer ingots glow on the anvil│
│     - Player must:                     │
│       a) Select the CORRECT ingot      │
│       b) Tap it IN RHYTHM with the     │
│          hammer's downbeat             │
│     - Perfect rhythm + correct =       │
│       SPARKS FLY, quality bonus,       │
│       golden shower of particles       │
│     - Correct but off-beat =           │
│       decent strike, no bonus          │
│     - Wrong answer =                   │
│       hammer misses, metal cools       │
│                                        │
│  4. QUENCHING PHASE                    │
│     - Dip the blade in water           │
│     - Final score reveal with          │
│       quality rating: ★ to ★★★★★      │
│                                        │
│  5. RESULT                             │
│     - Weapon forged! Stats displayed   │
│     - Higher quality = more damage     │
│       buff / rarer materials           │
└────────────────────────────────────────┘
```

#### Quality Rating

| Metric | Weight | Description |
|--------|--------|-------------|
| Accuracy | 40% | % of correct answers |
| Timing Precision | 30% | How close to center of green zone |
| Speed | 20% | Faster answers = hotter metal |
| Streak | 10% | Consecutive perfect strikes |

**Quality Tiers:**
- ★ Crude — +5% weapon damage next run
- ★★ Decent — +10% weapon damage
- ★★★ Fine — +15% weapon damage + 1 material drop
- ★★★★ Masterwork — +25% weapon damage + 2 material drops
- ★★★★★ Legendary — +35% weapon damage + rare material + cosmetic sparkle effect

#### Weapon Affixes *(Learned from V2)*

At ★★★+ quality, forged weapons have a chance to roll **elemental affixes** with real combat effects:

| Affix | Visual | Combat Effect |
|-------|--------|--------------|
| 🔥 **Flame Edge** | Blade wreathed in fire, ember trail | Burn damage over time (1 HP/s for 3s after hit) |
| ❄️ **Frost Chill** | Icy blue glow, snowflake particles | Slows enemy march speed by 30% |
| 💰 **Greed Edge** | Golden gleam, coin sparkles | +25% gold drops from slain enemies |
| ⚡ **Storm Strike** | Crackling lightning arcs | 15% chance for chain damage to next enemy in queue |

Affixes are **permanent** once forged — they persist across runs until the weapon is upgraded to the next tier (which can roll a new affix).

#### The Blacksmith Character
- **Name:** *Brok* (or similar)
- **Design:** Stocky dwarf, leather apron, massive forearms, tiny spectacles perched on nose
- **Reactions:** Nods approvingly on perfect strikes, winces on misses, celebrates wildly on ★★★★★, scratches head on ★

---

### 6.2 🪓 The Lumber Yard

> *"Every log tells a division story. Cut it right, or it won't fit."*

**Math Focus:** Division (primary), with multiplication verification  
**Session Length:** 2–4 minutes  
**Reward:** Gold, crafting wood (for upgrades), occasional rare wood types

#### Gameplay

```
┌────────────────────────────────────────┐
│          THE WOOD CUTTING GAME         │
│                                        │
│  Setup:                                │
│  - A log appears with a LENGTH         │
│    (e.g., 12 units)                    │
│  - A storage rack shows the REQUIRED   │
│    piece length (e.g., 2 units)        │
│  - The rack has LIMITED SLOTS          │
│                                        │
│  The Question:                         │
│  "How many cuts to fill the rack?"     │
│  → 12 ÷ 2 = 6 pieces                  │
│  → You need 5 CUTS (pieces - 1)       │
│    OR the game asks for pieces and     │
│    you select 6.                       │
│                                        │
│  Input Method — THE LINE STRETCH TOOL: │
│  ┌──────────────────────────────┐      │
│  │  ║████████████████████████║  │      │
│  │  0  2  4  6  8  10  12       │      │
│  │     ↑  ↑  ↑  ↑  ↑           │      │
│  │     │  │  │  │  │           │      │
│  │     ├──┤  Cut marks          │      │
│  │                              │      │
│  │  Player drags a handle along │      │
│  │  the log. Grid snaps at each │      │
│  │  integer position. The cut   │      │
│  │  count and piece length      │      │
│  │  update live as you drag.    │      │
│  └──────────────────────────────┘      │
│                                        │
│  Confirmation:                         │
│  - Player taps "CUT!" when satisfied  │
│  - If correct: Saw animation!          │
│    BZZZZZ — pieces slide into          │
│    storage slots with a satisfying     │
│    *clunk clunk clunk*                 │
│  - If wrong: Pieces don't fit!         │
│    Some fall off the rack or overlap.  │
│    "Try again!" (no harsh penalty)     │
│                                        │
│  Difficulty Scaling:                   │
│  - Easy: 12÷2, 10÷5, 8÷4             │
│  - Medium: 24÷6, 36÷9, 15÷3          │
│  - Hard: 48÷8, 72÷12, remainders!     │
│    (remainder logs go to scrap pile    │
│     for partial gold)                  │
│                                        │
│  Bonus Round — THE ODD LOG:           │
│  "This log is 13 units. Can it be     │
│   cut evenly into pieces of 4?"       │
│  → NO! 13÷4 = 3 remainder 1          │
│  → Player learns about remainders     │
│    through visual leftover pieces     │
└────────────────────────────────────────┘
```

#### The Lumber Yard Character
- **Name:** *Timber Tom*
- **Design:** Lanky, friendly lumberjack with a bushy mustache, plaid tunic, and an axe too big for him
- **Reactions:** Impressed whistle on fast cuts, stacks wood cheerfully, dramatic "TIMBERRRR!" shout on each log

---

### 6.3 🏰 The Arena (Daily Challenge)

> *"Test your might against the kingdom's finest — one shot, one score."*

**Math Focus:** All operations, escalating difficulty  
**Session Length:** 5–8 minutes  
**Reward:** Arena Points (separate leaderboard currency), exclusive cosmetics, bragging rights

#### Gameplay
- **Single attempt per day** — no retries, no "best of 3"
- Endless escalating waves — how far can you get?
- Global/friend leaderboard with **weekly seasons**
- Top performers earn unique **Arena Champion** cosmetics (crown variants, special swords)
- **Anti-addiction:** One attempt. Done. Come back tomorrow. The constraint IS the design.

---

### 6.4 📜 The Quest Board

> *"A hero's work is never done... but today's quests should take about 15 minutes."*

**3 daily quests** that rotate, drawn from a pool:

| Quest Type | Example | Reward |
|-----------|---------|--------|
| Combat | "Defeat 20 goblins" | 50 gold |
| Accuracy | "Answer 10 problems in a row correctly" | 30 gold + 1 material |
| Speed | "Answer 5 problems in under 3 seconds each" | 40 gold |
| Mini-Game | "Forge a ★★★ weapon at the blacksmith" | 60 gold |
| Division | "Cut 5 logs perfectly at the lumber yard" | 50 gold + rare wood |
| Exploration | "Complete a run reaching stage 7+" | 75 gold + chest |
| Combo | "Achieve a 10-combo in combat" | 40 gold |

**Weekly Quest:** One bigger objective (e.g., "Complete 3 full combat runs this week") for a premium reward (diamonds, rare cosmetic).

### 6.5 🔐 The Royal Treasury *(Learned from V2)*

> *"Ancient dwarven locks don't yield to picks. They yield to factors."*

**Math Focus:** Factor pairs, multiplication  
**Session Length:** 1–3 minutes (per chest)  
**Reward:** Gold, cosmetics, gems, rare artifacts

#### Gameplay
- Chests collected during combat runs are brought here to open
- Each chest has a **rotating tumbler lock** with a target number (e.g., 36)
- The player must spin two dial wheels to land on a valid **factor pair** (4 × 9, 6 × 6, 3 × 12)
- Higher-tier chests require multiple locks (silver = 2, gold = 3, legendary = 4)
- Some locks have constraints: "Find a factor pair where one factor is EVEN"
- Satisfying unlock animation: latch clicks, lid creaks open, golden light spills out

This replaces the generic "math lock-picking" concept with something that **teaches factoring through tactile play**.

---

### 6.6 🏅 Mastery Badges *(Learned from V2)*

> *"The Royal Mathematicians recognize excellence."*

**Math Focus:** Demonstrating sustained mastery  
**Reward:** Royal Emblems (displayed on knight's shield), permanent stat bonuses

Mastery Badges surface the **hidden math profiling** as visible achievements:

| Badge | Requirement | Reward |
|-------|------------|--------|
| **Squire of Sums** | 90% accuracy on 100+ addition problems | +1 ATK, shield emblem |
| **Knight of Subtraction** | 90% accuracy on 100+ subtraction problems | +1 DEF, shield emblem |
| **Master of the Times Table (×7)** | 95% accuracy on 7× table specifically | +2% crit, unique title |
| **Division Commander** | 85% accuracy on 50+ division problems | +5% gold, shield emblem |
| **Speed Demon** | Average answer time < 2s across 50 problems | +3% dodge, title |
| **Flawless Knight** | Complete a full 11-stage run with 0 wrong answers | Legendary cosmetic + diamond |

Badges are displayed on the knight's shield in the Village Hub — a **wall of pride** showing mathematical conquests.

---

### 6.7 🧩 Future Mini-Games (Designed but Not for V1 Launch)

These are **concepts** for post-launch content that extend the adventure:

| Mini-Game | Math Focus | Concept |
|-----------|-----------|---------|
| **The Potion Brewery** | Fractions & Ratios | Mix ingredients in correct proportions. "2 parts fire herb, 3 parts moon water" |
| **The Treasure Map** | Coordinates & Geometry | Navigate a grid map using coordinate pairs to find buried treasure |
| **The Castle Wall** | Patterns & Sequences | Build a wall by completing number patterns (2, 4, 6, ?, ?) |
| **The Royal Bakery** | Measurement & Conversion | Bake bread by converting recipe amounts (kg to g, etc.) |
| **The Siege Catapult** | Estimation & Angles | Estimate trajectory/distance to hit targets |

---

## 7. Progression Systems

### 7.1 Progression Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PROGRESSION LAYERS                       │
│                                                             │
│  Layer 1: KNIGHT LEVEL (1–50)                              │
│     └── Earned through XP from all activities              │
│     └── Each level = 1 Talent Point                        │
│     └── Unlocks new areas, activities, enemy types         │
│                                                             │
│  Layer 2: EQUIPMENT                                        │
│     └── Weapons: Forged at blacksmith, found in chests     │
│     └── Armor: Purchased or crafted                        │
│     └── Accessories: Quest rewards, rare drops             │
│                                                             │
│  Layer 3: VILLAGE UPGRADES                                 │
│     └── Upgrade the forge (better weapons possible)        │
│     └── Expand the lumber yard (more log types)            │
│     └── Build new structures (unlock activities)           │
│                                                             │
│  Layer 4: COSMETICS                                        │
│     └── Purely visual: helmet styles, sword effects,       │
│         victory dances, shield emblems                     │
│     └── Earned through gameplay only (no IAP)              │
│                                                             │
│  Layer 5: MATH MASTERY                                     │
│     └── Per-operation skill tracking (hidden from UI)      │
│     └── Adaptive difficulty adjusts silently               │
│     └── "Mastery Milestones" shown as achievements         │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Knight Level & Talents

**Expanded from current 25 → 50 levels** with a gentler XP curve.

| Stat | Per Point | Max Level | Effect at Max |
|------|-----------|-----------|--------------|
| **Strength** | +0.5 ATK | 10 | +5.0 ATK total |
| **Endurance** | +3 Max HP | 10 | +30 Max HP total |
| **Defense** | +0.3 Armor | 10 | +3.0 Armor total |
| **Agility** | +5% Dodge | 10 | +50% Dodge chance |
| **Wisdom** | +10% Gold, better chest quality | 10 | +100% gold, much better loot |

**New stats unlocked at higher levels:**

| Stat | Per Point | Max Level | Effect at Max | Unlocked At |
|------|-----------|-----------|--------------| ----------- |
| **Focus** *(from V2)* | +3% Crit Chance | 10 | +30% crit chance (2× damage on fast answers) | Knight Level 10 |
| **Crafting** | +quality bonus at forge & lumber | 10 | +50% craft quality bonus | Knight Level 15 |

### 7.3 Equipment System

Weapons now have **persistent progression** beyond cosmetics:

```
Iron Sword (starter)
  └── Steel Sword (forge upgrade, needs iron + coal)
       └── Silver Sword (needs silver ore + forge level 2)
            └── Enchanted Sword (needs magic crystal + forge level 3)
                 └── Legendary Blade (needs dragon scale + forge level 4)
```

Each weapon tier provides:
- Base damage increase (+1, +2, +3, +4, +5)
- Unique visual effect (plain → gleam → glow → flame trail → lightning arc)
- Unique attack animation variant

**Armor follows a similar tree** (leather → chainmail → plate → enchanted → dragon scale).

### 7.4 Currencies

| Currency | Earned From | Spent On |
|----------|------------|----------|
| **Gold** 🪙 | Combat, mini-games, quests, chests | Merchant items, equipment, village upgrades |
| **Materials** ⚒️ | Blacksmithing, lumber yard, combat drops | Weapon/armor crafting & upgrading |
| **Diamonds** 💎 | Boss defeats, weekly quests, achievements | Premium cosmetics, rare recipes |
| **Reputation** ⭐ | Completing runs, quests, arena | Unlocking new areas and activities |

> [!NOTE]
> **No real-money purchases.** All currencies are earned through gameplay. This is a key design commitment.

### 7.5 Unlockable Content Gating

| Requirement | Unlocks |
|-------------|---------|
| Knight Level 1 | Village Hub, Combat Runs (Forest), basic forge |
| Knight Level 5 | Lumber Yard, Quest Board |
| Knight Level 10 | Mountain Pass (multiplication/division combat) |
| Knight Level 15 | Arena, Crafting stat, forge upgrade to level 2 |
| Knight Level 20 | Dark Fortress (mixed operations combat) |
| Knight Level 25 | Advanced forge (level 3), rare materials |
| Knight Level 30 | Dragon's Lair (boss rush mode) |
| Knight Level 35 | Master forge (level 4), legendary recipes |
| Knight Level 40 | Ancient Library (geometry, future content) |
| Knight Level 50 | Grand Champion title, unique cosmetic set |

---

## 8. Math Engine Design

### 8.1 Adaptive Difficulty (Silent)

The game **secretly tracks** per-operation performance:

```gdscript
# Per-operation tracking (invisible to player)
var math_profile = {
    "addition": { "accuracy": 0.92, "avg_time": 2.1, "problems_seen": 340 },
    "subtraction": { "accuracy": 0.87, "avg_time": 2.8, "problems_seen": 280 },
    "multiplication": { "accuracy": 0.74, "avg_time": 4.2, "problems_seen": 150 },
    "division": { "accuracy": 0.68, "avg_time": 5.1, "problems_seen": 90 }
}
```

The engine uses this to:
- Gradually increase number ranges for operations the player is comfortable with
- Provide more practice for weaker operations without the player noticing
- Adjust time limits and distractor difficulty per-operation
- Mix in "challenge" problems slightly above comfort zone (~20% of problems)

### 8.2 Problem Variety

Beyond the existing 3 modes (standard, missing operand, multi-op chain), V1 adds:

| Mode | Description | Used In |
|------|-------------|---------|
| **Result Selection** | Classic: `7 × 8 = ?` → pick from bubbles | Combat, Arena |
| **Missing Operand** | `? × 8 = 56` → find the missing number | Combat (medium+), Forge |
| **Multi-Op Chain** | `3 + 4 × 2 = ?` | Combat (hard), Arena |
| **True/False Shield** | `12 ÷ 4 = 4` True or False? | Combat (shield-bearing enemies) |
| **Division with Remainder** | `13 ÷ 4 = ? R ?` | Lumber Yard |
| **Estimation** | "Which is closest to 100? [97, 88, 103, 112]" | Future: Catapult |

### 8.3 Number Ranges by Difficulty

| Difficulty | Addition | Subtraction | Multiplication | Division |
|-----------|----------|-------------|----------------|----------|
| Easy | 1–20 | 1–20 | 1–5 × 1–10 | ÷1–5, clean |
| Medium | 10–100 | 10–100 | 1–10 × 1–10 | ÷1–10, clean |
| Hard | 50–500 | 50–500 | 1–12 × 1–12 | ÷1–12, with remainder |
| Expert | 100–1000 | 100–1000 | 10–25 × 2–12 | ÷1–25, with remainder |

---

## 9. Input Methods

### 9.1 Retained from Current Build

The existing modular input system is strong and should be **carried forward with visual reskinning**:

| Method | Reskin Direction |
|--------|-----------------|
| **Number Bubbles + Swipe** | Bubbles become floating magical orbs with rune numbers. Swipe trail becomes a sword slash arc. |
| **Handwriting Recognition** | Drawing canvas becomes a magical sand tray or parchment scroll |
| **Keypad** | Keys become carved stone rune buttons |
| **Quick Tap** | Tap target becomes an anvil strike zone |
| **Timing Bar** | Bar becomes a sword alignment gauge |
| **Number Wheel** | Wheel becomes a medieval combination lock |

### 9.2 New Input: Line Stretch Tool (Lumber Yard)

Specific to the wood cutting mini-game:
- Player drags a handle along a horizontal log representation
- Grid snaps at integer positions with visible notch marks
- Live readout: "Piece length: 4 | Pieces: 3 | Fits rack: ✅"
- Tactile snap feedback (vibration on mobile) at each grid position

### 9.3 Input Settings

Players can set their **preferred default input method** per activity. The game remembers the choice.

---

## 10. Audio & Music Direction

### 10.1 Style Shift

> Moving from electronic/chiptune → **orchestral-lite with folk instruments**.

| Context | Mood | Instruments |
|---------|------|------------|
| Village Hub | Warm, cozy, inviting | Lute, flute, gentle drums |
| Combat (easy) | Upbeat, bouncy, fun | Fiddle, snare drum, trumpet stabs |
| Combat (hard) | Intense, driving, heroic | Full strings, war drums, brass |
| Boss Fight | Epic, dramatic, climactic | Choir, heavy percussion, organ |
| Blacksmith | Rhythmic, industrial, warm | Anvil hits, bellows, humming |
| Lumber Yard | Outdoorsy, cheerful | Acoustic guitar, bird chirps, axe chops |
| Arena | Tournament grandeur | Fanfare brass, crowd cheers |
| Victory | Triumphant, celebratory | Full orchestra swell, bells |
| Defeat | Bittersweet, encouraging | Soft strings, "we'll get 'em next time" |

### 10.2 Sound Effects Priority List

Must-have juicy SFX:
- Sword impacts with hit-stop freeze frame (50ms)
- Gold coins with metallic jingle cascade
- Combo counter tick-up with rising pitch
- Correct answer: bright chime + sword swoosh
- Wrong answer: dull thud + shield block (NOT harsh buzzer — never punishing)
- Level up: full fanfare with star burst
- Forge hammer: deep satisfying CLANG with spark crackle
- Log saw: rhythmic BZZZZ with wood creak
- Chest open: latch click → creak → golden light reveal

### 10.3 Juiciness & Game Feel Checklist *(Learned from V2)*

Specific technical specs for maximum juice:

- [x] **Impact Freeze (Hitstop):** 4 frames (~66ms) of micro-pause when the knight's sword connects with an enemy
- [x] **Screen Shake:** Subtle directional impulse matching the sword slash angle (horizontal slash = horizontal shake)
- [x] **Squash and Stretch:** All interactive elements (buttons, bubbles, enemies, logs, ingots) deform playfully on interaction
- [x] **Comic Speech Bubbles:** Float upward from defeated monsters ("OUCH!", "DIVIDED!", "CURSE THY MATH!")
- [x] **Haptic Feedback (Mobile):** Crisp vibration pulses on: anvil strikes, timber cuts, bubble pops, grid snaps, combo milestones, critical hits
- [x] **Chromatic Aberration Burst:** Brief RGB split on critical hits and ★★★★★ forge completions
- [x] **Time Slow on Kill:** 150ms slow-motion on final enemy defeat per wave

### 10.4 Adaptive Combat Music

> [!TIP]
> V2's key insight: the **Blacksmith BGM should integrate anvil clinks as musical instruments**. The forge rhythm track uses syncopated percussion where the anvil CLANG is part of the song — the music and gameplay become one.

The existing AudioManager's adaptive BGM system should be extended so that:
- Combat music tempo increases subtly as combo counter rises
- Forge music has the anvil beat baked into the rhythm track
- Lumber yard cutting sounds sync to the background acoustic rhythm

---

## 11. UI / UX Design

### 11.1 HUD (Combat)

```
┌─────────────────────────────────────────────────┐
│ [❤️❤️❤️❤️🖤] HP    Stage 3/10    🪙 127  💎 3  │
│                                                 │
│                                                 │
│        👹──→           ⚔️🛡️                    │
│     [7 × 8 = ?]      KNIGHT                    │
│                                                 │
│     COMBO: 🔥🔥🔥 ×3                           │
│                                                 │
│  ┌──────────────────────────────────────┐       │
│  │  (52)  (56)  (54)  (63)  (48)      │       │
│  │   ○     ○     ○     ○     ○        │       │
│  └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
```

- HP shown as hearts (not a bar) — more "game-like"
- Combo counter with visual fire/frost/lightning based on element
- Enemy HP shown as small pips above enemy sprite (not a health bar — keeps it cute)
- Gold and diamond counters in top-right, animate on gain
- Stage progress shown as dots: ●●●○○○○○○○

### 11.2 Village Hub UI

- **Isometric or top-down view** of a small village
- Buildings are **tappable** to enter activities
- Character walks between buildings with a cute waddle animation
- Speech bubbles from NPCs give hints and encouragement
- Time-of-day visual changes (morning → afternoon → evening based on real clock)

### 11.3 UI Theme

All UI elements share the medieval theme:
- **Buttons:** Wooden planks with iron rivets, press-in animation
- **Panels:** Parchment/scroll backgrounds with torn edges
- **Headers:** Carved stone or banner ribbons
- **Fonts:** Hand-lettered style (like the existing Silkscreen but warmer — consider something like *Fredoka* or a custom pixel font with rounded edges)
- **Transitions:** Page turns, scroll unfurls, drawbridge lowering

---

## 12. Technical Architecture Changes

### 12.1 What to Keep

The existing architecture is **solid** and should be preserved:

- ✅ **EventBus** — signal-based decoupling (excellent pattern)
- ✅ **GameManager** — state machine with scoring (expand, don't replace)
- ✅ **MathEngine** — problem generation with smart distractors (extend with new modes)
- ✅ **SaveManager** — JSON persistence (extend schema)
- ✅ **RunManager** — roguelike run loop (refactor for new structure)
- ✅ **AudioManager** — polyphonic system with crossfading (reskin audio assets)
- ✅ **SpriteManager** — dynamic sprite loader (extend for new art)
- ✅ **Modular Input Methods** — all 6 methods + PointCloud recognizer (reskin)

### 12.2 What to Add

| System | Purpose |
|--------|---------|
| **VillageManager** (autoload) | Hub state, building levels, NPC dialogue, time-of-day |
| **QuestManager** (autoload) | Daily/weekly quest generation, tracking, rewards |
| **CraftingManager** (autoload) | Equipment upgrade trees, material inventory, recipe unlocks |
| **MathProfiler** (autoload) | Silent per-operation skill tracking, adaptive difficulty |
| **MiniGameManager** (autoload) | State management for non-combat activities |

### 12.3 What to Refactor

| Current | Change |
|---------|--------|
| ASCII/Matrix rendering pipeline | Replace with sprite-based comic rendering |
| Instant-kill combat | HP-based damage system |
| Cosmetic-only equipment | Stats-affecting equipment with upgrade trees |
| 25-level cap | 50-level cap with gentler curve |
| Run-only progression | Village hub with persistent world state |
| Stage select cards | Village → location-based activity selection |

### 12.4 Save Data Schema (Extended)

```json
{
  "version": 3,
  "knight": {
    "level": 1,
    "xp": 0,
    "stat_points": 0,
    "stats": {
      "strength": 0,
      "endurance": 0,
      "defense": 0,
      "agility": 0,
      "wisdom": 0,
      "focus": 0,
      "crafting": 0
    }
  },
  "currencies": {
    "gold": 0,
    "diamonds": 0,
    "materials": {
      "iron": 0, "coal": 0, "silver_ore": 0,
      "magic_crystal": 0, "dragon_scale": 0,
      "common_wood": 0, "oak_wood": 0, "rare_wood": 0
    }
  },
  "equipment": {
    "weapon": { "id": "iron_sword", "tier": 1 },
    "armor": { "id": "leather", "tier": 1 },
    "accessory": null
  },
  "village": {
    "forge_level": 1,
    "lumber_yard_level": 0,
    "arena_unlocked": false,
    "library_unlocked": false
  },
  "math_profile": {
    "addition": { "accuracy": 0.0, "avg_time": 0.0, "total": 0 },
    "subtraction": { "accuracy": 0.0, "avg_time": 0.0, "total": 0 },
    "multiplication": { "accuracy": 0.0, "avg_time": 0.0, "total": 0 },
    "division": { "accuracy": 0.0, "avg_time": 0.0, "total": 0 }
  },
  "quests": {
    "daily": [],
    "weekly": null,
    "last_refresh": ""
  },
  "cosmetics": {
    "unlocked": [],
    "equipped": {}
  },
  "mastery_badges": [],
  "weapon_affix": null,
  "stats": {
    "total_runs": 0,
    "total_problems_solved": 0,
    "total_enemies_defeated": 0,
    "best_combo": 0,
    "best_arena_wave": 0
  },
  "settings": {
    "sfx_enabled": true,
    "music_enabled": true,
    "preferred_input_method": "bubbles",
    "language": "de"
  }
}
```

---

## 13. Monetization & Ethics

### 13.1 Business Model: Premium or Free with No Dark Patterns

> [!CAUTION]
> **Non-negotiable:** No lootboxes, no gacha, no energy systems, no pay-to-win, no ads interrupting gameplay, no FOMO mechanics.

**Option A — Premium (recommended):**
- One-time purchase (\$4.99–\$9.99)
- All content included
- Future updates free

**Option B — Free with optional supporter pack:**
- Full game free
- Optional "Knight's Patron" pack (\$4.99) = exclusive cosmetic set + "Thank you" badge
- No gameplay advantage

### 13.2 Session Guardrails

- After 30 minutes: Gentle yawn animation + "Maybe time for a break?"
- After 45 minutes: Slightly more insistent: "The knight is getting sleepy... Save your strength for tomorrow!"
- After 60 minutes: "Great training session! The knight is resting now." (No forced lockout, just strong suggestion)
- **Parental controls:** Optional time limit setting in options menu

---

## 14. Target Platforms & Performance

| Platform | Priority | Notes |
|----------|----------|-------|
| Android | Primary | Existing APK build pipeline, touch-first design |
| iOS | Secondary | Same touch design, separate export |
| Web (HTML5) | Tertiary | Demo/shareability |
| Windows/Mac | Low | Desktop testing, keyboard input supported |

**Performance Targets:**
- 60 FPS on mid-range phones (2022+)
- < 100MB install size
- < 50MB RAM usage
- Battery-friendly (no excessive particle systems or shaders running when idle)

---

## 15. Development Roadmap (Suggested Phases)

### Phase 1: Foundation (Art + Combat Rework)
- [ ] New art style pipeline: knight, 3 enemy types (goblin, skeleton, orc)
- [ ] HP-based combat system replacing instant-kill
- [ ] Damage formulas, combo system, speed bonuses
- [ ] Reskin UI to medieval theme (parchment, wood, stone)
- [ ] Village hub (static, tappable buildings, 2 locations: combat + forge)

### Phase 2: Mini-Games
- [ ] Blacksmithing forge complete gameplay loop
- [ ] Lumber yard complete gameplay loop
- [ ] Line Stretch input tool for lumber yard
- [ ] Quest board with daily quests

### Phase 3: Progression Depth
- [ ] Equipment upgrade trees (weapon + armor)
- [ ] Material/crafting system
- [ ] Extended level cap (50) with crafting stat
- [ ] Village upgrades (forge levels, building new structures)
- [ ] Adaptive math difficulty engine

### Phase 4: Polish & Content
- [ ] Full enemy bestiary (all 7 types + variations)
- [ ] Arena daily challenge mode
- [ ] New audio (orchestral-folk direction)
- [ ] Session guardrails and parent settings
- [ ] Achievement / mastery milestone system
- [ ] Tutorial and onboarding rework

### Phase 5: Future Content
- [ ] Additional mini-games (potion brewery, treasure map, etc.)
- [ ] Friend leaderboards
- [ ] Seasonal events / themed content
- [ ] New math domains (geometry, fractions)

---

## 16. Success Metrics

How do we know the redesign is working?

| Metric | Target | Why |
|--------|--------|-----|
| Average session length | 10–20 minutes | Engaged but not addicted |
| Return rate (next day) | > 40% | Fun enough to come back |
| Problems solved per session | 50–100 | Real math practice happening |
| Average accuracy | 75–85% | Problems are challenging but achievable |
| Completion rate (full runs) | > 60% | Difficulty is fair |
| Player-reported "fun" | 4+/5 | It doesn't feel like homework |

---

> *"The knight doesn't fight with numbers. The knight fights with COURAGE. The numbers just decide how hard the sword hits."*

— MathKnight GDD V1
