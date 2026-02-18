-- MoePower Options Panel
-- Registers a settings page under Game Menu → Options → AddOns → MoePower.
-- All settings are stored in MoePowerDB.settings (sub-table of the existing SavedVariable).

local _, MoePower = ...

-- Default values for every setting
local DEFAULTS = {
    scale               = 1.0,   -- Global orb scale multiplier (0.5–2.0)
    paladinHideWhenFull = false, -- Hide Paladin orbs at max Holy Power out of combat
}

-- Populate MoePowerDB.settings with defaults for any missing keys
local function InitSettings()
    MoePowerDB.settings = MoePowerDB.settings or {}
    for k, v in pairs(DEFAULTS) do
        if MoePowerDB.settings[k] == nil then
            MoePowerDB.settings[k] = v
        end
    end
    MoePower.settings = MoePowerDB.settings
end

-- Apply the saved scale to the main HUD frame (safe to call before frame exists)
function MoePower:ApplyScale()
    if MoePower.frame then
        MoePower.frame:SetScale(MoePower.settings and MoePower.settings.scale or 1.0)
    end
end

-- Build the canvas settings panel
local function BuildOptionsPanel()
    local panel = CreateFrame("Frame")

    -- ── Title ─────────────────────────────────────────────────────────────────
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MoePower")

    -- ── Display section ───────────────────────────────────────────────────────
    local displayHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    displayHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    displayHeader:SetText("Display")
    displayHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider1 = panel:CreateTexture(nil, "ARTWORK")
    divider1:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider1:SetSize(530, 1)
    divider1:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -4)

    -- Scale label
    local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", divider1, "BOTTOMLEFT", 0, -14)
    scaleLabel:SetText("Orb Scale")

    -- Scale value readout
    local scaleValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    scaleValue:SetText("1.0×")

    -- Scale slider (raw Slider frame; OptionsSliderTemplate removed in Dragonflight+)
    local scaleSlider = CreateFrame("Slider", nil, panel)
    scaleSlider:SetSize(200, 16)
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -10)
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local sliderBg = scaleSlider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    sliderBg:SetSize(200, 8)
    sliderBg:SetPoint("CENTER", scaleSlider, "CENTER", 0, 0)
    sliderBg:SetTexCoord(0, 1, 0, 0.25)

    local sliderLeft = scaleSlider:CreateTexture(nil, "BORDER")
    sliderLeft:SetTexture("Interface\\Buttons\\UI-SliderBar-Border")
    sliderLeft:SetSize(8, 16)
    sliderLeft:SetPoint("RIGHT", scaleSlider, "LEFT", 0, 0)
    sliderLeft:SetTexCoord(0, 0.125, 0, 0.5)

    local sliderRight = scaleSlider:CreateTexture(nil, "BORDER")
    sliderRight:SetTexture("Interface\\Buttons\\UI-SliderBar-Border")
    sliderRight:SetSize(8, 16)
    sliderRight:SetPoint("LEFT", scaleSlider, "RIGHT", 0, 0)
    sliderRight:SetTexCoord(0.875, 1, 0, 0.5)

    local sliderMinLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderMinLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -2)
    sliderMinLabel:SetText("0.5×")

    local sliderMaxLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderMaxLabel:SetPoint("TOPRIGHT", scaleSlider, "BOTTOMRIGHT", 0, -2)
    sliderMaxLabel:SetText("2.0×")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10  -- round to 1 d.p.
        scaleValue:SetText(string.format("%.1f×", value))
        if MoePower.settings then
            MoePower.settings.scale = value
            MoePower:ApplyScale()
        end
    end)

    -- ── Visibility section ────────────────────────────────────────────────────
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visHeader:SetPoint("TOPLEFT", sliderMinLabel, "BOTTOMLEFT", 0, -24)
    visHeader:SetText("Visibility")
    visHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider2 = panel:CreateTexture(nil, "ARTWORK")
    divider2:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider2:SetSize(530, 1)
    divider2:SetPoint("TOPLEFT", visHeader, "BOTTOMLEFT", 0, -4)

    -- Paladin hide-when-full checkbox
    local paladinCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    paladinCheck:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", -2, -8)

    local paladinCheckLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paladinCheckLabel:SetPoint("LEFT", paladinCheck, "RIGHT", 4, 0)
    paladinCheckLabel:SetText("Paladin: Hide orbs at maximum Holy Power out of combat")

    paladinCheck:SetScript("OnClick", function(self)
        if MoePower.settings then
            MoePower.settings.paladinHideWhenFull = self:GetChecked()
        end
    end)

    -- ── OnShow: sync widgets from saved settings ──────────────────────────────
    panel:SetScript("OnShow", function()
        if not MoePower.settings then return end
        scaleSlider:SetValue(MoePower.settings.scale)
        paladinCheck:SetChecked(MoePower.settings.paladinHideWhenFull)
    end)

    return panel
end

-- Register the options panel once SavedVariables are available
local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "MoePower" then return end
    self:UnregisterEvent("ADDON_LOADED")

    InitSettings()

    local panel = BuildOptionsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "MoePower")
    Settings.RegisterAddOnCategory(category)
    MoePower.settingsCategory = category
end)
