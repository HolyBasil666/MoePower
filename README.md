# MoePower

A lightweight, modular class power HUD for **World of Warcraft: The War Within**.

Displays your class resource (Holy Power, Essence, combo points, etc.) as animated orbs arranged in an arc around your character — no external libraries required.

![Interface: 120000](https://img.shields.io/badge/Interface-120000-blue)
![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-green)

---

## Features

- **Arc orb display** — power orbs arranged in a smooth arc, growing from the center outward
- **Fade animations** — smooth fade in/out transitions on power gain/loss
- **Edit Mode integration** — drag to reposition using WoW's built-in Edit Mode; position saves between sessions
- **Grid snapping** — positions snap to a 10px grid for clean alignment
- **Modular architecture** — each class is a self-contained module; only your class loads
- **No dependencies** — uses only native Blizzard APIs

---

## Supported Classes

| Class | Resource | Notes |
|-------|----------|-------|
| Paladin | Holy Power | 5 orbs; rune textures swap at low HP |
| Evoker | Essence | 5–6 orbs (talent-dependent); hides at full essence out of combat |
| Hunter | Tip of the Spear | Survival spec only; 3 orbs tracked via spell cast events |

---

## Installation

1. Download and extract the `MoePower` folder
2. Place it in `World of Warcraft/_retail_/Interface/AddOns/`
3. Enable **MoePower** in the AddOns list at character select
4. `/reload` if already logged in

---

## Positioning

1. Open **Edit Mode** (`Escape → Edit Mode` or the default keybind)
2. Drag the **MoePower** handle to your preferred position
3. Exit Edit Mode — position is saved automatically

---

## Class Notes

### Paladin — Holy Power
Orbs use the Blizzard holy power rune textures and are displayed in the game's natural rune order. At 1–2 Holy Power the runes appear dimmed to signal low resources.

### Evoker — Essence
Orbs are hidden when at full Essence and out of combat (no need to regenerate). They reappear when entering combat or when Essence starts regenerating.

### Hunter — Tip of the Spear (Survival only)
Tracks the Tip of the Spear buff internally via spell cast events, since aura data is blocked during combat in TWW 12.0. Stacks are synced from the actual aura when out of combat.

- **Kill Command** — grants 1 stack (2 with Primal Surge talent)
- **Takedown** — grants 3 stacks with Twin Fangs talent, otherwise consumes 1
- **Spender abilities** (Raptor Strike, Wildfire Bomb, etc.) — consume 1 stack

Orbs hide 1 second after leaving combat with no stacks.

---

