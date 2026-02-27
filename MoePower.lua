-- MoePower: Class Power HUD Framework
-- Modular architecture supporting multiple classes

local _, MoePower = ...

-- Initialize addon namespace
MoePower = MoePower or {}
local frame
local powerOrbs = {}
local activeModule

-- Saved variables (initialized by WoW)
MoePowerDB = MoePowerDB or {}

-- Constants
local GRID_SIZE          = 10
local DEFAULT_POSITION_X = 0
local DEFAULT_POSITION_Y = -80
local TRANSITION_TIME    = 0.1   -- Fade animation duration in seconds
local ACTIVE_ALPHA       = 1.0   -- Alpha when power orb is active

-- Arc layout settings (shared across all class modules)
local ARC_RADIUS      = 140   -- Distance from center
local BASE_ORB_SPACING = 12.5  -- Degrees between orbs

-- State
local inEditMode          = false
local playerMounted       = false
local cachedGrowDirection = "center"  -- Cached to avoid settings table read on every UpdatePower
local cachedDebug         = false     -- Cached to avoid settings table read on every UpdatePower
local UpdatePower  -- Forward declaration (referenced by SetupEditMode callbacks)
local dbgCtx = {}  -- Debug context: reset each UpdatePower call, printed once at end

-- Class module registry
local classModules = {}
MoePower.classModules = classModules  -- expose for Options.lua (populated at file load time)
MoePower.inCombat = false             -- shared combat flag; updated by PLAYER_REGEN_DISABLED/ENABLED

function MoePower:RegisterClassModule(module)
    if module.className then
        classModules[module.className] = module
    end
end

-- Get the active class module (respects optional specIndex filter)
local function GetClassModule()
    local _, classFilename = UnitClass("player")
    local module = classModules[classFilename]
    if module and module.specIndex then
        if GetSpecialization() ~= module.specIndex then
            return nil
        end
    end
    return module
end

-- Snap coordinate to grid
local function SnapToGrid(value)
    return math.floor(value / GRID_SIZE + 0.5) * GRID_SIZE
end

-- Save frame position with grid snapping
local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    x = SnapToGrid(x)
    y = SnapToGrid(y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    MoePowerDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- Load saved position
local function LoadPosition()
    if MoePowerDB.position then
        local pos = MoePowerDB.position
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

-- Show all orbs at max power (for Edit Mode preview)
local function ShowAllOrbs()
    MoePower:CancelHideOrbs()
    for i = 1, #powerOrbs do
        if not powerOrbs[i].active then
            powerOrbs[i].fadeOut:Stop()
            powerOrbs[i].fadeIn:Play()
            powerOrbs[i].active = true
        end
    end
end

-- Edit Mode integration
local function SetupEditMode()
    frame:SetMovable(true)
    frame:EnableMouse(false)  -- Mouse handled by dragFrame
    frame:SetClampedToScreen(true)

    -- Draggable overlay for Edit Mode
    local dragFrame = CreateFrame("Frame", nil, frame)
    dragFrame:SetSize(220, 150)
    dragFrame:SetPoint("CENTER", frame, "CENTER", 0, 135)
    dragFrame:EnableMouse(true)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:Hide()

    -- Visual indicator for Edit Mode
    local bg = dragFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(dragFrame)
    bg:SetColorTexture(0, 1, 0, 0.15)

    local label = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER")
    label:SetText("MoePower")
    label:SetTextColor(1, 1, 1, 1)

    dragFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then frame:StartMoving() end
    end)

    dragFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            SavePosition()
        end
    end)

    frame.dragFrame = dragFrame

    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            inEditMode = true
            frame.dragFrame:Show()
            ShowAllOrbs()
        end)

        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            inEditMode = false
            frame.dragFrame:Hide()
            UpdatePower("ExitEditMode")
        end)

        if EditModeManagerFrame:IsEditModeActive() then
            inEditMode = true
            dragFrame:Show()
            ShowAllOrbs()
        end
    else
        -- Fallback: always show a small handle
        dragFrame:SetSize(80, 30)
        dragFrame:SetPoint("CENTER", frame, "BOTTOM", 0, 0)
        dragFrame:Show()
    end
end

-- Expose active alpha for class modules
MoePower.ACTIVE_ALPHA = ACTIVE_ALPHA

-- Debug logging (active only when settings.debug == true)
function MoePower:DebugPrint(...)
    if cachedDebug then
        print("|cff00ccff[MoePower Debug]|r", ...)
    end
end

