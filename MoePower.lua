-- MoePower: Class Power HUD
-- Starting with Evoker class

local addonName = "MoePower"
local frame

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
    frame:SetSize(50, 50)  -- 50x50 icon size
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Center of screen

    -- Create icon texture
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture("Interface\\Icons\\ClassIcon_Evoker")  -- Evoker class icon

    -- Create border
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints(frame)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    frame:Show()

    print("|cff00ff00MoePower:|r Evoker HUD loaded - Icon displayed at center screen")
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
    end
end)