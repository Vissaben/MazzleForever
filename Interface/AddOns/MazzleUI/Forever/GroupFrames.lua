-- Original pet/party presentation on Blizzard's existing secure unit buttons.
-- The native pool owns membership, targeting, vehicles and visibility.
local _, M = ...
local P = M.UnitPresentation
local views, byOwner = {}, {}
local pending, scheduled, hooked, active, partyStrip, backgroundAlpha
local drawerAlpha, drawerHooked

local function StyleDrawer()
    local drawer=CompactRaidFrameManager
    if not active or not drawer or not drawer.Background then return end
    if drawerAlpha==nil then drawerAlpha=drawer.Background:GetAlpha() end
    -- Keep the native arrow, group controls and expanded panel functional.
    -- Only the collapsed drawer's tall decorative strip is removed.
    drawer.Background:SetAlpha(drawer.collapsed and 0 or drawerAlpha)
end

local function RememberPoints(region)
    local points = {}
    for index=1,region:GetNumPoints() do points[index]={region:GetPoint(index)} end
    return points
end

local function RestorePoints(region, points)
    region:ClearAllPoints()
    for _, point in ipairs(points) do region:SetPoint(unpack(point)) end
end

local function Update(view)
    -- Native UnitFrame_SetUnit keeps this public token current during vehicles
    -- and Edit Mode previews. It is forwarded unchanged to native display APIs.
    local unit = view.owner.unit or SecureButton_GetUnit(view.owner)
    for _, region in ipairs(view.regions) do region:SetAlpha(0) end
    view.health:SetValue(UnitHealthPercent(unit, true))
    view.power:SetValue(UnitPowerPercent(unit))
    view.labels[1]:SetText(P.TextValue(view.nativeName:GetText()))
    if view.compactText then view.labels[3]:SetFormattedText("%.0f",UnitHealth(unit))
    else view.labels[3]:SetFormattedText("%.0f\n%.0f", UnitHealth(unit), UnitHealthMax(unit)) end
    view.labels[4]:SetFormattedText("%.0f%%", UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100))
    view.labels[5]:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    if view.labels[6] then
        if view.compactText then view.labels[6]:SetFormattedText("%.0f",UnitPower(unit))
        else view.labels[6]:SetFormattedText("%.0f\n%.0f", UnitPower(unit), UnitPowerMax(unit)) end
    end
    local description = ""
    local restricted = C_Secrets.ShouldUnitIdentityBeSecret(unit)
    if not restricted then
        if view.kind == "party" then description = P.TextValue(UnitClass(unit))
        else description = P.TextValue(UnitCreatureType(unit)) end
    end
    view.labels[2]:SetFormattedText("%.0f %s", UnitLevel(unit), description)
    view.dead:SetAlphaFromBoolean(UnitIsDeadOrGhost(unit), 1, 0)
    if not M.db.models or restricted or not UnitExists(unit) then
        view.model:ClearModel()
        view.needsModel = true
    elseif view.needsModel then
        view.model:SetUnit(unit)
        view.model:SetPortraitZoom(0)
        view.model:SetPosition(0,0,0)
        view.needsModel = false
    end
end