-- Create fade animations for an orb frame
function MoePower:AddOrbAnimations(orbFrame)
    local fadeInGroup = orbFrame:CreateAnimationGroup()
    local fadeIn = fadeInGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(ACTIVE_ALPHA)
    fadeIn:SetDuration(TRANSITION_TIME)
    fadeIn:SetSmoothing("IN")
    fadeInGroup:SetScript("OnFinished", function() orbFrame:SetAlpha(ACTIVE_ALPHA) end)

    local fadeOutGroup = orbFrame:CreateAnimationGroup()
    local fadeOut = fadeOutGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(ACTIVE_ALPHA)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(TRANSITION_TIME)
    fadeOut:SetSmoothing("OUT")
    fadeOutGroup:SetScript("OnFinished", function() orbFrame:SetAlpha(0) end)

    return fadeInGroup, fadeOutGroup
end

-- Delayed hide mechanism for orbs (usable by any class module)
local hideVersion = 0
local hideActive  = false

function MoePower:ScheduleHideOrbs(orbs, delay)
    if not hideActive then
        hideActive = true
        hideVersion = hideVersion + 1
        local thisVersion = hideVersion
        if cachedDebug then
            dbgCtx.hideInfo = "→hide:" .. (delay or 1) .. "s"
        end
        C_Timer.After(delay or 1, function()
            if hideVersion == thisVersion then
                hideActive = false
                local isDebug = cachedDebug
                local debugHidden = isDebug and {} or nil
                for i = 1, #orbs do
                    if orbs[i].active then
                        orbs[i].fadeIn:Stop()
                        orbs[i].fadeOut:Play()
                        orbs[i].active = false
                        if isDebug then table.insert(debugHidden, i) end
                    end
                end
                if isDebug and debugHidden[1] then
                    print("|cff00ccff[MoePower Debug]|r", "HideOrbs | hidden=[" .. table.concat(debugHidden, ",") .. "]")
                end
            end
        end)
    end
end

function MoePower:CancelHideOrbs()
    if hideActive then
        hideVersion = hideVersion + 1
        hideActive = false
    end
end

-- Update power display (called by event handler)
UpdatePower = function(trigger)
    if inEditMode then return end
    if playerMounted then return end
    if not activeModule then return end
    local isDebug = cachedDebug
    if isDebug then
        dbgCtx = { trigger = trigger or "?" }
    end
    if activeModule.UpdatePower then
        activeModule:UpdatePower(powerOrbs)
    else
        MoePower:StandardUpdatePower(powerOrbs, activeModule)
    end
    if isDebug then
        local parts = { dbgCtx.trigger }
        if dbgCtx.power then table.insert(parts, dbgCtx.power .. "/" .. dbgCtx.max) end
        if dbgCtx.shown  and dbgCtx.shown[1]  then table.insert(parts, "shown=["  .. table.concat(dbgCtx.shown,  ",") .. "]") end
        if dbgCtx.hidden and dbgCtx.hidden[1] then table.insert(parts, "hidden=[" .. table.concat(dbgCtx.hidden, ",") .. "]") end
        if dbgCtx.hideInfo then table.insert(parts, dbgCtx.hideInfo) end
        print("|cff00ccff[MoePower Debug]|r", table.concat(parts, " | "))
    end
end

-- Shared orb management helpers

-- Resolve orb count for a module (powerType or fixed maxPower field)
local function GetModuleMaxPower(module)
    local maxPower = module.powerType
        and UnitPowerMax("player", module.powerType)
        or 0
    return maxPower > 0 and maxPower or (module.maxPower or 6)
end

-- Destroy and clear all existing orbs
local function ClearOrbs()
    for _, orb in ipairs(powerOrbs) do
        if orb.frame then
            orb.frame:Hide()
            orb.frame:SetParent(nil)
        end
    end
    powerOrbs = {}
end

