-- MoePower: Class Power HUD
-- Starting with Evoker class

local addonName = "MoePower"
local frame
local essenceOrbs = {}

-- Saved variables (initialized by WoW)
MoePowerDB = MoePowerDB or {}

-- Constants
local ESSENCE_COLOR = {r = 0.3, g = 0.8, b = 0.9}  -- Evoker essence color (cyan/teal)
local GRID_SIZE = 10  -- Snap to grid every 10 pixels

-- Create essence orbs in arc formation
local function CreateEssenceOrbs()
    local maxEssence = UnitPowerMax("player", Enum.PowerType.Essence)
    if maxEssence == 0 then
        maxEssence = 6  -- Default fallback
    end

    local orbSize = 28
    local arcRadius = 150  -- Distance from center (increased for wider spread)
    local arcSpan = 60     -- Total degrees of arc (flatter curve)
    local startAngle = 90 + (arcSpan / 2)  -- Start from top-left

    for i = 1, maxEssence do
        -- Calculate position in arc
        local angle = startAngle - ((i - 1) * (arcSpan / (maxEssence - 1)))
        local radian = math.rad(angle)
        local x = arcRadius * math.cos(radian)
        local y = arcRadius * math.sin(radian)

        -- Create orb frame with spell effect model
        local orb = CreateFrame("PlayerModel", nil, frame)
        orb:SetSize(orbSize, orbSize)
        orb:SetPoint("CENTER", frame, "CENTER", x, y)
        orb:SetModel("Spells/cfx_evoker_livingflame_precast.m2")
        orb:SetAlpha(1)

        -- Store references
        essenceOrbs[i] = {
            frame = orb
        }

        -- Start hidden (will show based on current essence)
        orb:Hide()
    end
end

-- Update orb display based on current essence
local function UpdateEssence()
    local currentEssence = UnitPower("player", Enum.PowerType.Essence)
    local maxEssence = #essenceOrbs

    -- Calculate centered range of orbs to show
    -- For max=5: 1 essence shows pos 3, 2 shows 2-3, 3 shows 2-4, etc.
    local startIndex = math.floor((maxEssence - currentEssence) / 2) + 1
    local endIndex = startIndex + currentEssence - 1

    for i = 1, maxEssence do
        if i >= startIndex and i <= endIndex then
            essenceOrbs[i].frame:Show()  -- Show centered orb
        else
            essenceOrbs[i].frame:Hide()  -- Hide orb
        end
    end
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
    dragFrame:SetPoint("CENTER", frame, "CENTER", 0, 140)  -- Position where orbs are
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

-- Initialize addon
local function Initialize()
    -- Check if player is an Evoker
    local _, classFilename = UnitClass("player")
    if classFilename ~= "EVOKER" then
        print("|cff00ff00MoePower:|r Currently only supports Evoker class")
        return
    end

    -- Create main frame
    frame = CreateFrame("Frame", "MoePowerFrame", UIParent)
    frame:SetSize(200, 200)  -- Larger to contain orbs
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -65)  -- Default position

    -- Load saved position if it exists
    LoadPosition()

    -- Setup Edit Mode integration
    SetupEditMode()

    -- Create essence orbs
    CreateEssenceOrbs()

    -- Initial update
    UpdateEssence()

    frame:Show()

    print("|cff00ff00MoePower:|r Evoker HUD loaded with Essence orbs (Edit Mode enabled)")
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
        -- Only update for player's essence changes
        if unit == "player" and powerType == "ESSENCE" then
            UpdateEssence()
        end
    end
end)