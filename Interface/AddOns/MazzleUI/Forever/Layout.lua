local _, M = ...

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
M.Copy = Copy

-- Preserve screen offsets when fitting a native pane at a different scale.
-- Edit Mode stores its anchors in UIParent units and applies the same conversion.
function M.ScaleLayoutFrame(frame, scale)
    if frame:GetScale()==scale then return end
    local ratio=frame:GetScale()/scale
    local points={}
    for i=1,frame:GetNumPoints() do points[i]={frame:GetPoint(i)} end
    frame:SetScale(scale)
    frame:ClearAllPoints()
    for _,p in ipairs(points) do frame:SetPoint(p[1],p[2],p[3],p[4]*ratio,p[5]*ratio) end
end

local meterScale, bagsScale
local statusWidths={}
function M.ApplyPanelScaling()
    if DamageMeter then
        if not meterScale then meterScale=DamageMeter:GetScale() end
        M.ScaleLayoutFrame(DamageMeter,M.geometry.meterScale)
    end
end

function M.ApplyStatusPanels()
    if BagsBar then
        if not bagsScale then bagsScale=BagsBar:GetScale() end
        M.ScaleLayoutFrame(BagsBar,math.min(M.geometry.bagsScale,(M.geometry.combatWidth-4)/BagsBar:GetWidth()))
    end
    if not StatusTrackingBarManager then return end
    for _,frame in ipairs(StatusTrackingBarManager.barContainers) do
        if not statusWidths[frame] then statusWidths[frame]=frame:GetWidth() end
        -- Forever's native minimum is half a 1192-unit bar. Fit that baseline
        -- to the pane while retaining the user's Edit Mode width adjustment.
        local key=Enum.EditModeStatusTrackingBarSetting.Size
        local size=frame:HasSetting(key) and frame:GetSettingValue(key) or 50
        frame:SetWidth(M.geometry.sideWidth*size/50)
    end
    StatusTrackingBarManager:CheckForLayoutChange()
end

function M.RestorePanelScaling()
    if meterScale and DamageMeter then M.ScaleLayoutFrame(DamageMeter,meterScale) end
    meterScale=nil
    if bagsScale and BagsBar then M.ScaleLayoutFrame(BagsBar,bagsScale) end
    bagsScale=nil
    for frame,width in pairs(statusWidths) do frame:SetWidth(width) end
    statusWidths={}
    if StatusTrackingBarManager then StatusTrackingBarManager:CheckForLayoutChange() end
end

