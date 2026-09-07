# MathKnight: Realm of Numbers
## Game Design Document — Version 2.0 (V2)
**Project Codename:** `MathKnight-V2`  
**Target Engine:** Godot 4.5.1 (Windows / Android / Cross-Platform)  
**Document Status:** Approved Architecture & Game Design Master Blueprint  

---

```
  /\                                                 /\
 / \'._   _________________________________________   _.'/ \
| o o )  [   MATHKNIGHT: REALM OF NUMBERS — V2    ]  ( o o |
 \_-_/    -----------------------------------------    \_-_/
  ||               [ MEDIEVAL COMIC RPG ]               ||
```

---

## 1. Executive Summary & Core Philosophy

### 1.1 High Concept
*MathKnight: Realm of Numbers* is a vibrant, comic-medieval action RPG where mental math is the blade, shield, and forge of a chivalric adventurer. Players don the plate armor of **Sir Solv-a-Lot** (or a custom Knight of the Round Abacus) to defend the realm against quirky, comical monsters, forge legendary blades upon rhythmic anvils, and saw timber for the kingdom’s construction through geometric division.

### 1.2 The "Honest Effort" Pedagogical Engine
Unlike hyper-gamified or predatory mobile titles that rely on superficial lottery loops and synthetic dopamine:
1. **Effort Feels Genuine:** The game embraces the fact that learning math takes real cognitive effort—a "little tiny bit of work." Math is not hidden behind arbitrary timers; it is celebrated as the source of heroic power.
2. **Juicy, Earned Dopamine:** Every correct calculation is accompanied by crunchy sound effects, screen impacts, sparks, flying woodchips, and visible tactical rewards. You don’t get prizes for merely breathing; you get epic rewards for conquering real mental hurdles.
3. **Proud Competence:** The emotional destination is **genuine mastery**. The player feels smart, capable, and confident—both in the game and in real-world arithmetic.
4. **No Addiction Dark Patterns:** No energy caps, no artificial gating, no FOMO counters. A run can be paused or concluded naturally at any time. When an expedition ends, the knight always returns to town with dignity, retaining all acquired gold, experience, and unlocked knowledge.

---

## 2. Art Direction & Visual Identity

```
+------------------------------------------------------------------------+
|                      VISUAL TONE & IDENTITY                            |
|                                                                        |
|   OLD: "Matrix Number Knight"       -->       NEW: "Comic Medieval"    |
|   - Green-on-black glyphs                     - Hand-crafted comic ink |
|   - Sterile ASCII wireframes                  - Warm stone & lush grass|
|   - Monochromatic terminal vibe               - Bouncy squash-&-stretch|
|   - Abstract math realm                       - Slapstick quirky armor |
+------------------------------------------------------------------------+
```

### 2.1 Aesthetic Pillars
* **Style:** High-charm 2D Comic Cartoon with bold ink outlines, vibrant hand-painted color palettes, and optional crispy pixel-art fidelity.
* **Tone:** Playful chivalry, lighthearted danger, slapstick heroism (reminiscent of *Asterix*, *Rayman Legends*, and *Kingdom Rush*).
* **Color Palette:**
  * Royal Lapis Blue, Crimson Red, and Burnished Gold for the Knightly Order.
  * Warm Oak, Mossy Stone, and Hearth Orange for the Town and Mini-Games.
  * Emerald Goblins, Bone-White Skeletons, and Violet Warlocks for the monstrous forces.

### 2.2 Character Roster & Bestiary

```
                     [ THE KNIGHT ]
                     (Sir Solv-a-Lot)
             ___   /
            |o.o| /   "By the power of the Prime!"
           [|[ ]|]
           /  |  \
          *  / \  *

             [ MONSTER ARCHETYPES ]
       .---.          .-.          (o o)
      ( >_< )        (o.o)         / V \
     [Goblin Scout] [Skelly]    [Mad Alchemist]
     Quick Add/Sub  Multi/Div    Potion Ratios
```

