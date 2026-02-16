-- MoePower: Class Power HUD Framework
-- Modular architecture supporting multiple classes

local addonName, MoePower = ...

-- Initialize addon namespace
MoePower = MoePower or {}
local frame
local powerOrbs = {}
local activeModule

-- Saved variables (initialized by WoW)
MoePowerDB = MoePowerDB or {}

-- Constants
local GRID_SIZE = 10  -- Snap to grid every 10 pixels
local DEFAULT_POSITION_X = 0
local DEFAULT_POSITION_Y = -80
local TRANSITION_TIME = 0.1  -- Fade animation duration in seconds
local ACTIVE_ALPHA = 1.0     -- Alpha when power orb is active

-- Arc layout settings (shared across all class modules)
local ARC_RADIUS = 140    -- Distance from center
local BASE_ORB_SPACING = 12.5  -- Degrees between orbs

-- State
local inEditMode = false
local UpdatePower  -- Forward declaration (referenced by SetupEditMode callbacks)

-- Class module registry
local classModules = {}

-- Register a class module
function MoePower:RegisterClassModule(module)
    if module.className then
        classModules[module.className] = module
        -- print("|cff00ff00MoePower:|r Registered module for " .. module.className)
    end
end

-- Get the active class module
local function GetClassModule()
    local _, classFilename = UnitClass("player")
    return classModules[classFilename]
end

-- Snap coordinate to grid
local function SnapToGrid(value)
    return math.floor(value / GRID_SIZE + 0.5) * GRID_SIZE
end

-- Save frame position with grid snapping
local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()

    -- Snap to grid
    x = SnapToGrid(x)
    y = SnapToGrid(y)

    -- Apply snapped position
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)

    -- Save snapped position
    MoePowerDB.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
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
    -- Make frame movable
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

    -- Drag functionality
    dragFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)

    dragFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            SavePosition()
        end
    end)

    -- Store reference to drag frame
    frame.dragFrame = dragFrame

    -- Hook into Edit Mode manager if it exists
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            print("|cff00ff00MoePower:|r Edit Mode entered")
            inEditMode = true
            if frame and frame.dragFrame then
                frame.dragFrame:Show()
            end
            ShowAllOrbs()
        end)

        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            print("|cff00ff00MoePower:|r Edit Mode exited")
            inEditMode = false
            if frame and frame.dragFrame then
                frame.dragFrame:Hide()
            end
            UpdatePower()
        end)

        -- Check if already in Edit Mode
        if EditModeManagerFrame:IsEditModeActive() then
            print("|cff00ff00MoePower:|r Already in Edit Mode")
            inEditMode = true
            dragFrame:Show()
            ShowAllOrbs()
        end
    else
        print("|cff00ff00MoePower:|r EditModeManagerFrame not found - using fallback")
        -- Fallback: always show a small handle
        dragFrame:SetSize(80, 30)
        dragFrame:SetPoint("CENTER", frame, "BOTTOM", 0, 0)
        dragFrame:Show()
    end
end

-- Expose active alpha for class modules
MoePower.ACTIVE_ALPHA = ACTIVE_ALPHA

-- Create fade animations for an orb frame
function MoePower:AddOrbAnimations(orbFrame)
    -- Fade in animation
    local fadeInGroup = orbFrame:CreateAnimationGroup()
    local fadeIn = fadeInGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(ACTIVE_ALPHA)
    fadeIn:SetDuration(TRANSITION_TIME)
    fadeIn:SetSmoothing("IN")

    fadeInGroup:SetScript("OnFinished", function()
        orbFrame:SetAlpha(ACTIVE_ALPHA)
    end)

    -- Fade out animation
    local fadeOutGroup = orbFrame:CreateAnimationGroup()
    local fadeOut = fadeOutGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(ACTIVE_ALPHA)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(TRANSITION_TIME)
    fadeOut:SetSmoothing("OUT")

    fadeOutGroup:SetScript("OnFinished", function()
        orbFrame:SetAlpha(0)
    end)

    return fadeInGroup, fadeOutGroup
end

-- Delayed hide mechanism for orbs (usable by any class module)
local hideVersion = 0
local hideActive = false

