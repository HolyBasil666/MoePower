-- MoePower: Class Power HUD
-- Starting with Evoker class

local addonName = "MoePower"
local frame
local essenceOrbs = {}

-- Evoker essence color (cyan/teal)
local ESSENCE_COLOR = {r = 0.3, g = 0.8, b = 0.9}

-- Create essence orbs in arc formation
local function CreateEssenceOrbs()
    local maxEssence = UnitPowerMax("player", Enum.PowerType.Essence)
    if maxEssence == 0 then
        maxEssence = 6  -- Default fallback
    end

    local orbSize = 28
    local arcRadius = 70  -- Distance from center
    local arcSpan = 140   -- Total degrees of arc
    local startAngle = 90 + (arcSpan / 2)  -- Start from top-left

    for i = 1, maxEssence do
        -- Calculate position in arc
        local angle = startAngle - ((i - 1) * (arcSpan / (maxEssence - 1)))
        local radian = math.rad(angle)
        local x = arcRadius * math.cos(radian)
        local y = arcRadius * math.sin(radian)

        -- Create orb frame
        local orb = CreateFrame("Frame", nil, frame)
        orb:SetSize(orbSize, orbSize)
        orb:SetPoint("CENTER", frame, "CENTER", x, y)

        -- Orb texture (always filled when visible)
        local fill = orb:CreateTexture(nil, "ARTWORK")
        fill:SetAllPoints(orb)
        fill:SetTexture("Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Ring")  -- Circular texture
        fill:SetVertexColor(ESSENCE_COLOR.r, ESSENCE_COLOR.g, ESSENCE_COLOR.b, 1)

        -- Border/ring
        local border = orb:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(orb)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

        -- Store references
        essenceOrbs[i] = {
            frame = orb,
            fill = fill
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
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Center of screen

    -- Create center icon texture
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(50, 50)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\ClassIcon_Evoker")

    -- Create center icon border
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("CENTER", frame, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Create essence orbs
    CreateEssenceOrbs()

    -- Initial update
    UpdateEssence()

    frame:Show()

    print("|cff00ff00MoePower:|r Evoker HUD loaded with Essence orbs")
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