1. **The Hero (Sir Solv-a-Lot):**
   * Expressive animated visor (eyes blink, squint in focus, or widen in alarm behind the slit).
   * Bobbing blue-feather plume that bounces with every step and attack.
   * Modular equipment: Visually updates when equipping crafted swords (Flame, Frost, Damascus, Golden, Frying Pan) and helmets (Viking, Wizard, Jester, Crown).
2. **The Common Rogues:**
   * **Grumpy Goblin Scouts:** Clumsy, wielding oversized sticks. Feature quick single-digit addition and subtraction.
   * **Rattling Skeletons:** Juggling bones and wooden shields. Feature multiplication tables (times-tables mastery).
   * **Slime Amalgams:** Gelatinous cubes that wobble and divide when hit, testing division and fractions.
   * **Rogue Squires:** Armored hedge knights who demand multi-step order of operations before their guard breaks.
3. **Elite Monsters & Mini-Bosses:**
   * **Ogre Gatekeeper:** Massive HP pool; requires consistent hits over multiple waves.
   * **The Mad Alchemist:** Throws flasks labeled with mystery operands (? + 7 = 15); player must identify the missing catalyst.
4. **World Bosses:**
   * **Gorg the Great-Divider:** Giant forest troll who challenges the knight to log-cutting and division duels.
   * **Baron Von Fraction:** An armored colossus whose armor plates break off in fractions (1/4, 2/4, 3/4).
   * **The Dragon of Primes:** Resides at the pinnacle of Mount Numerus; vulnerable only to prime factor strikes.

---

## 3. Core Combat Loop & Battle System

```
+-------------------------------------------------------------------------+
|                           EXPEDITION RUN LOOP                           |
|                                                                         |
|  [Wave Enters] ---> [Math Challenge] ---> [Player Inputs Answer]        |
|                            |                       |                    |
|                            |                       v                    |
|                            |            [KNIGHT ATTACKS & DEALS DMG]    |
|                            |            (Damage = ATK * Stat Boosts)    |
|                            |                       |                    |
|                            v                       v                    |
|                 [Enemy Timer/Distance]  [Enemy HP = 0? -> Defeated]     |
|                            |                       |                    |
|                            v                       v                    |
|                  [Enemy Attacks Knight]  [Gold, XP & Chests Collected]  |
|                  (Mitigated by Armor/      (Next Wave / Stage Choice)   |
|                   Dodge Stats)                                          |
+-------------------------------------------------------------------------+
```

### 3.1 Damage & Combat Formula
In V2, math problems do not simply execute binary instant-kill scripts. Instead, math operates as the **action catalyst for genuine RPG combat statistics**:

$$\text{Player Damage} = (\text{Base Weapon ATK} + \text{Strength}) \times \text{Speed Multiplier} \times \text{Combo Multiplier}$$

* **Base Weapon ATK:** Upgraded permanently at the Blacksmith.
* **Strength:** Upgraded through Knight Level-ups.
* **Speed Multiplier:** Fast answers (<= 1.2s) yield a 1.25x "Quick Strike" or 1.5x "Critical Decapitation".
* **Combo Multiplier:** Consecutive correct calculations without errors build the **Flow Gauge**, unlocking wide cleaving slashes that damage multiple enemies in the queue.
* **Enemy HP Pools:**
  * Goblin: 2 - 4 HP (1 fast hit or 2 steady hits).
  * Skeleton Knight: 6 - 10 HP (requires 2-3 successful equations).
  * Boss: 40 - 150 HP (epic endurance battle with dynamic phase shifts).

### 3.2 Defensive & Survival Mechanics
When enemies reach melee distance, they strike the Knight at regular intervals:
* **Max HP:** Total health pool per expedition.
* **Armor (Defense):** Flat reduction against incoming enemy blows:
  $$\text{Damage Received} = \max(1, \text{Enemy ATK} - \text{Knight Armor})$$
* **Dodge Chance (Agility):** Probability (0% to 35%) of completely evading an incoming strike, triggering a comical puff of dust and a "WHOOSH!" comic banner.
* **No Permadeath Wipeout:** When the knight's HP hits zero:
  * The expedition ends with an honorable retreat animation.
  * **All gathered gold, experience points, unlocked recipes, and discovered chests are KEPT.**
  * The player returns to town, upgrades stats/equipment, and sets out again with improved power and confidence.

