# MoePower - Development Guide

**Class Power HUD for World of Warcraft: The War Within**

## Project Info
- **Version**: 1.0.0
- **Interface**: 120000 (TWW Patch 12.0.0)
- **Author**: HolyBasil666
- **Architecture**: Modular class-based framework

## Critical Rule: No External Dependencies

**This addon must NEVER depend on external libraries or addons.**

❌ **Do NOT use**: LibStub, AceAddon, AceDB, LibSharedMedia, WeakAuras APIs
✅ **Only use**: Native Blizzard WoW API, built-in UI elements, Blizzard atlas textures

**Why**: Standalone operation, minimal overhead, no breakage from external updates.

```lua
// GOOD - Native Blizzard atlas
pcall(texture.SetAtlas, texture, "uf-essence-icon")

// BAD - External library
local LSM = LibStub("LibSharedMedia-3.0")
```

---

## File Structure

```
MoePower/
├── MoePower.toc          # Addon manifest (MUST declare SavedVariables!)
├── MoePower.lua          # Core framework
├── CLAUDE.md             # This file
└── Classes/
    ├── Evoker.lua        # Evoker essence module
    └── Paladin.lua       # Paladin holy power module
```

### MoePower.toc (Critical Fields)
```ini
## Interface: 120000
## SavedVariables: MoePowerDB    # MUST BE DECLARED or positions won't save!

MoePower.lua
Classes\Evoker.lua
Classes\Paladin.lua
```

---

## Architecture

### Modular Class System

**Framework** (MoePower.lua):
- Manages events, frame creation, position saving
- Provides shared utilities (`AddOrbAnimations`)
- Routes updates to active class module