function MoePower:ScheduleHideOrbs(orbs, delay)
    if not hideActive then
        hideActive = true
        hideVersion = hideVersion + 1
        local thisVersion = hideVersion
        C_Timer.After(delay or 1, function()
            if hideVersion == thisVersion then
                hideActive = false
                for i = 1, #orbs do
                    if orbs[i].active then
                        orbs[i].fadeIn:Stop()
                        orbs[i].fadeOut:Play()
                        orbs[i].active = false
                    end
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
UpdatePower = function()
    if inEditMode then return end
    if activeModule and activeModule.UpdatePower then
        activeModule:UpdatePower(powerOrbs)
    end
end

-- Recreate orbs (called when max power changes)
local function RecreateOrbs()
    if not activeModule or not activeModule.CreateOrbs or not frame then
        return
    end

    -- Get current max power
    local maxPower = UnitPowerMax("player", activeModule.powerType)
    if maxPower == 0 then
        maxPower = 6  -- Default fallback
    end

    -- Return if max power unchanged
    local currentOrbCount = #powerOrbs
    if currentOrbCount == maxPower then
        return
    end

    -- Calculate arc span based on orb count
    local arcSpan = BASE_ORB_SPACING * (maxPower - 1)

    -- Clear existing orbs
    for _, orb in ipairs(powerOrbs) do
        if orb.frame then
            orb.frame:Hide()
            orb.frame:SetParent(nil)
        end
    end
    powerOrbs = {}

    -- Create new orbs
    local layoutConfig = {
        arcRadius = ARC_RADIUS,
        arcSpan = arcSpan
    }
    powerOrbs = activeModule:CreateOrbs(frame, layoutConfig)

    -- Update display
    UpdatePower()

    print("|cff00ff00MoePower:|r Orbs recreated for " .. maxPower .. " max power")
end

-- Initialize addon
local function Initialize()
    -- Get class module
    activeModule = GetClassModule()

    if not activeModule then
        local _, classFilename = UnitClass("player")
        print("|cff00ff00MoePower:|r No module found for " .. (classFilename or "Unknown") .. " class")
        return
    end

    -- Create main frame
    frame = CreateFrame("Frame", "MoePowerFrame", UIParent)
    frame:SetSize(400, 400)
    frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POSITION_X, DEFAULT_POSITION_Y)
    frame:SetFrameStrata("MEDIUM")

    -- Load saved position
    LoadPosition()

    -- Setup Edit Mode
    SetupEditMode()

    -- Create power display
    if activeModule.CreateOrbs then
        -- Get max power
        local maxPower = UnitPowerMax("player", activeModule.powerType)
        if maxPower == 0 then
            maxPower = 6  -- Default fallback
        end

        -- Calculate arc span
        local arcSpan = BASE_ORB_SPACING * (maxPower - 1)

        local layoutConfig = {
            arcRadius = ARC_RADIUS,
            arcSpan = arcSpan
        }
        powerOrbs = activeModule:CreateOrbs(frame, layoutConfig)
    end

    -- Initial update
    UpdatePower()

    frame:Show()

    local className = activeModule.className
    local formattedName = className:sub(1, 1):upper() .. className:sub(2):lower()
    print("|cff00ff00MoePower:|r " .. formattedName .. " module loaded")
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_LOGIN" then
        -- Delay initialization to ensure player stats are fully loaded
        C_Timer.After(1, Initialize)
    elseif event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Delay recreation to ensure stats are fully updated
        C_Timer.After(1, RecreateOrbs)
    elseif event == "UNIT_MAXPOWER" then
        -- Recreate orbs when max power changes
        if unit == "player" and activeModule and activeModule.powerTypeName then
            local eventPowerType = (powerType or ""):upper()
            if eventPowerType == activeModule.powerTypeName then
                RecreateOrbs()
            end
        end
    elseif event == "UNIT_POWER_FREQUENT" then
        -- Update power display
        if unit == "player" and activeModule and activeModule.powerTypeName then
            local eventPowerType = (powerType or ""):upper()
            if eventPowerType == activeModule.powerTypeName then
                UpdatePower()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Update display when entering or leaving combat
        UpdatePower()
    end
end)
