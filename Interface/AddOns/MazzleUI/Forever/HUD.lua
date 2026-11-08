local _, M = ...
local root, units, enabled

local function Curve(parent, texture, width, height, flip, r, g, b, crop)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, height)
    local background = container:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(container)
    background:SetTexture(M.path .. "Art\\" .. texture .. ".blp")
    background:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, crop or 1)
    background:SetVertexColor(0.15, 0.15, 0.15, 0.6)
    local fill = CreateFrame("StatusBar", nil, container)
    fill:SetAllPoints(container)
    fill:SetOrientation("VERTICAL")
    fill:SetRotatesTexture(false)
    fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetStatusBarColor(r, g, b)
    fill:SetMinMaxValues(0, 1)
    -- A fixed alpha mask clips the native StatusBar fill to the ORIGINAL curve.
    -- Its dimensions never depend on secret health/power arithmetic.
    local mask = container:CreateMaskTexture()
    mask:SetTexture(M.path .. "Forever\\Textures\\" .. texture .. (flip and "-right.tga" or "-left.tga"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(width, 256)
    mask:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
    fill:GetStatusBarTexture():AddMaskTexture(mask)
    return container, fill
end

local function Update(view, rebuild)
    view:SetAlpha(UnitExists(view.unit) and 1 or 0)
    -- StatusBar and FontString sinks accept secret values; Lua must not compare,
    -- format, divide, concatenate or branch on them.
    if rebuild then
        view.health:SetValue(0)
        view.power:SetValue(0)
    end
    view.health:SetValue(UnitHealthPercent(view.unit, true))
    view.power:SetValue(UnitPowerPercent(view.unit))
    view.healthText:SetFormattedText("%.0f", UnitHealth(view.unit))
    view.powerText:SetFormattedText("%.0f", UnitPower(view.unit))
end

function M.CreateHUD()
    root = CreateFrame("Frame", "MazzleUIForeverHUD", UIParent)
    root:SetAllPoints(UIParent)
    root:EnableMouse(false)
    units = {}
    for index, unit in ipairs({"player", "target"}) do
        local view = CreateFrame("Frame", nil, root)
        view.unit = unit
        view:SetSize(128, 256)
        view:EnableMouse(false)
        local flip = index == 2
        view.healthContainer, view.health = Curve(view, "HL", 128, 256, flip, 1, 0, flip and 1 or 0)
        view.healthContainer:SetAllPoints(view)
        -- ML's visible curve occupies the top 140 pixels of its 256px texture.
        -- The legacy code filled 45.3125% transparent padding before the curve.
        view.powerContainer, view.power = Curve(view, "ML", 64, 140, flip, 0.2, 0.45, 1, 140 / 256)
        view.powerContainer:SetPoint("TOP", view, "BOTTOM", flip and 6 or -6, 183)
        view.healthText = view.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        view.healthText:SetSize(100, 20)
        view.healthText:SetPoint("BOTTOM", view, "BOTTOM", flip and -7 or 7, 26)
        view.powerText = view.power:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        view.powerText:SetSize(100, 20)
        view.powerText:SetPoint("BOTTOM", view, "BOTTOM", flip and 15 or -15, -19)
        view:SetScript("OnEvent", function() Update(view) end)
        for _, event in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER"}) do
            view:RegisterUnitEvent(event, unit)
        end
        view:RegisterEvent("PLAYER_TARGET_CHANGED")
        view:RegisterEvent("PLAYER_ENTERING_WORLD")
        view:SetScript("OnShow", function() view.rebuild = true end)
        units[index] = view
    end
    local elapsedTime = 0
    root:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.15 then return end
        elapsedTime = 0
        for _, view in ipairs(units) do
            Update(view, view.rebuild)
            view.rebuild = nil
        end
    end)
end

function M.LayoutHUD()
    if not root then return end
    local scale = M.geometry.scale
    for index, view in ipairs(units) do
        view:SetScale(scale)
        local size=math.max(12,9/view:GetEffectiveScale())
        view.healthText:SetFont(M.path.."Forever\\Fonts\\ARIALN.ttf",size,"OUTLINE")
        view.powerText:SetFont(M.path.."Forever\\Fonts\\ARIALN.ttf",size,"OUTLINE")
        view.healthText:SetHeight(size+4)
        view.powerText:SetHeight(size+4)
        view:ClearAllPoints()
        view:SetPoint("CENTER", UIParent, "CENTER", index == 1 and -100 or 100, 40)
        view.rebuild = true
        Update(view)
    end
end

function M.SetHUDShown(shown)
    enabled = shown
    if root then root:SetShown(shown) end
end

function M.HUDReport()
    local function Public(value)
        if issecretvalue(value) then return "restricted" end
        return tostring(value)
    end
    for _, view in ipairs(units or {}) do
        M.Print(view.unit .. ": health=" .. Public(UnitHealth(view.unit)) ..
            "; percent=" .. Public(UnitHealthPercent(view.unit, false)) ..
            "; bar=" .. Public(view.health:GetValue()) ..
            "; shown=" .. Public(view.health:IsShown()) ..
            "; alpha=" .. Public(view.health:GetAlpha()))
    end
end
