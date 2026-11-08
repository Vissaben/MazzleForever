-- Current-client replacement for the original Mazzifier setup flow.
local _, M = ...
local frame, draft, skinLabel, scaleLabel, review
local checks = {}

local function Button(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Text(parent, text, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Refresh()
    local name = draft.skin:gsub("MazzleUI_Skin_", ""):gsub("MazzleUI_Default_Skin", "Arabian Tile"):gsub("_", " ")
    skinLabel:SetText(name)
    scaleLabel:SetFormattedText("Panel scale: %.0f%%", draft.scale * 100)
    for key, button in pairs(checks) do button:SetChecked(draft[key]) end
    local layout = M.ReadLayouts()
    local active = layout.layouts[layout.activeLayout]
    review:SetText("Apply creates or updates your MazzleUI character layout.\nCurrent layout: " .. (active and active.layoutName or "unknown") ..
        "\nYour previous layout and bar preferences are saved for Restore.")
end

local function Create()
    frame = CreateFrame("Frame", "MazzleUIForeverSetup", UIParent, "BackdropTemplate")
    frame:SetSize(520, 455)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    frame:SetBackdropColor(0.025, 0.025, 0.04, 0.98)
    frame:SetBackdropBorderColor(0.25, 0.55, 0.75, 1)
    Text(frame, "Mazzifier - World of Warcraft: Forever", 18, -18, 480, "GameFontNormalLarge")
    Text(frame, "Original MazzleUI artwork with a new Forever runtime.\nSetup applies to this character. Artwork preferences are shared.", 18, -49, 484)
    Text(frame, "Original skin", 18, -93, 120, "GameFontNormal")
    skinLabel = Text(frame, "", 136, -93, 280)
    Button(frame, "Next", 66, 434, -87, function()
        for index, name in ipairs(M.skinNames) do
            if name == draft.skin then draft.skin = M.skinNames[index % #M.skinNames + 1]; break end
        end
        Refresh()
    end)
    scaleLabel = Text(frame, "", 18, -127, 210)
    Button(frame, "-", 32, 242, -121, function() draft.scale = math.max(0.75, draft.scale - 0.05); Refresh() end)
    Button(frame, "+", 32, 278, -121, function() draft.scale = math.min(1.25, draft.scale + 0.05); Refresh() end)
    local choices = {{"hud", "Curved health/power HUD"}, {"models", "3D unit models"},
        {"context", "Two-page action grid"}, {"viewport", "Reserve world-view space"},
        {"unitframes", "Original player/target panels"}, {"chatdock", "Dock open chat windows"},
        {"groupframes", "Original pet/party panels"}}
    for index, choice in ipairs(choices) do
        local key, caption = choice[1], choice[2]
        local x, y = 16 + ((index - 1) % 2) * 250, -158 - math.floor((index - 1) / 2) * 31
        local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        checkbox:SetSize(26, 26)
        checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        Text(frame, caption, x + 29, y - 6, 216)
        checkbox:SetScript("OnClick", function(self) draft[key] = self:GetChecked() end)
        checks[key] = checkbox
    end
    review = Text(frame, "", 18, -306, 484)
    Button(frame, "Apply layout", 124, 18, -404, function()
        if not M.SafeToLayout() then M.Print("Finish combat and close Edit Mode before applying setup."); return end
        for key, value in pairs(draft) do M.db[key] = value end
        M.character.enabled = true
        M.character.installerSeen = true
        frame:Hide()
        M.RequestLayout()
    end)
    Button(frame, "Restore", 104, 152, -404, function() M.Restore() end)
    Button(frame, "More settings", 126, 266, -404, function() frame:Hide(); M.OpenOptions() end)
    Button(frame, "Close", 98, 402, -404, function() frame:Hide() end)
    frame:Hide()
end

function M.OpenInstaller()
    if M.compatible ~= true then M.Print("This setup requires Forever interface 16001."); return end
    if not M.SafeToLayout() then M.Print("Open setup after combat and Edit Mode."); return end
    if not frame then Create() end
    draft = {}
    for _, key in ipairs({"skin", "scale", "hud", "models", "context", "viewport", "unitframes", "groupframes", "chatdock"}) do draft[key] = M.db[key] end
    M.character.installerSeen = true
    Refresh()
    frame:Show()
end
