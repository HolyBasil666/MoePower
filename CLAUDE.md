# MoePower - Development Notes

This file is for development reference only and won't be loaded by WoW.

## Project Overview
- **Name**: MoePower
- **Purpose**: Moe's Class Power HUD
- **Author**: HolyBasil666
- **Version**: 1.0.0
- **WoW Interface**: 120000 (The War Within)

## Key File Structure

### MoePower.toc
The Table of Contents file tells WoW about your addon:
- `## Interface:` - WoW version (120000 = The War Within patch 12.0.0)
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
