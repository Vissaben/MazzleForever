local _, M = ...
local presentation={}
local logChrome, chromeParents

local function Style(frame,scale,minimum)
    local saved=presentation[frame]
    if not saved then
        saved={scale=frame:GetScale(),font={frame:GetFont()},buttonSide=frame.buttonSide,
            inputFont=frame.editBox and {frame.editBox:GetFont()}}
        presentation[frame]=saved
    end
    M.ScaleLayoutFrame(frame,scale or M.geometry.chatScale)
    local font,size,flags=unpack(saved.font)
    frame:SetFont(font,math.max(size,(minimum or 9)/frame:GetEffectiveScale()),flags)
    if saved.inputFont then
        local path,height,outline=unpack(saved.inputFont)
        frame.editBox:SetFont(path,math.max(height,9/frame.editBox:GetEffectiveScale()),outline)
    end
    -- Reserve a real gutter for the native menu/social buttons. Their old
    -- negative anchors were being pushed off the left edge of the screen.
    FCF_SetButtonSide(frame,"left",true)
end

local function RestorePresentation()
    for frame,saved in pairs(presentation) do
        M.ScaleLayoutFrame(frame,saved.scale)
        frame:SetFont(unpack(saved.font))
        if saved.inputFont then frame.editBox:SetFont(unpack(saved.inputFont)) end
        if saved.buttonSide then FCF_SetButtonSide(frame,saved.buttonSide,true) end
    end
    presentation={}
end

local function WindowInfo(id)
    local name, _, _, _, _, _, shown, locked, docked, uninteractable = FCF_GetChatWindowInfo(id)
    return {name=name, shown=shown == true or shown == 1, locked=locked == true or locked == 1,
        docked=docked == true or docked == 1, uninteractable=uninteractable == true or uninteractable == 1}
end

local function Placement(frame,info)
    local id=frame:GetID()
    local point,x,y=GetChatWindowSavedPosition(id)
    local width,height=GetChatWindowSavedDimensions(id)
    if not point then point,x,y="BOTTOMLEFT",frame:GetLeft()/GetScreenWidth(),frame:GetBottom()/GetScreenHeight() end
    return {name=info.name,point=point,x=x,y=y,width=width or frame:GetWidth(),height=height or frame:GetHeight()}
end

local function ApplyCombatLog(backup)
    if CombatLog_LoadUI then CombatLog_LoadUI() end
    local frame=COMBATLOG
    if not frame then return end
    local id=frame:GetID()
    if not M.character.combatLog then
        -- Upgrade preview 6's dock without losing the pre-MazzleUI placement.
        local old=backup.changed[id]
        local current=WindowInfo(id)
        local info=backup.windows[id] and backup.windows[id].name==current.name and backup.windows[id] or current
        M.character.combatLog={info=M.Copy(info),placement=old and M.Copy(old) or Placement(frame,info)}
        for index,other in ipairs(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) do
            if other==frame then M.character.combatLog.dockIndex=index end
        end
        backup.changed[id]=nil
    end
    FCF_UnDockFrame(frame)
    SetChatWindowShown(id,true)
    FCF_CheckShowChatFrame(frame)
    FCF_SetLocked(frame,true)
    local g=M.geometry
    Style(frame,g.combatScale,g.logFont*UIParent:GetEffectiveScale())
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-g.sideInset/g.combatScale,g.logBottom/g.combatScale)
    frame:SetSize(g.combatWidth/g.combatScale,(g.logHeight-g.logHeader)/g.combatScale)
    -- Keep native rendering, filters and mouse-wheel scrolling. Its full-size
    -- tab/quick-filter controls are replaced by the compact header's native menu.
    if not logChrome then logChrome=CreateFrame("Frame",nil,UIParent); logChrome:Hide() end
    chromeParents=chromeParents or {}
    for _,object in pairs({_G[frame:GetName().."Tab"],frame.buttonFrame}) do
        if not chromeParents[object] then chromeParents[object]=object:GetParent() end
        object:SetParent(logChrome)
    end
end

local function RestoreCombatLog()
    for object,parent in pairs(chromeParents or {}) do object:SetParent(parent) end
    chromeParents=nil
    local saved=M.character.combatLog
    if not saved then return end
    local frame=COMBATLOG
    if frame and WindowInfo(frame:GetID()).name==saved.info.name then
        local id,p=frame:GetID(),saved.placement
        FCF_UnDockFrame(frame)
        SetChatWindowSavedPosition(id,p.point,p.x,p.y)
        SetChatWindowSavedDimensions(id,p.width,p.height)
        FCF_RestorePositionAndDimensions(frame)
        if saved.info.docked then FCF_DockFrame(frame,saved.dockIndex,false) end
        SetChatWindowShown(id,saved.info.shown); FCF_CheckShowChatFrame(frame)
        FCF_SetLocked(frame,saved.info.locked)
        FCF_SetUninteractable(frame,saved.info.uninteractable)
    end
    M.character.combatLog=nil
end

function M.ApplyChat()
    if not M.db.chatdock then M.RestoreChat(); return end
    local backup = M.character.chatDock
    if not backup then
        backup = {windows={}, changed={}}
        M.character.chatDock = backup
    end
    -- Keep every window's filters, name and contents. Only ordinary persistent
    -- windows participate; temporary whisper windows remain native-managed.
    for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local frame = _G["ChatFrame" .. id]
        if frame and frame~=COMBATLOG and not frame.isTemporary then
            local info = WindowInfo(id)
            if not backup.windows[id] and (info.shown or info.docked or id == 1) then
                backup.windows[id] = info
            end
            if id > 1 and info.shown and not frame.isDocked then
                if not backup.changed[id] then
                    local point, x, y = GetChatWindowSavedPosition(id)
                    local width, height = GetChatWindowSavedDimensions(id)
                    if not point then
                        point, x, y = "BOTTOMLEFT", frame:GetLeft() / GetScreenWidth(), frame:GetBottom() / GetScreenHeight()
                    end
                    backup.changed[id] = {name=info.name, point=point, x=x, y=y,
                        width=width or frame:GetWidth(), height=height or frame:GetHeight()}
                end
                FCF_DockFrame(frame, nil, false)
            end
            if id==1 or frame.isDocked then Style(frame) end
        end
    end
    ApplyCombatLog(backup)
    if ChatFrame1 and ChatFrame1.isDocked then FCF_SelectDockFrame(ChatFrame1) end
end

function M.RestoreChat()
    RestorePresentation()
    RestoreCombatLog()
    local backup = M.character.chatDock
    if not backup then return end
    for id, placement in pairs(backup.changed) do
        local frame = _G["ChatFrame" .. id]
        if frame and not frame.isTemporary and WindowInfo(id).name == placement.name then
            FCF_UnDockFrame(frame)
            SetChatWindowSavedPosition(id, placement.point, placement.x, placement.y)
            SetChatWindowSavedDimensions(id, placement.width, placement.height)
            FCF_RestorePositionAndDimensions(frame)
            local original = backup.windows[id]
            if original then SetChatWindowShown(id, original.shown); FCF_CheckShowChatFrame(frame) end
        end
    end
    -- Docking can harmonize the entire dock's click-through flags. Restore all
    -- original flags after removing our additions; leave renamed/reused IDs alone.
    for id, original in pairs(backup.windows) do
        local frame = _G["ChatFrame" .. id]
        if frame and not frame.isTemporary and WindowInfo(id).name == original.name then
            FCF_SetLocked(frame, original.locked)
            FCF_SetUninteractable(frame, original.uninteractable)
        end
    end
    M.character.chatDock = nil
end