---

## 4. Knight Life: Town Hub & Crafting Mini-Games

```
                               +----------------+
                               |   CASTLE TOWN  |
                               |    COURTYARD   |
                               +-------+--------+
                                       |
        +------------------+-----------+-----------+------------------+
        |                  |                       |                  |
        v                  v                       v                  v
  [THE BLACKSMITH]   [THE TIMBER MILL]       [THE GUILD HALL]   [ROYAL VAULT]
  - Rhythm Anvil     - Division Logging      - Daily Quests     - Chest Opening
  - Sharpness Craft  - Grid Snap Tool        - Bounties         - Relic Vault
  - Sword Enchants   - Storage Stacking      - Trophies         - Cosmetic Mirror
```

### 4.1 Mini-Game 1: The Blacksmith's Anvil (Sword Forging & Tempering)
* **Theme:** Sir Solv-a-Lot and the Master Smith shaping Damascus steel over glowing charcoal.
* **Core Mechanics:**
  * **Rhythm & Timing:** An anvil hammer swings in a steady 4/4 cadence (clink... clink... CLANG!).
  * **Mental Arithmetic Selection:** As the hammer approaches the strike zone, a glowing furnace calculation appears with multiple floating runic iron ingots displaying candidate numbers.
  * **Strike Execution:** The player taps the correct ingot right in rhythm with the hammer's impact.
* **Juice & Visual Feedback:**
  * A shower of golden sparks and chromatic aberration burst across the screen upon correct hits.
  * The steel blade visually transforms: dull iron -> mirror steel -> blue-tempered Damascus -> runic glow.
  * A combo heat meter at the bottom builds toward "Masterpiece Quality".
* **Progression Payoff:**
  * Permanent +1 to +10 Attack Power on the equipped weapon.
  * Chance to roll special combat affixes: *Flame Edge* (burn damage over time), *Frost Chill* (slows enemy walk speed), or *Greed Edge* (+25% gold drops).

```
   [BLACKSMITH ANVIL INTERACTION]
            ( Hammer )
                 |
                 v
             +-------+       [ 8 ]  [ 12 ]  [ 16 ]
             | ANVIL |        (Tap correct answer
             +-------+         on the beat!)
          "4 x 3 = [ ? ]"
```

### 4.2 Mini-Game 2: The Timber Mill (Lumberjack Division & Fractions)
* **Theme:** Supplying the Royal Engineers with precisely cut timber for drawbridges, siege defenses, and castle halls.
* **Core Mechanics:**
  * A raw tree log of specified length $L$ rolls onto the sawbench (e.g., $L = 12\text{ meters}$, $18\text{ meters}$, or $24\text{ meters}$).
  * The storage rack requisition specifies the required section length $S$ (e.g., "We need beam segments of length 3!").
  * The mathematical challenge: Calculate the required cuts / divisor:
    $$\text{Number of Pieces} = \frac{L}{S} \quad \Longrightarrow \quad \text{Cuts Needed} = \text{Pieces} - 1$$
* **Interactive Line-Stretch & Snapping Tool:**
  * The player drags a measurement line across the log.
  * The line snaps crisply to whole-number divisions on the wood grain with tactile ticks and audio clicks.
  * Visual cut guides appear on the log, displaying segment lengths in real time.
* **Juice & Physical Payoff:**
  * Releasing the cut triggers the giant waterwheel-powered sawblade: WHIRRR-CHUNK!
  * The cut logs split apart with realistic physics, tumbling into the waiting firewood carts.
  * If the cut matches the rack requirements, the timber stacks into the shed with a satisfying THUD-THUD-THUD and gold coins pop into the player's wallet.
  * If the division is wrong, funny imperfect scrap pieces bounce out comically ("Oops! Too short!").