-- C_EditMode.GetLayouts omits presets, but native SaveLayouts receives the full
-- list. Build a private copy; never write to the live EditModeManagerFrame data.
function M.ReadLayouts()
    local saved = C_EditMode.GetLayouts()
    local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    local result = { activeLayout = saved.activeLayout, layouts = presets }
    for _, layout in ipairs(saved.layouts) do result.layouts[#result.layouts + 1] = Copy(layout) end
    return result
end

local function Find(info, name, kind)
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == name and layout.layoutType == kind then return index end
    end
end

local function Anchor(system, point, relativePoint, x, y)
    system.isInDefaultPosition = false
    system.anchorInfo = { point = point, relativeTo = "UIParent", relativePoint = relativePoint, offsetX = x, offsetY = y }
    system.anchorInfo2 = nil
end

local function Setting(system, enum, name, displayValue)
    local key = enum and enum[name]
    if key == nil then return end
    local map = EditModeSettingDisplayInfoManager:GetSystemSettingDisplayInfoMap(system.system)
    local display = map and map[key]
    local value = displayValue
    if display and display.ConvertValue then value = display:ConvertValue(displayValue, false) end
    for _, item in ipairs(system.settings) do
        if item.setting == key then item.value = value; return end
    end
    system.settings[#system.settings + 1] = { setting = key, value = value }
end

function M.ConfigureLayout(layout)
    local E, U, A = Enum.EditModeSystem, Enum.EditModeUnitFrameSystemIndices, Enum.EditModeActionBarSystemIndices
    local g = M.geometry
    local iconScale, row = g.iconScale, g.actionRow
    for _, system in ipairs(layout.systems) do
        local id, index = system.system, system.systemIndex
        if id == E.ActionBar then
            if index == A.MainBar or index == A.Bar2 or index == A.Bar3 or index == A.RightBar1 then
                local left = index == A.MainBar or index == A.Bar2
                local upper = index == A.Bar2 or index == A.RightBar1
                Anchor(system, left and "BOTTOMRIGHT" or "BOTTOMLEFT", "BOTTOM",
                    left and -g.gap or g.gap, g.actionBottom + (upper and row * g.actionRows or 0))
                Setting(system, Enum.EditModeActionBarSetting, "Orientation", Enum.ActionBarOrientation.Horizontal)
                Setting(system, Enum.EditModeActionBarSetting, "NumRows", g.actionRows)
                Setting(system, Enum.EditModeActionBarSetting, "NumIcons", 12)
                Setting(system, Enum.EditModeActionBarSetting, "IconSize", iconScale * 100)
                Setting(system, Enum.EditModeActionBarSetting, "IconPadding", 2)
                Setting(system, Enum.EditModeActionBarSetting, "HideBarArt", 1)
                Setting(system, Enum.EditModeActionBarSetting, "AlwaysShowButtons", 0)
                Setting(system, Enum.EditModeActionBarSetting, "HideBarScrolling", 0)
            elseif index == A.StanceBar or index == A.PetActionBar or index == A.PossessActionBar then
                local pet=index==A.PetActionBar
                Anchor(system,pet and "BOTTOMLEFT" or "BOTTOMRIGHT","BOTTOM",
                    (pet and 1 or -1)*(g.caveSize/2+24),g.auxiliaryBottom)
            elseif index and index >= 5 and index <= 8 then
                -- Extra user-enabled bars must not retain anchors from another UI.
                Anchor(system, "RIGHT", "RIGHT", -10 - (index - 5) * 36, 0)
                Setting(system, Enum.EditModeActionBarSetting, "Orientation", Enum.ActionBarOrientation.Vertical)
                Setting(system, Enum.EditModeActionBarSetting, "NumRows", 1)
                Setting(system, Enum.EditModeActionBarSetting, "IconSize", 60)
            end
        elseif id == E.Minimap then
            Anchor(system, "BOTTOM", "BOTTOM", 0, g.mapBottom-8)
            Setting(system, Enum.EditModeMinimapSetting, "Size", 50)
        elseif id == E.UnitFrame then
            if index == U.Player then
                local s=M.SelectUnitStyle().player.scale*g.scale
                Anchor(system,"BOTTOMLEFT","BOTTOMLEFT",g.playerX+g.playerBounds.left*s,g.playerY+g.playerBounds.bottom*s)
            elseif index == U.Target then
                if M.db.unitframes then Anchor(system, "TOP", "BOTTOM", 0, g.targetTop)
                else Anchor(system, "BOTTOM", "BOTTOM", 0, g.height + 145 * g.scale) end
            elseif index == U.Pet then
                local pet=M.SelectUnitStyle().pet
                local s=pet.scale*g.scale
                Anchor(system,"BOTTOMLEFT","BOTTOMLEFT",g.petX+g.petBounds.left*s,g.petY+g.petBounds.bottom*s)
            elseif index == U.Focus then Anchor(system, "CENTER", "CENTER", 270, -70)
            elseif index == U.Party then
                if M.db.groupframes then Anchor(system,"TOPLEFT","BOTTOMLEFT",g.partyLeft,g.partyTop)
                else Anchor(system,"TOPLEFT","TOPLEFT",18,-220) end
            elseif index == U.Raid then Anchor(system, "TOPLEFT", "TOPLEFT", 18, -220)
            end
            if index == U.Target then Setting(system, Enum.EditModeUnitFrameSetting, "BuffsOnTop", 1) end
            if (M.db.unitframes and (index == U.Target or index == U.Player))
                or (M.db.groupframes and (index == U.Party or index == U.Pet)) then
                Setting(system, Enum.EditModeUnitFrameSetting, "FrameSize", 100)
            end
        elseif id == E.CastBar then
            Anchor(system, "BOTTOM", "BOTTOM", 0, g.height + 270 * g.scale)
            Setting(system, Enum.EditModeCastBarSetting, "LockToPlayerFrame", 0)
        elseif id == E.ChatFrame and (index == nil or index == 1) then
            Anchor(system, "BOTTOMLEFT", "BOTTOMLEFT", g.chatX, g.chatBottom)
            local width, height = g.chatWidth, g.chatHeight
            Setting(system, Enum.EditModeChatFrameSetting, "WidthHundreds", math.floor(width / 100))
            Setting(system, Enum.EditModeChatFrameSetting, "WidthTensAndOnes", width % 100)
            Setting(system, Enum.EditModeChatFrameSetting, "HeightHundreds", math.floor(height / 100))
            Setting(system, Enum.EditModeChatFrameSetting, "HeightTensAndOnes", height % 100)
        elseif id == E.MicroMenu then
            Anchor(system, "BOTTOMRIGHT", "BOTTOMRIGHT", -g.sideInset, g.menuBottom)
            Setting(system, Enum.EditModeMicroMenuSetting, "Orientation", Enum.MicroMenuOrientation.Horizontal)
            Setting(system, Enum.EditModeMicroMenuSetting, "Size", 70)
        elseif id == E.Bags then
            Anchor(system, "BOTTOMRIGHT", "BOTTOMRIGHT", -g.sideInset, g.bagsBottom)
            Setting(system, Enum.EditModeBagsSetting, "Orientation", Enum.BagsOrientation.Horizontal)
            Setting(system, Enum.EditModeBagsSetting, "Direction", Enum.BagsDirection.Left)
            Setting(system, Enum.EditModeBagsSetting, "Size", 75)
            Setting(system, Enum.EditModeBagsSetting, "BagSlotPadding", 2)
        elseif id == E.AuraFrame then
            local aura=Enum.EditModeAuraFrameSystemIndices
            if index==aura.BuffFrame or index==aura.DebuffFrame then
                Anchor(system,"BOTTOMLEFT","BOTTOMLEFT",g.sideInset,index==aura.BuffFrame and g.buffBottom or g.debuffBottom)
                Setting(system,Enum.EditModeAuraFrameSetting,"Orientation",Enum.AuraFrameOrientation.Horizontal)
                Setting(system,Enum.EditModeAuraFrameSetting,"IconDirection",Enum.AuraFrameIconDirection.Right)
                Setting(system,Enum.EditModeAuraFrameSetting,"IconWrap",Enum.AuraFrameIconDirection.Up)
                Setting(system,Enum.EditModeAuraFrameSetting,"IconSize",90)
                Setting(system,Enum.EditModeAuraFrameSetting,"IconPadding",5)
                Setting(system,Enum.EditModeAuraFrameSetting,index==aura.BuffFrame and "IconLimitBuffFrame" or "IconLimitDebuffFrame",8)
            end
        elseif id == E.StatusTrackingBar then
            Anchor(system, "BOTTOMRIGHT", "BOTTOMRIGHT", -g.sideInset, g.statusBottom+((index or 1)-1)*18)
            Setting(system, Enum.EditModeStatusTrackingBarSetting, "Size", 50)
        elseif id == E.ObjectiveTracker then
            Anchor(system, "TOPRIGHT", "TOPRIGHT", -166, -120)
            Setting(system, Enum.EditModeObjectiveTrackerSetting, "Height",
                math.max(400, math.min(1000, math.floor((UIParent:GetHeight() - g.height - 240) / 10) * 10)))
        elseif id == E.DamageMeter then
            Anchor(system, "BOTTOMRIGHT", "BOTTOMRIGHT", -g.sideInset, g.meterBottom)
            Setting(system, Enum.EditModeDamageMeterSetting, "FrameWidth", g.meterWidth)
            Setting(system, Enum.EditModeDamageMeterSetting, "FrameHeight", g.meterHeight)
            Setting(system, Enum.EditModeDamageMeterSetting, "Visibility", Enum.DamageMeterVisibility.Hidden)
            Setting(system, Enum.EditModeDamageMeterSetting, "Style", Enum.DamageMeterStyle.Thin)
            Setting(system, Enum.EditModeDamageMeterSetting, "BackgroundTransparency", 0)
            Setting(system, Enum.EditModeDamageMeterSetting, "BarHeight", 18)
            Setting(system, Enum.EditModeDamageMeterSetting, "Padding", 2)
            Setting(system, Enum.EditModeDamageMeterSetting, "TextSize", math.max(100,math.min(150,math.ceil(9/(12*UIParent:GetEffectiveScale()*g.meterScale)*10)*10)))
        elseif id == E.GroupFinder then Anchor(system, "BOTTOM", "BOTTOM", 0, g.height + 10)
        elseif id == E.MainActionBarEndCap then Setting(system, Enum.EditModeMainActionBarEndCapSetting, "Hidden", 1)
        end
    end
end

-- Advance this only when generated native layout geometry needs a migration.
-- Cosmetic updates and ordinary login must retain the user's Edit Mode changes.
local layoutRevision = 6
local function LayoutInputs()
    return {revision=layoutRevision, width=UIParent:GetWidth(), height=UIParent:GetHeight(),
        scale=M.db.scale, unitframes=M.db.unitframes,groupframes=M.db.groupframes}
end

local function InputsChanged(current, previous)
    if type(previous) ~= "table" then return true end
    for key, value in pairs(current) do if previous[key] ~= value then return true end end
    return false
end

function M.ApplyNativeLayout(reset)
    if not M.SafeToLayout() then return false end
    if not EditModeManagerFrame or not EditModeManagerFrame:IsInitialized() then
        M.Print("Edit Mode is not ready. Use /mazzle apply once the world has loaded.")
        return false
    end
    local info = M.ReadLayouts()
    local kind = Enum.EditModeLayoutType.Character
    local index = M.character.layoutName and Find(info, M.character.layoutName, kind)
    local added = not index
    if added then
        local count = 0
        for _, layout in ipairs(info.layouts) do if layout.layoutType == kind then count = count + 1 end end
        if count >= Constants.EditModeConsts.EditModeMaxLayoutsPerType then
            M.Print("Your character Edit Mode layouts are full. Free one slot, then /mazzle apply.")
            return false
        end
        local active = info.layouts[info.activeLayout]
        if not active then M.Print("No active Edit Mode layout is available."); return false end
        M.character.previousLayout = { name = active.layoutName, kind = active.layoutType }
        local name, number = "MazzleUI", 1
        while Find(info, name, kind) do number = number + 1; name = "MazzleUI " .. number end
        local layout = EditModePresetLayoutManager:GetCopyOfPresetLayouts()[1]
        layout.layoutName, layout.layoutType, layout.layoutIndex = name, kind, nil
        index = #info.layouts + 1
        info.layouts[index] = layout
        M.character.layoutName = name
    end
    local inputs = LayoutInputs()
    local rebuild = added or reset or InputsChanged(inputs, M.character.layoutInputs)
    local activate = info.activeLayout ~= index
    if rebuild then
        -- Generate from a native preset when geometry changes or the user asks
        -- to reset positions. Never import another UI's external frame anchors.
        local name = info.layouts[index].layoutName
        info.layouts[index] = EditModePresetLayoutManager:GetCopyOfPresetLayouts()[1]
        info.layouts[index].layoutName, info.layouts[index].layoutType, info.layouts[index].layoutIndex = name, kind, nil
        M.ConfigureLayout(info.layouts[index])
        C_EditMode.SaveLayouts(info)
        M.character.layoutInputs = inputs
    end
    if added then C_EditMode.OnLayoutAdded(index, true, false)
    elseif rebuild or activate then C_EditMode.SetActiveLayout(index) end
    M.character.barSettings = M.character.barSettings or {}
    for number = 2, 4 do
        local key = "PROXY_SHOW_ACTIONBAR_" .. number
        if Settings.GetSetting(key) then
            if M.character.barSettings[key] == nil then M.character.barSettings[key] = Settings.GetValue(key) end
            if (rebuild or activate) and Settings.GetValue(key) ~= true then Settings.SetValue(key, true) end
        end
    end
    if FCF_SelectDockFrame and ChatFrame1 then
        if not M.character.selectedChat and SELECTED_DOCK_FRAME then
            M.character.selectedChat = SELECTED_DOCK_FRAME:GetID()
        end
        if rebuild or activate then FCF_SelectDockFrame(ChatFrame1) end
    end
    M.character.lastLayout = { width = UIParent:GetWidth(), height = UIParent:GetHeight(),
        geometry = Copy(M.geometry), systems = Copy(info.layouts[index].systems) }
    return true
end

function M.RestoreNativeLayout()
    local previous = M.character.previousLayout
    if type(previous) == "table" then
        local index = Find(M.ReadLayouts(), previous.name, previous.kind)
        if index then C_EditMode.SetActiveLayout(index)
        else M.Print("Your previous Edit Mode layout was removed; select another in Edit Mode.") end
    end
    if type(M.character.barSettings) == "table" then
        for key, value in pairs(M.character.barSettings) do
            if Settings.GetSetting(key) then Settings.SetValue(key, value) end
        end
    end
    if M.character.selectedChat and FCF_SelectDockFrame then
        local frame = _G["ChatFrame" .. M.character.selectedChat]
        if frame and frame.isDocked then FCF_SelectDockFrame(frame) end
    end
end
