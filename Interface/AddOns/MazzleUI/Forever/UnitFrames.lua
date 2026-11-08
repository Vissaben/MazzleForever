-- Original DUF presentation data rendered on Forever's native unit buttons.
local _, M = ...
local views = {}

local function TextValue(value)
    if issecretvalue(value) then return value end
    return value or ""
end

local function Bar(view)
    local bar = CreateFrame("StatusBar", nil, view)
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(bar)
    back:SetColorTexture(0, 0, 0, 0.8)
    bar:EnableMouse(false)
    return bar
end

local function Position(region, spec, references)
    region:ClearAllPoints()
    region:SetSize(spec.width, spec.height)
    region:SetPoint(spec.attachpoint, assert(references[spec.attach], "Missing original unit anchor: " .. spec.attach),
        spec.attachto, spec.xoffset or 0, spec.yoffset or 0)
end

local function StyleText(label, spec)
    local font = spec.label == "Name" and "FRIZQT__.ttf" or "ARIALN.ttf"
    local pixels = label:GetEffectiveScale()
    local size = math.max(spec.textheight,(spec.label == "Name" and 8 or 7)/pixels)
    label:SetFont(M.path .. "Forever\\Fonts\\" .. font, size, "OUTLINE")
    label:SetHeight(math.max(spec.height,size*(spec.height >= 22 and 2 or 1)+2))
    label:SetJustifyH(spec.justify)
    label:SetWordWrap(false)
    label:SetTextColor(spec.textcolor.r, spec.textcolor.g, spec.textcolor.b, 1)
end

M.UnitPresentation = {Bar=Bar, Position=Position, TextValue=TextValue, StyleText=StyleText}

local function UpdateModel(view, unit)
    if not view.model then return end
    if not M.db.models or C_Secrets.ShouldUnitIdentityBeSecret(unit) then
        view.model:ClearModel()
        view.needsModel = true
    elseif view.needsModel then
        view.model:SetUnit(unit)
        view.model:SetPortraitZoom(0)
        view.model:SetPosition(0, 0, 0)
        view.needsModel = false
    end
end

local function Update(view)
    -- Resolve the native secure button's effective unit, including player/vehicle
    -- switches. The result is only forwarded to native unit/widget functions.
    local unit = SecureButton_GetUnit(view.owner)
    view.health:SetValue(UnitHealthPercent(unit, true))
    view.power:SetValue(UnitPowerPercent(unit))
    local labels = view.labels
    if view.kind == "player" then
        labels[1]:SetText(TextValue(view.owner.name:GetText()))
        labels[3]:SetFormattedText("%.0f/%.0f", UnitHealth(unit), UnitHealthMax(unit))
        labels[4]:SetFormattedText("%.0f/%.0f", UnitPower(unit), UnitPowerMax(unit))
    else
        labels[1]:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
        labels[3]:SetFormattedText("%.0f%%", UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100))
        labels[6]:SetText(TextValue(view.owner.name:GetText()))
        labels[9]:SetFormattedText("%.0f/%.0f\n%.0f/%.0f", UnitHealth(unit), UnitHealthMax(unit), UnitPower(unit), UnitPowerMax(unit))
        if UnitExists("targettarget") then
            labels[8]:SetFormattedText("Looking at %s", UnitName("targettarget"))
        else labels[8]:SetText("") end
    end
    local description = ""
    if not C_Secrets.ShouldUnitIdentityBeSecret(unit) then
        local player = UnitIsPlayer(unit)
        if not issecretvalue(player) and not player then description = TextValue(UnitCreatureType(unit))
        else description = TextValue(UnitClass(unit)) end
    end
    labels[2]:SetFormattedText("%s %s", TextValue(view.nativeLevel:GetText()), description)
    for _, status in ipairs(view.statusLabels) do
        status.output:SetText(TextValue(status.source:GetText()))
        status.output:SetAlphaFromBoolean(status.source:IsShown(), 1, 0)
    end
    UpdateModel(view, unit)
end

local function Create(kind, owner)
    local player = kind == "player"
    local content = player and owner.PlayerFrameContent or owner.TargetFrameContent
    local main = content and (player and content.PlayerFrameContentMain or content.TargetFrameContentMain)
    local art = player and owner.PlayerFrameContainer or owner.TargetFrameContainer
    assert(main and art and main.HealthBarsContainer and owner.name, "Unsupported Forever unit-frame hierarchy")
    local view = CreateFrame("Frame", "MazzleUIForever" .. (player and "Player" or "Target") .. "Panel", owner)
    view.kind, view.owner, view.main, view.art = kind, owner, main, art
    view:EnableMouse(false)
    view.health, view.power = Bar(view), Bar(view)
    -- All text lives above both bars, with fixed bounds. Secret text never
    -- determines widget geometry or the size of a protected unit button.
    local textLayer = CreateFrame("Frame", nil, view)
    textLayer:SetAllPoints(view)
    textLayer:SetFrameLevel(view.health:GetFrameLevel() + 2)
    textLayer:EnableMouse(false)
    view.labels, view.statusLabels = {}, {}
    for _, index in ipairs(player and {1, 2, 3, 4} or {1, 2, 3, 6, 8, 9}) do
        view.labels[index] = textLayer:CreateFontString(nil, "OVERLAY")
    end
    view.nativeLevel = player and PlayerLevelText or main.LevelText
    assert(view.nativeLevel, "Missing native level label")
    for _, key in ipairs({"DeadText", "UnconsciousText"}) do
        local native = main.HealthBarsContainer[key]
        if native then
            local label = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetSize(150, 18)
            label:SetPoint("CENTER", view, "CENTER", 0, 0)
            view.statusLabels[#view.statusLabels + 1] = {source=native, output=label}
        end
    end
    if player then
        view.model = CreateFrame("PlayerModel", nil, view)
        view.model:SetSize(100, 100)
        view.model:EnableMouse(false)
        view.modelAnchor=CreateFrame("Frame",nil,view)
        view.modelAnchor:EnableMouse(false)
        view.pedestal=view:CreateTexture(nil,"BACKGROUND")
        view.pedestal:SetTexture(M.path .. "Art\\pedestal.tga")
        view.model:SetPoint("BOTTOM",view.pedestal,"BOTTOM",-1,5)
        view.needsModel = true
        view:RegisterEvent("UNIT_PORTRAIT_UPDATE")
        view:RegisterEvent("UNIT_ENTERED_VEHICLE")
        view:RegisterEvent("UNIT_EXITED_VEHICLE")
        view:SetScript("OnEvent", function() view.needsModel = true end)
    end
    view:SetScript("OnShow", function() view.needsModel = true; view.redraw = true end)
    local elapsedTime = 0
    view:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.1 then return end
        elapsedTime = 0
        if view.redraw then view.health:SetValue(0); view.power:SetValue(0); view.redraw = false end
        Update(view)
    end)
    view:Hide()
    return view
