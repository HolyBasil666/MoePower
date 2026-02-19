-- MoePower Options Panel
-- Registers a settings page under Game Menu → Options → AddOns → MoePower.
-- All settings are stored in MoePowerDB.settings (sub-table of the existing SavedVariable).

local _, MoePower = ...

-- Default values for every setting
local DEFAULTS = {
    scale               = 1.0,     -- Global orb scale multiplier (0.5–2.0)
    paladinHideWhenFull = false,   -- Hide Paladin orbs at max Holy Power out of combat
    layout              = "arc",   -- "arc" or "horizontal"
    growDirection       = "center", -- "center", "left", or "right"
}

-- Display names for each class module (used in the Modules section)
local CLASS_DISPLAY_NAMES = {
    DEATHKNIGHT = "Death Knight",
    EVOKER      = "Evoker",
    HUNTER      = "Hunter",
    MONK        = "Monk",
    PALADIN     = "Paladin",
}

-- Populate MoePowerDB.settings with defaults for any missing keys
local function InitSettings()
    MoePowerDB.settings = MoePowerDB.settings or {}
    for k, v in pairs(DEFAULTS) do
        if MoePowerDB.settings[k] == nil then
            MoePowerDB.settings[k] = v
        end
    end
    -- moduleEnabled is a sub-table: nil/true = enabled, false = disabled
    MoePowerDB.settings.moduleEnabled = MoePowerDB.settings.moduleEnabled or {}
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
    local moduleCheckboxes = {}  -- [className] = checkButton, for OnShow sync

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

    -- ── Layout section ────────────────────────────────────────────────────────
    local layoutHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layoutHeader:SetPoint("TOPLEFT", sliderMinLabel, "BOTTOMLEFT", 0, -24)
    layoutHeader:SetText("Layout")
    layoutHeader:SetTextColor(0.6, 0.6, 0.6)

    local dividerL = panel:CreateTexture(nil, "ARTWORK")
    dividerL:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    dividerL:SetSize(530, 1)
    dividerL:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -4)

    local arcRadio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    arcRadio:SetPoint("TOPLEFT", dividerL, "BOTTOMLEFT", -2, -6)

    local arcRadioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arcRadioLabel:SetPoint("LEFT", arcRadio, "RIGHT", 4, 0)
    arcRadioLabel:SetText("Arc  (default)")

    local horizRadio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    horizRadio:SetPoint("LEFT", arcRadioLabel, "RIGHT", 24, 0)

    local horizRadioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    horizRadioLabel:SetPoint("LEFT", horizRadio, "RIGHT", 4, 0)
    horizRadioLabel:SetText("Horizontal line")

    arcRadio:SetScript("OnClick", function(self)
        self:SetChecked(true)
        horizRadio:SetChecked(false)
        if MoePower.settings then
            MoePower.settings.layout = "arc"
            if MoePower.RebuildOrbs then MoePower:RebuildOrbs() end
        end
    end)

    horizRadio:SetScript("OnClick", function(self)
        self:SetChecked(true)
        arcRadio:SetChecked(false)
        if MoePower.settings then
            MoePower.settings.layout = "horizontal"
            if MoePower.RebuildOrbs then MoePower:RebuildOrbs() end
        end
    end)

    -- ── Grow Direction section ────────────────────────────────────────────────
    local growHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growHeader:SetPoint("TOPLEFT", arcRadio, "BOTTOMLEFT", 2, -24)
    growHeader:SetText("Orb Fill Direction")
    growHeader:SetTextColor(0.6, 0.6, 0.6)

    local dividerG = panel:CreateTexture(nil, "ARTWORK")
    dividerG:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    dividerG:SetSize(530, 1)
    dividerG:SetPoint("TOPLEFT", growHeader, "BOTTOMLEFT", 0, -4)

    local centerRadio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    centerRadio:SetPoint("TOPLEFT", dividerG, "BOTTOMLEFT", -2, -6)

    local centerRadioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    centerRadioLabel:SetPoint("LEFT", centerRadio, "RIGHT", 4, 0)
    centerRadioLabel:SetText("Center outward  (default)")

    local leftRadio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    leftRadio:SetPoint("LEFT", centerRadioLabel, "RIGHT", 24, 0)

    local leftRadioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftRadioLabel:SetPoint("LEFT", leftRadio, "RIGHT", 4, 0)
    leftRadioLabel:SetText("Left > Right")

    local rightRadio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rightRadio:SetPoint("LEFT", leftRadioLabel, "RIGHT", 24, 0)

    local rightRadioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightRadioLabel:SetPoint("LEFT", rightRadio, "RIGHT", 4, 0)
    rightRadioLabel:SetText("Right > Left")

    local function SetGrowDirection(dir)
        centerRadio:SetChecked(dir == "center")
        leftRadio:SetChecked(dir == "left")
        rightRadio:SetChecked(dir == "right")
        if MoePower.settings then
            MoePower.settings.growDirection = dir
            if MoePower.ApplyGrowDirection then MoePower:ApplyGrowDirection() end
        end
    end

    centerRadio:SetScript("OnClick", function() SetGrowDirection("center") end)
    leftRadio:SetScript("OnClick",   function() SetGrowDirection("left")   end)
    rightRadio:SetScript("OnClick",  function() SetGrowDirection("right")  end)

    -- ── Visibility section ────────────────────────────────────────────────────
    local visHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visHeader:SetPoint("TOPLEFT", centerRadio, "BOTTOMLEFT", 2, -24)
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

    -- ── Modules section ───────────────────────────────────────────────────────
    local modHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modHeader:SetPoint("TOPLEFT", paladinCheck, "BOTTOMLEFT", 2, -24)
    modHeader:SetText("Modules")
    modHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider3 = panel:CreateTexture(nil, "ARTWORK")
    divider3:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider3:SetSize(530, 1)
    divider3:SetPoint("TOPLEFT", modHeader, "BOTTOMLEFT", 0, -4)

    -- One checkbox per registered class module, sorted alphabetically
    local sortedClasses = {}
    for className in pairs(MoePower.classModules) do
        table.insert(sortedClasses, className)
    end
    table.sort(sortedClasses, function(a, b)
        return (CLASS_DISPLAY_NAMES[a] or a) < (CLASS_DISPLAY_NAMES[b] or b)
    end)

    local prevAnchor = divider3
    for _, className in ipairs(sortedClasses) do
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -8)

        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText("Enable " .. (CLASS_DISPLAY_NAMES[className] or className))

        cb:SetScript("OnClick", function(self)
            if not MoePower.settings then return end
            local isEnabled = not not self:GetChecked()
            MoePower.settings.moduleEnabled[className] = isEnabled
            MoePower:ApplyModuleEnabled(className, isEnabled)
        end)

        moduleCheckboxes[className] = cb
        prevAnchor = cb
    end

    -- ── OnShow: sync widgets from saved settings ──────────────────────────────
    panel:SetScript("OnShow", function()
        if not MoePower.settings then return end
        scaleSlider:SetValue(MoePower.settings.scale)
        paladinCheck:SetChecked(MoePower.settings.paladinHideWhenFull)
        -- Sync layout radio buttons
        local isArc = (MoePower.settings.layout or "arc") == "arc"
        arcRadio:SetChecked(isArc)
        horizRadio:SetChecked(not isArc)
        -- Sync grow direction radio buttons
        local dir = MoePower.settings.growDirection or "center"
        centerRadio:SetChecked(dir == "center")
        leftRadio:SetChecked(dir == "left")
        rightRadio:SetChecked(dir == "right")
        -- Sync module checkboxes: enabled unless explicitly set to false
        local moduleEnabled = MoePower.settings.moduleEnabled
        for className, cb in pairs(moduleCheckboxes) do
            cb:SetChecked(moduleEnabled[className] ~= false)
        end
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
