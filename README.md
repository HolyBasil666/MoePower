# MoePower

A lightweight, modular class power HUD for **World of Warcraft: The War Within**.

Displays your class resource (Holy Power, Essence, combo points, etc.) as animated orbs arranged in an arc around your character — no external libraries required.

![Version: 0.9](https://img.shields.io/badge/Version-0.9-orange)

---

## Features

- **Arc orb display** — power orbs arranged in a smooth arc, growing from the center outward
- **Fade animations** — smooth fade in/out transitions on power gain/loss
- **Edit Mode integration** — drag to reposition using WoW's built-in Edit Mode; position saves between sessions
- **No dependencies** — uses only native Blizzard APIs

---

## Supported Classes

| Class | Resource | Notes |
|-------|----------|-------|
| Paladin | Holy Power | 5 orbs; rune textures swap at low HP |
| Evoker | Essence | 5–6 orbs (talent-dependent); hides at full essence out of combat |
| Hunter | Tip of the Spear | Survival spec only; 3 orbs tracked via spell cast events |
| Death Knight | Runes | 6 orbs; spec-specific textures (Blood/Frost/Unholy); hides at full runes out of combat |

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