-- Create orbs for the active module (delegates to module's CreateOrbs or the generic BuildOrbFrames)
local function BuildOrbs()
    if not activeModule then return end
    local maxPower = GetModuleMaxPower(activeModule)
    local arcSpan  = BASE_ORB_SPACING * (maxPower - 1)
    local layout   = MoePower.settings and MoePower.settings.layout or "arc"
    local layoutConfig = { layout = layout, arcRadius = ARC_RADIUS, arcSpan = arcSpan }
    if activeModule.CreateOrbs then
        powerOrbs = activeModule:CreateOrbs(frame, layoutConfig)
    else
        powerOrbs = MoePower:BuildOrbFrames(frame, layoutConfig, activeModule)
    end
end

-- Recreate orbs when max power changes (e.g. talent change within the same spec)
local function RecreateOrbs()
    if not activeModule or not frame then return end
    local maxPower = GetModuleMaxPower(activeModule)
    if #powerOrbs == maxPower then return end  -- count unchanged, skip
    ClearOrbs()
    BuildOrbs()
    UpdatePower("RecreateOrbs")
end

-- Force a full orb rebuild (called when layout settings change at runtime)
function MoePower:RebuildOrbs()
    if not activeModule or not frame then return end
    ClearOrbs()
    BuildOrbs()
    UpdatePower("RebuildOrbs")
end

-- Returns the startIndex and endIndex of orbs that should be visible for the current
-- grow direction setting. Uses a cached value to avoid a settings table read per tick.
function MoePower:GetVisibleRange(currentPower, maxPower)
    if cachedGrowDirection == "left" then
        return 1, currentPower
    elseif cachedGrowDirection == "right" then
        return maxPower - currentPower + 1, maxPower
    else  -- "center" (default)
        local s = math.floor((maxPower - currentPower) / 2) + 1
        return s, s + currentPower - 1
    end
end

-- Compute x, y position for orb i (1-based) given layout configuration and orb pixel size.
function MoePower:GetOrbPosition(i, maxPower, layoutConfig, orbSize)
    local arcRadius = layoutConfig.arcRadius
    if (layoutConfig.layout or "arc") == "horizontal" then
        local horizStep = orbSize + 4
        return -(horizStep * (maxPower - 1) / 2) + (i - 1) * horizStep, arcRadius
    else
        local arcSpan    = layoutConfig.arcSpan
        local startAngle = 90 + (arcSpan / 2)
        local arcStep    = maxPower > 1 and arcSpan / (maxPower - 1) or 0
        local radian     = math.rad(startAngle - (i - 1) * arcStep)
        return arcRadius * math.cos(radian), arcRadius * math.sin(radian)
    end
end

-- Fade orbs in/out: show orbs within [startIndex, endIndex], hide the rest.
function MoePower:UpdateOrbVisibility(orbs, startIndex, endIndex)
    local isDebug = cachedDebug
    local debugShown, debugHidden
    if isDebug then debugShown, debugHidden = {}, {} end
    for i = 1, #orbs do
        if i >= startIndex and i <= endIndex then
            if not orbs[i].active then
                orbs[i].fadeOut:Stop()
                orbs[i].fadeIn:Play()
                orbs[i].active = true
                if isDebug then table.insert(debugShown, i) end
            end
        else
            if orbs[i].active then
                orbs[i].fadeIn:Stop()
                orbs[i].fadeOut:Play()
                orbs[i].active = false
                if isDebug then table.insert(debugHidden, i) end
            end
        end
    end
    if isDebug then
        dbgCtx.shown  = debugShown
        dbgCtx.hidden = debugHidden
    end
end

-- Generic CreateOrbs: builds all orb frames for the given module.
-- Calls module hook methods when present; falls back to config/defaults otherwise.
-- Hook API (all optional unless noted):
--   module:GetCurrentPower()             → number  (default: UnitPower(powerType) or 0)
--   module:GetForegroundAtlas(i, cp)     → string|nil  (nil = use color fallback)
--   module:GetForegroundOffset(i)        → x, y    (default: 0, 0)
--   module:GetForegroundFallbackColor()  → {r,g,b,a}
function MoePower:BuildOrbFrames(parentFrame, layoutConfig, module)
    local cfg      = module.config
    local orbSize  = cfg.orbSize
    local maxPower = GetModuleMaxPower(module)

    -- Initial power (determines starting alpha)
    local currentPower
    if module.GetCurrentPower then
        currentPower = module:GetCurrentPower()
    elseif module.powerType then
        currentPower = UnitPower("player", module.powerType)
    else
        currentPower = 0
    end
    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, maxPower)

    -- Hoist static atlas checks outside loop (only used when no GetForegroundAtlas hook)
    local useBgAtlas = cfg.backgroundAtlas and C_Texture.GetAtlasInfo(cfg.backgroundAtlas) ~= nil
    local useFgAtlas = cfg.foregroundAtlas  and C_Texture.GetAtlasInfo(cfg.foregroundAtlas) ~= nil

    local orbs = {}
    for i = 1, maxPower do
        local x, y = MoePower:GetOrbPosition(i, maxPower, layoutConfig, orbSize)

        local orbFrame = CreateFrame("Frame", nil, parentFrame)
        orbFrame:SetSize(orbSize, orbSize)
        orbFrame:SetPoint("CENTER", parentFrame, "CENTER", x, y)

        -- Background (optional; present only when backgroundAtlas key is non-nil)
        local background
        if cfg.backgroundAtlas then
            background = orbFrame:CreateTexture(nil, "BACKGROUND")
            background:SetSize(orbSize * (cfg.backgroundScale or 1.0), orbSize * (cfg.backgroundScale or 1.0))
            background:SetPoint("CENTER", orbFrame, "CENTER", 0, 0)
            if useBgAtlas then
                background:SetAtlas(cfg.backgroundAtlas)
            else
                local bc = cfg.backgroundFallbackColor or {0.2, 0.2, 0.2, 0.75}
                background:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
            end
        end

        -- Foreground
        local foreground = orbFrame:CreateTexture(nil, "ARTWORK")
        local fgX, fgY   = 0, 0
        if module.GetForegroundOffset then fgX, fgY = module:GetForegroundOffset(i) end
        foreground:SetSize(orbSize * (cfg.foregroundScale or 1.0), orbSize * (cfg.foregroundScale or 1.0))
        foreground:SetPoint("CENTER", orbFrame, "CENTER", fgX, fgY)
        -- Per-orb atlas hook takes priority; falls back to static config atlas; then color
        local fgAtlas = module.GetForegroundAtlas and module:GetForegroundAtlas(i, currentPower)
                     or (useFgAtlas and cfg.foregroundAtlas)
        if fgAtlas then
            foreground:SetAtlas(fgAtlas)
        else
            local fc = (module.GetForegroundFallbackColor and module:GetForegroundFallbackColor())
                    or cfg.foregroundFallbackColor or {1, 1, 1, 1}
            foreground:SetColorTexture(fc[1], fc[2], fc[3], fc[4])
        end

        local fadeIn, fadeOut = MoePower:AddOrbAnimations(orbFrame)

        local active = i >= startIndex and i <= endIndex
        orbFrame:SetAlpha(active and ACTIVE_ALPHA or 0)

        orbs[i] = {
            frame      = orbFrame,
            background = background,
            foreground = foreground,
            fadeIn     = fadeIn,
            fadeOut    = fadeOut,
            active     = active,
        }
        orbFrame:Show()
    end
    return orbs