end

local function Style(view, profile)
    view:SetSize(profile.width, profile.height)
    -- FrameSize is 100 in our private native layout; this is the original DUF
    -- scale applied to the same reference-height scale as the original panels.
    local ownerScale=view.owner:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local scale=profile.scale*M.geometry.scale/ownerScale
    view:SetScale(scale)
    view:ClearAllPoints()
    if view.kind == "player" then
        local b=M.geometry.playerBounds
        view.owner:SetSize((b.right-b.left)*scale,(b.top-b.bottom)*scale)
        view:SetPoint("BOTTOMLEFT",view.owner,"BOTTOMLEFT",-b.left,-b.bottom)
    else
        view.owner:SetSize(M.geometry.caveSize/ownerScale,
            (M.geometry.targetTop-115*profile.scale*M.geometry.scale)/ownerScale)
        view:SetPoint("TOP", view.owner, "TOP", 0, 0)
    end
    view.owner:SetHitRectInsets(0,0,0,0)
    local references = {["Unit Frame"]=view, ["_HealthBar"]=view.health, ["_ManaBar"]=view.power, UIParent=UIParent}
    for index, label in pairs(view.labels) do references["_TextBox_" .. index] = label end
    for index, bar in ipairs({view.health, view.power}) do
        local spec = profile.bars[index]
        Position(bar, spec, references)
        bar:SetOrientation(spec.direction == 3 and "VERTICAL" or "HORIZONTAL")
        local color = spec.color or spec.manacolor
        bar:SetStatusBarColor(color.r, color.g, color.b, 1)
    end
    if view.modelAnchor then
        references._ClassIcon=view.modelAnchor
        local spec=M.Copy(profile.ClassIcon)
        spec.width,spec.height=spec.size,spec.size
        Position(view.modelAnchor,spec,references)
        Position(view.pedestal,profile.TextBox[8],references)
    end
    for index, label in pairs(view.labels) do
        local spec = profile.TextBox[index]
        Position(label, spec, references)
        if view.kind == "target" and spec.attach == "UIParent" then
            -- Original absolute screen anchors must clear the larger current
            -- minimap. Preserve the text/bar relationships while lifting the cave.
            label:ClearAllPoints()
            label:SetPoint(spec.attachpoint, UIParent, spec.attachto, spec.xoffset or 0,
                (spec.yoffset or 0) + M.geometry.targetLift / (profile.scale * M.geometry.scale))
        end
        StyleText(label, spec)
    end
    view.redraw, view.needsModel = true, true
end

function M.RestoreUnitFrames()
    for _, view in pairs(views) do
        view:Hide()
        if view.backup then
            view.main:SetAlpha(view.backup.mainAlpha)
            view.art:SetAlpha(view.backup.artAlpha)
            if view.resource then view.resource:SetIgnoreParentAlpha(view.backup.resourceIgnoresAlpha) end
            view.owner:SetSize(view.backup.width,view.backup.height)
            view.owner:SetHitRectInsets(unpack(view.backup.hitRect))
            view.backup = nil
        end
        if view.model then view.model:ClearModel() end
    end
end

function M.ApplyUnitFrames()
    if not M.db.unitframes then M.RestoreUnitFrames(); return end
    local chosen = M.SelectUnitStyle()
    -- Check both hierarchies before changing either. Failure leaves native unit
    -- presentation usable instead of hiding half of a partially-created style.
    for _, entry in ipairs({{"player", PlayerFrame}, {"target", TargetFrame}}) do
        if not views[entry[1]] then views[entry[1]] = Create(entry[1], entry[2]) end
    end
    for kind, view in pairs(views) do
        if not view.backup then
            view.resource = kind == "player" and view.main.AlternatePowerBarArea or nil
            view.backup = {mainAlpha=view.main:GetAlpha(), artAlpha=view.art:GetAlpha(),
                width=view.owner:GetWidth(),height=view.owner:GetHeight(),hitRect={view.owner:GetHitRectInsets()},
                resourceIgnoresAlpha=view.resource and view.resource:IsIgnoringParentAlpha()}
        end
        Style(view, chosen[kind])
        -- Native events keep running underneath; Contextual (auras, raid marks,
        -- threat, PvP) and class-resource frames remain visible and interactive.
        view.main:SetAlpha(0)
        view.art:SetAlpha(0)
        if view.resource then view.resource:SetIgnoreParentAlpha(true) end
        view:Show()
    end
end
