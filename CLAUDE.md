# MoePower - Development Notes

This file is for development reference only and won't be loaded by WoW.

## Project Overview
- **Name**: MoePower
- **Purpose**: Moe's Class Power HUD
- **Author**: HolyBasil666
- **Version**: 1.0.0
- **WoW Interface**: 120001 (The War Within patch 12.0.1)

## Development Principles

### No External Addon Dependencies
**CRITICAL RULE**: This addon must NEVER depend on external addons or libraries.

- **Do NOT use**: LibStub, LibSharedMedia, AceAddon, AceDB, WeakAuras APIs, or any other addon libraries
- **Only use**: Native Blizzard WoW API functions and built-in UI elements
- **Assets**: Only use Blizzard game files (model IDs, atlas textures, Interface\\ paths)
- **TOC file**: Keep `## RequiredDeps:` empty

**Why**: This ensures the addon:
1. Works standalone without requiring users to install other addons
2. Has minimal performance overhead
3. Won't break if other addons are updated/removed
4. Is easier to maintain and debug

**Examples of acceptable vs. unacceptable code**:
```lua
-- GOOD: Native Blizzard atlas
local success = pcall(border.SetAtlas, border, "uf-essence-icon")

-- BAD: External library dependency
local LSM = LibStub("LibSharedMedia-3.0")
local texture = LSM:Fetch("texture", "SomeTexture")

-- GOOD: Native WoW model file ID
local modelId = 4417910  -- spells/cfx_evoker_livingflame_precast.m2
pcall(orb.SetModel, orb, modelId)

-- BAD: WeakAuras API
WeakAuras.ScanEvents("UNIT_POWER_UPDATE")
```

## Key File Structure

### MoePower.toc
The Table of Contents file tells WoW about your addon:
- `## Interface:` - WoW version (120001 = The War Within patch 12.0.1)
- `## Title:` - Display name in addon list
- `## Notes:` - Description shown in-game
- `## SavedVariables:` - Global saved variables across characters
- `## SavedVariablesPerCharacter:` - Per-character saved variables
- File list at bottom (e.g., `MoePower.lua`) - Order matters! Files load in sequence

### MoePower.lua
Main addon code file. Currently prints a success message on load.

## Important WoW Addon Concepts

### Loading Order
Files load in the order listed in the .toc file. Dependencies and initialization should come first.

### Events
Use `frame:RegisterEvent("EVENT_NAME")` to listen for game events.
Common events: PLAYER_LOGIN, ADDON_LOADED, UNIT_POWER_UPDATE, etc.

### Frames
UI elements are frames. Create with `CreateFrame("FrameType", "FrameName", parentFrame)`.

### Saved Variables
Variables listed in `## SavedVariables:` persist between sessions.
They're loaded during ADDON_LOADED event.

### API Documentation
- Wowpedia/Warcraft Wiki has comprehensive API documentation
- Use `/dump` command in-game to inspect values
- Use `/framestack` to see UI frame hierarchy

## Development Workflow
1. Edit files in this folder
2. Use `/reload` in-game to reload UI and test changes
3. Check for errors with `/console scriptErrors 1` or BugSack addon
4. Commit changes to git when features are working

## Useful Commands
- `/reload` - Reload UI without restarting game
- `/fstack` - Show frame stack under mouse
- `/etrace` - Event trace to see what events fire
- `/dump UnitPower("player")` - Check current power value
- `/dump UnitPowerMax("player")` - Check maximum power
- `/dump UnitPowerType("player")` - Get power type enum

## Class Power Systems

### Power Types (Enum.PowerType)
Current power types as of patch 11.0.0+:

