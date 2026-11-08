-- Independently implemented replacement for the original 4x4, two-page menu.
-- Blizzard owns action execution and button updates; no action is auto-filled.
local _, M = ...
local menu, toggle, pages

local function Wheel(frame)
    frame:EnableMouseWheel(true)
    SecureHandlerWrapScript(frame, "OnMouseWheel", menu, [[
        control:GetFrameRef("page1"):Hide()
        control:GetFrameRef("page2"):Hide()
        if offset > 0 then control:GetFrameRef("page1"):Show()
        else control:GetFrameRef("page2"):Show() end
    ]])
end

local function Label(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function SecureButton(name, parent, text)
    -- Combining UIPanelButton/Backdrop templates replaces SecureHandler_OnLoad.
    -- Keep the secure template's scripts and draw this small button ourselves.
    local button = CreateFrame("Button", name, parent, "SecureHandlerClickTemplate")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetColorTexture(0.12, 0.22, 0.27, 1)
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    local caption = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("CENTER", button, "CENTER", 0, 0)
    caption:SetText(text)
    button:RegisterForClicks("AnyUp")
    return button
end

function M.CreateContext()
    menu = CreateFrame("Frame", "MazzleUIForeverContext", UIParent, "SecureHandlerBaseTemplate")
    menu:SetSize(206, 242)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    local background = menu:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(menu)
    background:SetColorTexture(0.025, 0.025, 0.04, 0.95)
    Label(menu, "Shared with action bars 6-8", 10, -224)
    pages = {}
    for page = 1, 2 do
        local content = CreateFrame("Frame", nil, menu)
        content:SetAllPoints(menu)
        Label(content, "MazzleUI actions " .. page .. "/2", 10, -10)
        pages[page] = content
        menu:SetFrameRef("page" .. page, content)
        for index = 1, 16 do
            local number = (page - 1) * 16 + index
            local button = CreateFrame("CheckButton", "MazzleUIForeverContextAction" .. number, content, "ActionBarButtonTemplate")
            -- Modern extra bars use 145-180. Avoid the old 89-120 range, which
            -- overlaps class/form pages. These are shared real slots, not copies.
            button:SetID(0)
            button:SetAttribute("action", 144 + number)
            button:SetAttribute("useparent-actionpage", false)
            button:SetAttribute("showgrid", 1)
            button:SetAttribute("flyoutDirection", "UP")
            button.buttonType = "MAZZLEUIFOREVERCONTEXT"
            button:UpdateHotkeys(button.buttonType)
            button:SetSize(45, 45)
            button:SetPoint("TOPLEFT", menu, "TOPLEFT", 10 + ((index - 1) % 4) * 47, -32 - math.floor((index - 1) / 4) * 47)
            Wheel(button)
        end
        local pageButton = SecureButton("MazzleUIForeverContextPage" .. page, menu, tostring(page))
        pageButton:SetSize(26, 20)
        pageButton:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10 - (2 - page) * 28, -5)
        pageButton:SetFrameRef("show", content)
        pageButton:SetAttribute("_onclick", [[
            local menu = self:GetParent()
            menu:GetFrameRef("page1"):Hide()
            menu:GetFrameRef("page2"):Hide()
            self:GetFrameRef("show"):Show()
        ]])
        Wheel(pageButton)
    end
    pages[2]:Hide()
    Wheel(menu)
    menu:Hide()
    toggle = SecureButton("MazzleUIForeverContextToggle", UIParent, "Actions")
    toggle:SetSize(62, 24)
    toggle:SetFrameRef("menu", menu)
    toggle:SetAttribute("_onclick", [[
        if not self:GetAttribute("enabled") then return end
        local menu = self:GetFrameRef("menu")
        if menu:IsShown() then menu:Hide() else menu:Show() end
    ]])
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Two pages of actions; mouse wheel changes page.\nDrag actions here as on a normal action bar.\nAssign a toggle key in Key Bindings > MazzleUI.")
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function M.LayoutContext()
    if not menu then return end
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -M.geometry.sideInset, M.geometry.statusBottom+30)
    toggle:ClearAllPoints()
    toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        -M.geometry.sideInset-M.geometry.sideWidth-16,M.geometry.menuBottom)
end

function M.SetContextShown(enabled)
    if not toggle then return end
    toggle:SetAttribute("enabled", enabled)
    toggle:SetShown(enabled)
    if not enabled then menu:Hide() end
end

function M.ToggleContext()
    if not M.SafeToLayout() then
        M.Print("Use the Actions button or its key binding during combat.")
        return
    end
    if menu and M.character.enabled and M.db.context then menu:SetShown(not menu:IsShown()) end
end

BINDING_HEADER_MAZZLEUIFOREVER = "MazzleUI"
_G["BINDING_NAME_CLICK MazzleUIForeverContextToggle:LeftButton"] = "Toggle action grid"
