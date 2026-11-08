local _, M = ...
local root, panels, cave, model, portrait, menu, mapBorder
local worldPoints
local mapBackup, mapHooked
local mapPieces={}

local function SaveMapPiece(frame)
    if not frame or mapPieces[frame] then return end
    local saved={points={},scale=frame.GetScale and frame:GetScale(),ignore=frame.ignoreInLayout,
        width=frame:GetWidth(),height=frame:GetHeight()}
    for i=1,frame:GetNumPoints() do saved.points[i]={frame:GetPoint(i)} end
    if frame.GetFont then saved.font={frame:GetFont()}; saved.justify=frame:GetJustifyH() end
    if frame.CanWordWrap then saved.wrap=frame:CanWordWrap(); saved.nonspace=frame:CanNonSpaceWrap() end
    mapPieces[frame]=saved
end

local function MapPiece(frame,point,relative,relativePoint,x,y,scale,width,height)
    if not frame then return end
    SaveMapPiece(frame)
    local parentScale=frame:GetParent():GetEffectiveScale()/UIParent:GetEffectiveScale()
    frame.ignoreInLayout=true
    frame:SetScale(scale/parentScale)
    frame:ClearAllPoints()
    frame:SetPoint(point,relative,relativePoint,x/scale,y/scale)
    if width then frame:SetSize(width/scale,height/scale) end
end

local function MapFont(text,parent,width,height,minimum)
    if not text then return end
    SaveMapPiece(text)
    local font,_,flags=unpack(mapPieces[text].font)
    text:SetFont(font,minimum/parent:GetEffectiveScale(),flags)
    text:ClearAllPoints()
    text:SetPoint("CENTER",parent,"CENTER",0,0)
    text:SetSize(width,height)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
end

local function LayoutMapControls()
    local g=M.geometry
    local zone=MinimapCluster.ZoneTextButton
    local labelHeight=math.max(14,10/UIParent:GetEffectiveScale())
    MapPiece(zone,"TOP",Minimap,"TOP",0,-2,1,g.mapSize-4,labelHeight)
    if zone then
        MapFont(MinimapZoneText,zone,g.mapSize-8,labelHeight,8)
        for _,texture in pairs({zone.StateTexture,zone.AddTexture}) do
            SaveMapPiece(texture)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER",zone,"CENTER",0,0)
            texture:SetSize(g.mapSize-4,labelHeight)
        end
    end
    -- Native buttons keep their click handlers, notifications and tooltips.
    MapPiece(MinimapCluster.Tracking,"RIGHT",Minimap,"TOPLEFT",-3,-10,0.85)
    MapPiece(GameTimeFrame,"LEFT",Minimap,"TOPRIGHT",3,-10,0.7)
    MapPiece(MinimapCluster.IndicatorFrame,"RIGHT",Minimap,"LEFT",-3,0,0.8)
    MapPiece(AddonCompartmentFrame,"LEFT",Minimap,"RIGHT",3,0,0.7)
    MapPiece(MinimapCluster.InstanceDifficulty,"RIGHT",Minimap,"BOTTOMLEFT",-3,10,0.7)
    local coords=MinimapCluster.MinimapContainer.PlayerCoords
    MapPiece(coords,"BOTTOM",Minimap,"BOTTOM",0,2,1,g.mapSize-4,labelHeight)
    if coords then MapFont(coords.CoordText,coords,g.mapSize-4,labelHeight,7) end
    -- This optional native clock has its own visibility preference. Give it
    -- room rather than stacking it on the now compact location label.
    MapPiece(TimeManagerClockButton,"TOPRIGHT",UIParent,"TOPRIGHT",-12,-8,1,80,20)
    if TimeManagerClockButton and TimeManagerClockTicker then
        MapFont(TimeManagerClockTicker,TimeManagerClockButton,80,20,8)
    end
end

local function RestoreMapControls()
    for frame,saved in pairs(mapPieces) do
        if saved.scale then frame:SetScale(saved.scale) end
        frame.ignoreInLayout=saved.ignore
        frame:ClearAllPoints()
        for _,p in ipairs(saved.points) do frame:SetPoint(unpack(p)) end
        frame:SetSize(saved.width,saved.height)
        if saved.font then frame:SetFont(unpack(saved.font)); frame:SetJustifyH(saved.justify) end
        if saved.wrap~=nil then frame:SetWordWrap(saved.wrap); frame:SetNonSpaceWrap(saved.nonspace) end
    end
    mapPieces={}
