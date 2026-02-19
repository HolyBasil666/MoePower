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

-- Per-class spec entries shown in the Modules section.
-- Classes listed here get per-spec checkboxes instead of a single class toggle.
-- Only include specs the module actually tracks; unsupported specs are always inactive.
local SPEC_CONFIG = {
    DEATHKNIGHT = {
        { key = "BLOOD",         label = "Blood"         },
        { key = "FROST",         label = "Frost"         },
        { key = "UNHOLY",        label = "Unholy"        },
    },
    EVOKER = {
        { key = "DEVASTATION",   label = "Devastation"   },
        { key = "PRESERVATION",  label = "Preservation"  },
        { key = "AUGMENTATION",  label = "Augmentation"  },
    },
    HUNTER = {
        { key = "SURVIVAL",      label = "Survival"      },
    },
    MONK = {
        { key = "MISTWEAVER",    label = "Mistweaver"    },
        { key = "WINDWALKER",    label = "Windwalker"    },
    },
    PALADIN = {
        { key = "HOLY",          label = "Holy"          },
        { key = "PROTECTION",    label = "Protection"    },
        { key = "RETRIBUTION",   label = "Retribution"   },
    },
}

-- Populate MoePowerDB.settings with defaults for any missing keys
local function InitSettings()
    MoePowerDB.settings = MoePowerDB.settings or {}
    for k, v in pairs(DEFAULTS) do
        if MoePowerDB.settings[k] == nil then
            MoePowerDB.settings[k] = v
        end
    end
    -- moduleEnabled is a sub-table: nil/true = enabled, false = disabled (class-level fallback)
    MoePowerDB.settings.moduleEnabled = MoePowerDB.settings.moduleEnabled or {}
    -- specEnabled[className][specKey]: nil/true = enabled, false = disabled
    MoePowerDB.settings.specEnabled   = MoePowerDB.settings.specEnabled   or {}
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
    local classCheckboxes = {}  -- [className] = checkButton  (class-level, fallback for modules without SPEC_CONFIG)
    local specCheckboxes  = {}  -- [className][specKey] = checkButton

    -- ── ScrollFrame wrapping all content ──────────────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", "MoePowerOptionsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 40)))
    end)

    -- Content frame (scroll child) — all UI elements live here
    local C = CreateFrame("Frame", nil, scrollFrame)
    C:SetWidth(600)
    C:SetHeight(1200)   -- generous fixed height; scrollbar range adjusts automatically
    scrollFrame:SetScrollChild(C)

    -- ── Title ─────────────────────────────────────────────────────────────────
    local title = C:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MoePower")

    -- ── Display section ───────────────────────────────────────────────────────
    local displayHeader = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    displayHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    displayHeader:SetText("Display")
    displayHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider1 = C:CreateTexture(nil, "ARTWORK")
    divider1:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider1:SetSize(530, 1)
    divider1:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -4)

    -- Scale label
    local scaleLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", divider1, "BOTTOMLEFT", 0, -14)
    scaleLabel:SetText("Orb Scale")

    -- Scale value readout
    local scaleValue = C:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    scaleValue:SetText("1.0×")

    -- Scale slider (raw Slider frame; OptionsSliderTemplate removed in Dragonflight+)
    local scaleSlider = CreateFrame("Slider", nil, C)
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

    local sliderMinLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderMinLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -2)
    sliderMinLabel:SetText("0.5×")

    local sliderMaxLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    local layoutHeader = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layoutHeader:SetPoint("TOPLEFT", sliderMinLabel, "BOTTOMLEFT", 0, -24)
    layoutHeader:SetText("Layout")
    layoutHeader:SetTextColor(0.6, 0.6, 0.6)

    local dividerL = C:CreateTexture(nil, "ARTWORK")
    dividerL:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    dividerL:SetSize(530, 1)
    dividerL:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -4)

    local arcRadio = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    arcRadio:SetPoint("TOPLEFT", dividerL, "BOTTOMLEFT", -2, -6)

    local arcRadioLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arcRadioLabel:SetPoint("LEFT", arcRadio, "RIGHT", 4, 0)
    arcRadioLabel:SetText("Arc  (default)")

    local horizRadio = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    horizRadio:SetPoint("LEFT", arcRadioLabel, "RIGHT", 24, 0)

    local horizRadioLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    local growHeader = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growHeader:SetPoint("TOPLEFT", arcRadio, "BOTTOMLEFT", 2, -24)
    growHeader:SetText("Orb Fill Direction")
    growHeader:SetTextColor(0.6, 0.6, 0.6)

    local dividerG = C:CreateTexture(nil, "ARTWORK")
    dividerG:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    dividerG:SetSize(530, 1)
    dividerG:SetPoint("TOPLEFT", growHeader, "BOTTOMLEFT", 0, -4)

    local centerRadio = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    centerRadio:SetPoint("TOPLEFT", dividerG, "BOTTOMLEFT", -2, -6)

    local centerRadioLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    centerRadioLabel:SetPoint("LEFT", centerRadio, "RIGHT", 4, 0)
    centerRadioLabel:SetText("Center outward  (default)")

    local leftRadio = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    leftRadio:SetPoint("LEFT", centerRadioLabel, "RIGHT", 24, 0)

    local leftRadioLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftRadioLabel:SetPoint("LEFT", leftRadio, "RIGHT", 4, 0)
    leftRadioLabel:SetText("Left > Right")

    local rightRadio = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    rightRadio:SetPoint("LEFT", leftRadioLabel, "RIGHT", 24, 0)

    local rightRadioLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    local visHeader = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visHeader:SetPoint("TOPLEFT", centerRadio, "BOTTOMLEFT", 2, -24)
    visHeader:SetText("Visibility")
    visHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider2 = C:CreateTexture(nil, "ARTWORK")
    divider2:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider2:SetSize(530, 1)
    divider2:SetPoint("TOPLEFT", visHeader, "BOTTOMLEFT", 0, -4)

    -- Paladin hide-when-full checkbox
    local paladinCheck = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
    paladinCheck:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", -2, -8)

    local paladinCheckLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paladinCheckLabel:SetPoint("LEFT", paladinCheck, "RIGHT", 4, 0)
    paladinCheckLabel:SetText("Paladin: Hide orbs at maximum Holy Power out of combat")

    paladinCheck:SetScript("OnClick", function(self)
        if MoePower.settings then
            MoePower.settings.paladinHideWhenFull = self:GetChecked()
        end
    end)

    -- ── Modules section ───────────────────────────────────────────────────────
    local modHeader = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modHeader:SetPoint("TOPLEFT", paladinCheck, "BOTTOMLEFT", 2, -24)
    modHeader:SetText("Modules")
    modHeader:SetTextColor(0.6, 0.6, 0.6)

    local divider3 = C:CreateTexture(nil, "ARTWORK")
    divider3:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider3:SetSize(530, 1)
    divider3:SetPoint("TOPLEFT", modHeader, "BOTTOMLEFT", 0, -4)

    -- Sorted class list (alphabetical by display name)
    local sortedClasses = {}
    for className in pairs(MoePower.classModules) do
        table.insert(sortedClasses, className)
    end
    table.sort(sortedClasses, function(a, b)
        return (CLASS_DISPLAY_NAMES[a] or a) < (CLASS_DISPLAY_NAMES[b] or b)
    end)

    -- Layout constants
    local INDENT_CLASS = 2    -- x: class header from divider left
    local INDENT_SPEC  = 18   -- x: spec checkboxes from divider left
    local H_LABEL      = 14   -- approximate height of a GameFontNormal string
    local H_CB         = 26   -- height of UICheckButtonTemplate checkbox
    local curY         = 0    -- running Y below divider3.BOTTOMLEFT (negative = downward)

    for _, className in ipairs(sortedClasses) do
        local specCfg = SPEC_CONFIG[className]
        if specCfg then
            -- Class label (acts as a group header; individual spec checkboxes provide the toggles)
            curY = curY - 10
            local classLabel = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            classLabel:SetPoint("TOPLEFT", divider3, "BOTTOMLEFT", INDENT_CLASS, curY)
            classLabel:SetText(CLASS_DISPLAY_NAMES[className] or className)
            curY = curY - H_LABEL

            -- Per-spec checkboxes, indented under the class label
            for _, spec in ipairs(specCfg) do
                curY = curY - 4
                local cb = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", divider3, "BOTTOMLEFT", INDENT_SPEC, curY)

                local lbl = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                lbl:SetText(spec.label)

                local specKey = spec.key  -- capture for closure
                cb:SetScript("OnClick", function(self)
                    if not MoePower.settings then return end
                    local isEnabled = not not self:GetChecked()
                    MoePower.settings.specEnabled[className] = MoePower.settings.specEnabled[className] or {}
                    MoePower.settings.specEnabled[className][specKey] = isEnabled
                    MoePower:ApplySpecEnabled(className, specKey, isEnabled)
                end)

                specCheckboxes[className] = specCheckboxes[className] or {}
                specCheckboxes[className][specKey] = cb
                curY = curY - H_CB
            end
        else
            -- Fallback: single class-level toggle (for future modules without SPEC_CONFIG)
            curY = curY - 8
            local cb = CreateFrame("CheckButton", nil, C, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", divider3, "BOTTOMLEFT", INDENT_CLASS, curY)

            local lbl = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            lbl:SetText("Enable " .. (CLASS_DISPLAY_NAMES[className] or className))

            cb:SetScript("OnClick", function(self)
                if not MoePower.settings then return end
                local isEnabled = not not self:GetChecked()
                MoePower.settings.moduleEnabled[className] = isEnabled
                MoePower:ApplyModuleEnabled(className, isEnabled)
            end)

            classCheckboxes[className] = cb
            curY = curY - H_CB
        end
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
        -- Sync per-spec checkboxes: enabled unless explicitly set to false
        local specEnabled = MoePower.settings.specEnabled
        for className, specs in pairs(specCheckboxes) do
            local classSpecEnabled = specEnabled[className] or {}
            for specKey, cb in pairs(specs) do
                cb:SetChecked(classSpecEnabled[specKey] ~= false)
            end
        end
        -- Sync class-level checkboxes (fallback for modules without SPEC_CONFIG)
        local moduleEnabled = MoePower.settings.moduleEnabled
        for className, cb in pairs(classCheckboxes) do
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