end

-- Generic UpdatePower: reads current power, fades orbs, schedules/cancels hide.
-- Hook API:
--   module:GetCurrentPower()                → number
--   module:ShouldHideOOC(currentPower, max) → bool  (default: false)
--   module:OnAfterUpdatePower(orbs, cp)     → void  (post-update hook, e.g. texture swaps)
function MoePower:StandardUpdatePower(orbs, module)
    local n = #orbs
    if n == 0 then return end

    local currentPower
    if module.GetCurrentPower then
        currentPower = module:GetCurrentPower()
    elseif module.powerType then
        currentPower = UnitPower("player", module.powerType)
    else
        currentPower = 0
    end

    local startIndex, endIndex = MoePower:GetVisibleRange(currentPower, n)
    if cachedDebug then
        dbgCtx.power = currentPower
        dbgCtx.max   = n
    end
    MoePower:UpdateOrbVisibility(orbs, startIndex, endIndex)

    local shouldHide = module.ShouldHideOOC and module:ShouldHideOOC(currentPower, n)
    if not MoePower.inCombat and shouldHide then
        MoePower:ScheduleHideOrbs(orbs, 1)
    else
        MoePower:CancelHideOrbs()
    end

    if module.OnAfterUpdatePower then
        module:OnAfterUpdatePower(orbs, currentPower)
    end
end

-- Re-render orbs for the current power without recreating frames (grow direction change)
function MoePower:ApplyGrowDirection()
    cachedGrowDirection = MoePower.settings and MoePower.settings.growDirection or "center"
    UpdatePower("ApplyGrowDirection")
end

-- Sync debug cache after the debug setting changes (called from Options panel)
function MoePower:ApplyDebug()
    cachedDebug = MoePower.settings and MoePower.settings.debug or false
end