```
   [TIMBER MILL LINE-STRETCH DIVISION]
    Req: Length 3 per piece
   +---------------------------------------+
   | [ 3m ] | [ 3m ] | [ 3m ] | [ 3m ]     | Total: 12m
   +---+----+---+----+---+----+---+--------+
       ^        ^        ^        ^
       |        |        |        (Snapping cut markers)
       Drag line stretches across grid
```

### 4.3 Mini-Game 3: The Royal Treasury (Lock-Picking & Factoring)
* **Theme:** Unlocking ancient Dwarven treasure chests discovered during dungeon runs.
* **Mechanic:** The chest features rotating tumbler dials with factor pairs. E.g., The lock target is 36; the player spins dials to align matching factors (4 x 9, 6 x 6).
* **Reward:** Yields precious gems, cosmetic knight skins, and rare artifacts.

---

## 5. Input Modalities: Versatile, Ergonomic & Accessible

MathKnight V2 unifies and refines multiple intuitive input methods so that any player on any device (phone, tablet, PC mouse/keyboard) can play comfortably:

| Input Method | Interaction Style | Pedagogical Benefit | Primary Game Mode |
| :--- | :--- | :--- | :--- |
| **Bubble Slicing** | Swipe gesture cutting flying number bubbles | Spatial hand-eye coordination | Fast Wave Battles |
| **Line-Stretch Snap** | Dragging 1D/2D rulers with integer magnetic grid snaps | Visualizing fractions, lengths, and arrays ($X \times Y$) | Timber Mill & Equation Forge |
| **Handwriting Canvas** | Freehand digit writing with neural/stroke recognition | Motor memory reinforcement of numeral writing | Boss Fights & Scholar Quests |
| **Rhythmic Tap Pad** | Clean, high-contrast big button grid with haptic feedback | Maximum speed and low friction for rapid testing | Blacksmith Anvil & Speed Trials |
| **Number Wheel** | Circular radial dial with angular snap | Angle intuition and rotational estimation | Castle Locks & Dial Riddles |

---

## 6. Progression Systems & Economy Loop

```
+--------------------------------------------------------------------------+
|                          PROGRESSION ARCHITECTURE                        |
|                                                                          |
|       [COMBAT RUNS]        [TIMBER MILL]        [BLACKSMITH FORGE]       |
|             |                    |                      |                |
|             v                    v                      v                |
|       +-----------+        +------------+        +-------------+         |
|       | Gold Coins|        | Wood Beams |        | Iron Ingots |         |
|       +-----+-----+        +-----+------+        +------+------+         |
|             |                    |                      |                |
|             +--------------------+----------------------+                |
|                                  |                                       |
|                                  v                                       |
|                  [CASTLE TOWN EXPANSION & UPGRADES]                      |
|                  - Upgrade Knight Base Stats (STR, DEF, HP)              |
|                  - Unlock New Weapon Blueprints                          |
|                  - Expand Storage Racks & Mill Capacity                  |
|                  - Unlock Cosmetic Armor, Capes & Helmets                |
+--------------------------------------------------------------------------+
```

### 6.1 Currencies
1. **Gold Coins:** Earned from defeating monsters, cutting timber, and flawless sets. Used for stat upgrades and purchasing items.
2. **Crafting Materials (Iron, Wood, Runestones):** Gathered from the mini-games and dungeon chests to craft and temper gear.
3. **Royal Emblems (Mastery Badges):** Earned by demonstrating mastery over specific mathematical domains (e.g., "Master of the 7-Times Table", "Logarithm Squire").

### 6.2 The Knight's Permanent Stat Progression
* **Level Cap:** Level 50.
* **Stats:**
  * **Strength (ATK):** Increases damage per hit by +1.0 per point.
  * **Endurance (Max HP):** Increases expedition life bar by +5 HP per point.
  * **Defense (Armor):** Mitigates incoming enemy attack damage.
  * **Agility (Dodge):** Grants passive percentage chance to evade damage.
  * **Focus (Crit Chance):** Grants chance for fast answers to trigger double-damage slashes.

---

## 7. Sound, Music & Juiciness Specifications