| Value | Enum Name | Primary Users | Notes |
|-------|-----------|---------------|-------|
| 0 | Mana | Most casters, default for NPCs | Core resource |
| 1 | Rage | Warriors, Druids (Bear) | Builds through damage |
| 2 | Focus | Hunters, Hunter pets | Regenerates over time |
| 3 | Energy | Rogues, Monks, Druids (Cat) | Regenerates over time |
| 4 | ComboPoints | Rogues, Druids (Feral) | Builder/spender system |
| 5 | Runes | Death Knights | 6 runes that recharge |
| 6 | RunicPower | Death Knights | Secondary resource |
| 7 | SoulShards | Warlocks | Fragment-based resource |
| 8 | LunarPower | Balance Druids | Astral Power |
| 9 | HolyPower | Retribution Paladins | Builder/spender |
| 11 | Maelstrom | Enhancement/Elemental Shamans | Elemental resource |
| 12 | Chi | Windwalker Monks | Martial resource |
| 13 | Insanity | Shadow Priests | Void resource |
| 16 | ArcaneCharges | Arcane Mages | 0-4 charges |
| 17 | Fury | Havoc Demon Hunters | Primary resource |
| 18 | Pain | Vengeance Demon Hunters | Tank resource |
| 19 | Essence | Evokers | Draconic resource |
| 20-22 | RuneBlood, RuneFrost, RuneUnholy | Death Knights (individual runes) | Added patch 10.0.0 |
| 25 | AlternateMount | Dragonriding Vigor | Mount-specific |
| 26 | Balance | Special encounters | Added patch 10.2.7 |

**Deprecated (do not use):**
- 14: BurningEmbers (removed in Legion)
- 15: DemonicFury (removed in Legion)

**Important Notes:**
- Use `Enum.PowerType.Mana`, not `SPELL_POWER_MANA` (deprecated since 7.2.5)
- Some alternate power types exist for encounters/vehicles
- Check `UnitPowerType("player")` to detect player's current primary power

### Key API Functions
```lua
-- Power information
UnitPower(unit, powerType) -- Current power amount
UnitPowerMax(unit, powerType) -- Maximum power
UnitPowerType(unit) -- Returns powerTypeEnum, powerToken, altR, altG, altB, altPowerType
PowerBarColor[powerType] -- Default Blizzard colors {r, g, b, a}

-- Modern Enum.PowerType usage (DO USE THIS)
local currentPower = UnitPower("player", Enum.PowerType.Mana)
local maxPower = UnitPowerMax("player", Enum.PowerType.Mana)

-- Deprecated syntax (DON'T USE THIS)
-- local power = UnitPower("player", SPELL_POWER_MANA) -- OLD WAY

-- Get player's primary power type
local powerType, powerToken = UnitPowerType("player")
-- powerType is the enum number (0 for Mana, 1 for Rage, etc.)
-- powerToken is the string name ("MANA", "RAGE", etc.)

-- Class and spec
UnitClass(unit) -- Returns className, classFilename, classID
GetSpecialization() -- Current spec number (1-4)
GetSpecializationInfo(specIndex) -- Detailed spec info

-- Events to monitor
UNIT_POWER_UPDATE -- Fires when power changes, args: unitTarget, powerType
UNIT_POWER_FREQUENT -- Fires more frequently for smooth updates
UNIT_MAXPOWER -- Fires when max power changes
PLAYER_SPECIALIZATION_CHANGED -- Spec change (respec or talent change)
PLAYER_ENTERING_WORLD -- Login/reload/zone change
ADDON_LOADED -- Fires when addon loads, args: addonName
```

## UI/Frame Development

### Creating a Power Bar
```lua
local frame = CreateFrame("Frame", "MoePowerFrame", UIParent)
frame:SetSize(width, height)
frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

-- Texture for background
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0, 0, 0, 0.5)

-- Texture for power bar
local bar = frame:CreateTexture(nil, "ARTWORK")
bar:SetPoint("BOTTOMLEFT")
bar:SetSize(width * fillPercent, height)
bar:SetColorTexture(r, g, b, 1)
```

### Frame Layers (Z-order)
1. BACKGROUND
2. BORDER
3. ARTWORK
4. OVERLAY
5. HIGHLIGHT

### Anchoring
```lua
frame:SetPoint("point", relativeTo, "relativePoint", x, y)
-- Example: SetPoint("TOPLEFT", UIParent, "CENTER", 0, 100)
```

## Performance Best Practices

1. **Throttle Updates**: Don't update on every UNIT_POWER_FREQUENT for smooth animations
2. **Hide When Not Needed**: Use `frame:Hide()` when player is dead/ghost
3. **Unregister Events**: Unregister events when not needed to reduce overhead
4. **Avoid String Concatenation**: Use string.format() for better performance
5. **Cache Values**: Store frequently accessed values (class, spec) instead of calling API repeatedly