-- Initialize (or reinitialize) the addon — safe to call multiple times.
-- On first call: creates the main frame and Edit Mode hooks.
-- On subsequent calls (e.g. spec change): reuses the existing frame.
local function Initialize()
    playerMounted = IsMounted()
    activeModule = GetClassModule()

    -- First run: create the persistent main frame
    if not frame then
        if not activeModule then
            local _, classFilename = UnitClass("player")
            print("|cff00ff00MoePower:|r No module found for " .. (classFilename or "Unknown") .. " class")
            return
        end
        frame = CreateFrame("Frame", "MoePowerFrame", UIParent)
        frame:SetSize(400, 400)
        frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POSITION_X, DEFAULT_POSITION_Y)
        frame:SetFrameStrata("MEDIUM")
        MoePower.frame = frame  -- Expose for Options.lua ApplyScale
        LoadPosition()
        SetupEditMode()
    end

    ClearOrbs()

    if not activeModule then
        frame:Hide()
        return
    end

    -- Respect per-spec / per-module enabled setting (Options panel)
    if MoePower.settings then
        local cn = activeModule.className
        if activeModule.specKeys then
            -- Spec-level check: only block if this specific spec is explicitly disabled
            local specEnabled = MoePower.settings.specEnabled
            if specEnabled and specEnabled[cn] then
                local currentSpecKey = activeModule.specKeys[GetSpecialization()]
                if currentSpecKey and specEnabled[cn][currentSpecKey] == false then
                    frame:Hide()
                    return
                end
            end
        else
            -- Class-level fallback for modules without specKeys
            local moduleEnabled = MoePower.settings.moduleEnabled
            if moduleEnabled and moduleEnabled[cn] == false then
                frame:Hide()
                return
            end
        end
    end

    cachedGrowDirection = MoePower.settings and MoePower.settings.growDirection or "center"
    cachedDebug         = MoePower.settings and MoePower.settings.debug         or false
    BuildOrbs()
    UpdatePower("Initialize")
    MoePower:ApplyScale()
    frame:Show()

    local className = activeModule.className
    print("|cff00ff00MoePower:|r " .. className:sub(1, 1):upper() .. className:sub(2):lower() .. " module loaded")
end

-- Enable or disable the active class module at runtime (called from Options panel)
function MoePower:ApplyModuleEnabled(className, enabled)
    if not activeModule or activeModule.className ~= className then return end
    if enabled then
        Initialize()  -- safe to call multiple times; re-checks setting, rebuilds orbs, shows frame
    elseif frame then
        frame:Hide()
    end
end

-- Enable or disable a specific spec at runtime (called from Options panel)
function MoePower:ApplySpecEnabled(className, specKey, enabled)
    if not activeModule or activeModule.className ~= className then return end
    if enabled then
        Initialize()  -- re-checks spec setting, rebuilds orbs if needed
    elseif frame then
        local currentSpecKey = activeModule.specKeys and activeModule.specKeys[GetSpecialization()]
        if currentSpecKey == specKey then
            ClearOrbs()
            frame:Hide()
        end
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        -- Delay to ensure player stats are fully loaded
        C_Timer.After(1, Initialize)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Zone change / instance transition: refresh display with current power state
        UpdatePower(event)
    elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        -- Delay to ensure updated stats are available
        C_Timer.After(1, RecreateOrbs)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec change may activate a different module entirely
        C_Timer.After(1, Initialize)
    elseif event == "UNIT_MAXPOWER" then
        if arg1 == "player" and activeModule and activeModule.powerTypeName then
            if arg2 == activeModule.powerTypeName then
                RecreateOrbs()
            end
        end
    elseif event == "UNIT_POWER_FREQUENT" then
        if arg1 == "player" and activeModule and activeModule.powerTypeName then
            if arg2 == activeModule.powerTypeName then
                UpdatePower(event)
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Route spell casts to modules that track via spells (arg2=castGUID, arg3=spellID)
        if arg1 == "player" and activeModule and activeModule.OnSpellCast then
            activeModule:OnSpellCast(arg3, arg2)
            UpdatePower(event)
        end
    elseif event == "UNIT_AURA" then
        -- Sync aura-tracking modules out of combat when buffs change (opt-in via tracksAura).
        -- In combat, internal counters are authoritative; aura data is not read during combat
        -- (TWW 12.0), so skip UpdatePower entirely to avoid wasted work on every buff tick.
        if arg1 == "player" and activeModule and activeModule.tracksAura
        and not MoePower.inCombat then
            UpdatePower(event)
        end
    elseif event == "RUNE_POWER_UPDATE" then
        -- Fires on every individual rune spend/recharge (DK only)
        UpdatePower(event)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        MoePower.inCombat = event == "PLAYER_REGEN_DISABLED"
        UpdatePower(event)
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local wasMounted = playerMounted
        playerMounted = IsMounted()
        if playerMounted and not wasMounted then
            -- Just mounted: fade out all orbs immediately
            if powerOrbs and #powerOrbs > 0 then
                MoePower:ScheduleHideOrbs(powerOrbs, 0)
            end
        elseif not playerMounted and wasMounted then
            -- Just unmounted: cancel any pending hide, restore normal display
            MoePower:CancelHideOrbs()
            UpdatePower(event)
        end
    end
end)
