local _, M = ...
local category

function M.CreateOptions()
    category = Settings.RegisterVerticalLayoutCategory("MazzleUI Forever")
    local function Register(key, label, kind)
        local setting = Settings.RegisterAddOnSetting(category, "MAZZLEUI_FOREVER_" .. key,
            key, M.db, kind, label, M.defaults[key])
        setting:SetValueChangedCallback(M.RequestLayout)
        return setting
    end
    local skin = Register("skin", "Original MazzleUI skin", Settings.VarType.String)
    Settings.CreateDropdown(category, skin, function()
        local choices = Settings.CreateControlTextContainer()
        for _, name in ipairs(M.skinNames) do
            choices:Add(name, name:gsub("MazzleUI_Skin_", ""):gsub("MazzleUI_Default_Skin", "Arabian Tile (default)"):gsub("_", " "))
        end
        return choices:GetData()
    end, "Artwork supplied with the original MazzleUI 1.18 compilation.")
    local scale = Register("scale", "Panel and HUD scale", Settings.VarType.Number)
    local slider = Settings.CreateSliderOptions(0.75, 1.25, 0.05)
    slider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return string.format("%.0f%%", value * 100) end)
    Settings.CreateSlider(category, scale, slider, "Adapt the original 1200-pixel design to your display.")
    Settings.CreateCheckbox(category, Register("hud", "Original curved health and power HUD", Settings.VarType.Boolean),
        "Use the supplied MazzleUI curve artwork with native health and power bars.")
    Settings.CreateCheckbox(category, Register("models", "3D unit models", Settings.VarType.Boolean),
        "Show full models in the original unit panels when the client permits access to their identities.")
    Settings.CreateCheckbox(category, Register("viewport", "Reserve space beneath the world view", Settings.VarType.Boolean),
        "Use MazzleUI's original world viewport. Optional; disabled initially.")
    Settings.CreateCheckbox(category, Register("context", "Two-page action grid", Settings.VarType.Boolean),
        "Show the Actions button. Its 32 slots are shared with native action bars 6-8; changes appear in both places.")
    Settings.CreateCheckbox(category, Register("unitframes", "Original player and target unit panels", Settings.VarType.Boolean),
        "Use Mazzifier's original horizontal player bars and vertical target bars. Native targeting, menus and auras remain active.")
    Settings.CreateCheckbox(category, Register("chatdock", "Dock open chat windows in the left panel", Settings.VarType.Boolean),
        "Keep existing chat tabs together. Filters and messages are preserved; disabling restores windows docked by MazzleUI.")
    Settings.CreateCheckbox(category, Register("groupframes", "Original pet and party model panels", Settings.VarType.Boolean),
        "Place the pet beside the player and two party models on each side of the target cave. Native targeting, menus and indicators remain active.")
    Settings.RegisterAddOnCategory(category)
end

function M.OpenOptions()
    if not M.SafeToLayout() then M.Print("Finish combat and close Edit Mode first."); return end
    if category then Settings.OpenToCategory(category:GetID()) end
end
