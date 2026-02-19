# MoePower

A lightweight, modular class power HUD for **World of Warcraft: The War Within**.

Displays your class resource (Holy Power, Essence, combo points, etc.) as animated orbs arranged in an arc or horizontal line around your character — no external libraries required.

![Version: 1.0](https://img.shields.io/badge/Version-1.0-blue)

---

## Features

- **Arc or horizontal line display** — switch between a smooth arc and a flat horizontal line in the options panel
- **Orb fill direction** — choose center outward (default), left → right, or right → left
- **Fade animations** — smooth fade in/out transitions on power gain/loss
- **Edit Mode integration** — drag to reposition using WoW's built-in Edit Mode; position saves between sessions
- **Options panel** — `Game Menu → Options → AddOns → MoePower`; configure scale, layout, fill direction, and per-class toggles
- **No dependencies** — uses only native Blizzard APIs

---

## Supported Classes

| Class | Resource | Notes |
|-------|----------|-------|
| Paladin | Holy Power | 5 orbs; rune textures swap at low HP |
| Evoker | Essence | 5–6 orbs (talent-dependent); hides at full essence out of combat |
| Hunter | Tip of the Spear | Survival spec only; 3 orbs tracked via spell cast events |
| Death Knight | Runes | 6 orbs; spec-specific textures (Blood/Frost/Unholy); hides at full runes out of combat |
| Monk | Chi / Teachings | Windwalker: 5–6 chi orbs; Mistweaver: 4 orbs tracking Teachings of the Monastery stacks |

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

## Options

Open via `Game Menu → Options → AddOns → MoePower`.

| Setting | Description |
|---------|-------------|
| **Orb Scale** | Global size multiplier (0.5× – 2.0×), applied live |
| **Layout** | Arc (default) or Horizontal line |
| **Orb Fill Direction** | Center outward (default), Left → Right, or Right → Left |
| **Paladin: Hide at max** | Hide Paladin orbs at full Holy Power when out of combat |
| **Modules** | Enable or disable individual class modules |

---