local function Create(kind, owner)
    local regions, name
    if kind == "party" then
        assert(owner.HealthBarContainer and owner.ManaBar and owner.Name and owner.PartyMemberOverlay,
            "Unsupported Forever party-frame hierarchy")
        name = owner.Name
        regions = {owner.Portrait, owner.Texture, owner.VehicleTexture, owner.Flash,
            owner.Name, owner.HealthBarContainer, owner.ManaBar, owner.PartyMemberOverlay.Status}
    else
        assert(PetFrameHealthBar and PetFrameManaBar and PetName and PetFrameTexture,
            "Unsupported Forever pet-frame hierarchy")
        name = PetName
        regions = {PetPortrait, PetFrameTexture, PetFrameFlash, PetAttackModeTexture,
            PetFrameHealthBar, PetFrameManaBar, PetName}
    end
    for index=1,(kind == "party" and 8 or 7) do assert(regions[index], "Missing native group artwork") end
    local view = CreateFrame("Frame", nil, owner)
    view.kind, view.owner, view.regions, view.nativeName = kind, owner, regions, name
    view:EnableMouse(false)
    view.health, view.power = P.Bar(view), P.Bar(view)
    view.model = CreateFrame("PlayerModel", nil, view)
    local modelSize=kind == "party" and 92 or 75
    view.model:SetSize(modelSize,modelSize)
    view.model:EnableMouse(false)
    view.pedestal = view:CreateTexture(nil,"BACKGROUND")
    view.pedestal:SetTexture(M.path.."Art\\pedestal.tga")
    view.model:SetPoint("BOTTOM",view.pedestal,"BOTTOM",0,kind == "party" and 5 or 6)
    local text = CreateFrame("Frame",nil,view)
    text:SetAllPoints(view)
    text:SetFrameLevel(view.model:GetFrameLevel()+2)
    text:EnableMouse(false)
    view.labels, view.indices = {}, kind == "party" and {1,2,3,4,5,6} or {1,2,3,4,5}
    for _, index in ipairs(view.indices) do view.labels[index]=text:CreateFontString(nil,"OVERLAY") end
    view.dead = text:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    view.dead:SetSize(99,12)
    view.dead:SetPoint("CENTER",view,"CENTER",0,10)
    view.dead:SetText(DEAD)
    view.dead:SetTextColor(1,0,0,1)
    view:SetScript("OnShow",function() view.needsModel=true end)
    view:SetScript("OnEvent",function() view.needsModel=true end)
    for _, event in ipairs({"GROUP_ROSTER_UPDATE","UNIT_PET","UNIT_PORTRAIT_UPDATE","UNIT_ENTERED_VEHICLE","UNIT_EXITED_VEHICLE"}) do view:RegisterEvent(event) end
    local elapsedTime = 0
    view:SetScript("OnUpdate",function(_,elapsed)
        elapsedTime=elapsedTime+elapsed
        if elapsedTime<0.1 then return end
        elapsedTime=0
        Update(view)
    end)
    view:Hide()
    views[#views+1], byOwner[owner] = view, view
    return view
end

local function Style(view, profile, index)
    local g=M.geometry
    if not view.backup then
        view.backup={alphas={},points={},parent=view.owner:GetParent(),
            ownerPoints=RememberPoints(view.owner),width=view.owner:GetWidth(),height=view.owner:GetHeight(),
            hitRect={view.owner:GetHitRectInsets()}}
        for i, region in ipairs(view.regions) do view.backup.alphas[i]=region:GetAlpha() end
        if view.kind == "party" then
            for _, region in ipairs({view.owner.AuraFrameContainer,view.owner.PetFrame,view.owner.ReadyCheck}) do
                if region then view.backup.points[region]=RememberPoints(region) end
            end
        end
    end
    local bounds=view.kind == "party" and g.partyBounds or g.petBounds
    local left,bottom,right,top=bounds.left,bounds.bottom,bounds.right,bounds.top
    -- The strip is outside Blizzard's layout tree. Adding addon layoutIndex
    -- values to that tree taints its later native party updates in Edit Mode.
    -- Blizzard retains the member pool, button attributes and unit updates.
    if view.kind == "party" then view.owner:SetParent(partyStrip) end
    local ownerScale=view.owner:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local scale=profile.scale*g.scale/ownerScale
    view.owner:SetSize((right-left)*scale,(top-bottom)*scale)
    view.owner:SetHitRectInsets(0,0,0,0)
    if view.kind == "party" then
        local pos=g.party[index]
        view.owner:ClearAllPoints()
        view.owner:SetPoint("BOTTOMLEFT",partyStrip,"BOTTOMLEFT",
            (pos.x+left*profile.scale*g.scale-g.partyLeft)/ownerScale,
            (pos.y+bottom*profile.scale*g.scale-g.partyBottom)/ownerScale)
    end
    local references = {["Unit Frame"]=view, ["_HealthBar"]=view.health, ["_ManaBar"]=view.power}
    for index, label in pairs(view.labels) do references["_TextBox_"..index]=label end
    view:SetSize(profile.width,profile.height)
    view:SetScale(scale)
    view.compactText=UIParent:GetHeight()*UIParent:GetEffectiveScale()<800
    view:ClearAllPoints()
    view:SetPoint("BOTTOMLEFT",view.owner,"BOTTOMLEFT",-left,-bottom)
    for index, bar in ipairs({view.health,view.power}) do
        local spec = profile.bars[index]
        P.Position(bar,spec,references)
        bar:SetOrientation(spec.direction == 3 and "VERTICAL" or "HORIZONTAL")
        local color=spec.color or spec.manacolor
        bar:SetStatusBarColor(color.r,color.g,color.b,1)
    end
    for index, label in pairs(view.labels) do
        local spec=profile.TextBox[index]
        if index==2 and view.kind=="party" then spec=M.Copy(spec); spec.height=16 end
        P.Position(label,spec,references)
        P.StyleText(label,spec)
        label:SetAlpha(view.compactText and (index==4 or index==5) and 0 or 1)
    end
    P.Position(view.pedestal,profile.TextBox[10],references)
    view.fittedBounds={left=left,bottom=bottom,right=right,top=top,scale=scale}
    if view.kind == "party" then
        local aura,pet,ready=view.owner.AuraFrameContainer,view.owner.PetFrame,view.owner.ReadyCheck
        if aura then aura:ClearAllPoints(); aura:SetPoint("BOTTOMLEFT",view.owner,"TOPLEFT",0,4) end
        if pet then pet:ClearAllPoints(); pet:SetPoint("BOTTOMLEFT",view.owner,"TOPLEFT",0,22) end
        if ready then ready:ClearAllPoints(); ready:SetPoint("CENTER",view.model,"CENTER",0,0) end
    end
    for _, region in ipairs(view.regions) do region:SetAlpha(0) end
    view.needsModel=true
    view:Show()
end

function M.RestoreGroupFrames()
    active, pending = false, false
    if drawerAlpha~=nil then CompactRaidFrameManager.Background:SetAlpha(drawerAlpha); drawerAlpha=nil end
    for _, view in ipairs(views) do
        view:Hide()
        view.model:ClearModel()
        if view.backup then
            for index, region in ipairs(view.regions) do region:SetAlpha(view.backup.alphas[index]) end
            for region, points in pairs(view.backup.points) do RestorePoints(region,points) end
            if view.backup.hitRect then view.owner:SetHitRectInsets(unpack(view.backup.hitRect)) end
            view.owner:SetParent(view.backup.parent)
            view.owner:SetSize(view.backup.width,view.backup.height)
            RestorePoints(view.owner,view.backup.ownerPoints)
            view.backup=nil
        end
    end
    if partyStrip then UnregisterStateDriver(partyStrip,"visibility"); partyStrip:Hide() end
    if backgroundAlpha then PartyFrame.Background:SetAlpha(backgroundAlpha); backgroundAlpha=nil end
end

local function StripVisibility()
    if not partyStrip or not active then return end
    RegisterStateDriver(partyStrip,"visibility",EditModeManagerFrame:IsShown() and "show"
        or "[group:raid] hide; [group:party] show; hide")
end

local function Apply()
    local profile=M.SelectUnitStyle()
    local candidates={}
    if PetFrame then candidates[#candidates+1]={"pet",PetFrame} end
    if PartyFrame and PartyFrame.GetPartyMemberFrame then
        if not partyStrip then
            partyStrip=CreateFrame("Frame","MazzleUIForeverPartyStrip",UIParent,"SecureHandlerStateTemplate")
            partyStrip:EnableMouse(false)
        end
        local g=M.geometry
        partyStrip:SetSize(g.partyRight-g.partyLeft,g.partyTop-g.partyBottom)
        partyStrip:ClearAllPoints()
        partyStrip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.partyLeft,g.partyBottom)
        StripVisibility()
        if PartyFrame.Background then
            if backgroundAlpha == nil then backgroundAlpha=PartyFrame.Background:GetAlpha() end
            PartyFrame.Background:SetAlpha(0)
        end
        for index=1,4 do
            local owner=PartyFrame:GetPartyMemberFrame(index)
            if owner then candidates[#candidates+1]={"party",owner,index} end
        end
    end
    -- Validate/create all views before hiding native art.
    for _, entry in ipairs(candidates) do if not byOwner[entry[2]] then Create(entry[1],entry[2]) end end
    for _, entry in ipairs(candidates) do Style(byOwner[entry[2]],profile[entry[1]],entry[3]) end
end

local function Resume()
    -- Only child presentation changes here; never save an Edit Mode layout.
    -- Native preview recreates the pool while Edit Mode is open, so it needs
    -- these same anchors immediately instead of four overlapping TOPLEFTs.
    if not pending or scheduled or not active or InCombatLockdown() then return end
    scheduled=true
    C_Timer.After(0,function()
        scheduled=false
        if not pending or not active or InCombatLockdown() then return end
        pending=false
        if not M.Run("Group panels",Apply) then M.RestoreGroupFrames() end
    end)
end

function M.ApplyGroupFrames()
    if not M.db.groupframes then M.RestoreGroupFrames(); return end
    active, pending=true, false
    if not drawerHooked and CompactRaidFrameManager_Expand and CompactRaidFrameManager_Collapse then
        hooksecurefunc("CompactRaidFrameManager_Expand",StyleDrawer)
        hooksecurefunc("CompactRaidFrameManager_Collapse",StyleDrawer)
        drawerHooked=true
    end
    StyleDrawer()
    if not hooked and PartyFrame and PartyFrame.InitializePartyMemberFrames then
        hooksecurefunc(PartyFrame,"InitializePartyMemberFrames",function()
            if active then pending=true; Resume() end
        end)
        hooked=true
    end
    Apply()
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",Resume)
EventRegistry:RegisterCallback("EditMode.Exit",Resume)
EventRegistry:RegisterCallback("EditMode.Enter",StripVisibility)
EventRegistry:RegisterCallback("EditMode.Exit",StripVisibility)