## Saved Variables Best Practices

```lua
-- Initialize with defaults
MoePowerDB = MoePowerDB or {
    position = { point = "CENTER", x = 0, y = -200 },
    scale = 1.0,
    colors = {},
    enabled = true
}

-- Per-character settings
MoePowerCharDB = MoePowerCharDB or {
    showInCombatOnly = false
}
```

## Common Pitfalls

1. **Timing**: Some API calls return nil during early load. Use PLAYER_LOGIN or PLAYER_ENTERING_WORLD
2. **Unit Tokens**: Always use "player" not character name for the player unit
3. **Coordinate System**: (0,0) is bottom-left, positive Y goes up
4. **Frame Strata**: Higher strata appears on top (BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN < TOOLTIP)
5. **Textures**: Must set size explicitly, don't inherit parent size automatically

## Debugging Techniques

1. Print to chat: `print("Debug:", value)`
2. Use DevTools addon for better debugging
3. Check Lua errors: `/console scriptErrors 1`
4. Reload often during development: `/reload`
5. Use `/fstack` to inspect frame hierarchy
6. Use BugSack or BugGrabber addons to catch errors

## Testing Checklist

- [ ] Test on multiple classes (different power types)
- [ ] Test spec changes
- [ ] Test in/out of combat
- [ ] Test while dead/ghost
- [ ] Test in dungeons/raids
- [ ] Test with UI scale changes
- [ ] Test /reload and fresh login
- [ ] Test with other addons enabled/disabled

## Resources

- **Wowpedia**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **WoW Interface**: https://www.wowinterface.com/
- **CurseForge**: For addon distribution
- **Townlong Yak**: API documentation and examples
- **GitHub WoW UI Source**: https://github.com/Gethe/wow-ui-source

## Edit Mode Integration

### Overview
Edit Mode allows players to move and customize UI elements using Blizzard's built-in system (ESC > Edit Mode).

### Implementation Requirements
```lua
-- 1. Register your frame as an Edit Mode system
local editModeManager = {
    name = "MoePower",
    -- Called when entering edit mode
    OnEditModeEnter = function(self)
        -- Show drag outline, enable movement
    end,
    -- Called when exiting edit mode
    OnEditModeExit = function(self)
        -- Save position, hide drag outline
    end,
}

-- 2. Make frame movable in Edit Mode
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
    if EditModeManagerFrame:IsEditModeActive() then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position to SavedVariables
    local point, _, relativePoint, x, y = self:GetPoint()
    MoePowerDB.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end)

-- 3. Register with Edit Mode Manager (Dragonflight+)
if EditModeManagerFrame then
    EditModeManagerFrame:RegisterSystemFrame(frame)
end
```

### Edit Mode API Functions
```lua
EditModeManagerFrame:IsEditModeActive() -- Check if Edit Mode is active
EditModeManagerFrame:EnterEditMode() -- Enter Edit Mode programmatically
EditModeManagerFrame:ExitEditMode() -- Exit Edit Mode
```

### Position Restoration
```lua
-- Restore saved position on load
local function RestorePosition()
    local pos = MoePowerDB.position
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(
            pos.point or "CENTER",
            UIParent,
            pos.relativePoint or "CENTER",
            pos.x or 0,
            pos.y or -200
        )
    end
end

-- Call after PLAYER_LOGIN
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        RestorePosition()
    end
end)
```

### Visual Feedback in Edit Mode
```lua
-- Optional: Show border when in Edit Mode
local editBorder = frame:CreateTexture(nil, "OVERLAY")
editBorder:SetAllPoints(frame)
editBorder:SetColorTexture(1, 1, 1, 0.3)
editBorder:Hide()

-- Show/hide border based on Edit Mode state
hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    editBorder:Show()
end)

hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    editBorder:Hide()
end)
```

## Project Goals

MoePower aims to provide:
1. Clean, minimal class power display
2. **Movable via Edit Mode system** - Players can position it anywhere
3. Customizable position and appearance
4. Support for all class power types
5. Smooth animations and updates
6. Low performance impact
7. Easy configuration through Edit Mode