### 7.1 Dynamic Music System
* **Town Theme:** Warm lute, acoustic guitar, cheerful medieval flute, tavern foot-taps.
* **Combat Theme:** Driving orchestral percussion, brass fanfares, bouncy cello lines that increase in tempo as the combo meter ascends.
* **Blacksmith Rhythm Track:** Syncopated percussion with metallic anvil clangs integrated as part of the musical rhythm.

### 7.2 Juiciness Checklist (Game Feel)
- [x] **Impact Freeze (Hitstop):** 4 frames of micro-pause when the knight lands a strike on an enemy.
- [x] **Screen Shake:** Subtle directional impulse corresponding to sword slash angle.
- [x] **Squash and Stretch:** Buttons, bubbles, enemies, and logs deform playfully on interaction.
- [x] **Comic Speech Bubbles:** Float upwards from defeated monsters ("OUCH!", "DIVIDED!", "CURSE THY MATH!").
- [x] **Haptic Feedback:** Crisp vibration pulse on mobile devices when cutting timber or striking the anvil.

---

## 8. Technical Architecture (Godot 4.5)

```
===========================================================================
                      GODOT 4.5 NODE & SINGLETON MAP
===========================================================================

 [Autoload Singletons]
   ├── EventBus.gd           --> Global signals (combats, crafts, cuts)
   ├── GameManager.gd        --> Game states, run tracking, flow control
   ├── MathEngine.gd         --> Procedural arithmetic problem generators
   ├── RunManager.gd         --> Active dungeon expedition stats & choices
   ├── SaveManager.gd        --> Persistent JSON save data (stats, gear, gold)
   ├── TownManager.gd  [NEW] --> Town buildings, resource stockpiles & quests
   └── AudioManager.gd       --> Dynamic music layers & responsive SFX

 [Core Scenes & Modules]
   ├── res://scenes/town/
   │     ├── TownHub.tscn            --> Main courtyard navigation
   │     ├── BlacksmithForge.tscn    --> Rhythmic anvil mini-game
   │     └── TimberMill.tscn         --> Line-stretch division logging game
   ├── res://scenes/combat/
   │     ├── BattleArena.tscn        --> Wave-based monster combat
   │     ├── KnightHero.tscn         --> Animated 2D comic knight with gear
   │     └── EnemyRoster/            --> Goblin, Skeleton, Slime, Bosses
   └── res://scenes/ui/
         ├── InputOverlay.tscn       --> Bubble slice, handwriting, stretch
         └── VictoryExpedition.tscn  --> Non-punitive run rewards screen
```

---

## 9. Phased Implementation Roadmap

```
PHASE 1: Art Direction & Comic Visual Overhaul
├── Finalize comic knight sprite frames (Sword Attack, Idle Bob, Hurt, Celebrate).
├── Implement comic enemy archetypes (Goblin, Skeleton, Slime).
└── Deploy comic hit-splashes and text bubble fx ("POW!", "CLANG!").

PHASE 2: Stat-Driven Combat & HP Rework
├── Decouple math solves from instant-death; hook into Knight ATK and Enemy HP.
├── Implement Armor mitigation, Dodge rolls, and Critical Strike multipliers.
└── Revamp run-end sequence to ensure zero progress is lost on defeat.

PHASE 3: The Blacksmithing Mini-Game
├── Construct rhythmic anvil audio-visual beat clock.
├── Integrate math formula ingot selection on strike timing.
└── Implement weapon sharpening stat persistence in SaveManager.

PHASE 4: The Timber Mill Division Game
├── Adapt line-stretch grid tool for log cutting mechanics.
├── Build physics-based falling log animation and storage rack stacking.
└── Integrate wood resource rewards into the town economy.

PHASE 5: Town Hub, Quests & Polish
├── Assemble Castle Town Hub connecting all modes.
├── Add Daily Guild Bounties and Mathematical Mastery Trophies.
└── Full audio juice pass, haptics, and responsive screen shakes.
```

---
*End of Game Design Document V2. Prepared for MathKnight Engine Development.*