end

local function Position(object, point, relative, relativePoint, x, y, width, height)
    object:ClearAllPoints()
    object:SetPoint(point, relative, relativePoint, x, y)
    if width then object:SetSize(width, height) end
end

function M.RefreshModel()
    if not model then return end
    cave:SetShown(UnitExists("target"))
    -- Identity may be restricted even when a unit exists. Never send a restricted
    -- identity to PlayerModel, or cache a previous target's model after changing.
    if not M.db.models or not UnitExists("target")
        or (C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret("target")) then
        model:ClearModel()
        return
    end
    model:SetUnit("target")
    model:SetPortraitZoom(0)
    model:SetPosition(0, 0, 0)
end

function M.CreateArt()
    root = CreateFrame("Frame", "MazzleUIForeverArt", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("BACKGROUND")
    root:EnableMouse(false)
    panels = {}
    for index = 1, 4 do panels[index] = root:CreateTexture(nil, "BACKGROUND") end
    cave = root:CreateTexture(nil, "ARTWORK")
    -- The target remains clickable through a native secure unit button.
    portrait = CreateFrame("Button", "MazzleUIForeverPortrait", UIParent, "SecureUnitButtonTemplate")
    portrait:RegisterForClicks("AnyUp")
    portrait:SetAttribute("unit", "target")
    portrait:SetAttribute("type1", "target")
    portrait:SetAttribute("type2", "togglemenu")
    RegisterUnitWatch(portrait)
    model = CreateFrame("PlayerModel", nil, portrait)
    model:SetAllPoints(portrait)
    model:EnableMouse(false)
    portrait:SetScript("OnEvent", M.RefreshModel)
    for _, event in ipairs({"PLAYER_TARGET_CHANGED", "UNIT_PORTRAIT_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
        portrait:RegisterEvent(event)
    end
    menu = CreateFrame("Button", "MazzleUIForeverOptionsButton", UIParent)
    menu:SetNormalTexture(M.path .. "Art\\MazzleUI_Options.blp")
    menu:SetHighlightTexture(M.path .. "Art\\ButtonHighlight.tga")
    menu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    menu:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if M.SafeToLayout() then ReloadUI() else M.Print("Reload after combat and Edit Mode.") end
        else M.OpenOptions() end
    end)
    menu:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("MazzleUI - left-click settings, right-click reload")
        GameTooltip:Show()
    end)
    menu:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Keep the native minimap's controls, tracking, mail and calendar.
    local borderFrame = CreateFrame("Frame", nil, Minimap)
    borderFrame:SetAllPoints(Minimap)
    borderFrame:EnableMouse(false)
    mapBorder = borderFrame:CreateTexture(nil, "OVERLAY")
    -- These original atlases place the map at (101,36)-(232,164), rather
    -- than in the middle of the image. Keep decorative overhangs on all skins.
    mapBorder:SetPoint("CENTER", Minimap, "CENTER", (128-166.5)*198/131, (100-128)*198/128)
    mapBorder:SetSize(256*198/131, 256*198/128)
end

function M.LayoutArt()
    -- Original CreatePanel used 470px outer panels and 238px height at 1200px
    -- reference height. Stretch only the two middle panels on wider displays.
    local width, height = UIParent:GetSize()
    M.geometry = M.ComputeGeometry(width,height)
    local scale, edge, panelHeight = M.geometry.scale, M.geometry.edge, M.geometry.height
    local middle = (width - edge * 2) / 2
    local skin = M.skins[M.db.skin]
    local x = 0
    for index, key in ipairs({"l", "ml", "mr", "r"}) do
        local panelWidth = (index == 1 or index == 4) and edge or middle
        panels[index]:SetTexture(skin[key])
        Position(panels[index], "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0, panelWidth, panelHeight)
        x = x + panelWidth
    end
    local caveSize, caveY = M.geometry.caveSize, M.geometry.caveY
    cave:SetTexture(skin.cave)
    Position(cave, "BOTTOM", UIParent, "BOTTOM", 0, caveY, caveSize, caveSize)
    local targetScale = M.SelectUnitStyle().target.scale*scale
    local labelHeight=math.max(12*targetScale,7/UIParent:GetEffectiveScale()+2*targetScale)
    local modelBottom=math.max(131*targetScale,115*targetScale+2*labelHeight+3*targetScale)
    local modelHeight=math.min(120*targetScale,caveY+caveSize*(1-73/256)-modelBottom)
    Position(portrait, "BOTTOM", UIParent, "BOTTOM", 0, modelBottom, 120*targetScale, math.max(40*scale,modelHeight))
    Position(menu, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        -M.geometry.sideInset,M.geometry.height-10*scale-M.geometry.infoLine,18,18)
    mapBorder:SetTexture(skin.mapborder)
    M.RefreshModel()
    M.LayoutHUD()
end

function M.ApplyMinimap()
    local container = MinimapCluster.MinimapContainer
    if not mapBackup then
        mapBackup = {ignore=container.ignoreInLayout, border=MinimapCompassTexture:GetAlpha(),
            underlay=MinimapCompassTextureUnderlay:GetAlpha()}
    end
    -- Keep map, location and native utility controls in one bottom-center area.
    container.ignoreInLayout = true
    container:SetScale(M.geometry.mapSize/198)
    container:ClearAllPoints()
    container:SetPoint("CENTER",UIParent,"BOTTOM",0,
        (M.geometry.mapBottom+M.geometry.mapSize/2)/(M.geometry.mapSize/198))
    Minimap:SetMaskTexture(M.path.."Art\\MazzleUIMinimapMask.blp")
    MinimapCompassTexture:SetAlpha(0)
    MinimapCompassTextureUnderlay:SetAlpha(0)
    LayoutMapControls()
    if not mapHooked then
        hooksecurefunc(MinimapCluster,"UpdateMinimapConfig",function()
            if mapBackup and M.character.enabled then M.RequestLayout() end
        end)
        mapHooked=true
    end
end

function M.RestoreMinimap()
    if not mapBackup then return end
    local backup=mapBackup
    mapBackup=nil
    RestoreMapControls()
    MinimapCluster.MinimapContainer.ignoreInLayout=backup.ignore
    MinimapCompassTexture:SetAlpha(backup.border)
    MinimapCompassTextureUnderlay:SetAlpha(backup.underlay)
    MinimapCluster:UpdateMinimapConfig()
    MinimapCluster:UpdateSystemSettingSize()
end

EventRegistry:RegisterCallback("EditMode.Exit",function()
    if mapBackup and M.character.enabled then M.RequestLayout() end
end)

function M.ShowArt(shown)
    if not root then return end
    root:SetShown(shown)
    menu:SetShown(shown)
    mapBorder:SetShown(shown)
    if not shown then M.RestoreMinimap() end
    if shown and M.db.models then
        RegisterUnitWatch(portrait)
    else
        UnregisterUnitWatch(portrait)
        portrait:Hide()
        model:ClearModel()
    end
    M.SetHUDShown(shown and M.db.hud)
    M.SetContextShown(shown and M.db.context)
end

function M.ApplyViewport()
    if not M.db.viewport then M.RestoreViewport(); return end
    if not worldPoints then
        worldPoints = {}
        for index = 1, WorldFrame:GetNumPoints() do worldPoints[index] = {WorldFrame:GetPoint(index)} end
    end
    WorldFrame:ClearAllPoints()
    WorldFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    WorldFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 147 * M.geometry.scale)
end

function M.RestoreViewport()
    if not worldPoints then return end
    WorldFrame:ClearAllPoints()
    for _, point in ipairs(worldPoints) do WorldFrame:SetPoint(unpack(point)) end
    worldPoints = nil
end

-- Alt-Z must restore the scene instead of leaving an empty strip in screenshots.
UIParent:HookScript("OnHide", function() if M.SafeToLayout() then M.RestoreViewport() end end)
UIParent:HookScript("OnShow", function() if M.created and M.character.enabled then M.RequestLayout() end end)