**Class Modules** (Classes/*.lua):
- Self-contained class-specific logic
- Register with `MoePower:RegisterClassModule()`
- Only the player's class module activates

```lua
// Module structure
local ClassModule = {
    className = "EVOKER",                  -- UnitClass() filename
    powerType = Enum.PowerType.Essence,    -- Power enum
    powerTypeName = "ESSENCE",             -- UPPERCASE for optimization

    config = {
        orbSize = 25,
        activeAlpha = 1.0,
        transitionTime = 0.15,
        backgroundAtlas = "uf-essence-bg-active",
        foregroundAtlas = "uf-essence-icon"
    }
}

function ClassModule:CreateOrbs(frame, layoutConfig)
    // Create orb frames in arc formation
    // Use MoePower:AddOrbAnimations(frame, config) for fade effects
    return orbsArray
end

function ClassModule:UpdatePower(orbs)
    // Update orb visibility based on UnitPower()
end

MoePower:RegisterClassModule(ClassModule)
```

### Framework Utilities

**`MoePower:AddOrbAnimations(frame, config)`**
Centralizes fade in/out animation logic. Returns fadeIn, fadeOut animation groups.

```lua
local fadeIn, fadeOut = MoePower:AddOrbAnimations(orbFrame, cfg)
// Store and use: orb.fadeIn:Play(), orb.fadeOut:Play()
```

---

## Implementation Details

### Arc Layout System
Orbs arranged in arc formation with configurable radius and spacing:

```lua
// In MoePower.lua
local ARC_RADIUS = 140              -- Distance from center
local BASE_ORB_SPACING = 12.5       -- Degrees between orbs
local arcSpan = BASE_ORB_SPACING * (maxPower - 1)

// In module CreateOrbs()
local startAngle = 90 + (arcSpan / 2)  -- Start from top
local angle = startAngle - ((i - 1) * (arcSpan / (maxPower - 1)))
local radian = math.rad(angle)
local x = arcRadius * math.cos(radian)
local y = arcRadius * math.sin(radian)
```

### Centered Display Pattern
Orbs grow from center outward (e.g., 3/5 essence shows middle 3 orbs):

```lua
local startIndex = math.floor((maxPower - currentPower) / 2) + 1
local endIndex = startIndex + currentPower - 1
// Orbs i where startIndex <= i <= endIndex are visible
```

### Event Handling & Optimization

**Registered Events**:
- `PLAYER_LOGIN` → Initialize (1s delay for stat loading)
- `UNIT_POWER_FREQUENT` → Update display
- `UNIT_MAXPOWER` → Recreate orbs (e.g., talent changes)
- `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`, `PLAYER_SPECIALIZATION_CHANGED` → Recreate orbs (1s delay)
- `PLAYER_REGEN_DISABLED/ENABLED` → Combat visibility (Evoker only)

**Performance Optimization**:
```lua
// BAD: Two string operations every update (fires multiple times/sec)
local modulePowerType = (activeModule.powerTypeName or ""):upper()

// GOOD: powerTypeName already uppercase, one operation only
if eventPowerType == activeModule.powerTypeName then
    UpdatePower()
end
```

### Position Persistence

**Grid Snapping**: Positions snap to 10px grid for alignment.

```lua
// Must be in .toc or positions don't save!
## SavedVariables: MoePowerDB

// Framework saves on drag end
MoePowerDB.position = { point, relativePoint, x, y }

// Framework loads on PLAYER_LOGIN
LoadPosition() // Called in Initialize()
```

---

## Class-Specific Implementations

### Evoker (Essence)
- **Max Power**: 6 (dynamic via talents)
- **Visibility**: Shows only in combat OR when regenerating (current < max)
- **Textures**: `uf-essence-bg-active`, `uf-essence-icon`
- **Logic**: Checks `UnitAffectingCombat("player")` in UpdatePower

### Paladin (Holy Power)
- **Max Power**: 5 (always fixed)
- **Visibility**: Always shown
- **Textures**: `uf-holypower-rune{1-5}-{active/ready}` (custom mapping)
- **Rune Mapping**: Positions 1-5 → Runes {4, 2, 1, 3, 5}
- **Texture Variants**: "active" for 1-2 HP, "ready" for 3+ HP

```lua
local runeMap = {4, 2, 1, 3, 5}
local textureVariant = (currentPower <= 2) and "active" or "ready"
local runeAtlas = "uf-holypower-rune" .. runeMap[i] .. "-" .. textureVariant
```

---

## Lessons Learned

### 1. **SavedVariables MUST Be Declared in .toc**
❌ **Problem**: Position changes lost on `/reload`
✅ **Solution**: Add `## SavedVariables: MoePowerDB` to .toc file

WoW won't persist variables unless declared. Easy to overlook!

### 2. **Timing Matters - Stats Load Delayed**
❌ **Problem**: `UnitPowerMax()` returns 0 or wrong value on PLAYER_LOGIN
✅ **Solution**: Use `C_Timer.After(1, Initialize)` for 1-second delay

Also applies to talent/trait change events. Always delay stat queries.

### 3. **String Operations in Hot Paths Are Expensive**
❌ **Problem**: Calling `:upper()` twice per power update (fires multiple times/sec)
✅ **Solution**: Store power type names in uppercase, uppercase event type once

Small optimization, big impact on frequent events.

### 4. **Don't Duplicate Code - Centralize Utilities**
❌ **Problem**: 23 lines of animation code duplicated in each module
✅ **Solution**: `MoePower:AddOrbAnimations()` helper in framework

Eliminated ~46 lines, easier to maintain, consistent behavior.

### 5. **Atlas Texture Names Are Inconsistent**
❌ **Problem**: Guessing atlas names rarely works
✅ **Solution**: Use `/fstack`, inspect Blizzard frames, or check wow-ui-source repo

Example: Holy Power uses `uf-holypower-rune#-active`, not `nameplates-holypower-*`.

### 6. **pcall() for Atlas Loading**
✅ **Always use**: `pcall(texture.SetAtlas, texture, atlasName)`

Atlas might not exist on all clients. Fallback to color texture on failure.

### 7. **Combat Events Need Framework Filtering (Future)**
⚠️ **Current**: Evoker checks combat in module, Paladin doesn't care
🔮 **Future**: Add user setting, check in framework before calling UpdatePower

Keep settings logic in framework, modules focus on display.

---

## Development Workflow

1. **Edit** `.lua` files
2. **Test** with `/reload` in-game
3. **Debug** with `/console scriptErrors 1` or BugSack addon
4. **Inspect** frames with `/fstack`
5. **Commit** when feature works

### Useful Commands
- `/reload` - Reload UI
- `/fstack` - Frame stack inspector
- `/dump UnitPower("player", Enum.PowerType.Essence)` - Check power value
- `/etrace` - Event trace (see what fires)

---

## Adding New Class Modules

1. Create `Classes/YourClass.lua`
2. Define module table with required fields:
   ```lua
   local YourModule = {
       className = "WARRIOR",                    // UnitClass() result
       powerType = Enum.PowerType.Rage,          // Power enum
       powerTypeName = "RAGE",                   // UPPERCASE!
       config = { orbSize, activeAlpha, ... }
   }
   ```
3. Implement `CreateOrbs(frame, layoutConfig)` and `UpdatePower(orbs)`
4. Call `MoePower:RegisterClassModule(YourModule)`
5. Add to `MoePower.toc` file list

**Key Points**:
- Use `MoePower:AddOrbAnimations()` for fade effects
- Check `UnitPower()` and `UnitPowerMax()` in UpdatePower
- Store power type name in **UPPERCASE** for optimization
- Use Blizzard atlas textures (check `/fstack` for names)

---

## Future Enhancements

### Combat Visibility Settings
Allow users to configure per-class visibility modes:
- "always" - Always show (current Paladin)
- "combat_only" - Only in combat
- "combat_or_regen" - Combat or regenerating (current Evoker)

**Recommended Implementation**: Check setting in framework before calling UpdatePower.

```lua
// In MoePowerDB
combatSettings = {
    EVOKER = "combat_or_regen",
    PALADIN = "always",
}

// In event handler
if MoePowerDB.combatSettings[activeModule.className] ~= "always" then
    UpdatePower()
end
```

### Scale/Alpha Settings
- Per-class or global scale multiplier
- Configurable active/inactive alpha values
- Stored in `MoePowerDB`

---

## Testing Checklist

- [x] Evoker essence display
- [x] Paladin holy power display
- [x] Position saving/loading
- [x] Spec/talent changes (dynamic max power)
- [x] Combat visibility (Evoker)
- [ ] Other classes (Rogue, DK, Warlock, etc.)
- [ ] UI scale changes
- [ ] Multiple monitors/resolutions

---

## Resources

- **Wowpedia API**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **WoW UI Source**: https://github.com/Gethe/wow-ui-source (atlas names, frame structures)
- **Enum.PowerType Reference**: See table in this file under "Class Power Systems"

---

## Class Power Types Reference

| Value | Enum Name | Users | Max | Notes |
|-------|-----------|-------|-----|-------|
| 9 | HolyPower | Paladin | 5 | Fixed max |
| 19 | Essence | Evoker | 5-6 | Talent-dependent |
| 4 | ComboPoints | Rogue, Feral | 5-7 | Talent-dependent |
| 5 | Runes | Death Knight | 6 | 6 runes (2 per type) |
| 7 | SoulShards | Warlock | 5 | Fixed max |
| 12 | Chi | Monk | 5-6 | Talent-dependent |

**Important**: Use `Enum.PowerType.X`, not deprecated `SPELL_POWER_X` constants.

---

## Current Status

**Implemented Classes**: Evoker, Paladin
**Features**: Arc layout, centered display, fade animations, Edit Mode integration, position persistence, combat visibility (Evoker)
**Commits**:
- e5c34a2: Initial Paladin module with Holy Power
- 768b0a6: Timing delays for stat loading
- 5b9adef: Combat visibility & string optimizations
- 93fc0bc: Centralized animations & fixed position saving

**Next Steps**: Additional class modules (Rogue, DK, Warlock), user settings UI
