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

-- Edit Mode integration
local function SetupEditMode()
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(false)  -- Don't capture mouse input (dragFrame handles it in Edit Mode)
    frame:SetClampedToScreen(true)

    -- Create draggable overlay for Edit Mode (covers orb area)
    local dragFrame = CreateFrame("Frame", nil, frame)
    dragFrame:SetSize(220, 150)  -- Taller to reach horizontal center line
    dragFrame:SetPoint("CENTER", frame, "CENTER", 0, 135)  -- Position where orbs are
    dragFrame:EnableMouse(true)
    dragFrame:SetFrameStrata("HIGH")
    dragFrame:Hide()  -- Hidden by default

    -- Make it obvious when in Edit Mode
    local bg = dragFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(dragFrame)
    bg:SetColorTexture(0, 1, 0, 0.3)  -- Semi-transparent green

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
            if frame and frame.dragFrame then
                frame.dragFrame:Show()
            end
        end)

        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            print("|cff00ff00MoePower:|r Edit Mode exited")
            if frame and frame.dragFrame then
                frame.dragFrame:Hide()
            end
        end)

        -- Check if already in Edit Mode
        if EditModeManagerFrame:IsEditModeActive() then
            print("|cff00ff00MoePower:|r Already in Edit Mode")
            dragFrame:Show()
        end
    else
        print("|cff00ff00MoePower:|r EditModeManagerFrame not found - using fallback")
        -- Fallback: always show a small handle
        dragFrame:SetSize(80, 30)
        dragFrame:SetPoint("CENTER", frame, "BOTTOM", 0, 0)
        dragFrame:Show()
    end
end

-- Update power display (called by event handler)
local function UpdatePower()
    if activeModule and activeModule.UpdatePower then
        activeModule:UpdatePower(powerOrbs)
    end
end

-- Initialize addon
local function Initialize()
    -- Get the class module for this character
    activeModule = GetClassModule()

    if not activeModule then
        local _, classFilename = UnitClass("player")
        print("|cff00ff00MoePower:|r No module found for " .. (classFilename or "Unknown") .. " class")
        return
    end

    -- Create main frame
    frame = CreateFrame("Frame", "MoePowerFrame", UIParent)
    frame:SetSize(200, 200)  -- Larger to contain orbs
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -70)  -- Default position

    -- Load saved position if it exists
    LoadPosition()

    -- Setup Edit Mode integration
    SetupEditMode()

    -- Create power display using the class module
    if activeModule.CreateOrbs then
        powerOrbs = activeModule:CreateOrbs(frame)
    end

    -- Initial update
    UpdatePower()

    frame:Show()

    print("|cff00ff00MoePower:|r " .. activeModule.className .. " HUD loaded (Edit Mode enabled)")
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_LOGIN" then
        Initialize()
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        -- Only update for player's power changes
        if unit == "player" and activeModule and activeModule.powerType then
            -- Check if this is the power type we're tracking
            local powerTypeName = powerType or ""
            if powerTypeName:upper() == "ESSENCE" and activeModule.powerType == Enum.PowerType.Essence then
                UpdatePower()
            end
        end
    end
end)
