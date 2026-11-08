"""Independent offline tests for this MazzleUI port, not a WoW secure emulator."""
from pathlib import Path
from zipfile import ZipFile
import copy
import re
import sys
from original_profiles import original_profile, plain, literal

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".validation/python"))
from PIL import Image
from lupa.lua51 import LuaRuntime

ADDON = ROOT / "Interface/AddOns/MazzleUI"
REFERENCE = ROOT / ".validation/wow-ui-source/Interface/AddOns"
TOC = ADDON / "MazzleUI_Camelot.toc"
SOURCES = [line.replace("\\", "/") for line in TOC.read_text().splitlines() if line and not line.startswith("#")]

STUBS = r'''
combat, editing, saves, openCategory = false, false, 0, nil
frames, timers, messages, errors = {}, {}, {}, {}
MazzleUIForeverCharacter={enabled=true}
function InCombatLockdown() return combat end
function print(message) table.insert(messages, message) end
function GetBuildInfo() return '1.60.1','70862','',16001 end
function geterrorhandler() return function(message) table.insert(errors,message) end end
function UnitExists() return true end
function UnitHealth() return health end
function UnitHealthMax() return maximum end
function UnitHealthPercent() return health end
function UnitPower() return health end
function UnitPowerMax() return maximum end
function UnitPowerPercent() return health end
function UnitName() return 'Test unit' end
function UnitIsPlayer() return true end
function UnitClass() return 'Shaman','SHAMAN' end
function UnitCreatureType() return 'Humanoid' end
function UnitLevel() return health end
function UnitIsDeadOrGhost() return health end
DEAD='Dead'
function issecretvalue(value) return type(value)=='table' and getmetatable(value)~=nil end
function SecureButton_GetUnit(frame) return frame.attributes.unit end
CurveConstants={ScaleTo100={}}
function ToggleQuestLog() end
function GetGameTime() return 17,48 end
function GetFramerate() return 60 end
function GetNetStats() return 0,0,35,40 end
function GetMoney() return 12345 end
function UpdateAddOnMemoryUsage() memoryReads=(memoryReads or 0)+1 end
function GetAddOnMemoryUsage() return 1024 end
function AbbreviateLargeNumbers(value) return value end
NUM_BAG_SLOTS=4
C_Container={GetContainerNumFreeSlots=function() return 2,0 end,GetContainerNumSlots=function() return 8 end}
C_AddOns={GetNumAddOns=function() return 2 end,LoadAddOn=function() end}
C_DamageMeter={IsDamageMeterAvailable=function() return true end,
    GetCombatSessionFromType=function() return damageSession or {combatSources={}} end}
local function safe() assert(not combat or restricted, 'protected mutation in combat') end
local methods = {}
function methods:SetAttribute(k,v) safe(); self.attributes[k]=v end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:SetID(id) safe(); self.id=id end
function methods:GetID() return self.id or 0 end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) safe(); self.parent=parent end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameRef(key,value)
    safe(); assert(self.template and self.template:match('SecureHandler[^,]*$'), 'secure OnLoad overridden by a later template')
    self.refs=self.refs or {}; self.refs[key]=value
end
function methods:GetFrameRef(key) return self.refs[key] end
function methods:UpdateHotkeys() end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:EnableMouseWheel(value) self.mouseWheel=value end
function methods:SetPoint(...) safe(); self.points[#self.points+1]={...} end
function methods:GetPoint(i) return unpack(self.points[i or 1]) end
function methods:GetNumPoints() return #self.points end
function methods:ClearAllPoints() safe(); self.points={} end
function methods:SetSize(w,h) safe(); assert(w>0 and h>0); self.w=w; self.h=h end
function methods:SetWidth(w) self.w=w end
function methods:SetHeight(h) self.h=h end
function methods:SetJustifyH() end
function methods:GetJustifyH() return 'LEFT' end
function methods:SetWordWrap() end
function methods:SetNonSpaceWrap() end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:GetSize() return self.w,self.h end
function methods:GetWidth() return self.w end
function methods:GetHeight() return self.h end
function methods:GetLeft() return self.points[1] and self.points[1][4] or 0 end
function methods:GetBottom() return self.points[1] and self.points[1][5] or 0 end
function methods:SetAllPoints(relative) safe(); self.relative=relative end
function methods:SetScale(scale) safe(); self.scale=scale end
function methods:SetFrameStrata() safe() end
function methods:SetFrameLevel(level) safe(); self.level=level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:EnableMouse() safe() end
function methods:RegisterForClicks() safe() end
function methods:SetAlpha(a) self.alpha=a end
function methods:GetAlpha() if self.alpha~=nil then return self.alpha end; return 1 end
function methods:SetHitRectInsets(...) safe(); self.hitRect={...} end
function methods:GetHitRectInsets() return unpack(self.hitRect or {0,0,0,0}) end
function methods:SetAlphaFromBoolean(value,yes,no) self.alpha=value and yes or no end
function methods:IsIgnoringParentAlpha() return self.ignoreParentAlpha or false end
function methods:SetIgnoreParentAlpha(value) safe(); self.ignoreParentAlpha=value end
function methods:SetShown(v) safe(); self.shown=v end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown ~= false end
function methods:SetTexture(path) self.texturePath=path end
function methods:SetMaskTexture(path) self.maskPath=path end
function methods:SetColorTexture() end
function methods:SetTexCoord(...) self.crop={...} end
function methods:SetVertexColor() end
function methods:SetNormalTexture(path) self.texturePath=path end
function methods:SetHighlightTexture() end
function methods:SetOrientation() end
function methods:SetRotatesTexture() end
function methods:SetStatusBarColor() end
function methods:SetStatusBarTexture(path) self.texture=self:CreateTexture(); self.texture:SetTexture(path) end
function methods:GetStatusBarTexture() return self.texture end
function methods:AddMaskTexture(mask) self.mask=mask end
function methods:SetMinMaxValues(a,b) self.min=a; self.max=b end
function methods:SetValue(value) self.value=value end
function methods:SetText(value)
    assert(self.kind~='FontString' or self.font,'FontString:SetText(): Font not set')
    self.text=value
end
function methods:GetText() return self.text end
function methods:SetFont(path,size,flags) self.font={path,size,flags}; self.fontInherited=nil end
function methods:GetFont() return unpack(self.font or {'Fonts\\FRIZQT__.TTF',14,''}) end
function methods:SetTextColor(...) self.color={...} end
function methods:SetFormattedText(format,...)
    assert(self.kind~='FontString' or self.font,'FontString:SetFormattedText(): Font not set')
    self.text=(...); self.arguments={...}; self.format=format
end
function methods:SetUnit(unit) assert(not identitySecret); self.unit=unit end
function methods:ClearModel() self.unit=nil end
function methods:SetPortraitZoom() end
function methods:SetPosition() end
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn) self.scripts[event]=fn end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:RegisterUnitEvent(event,unit) self.events[event]=unit end
function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
function methods:CreateMaskTexture() return CreateFrame('Mask',nil,self) end
function methods:CreateFontString(name,layer,template)
    local text=CreateFrame('FontString',name,self)
    if template then text.font={'Fonts\\FRIZQT__.TTF',14,''}; text.fontInherited=true end
    return text
end
function CreateFrame(kind,name,parent,template)
    safe()
    local frame=setmetatable({kind=kind,name=name,parent=parent,template=template,points={},attributes={},events={},scripts={}}, {__index=methods})
    if name then _G[name]=frame end
    table.insert(frames,frame)
    return frame
end
function RegisterUnitWatch(frame) safe(); assert(frame.attributes.unit,'unit must precede watch'); frame.watched=true end
function UnregisterUnitWatch(frame) safe(); frame.watched=false end
function RegisterStateDriver(frame,state,condition) safe(); frame.stateDriver=condition; frame:Show() end
function UnregisterStateDriver(frame,state) safe(); frame.stateDriver=nil end
function SecureHandlerWrapScript(frame,event,header,snippet)
    safe(); frame.wraps=frame.wraps or {}; frame.wraps[event]={header=header,snippet=snippet}
end
function hooksecurefunc(object,key,callback)
    local original=object[key]
    object[key]=function(...)
        local results={original(...)}
        callback(...)
        return unpack(results)
    end
end
function secureSnippet(frame,event,offset)
    local wrap=frame.wraps and frame.wraps[event]
    local snippet=wrap and wrap.snippet or frame.attributes._onclick
    assert(snippet)
    local env={self=frame,control=wrap and wrap.header or frame,offset=offset,button='LeftButton',down=false}
    local fn=assert(loadstring(snippet)); setfenv(fn,env)
    restricted=true; local ok,err=pcall(fn); restricted=false; assert(ok,err)
end
function fire(event,...)
    local count=#frames
    for i=1,count do local f=frames[i]; if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
function flush()
    local count=0
    while #timers>0 do count=count+1; assert(count<10,'unbounded layout'); table.remove(timers,1)() end
    assert(#errors==0,table.concat(errors,'\n'))
end
C_Timer={After=function(_,fn) table.insert(timers,fn) end}
C_Secrets={ShouldUnitIdentityBeSecret=function() return identitySecret==true end}
SlashCmdList={}
EventRegistry={callbacks={}}
function EventRegistry:RegisterCallback(event,fn,owner)
    self.callbacks[event]=self.callbacks[event] or {}
    table.insert(self.callbacks[event],function(...) return fn(owner,...) end)
    self[event]=function(...) for _,callback in ipairs(self.callbacks[event]) do callback(...) end end
end
UIParent=CreateFrame('Frame','UIParent'); UIParent:SetSize(1920,1200)
WorldFrame=CreateFrame('Frame','WorldFrame'); WorldFrame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',0,0); WorldFrame:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',0,0)
MinimapCluster=CreateFrame('Frame','MinimapCluster',UIParent)
MinimapCluster.MinimapContainer=CreateFrame('Frame',nil,MinimapCluster)
Minimap=CreateFrame('Frame','Minimap',MinimapCluster.MinimapContainer)
Minimap:SetSize(198,198)
for _,key in ipairs({'ZoneTextButton','Tracking','IndicatorFrame','InstanceDifficulty'}) do
    MinimapCluster[key]=CreateFrame('Frame',nil,MinimapCluster)
    MinimapCluster[key]:SetSize(152,23)
    MinimapCluster[key]:SetPoint('TOP',MinimapCluster,'TOP',10,0)
end
MinimapZoneText=MinimapCluster.ZoneTextButton:CreateFontString()
MinimapZoneText:SetSize(110,12)
MinimapZoneText:SetPoint('LEFT',MinimapCluster.ZoneTextButton,'LEFT',8,-1)
MinimapCluster.ZoneTextButton.StateTexture=MinimapCluster.ZoneTextButton:CreateTexture()
MinimapCluster.ZoneTextButton.AddTexture=MinimapCluster.ZoneTextButton:CreateTexture()
MinimapCluster.ZoneTextButton.StateTexture:SetSize(152,23)
MinimapCluster.ZoneTextButton.AddTexture:SetSize(152,23)
MinimapCluster.MinimapContainer.PlayerCoords=CreateFrame('Frame',nil,MinimapCluster.MinimapContainer)
MinimapCluster.MinimapContainer.PlayerCoords:SetSize(90,10)
MinimapCluster.MinimapContainer.PlayerCoords.CoordText=MinimapCluster.MinimapContainer.PlayerCoords:CreateFontString()
MinimapCluster.MinimapContainer.PlayerCoords.CoordText:SetSize(90,10)
GameTimeFrame=CreateFrame('Frame','GameTimeFrame',MinimapCluster)
AddonCompartmentFrame=CreateFrame('Frame','AddonCompartmentFrame',MinimapCluster)
TimeManagerClockButton=CreateFrame('Frame','TimeManagerClockButton',MinimapCluster)
GameTimeFrame:SetSize(23,23); AddonCompartmentFrame:SetSize(23,23); TimeManagerClockButton:SetSize(40,16)
DamageMeter=CreateFrame('Frame','DamageMeter',UIParent)
function DamageMeter:UpdateShownState() self:SetShown(self.visibility~=Enum.DamageMeterVisibility.Hidden) end
BagsBar=CreateFrame('Frame','BagsBar',UIParent); BagsBar:SetSize(270,45); BagsBar:SetScale(0.75)
StatusTrackingBarManager=CreateFrame('Frame','StatusTrackingBarManager',UIParent)
StatusTrackingBarManager.barContainers={}
for i=1,2 do
    local container=CreateFrame('Frame',nil,StatusTrackingBarManager)
    container:SetSize(596,17)
    function container:HasSetting() return true end
    function container:GetSettingValue() return self.sizeSetting or 50 end
    StatusTrackingBarManager.barContainers[i]=container
end
function StatusTrackingBarManager:CheckForLayoutChange()
    for _,container in ipairs(self.barContainers) do container.barWidth=container:GetWidth()-3 end
end
MinimapCompassTexture=Minimap:CreateTexture()
MinimapCompassTextureUnderlay=Minimap:CreateTexture()
function MinimapCluster:Layout() end
function MinimapCluster:UpdateMinimapConfig() Minimap:SetMaskTexture('native-mask') end
function MinimapCluster:UpdateSystemSettingSize() self.MinimapContainer:SetScale(1) end
chatInfo,chatPositions,chatDimensions={},{},{}
for id=1,4 do
    local frame=CreateFrame('Frame','ChatFrame'..id,UIParent)
    frame:SetID(id); frame:SetSize(350,180); frame:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',450,380)
    frame.isDocked=id==1 and true or nil
    frame.isUninteractable=id==1
    frame.isLocked=id==1
    frame.isTemporary=id==3
    chatInfo[id]={name='Window '..id,shown=id~=4,filters={'SAY','PARTY'}}
    frame.tab=CreateFrame('Frame','ChatFrame'..id..'Tab',UIParent)
    frame.editBox=CreateFrame('EditBox',nil,frame)
    if id==4 then frame:Hide() end
end
DEFAULT_CHAT_FRAME=ChatFrame1; COMBATLOG=ChatFrame2; SELECTED_DOCK_FRAME=ChatFrame1
GENERAL_CHAT_DOCK={DOCKED_CHAT_FRAMES={ChatFrame1}}
function GetScreenWidth() return UIParent:GetWidth() end
function GetScreenHeight() return UIParent:GetHeight() end
function FCF_GetChatWindowInfo(id)
    local frame=_G['ChatFrame'..id]; local info=chatInfo[id]
    return info.name,18,0,0,0,0.5,info.shown,frame.isLocked,frame.isDocked,frame.isUninteractable
end
function GetChatWindowSavedPosition(id) return unpack(chatPositions[id] or {}) end
function GetChatWindowSavedDimensions(id) return unpack(chatDimensions[id] or {}) end
function SetChatWindowSavedPosition(id,...) chatPositions[id]={...} end
function SetChatWindowSavedDimensions(id,...) chatDimensions[id]={...} end
function SetChatWindowShown(id,shown) chatInfo[id].shown=shown end
function SetChatWindowDocked() end
function FCF_CheckShowChatFrame(frame) frame:SetShown(chatInfo[frame.id].shown) end
function FCF_SetLocked(frame,value) frame.isLocked=value end
function FCF_SetUninteractable(frame,value) frame.isUninteractable=value end
function FCF_SelectDockFrame(frame) SELECTED_DOCK_FRAME=frame end
function FCFDock_SelectWindow(_,frame) FCF_SelectDockFrame(frame) end
function FCF_SaveDock() end
function FCF_UpdateButtonSide() end
function FCF_GetButtonSide() return 'left' end
function FCF_SetButtonSide() end
function FCF_DockUpdate() end
function Blizzard_CombatLog_Update_QuickButtons() end
function FCFDock_AddChatFrame(dock,frame)
    frame.isDocked=1; table.insert(dock.DOCKED_CHAT_FRAMES,frame)
    frame:ClearAllPoints(); frame:SetAllPoints(ChatFrame1)
end
function FCFDock_RemoveChatFrame(dock,frame)
    frame.isDocked=nil
    for index,item in ipairs(dock.DOCKED_CHAT_FRAMES) do if item==frame then table.remove(dock.DOCKED_CHAT_FRAMES,index); break end end
end
function FCF_RestorePositionAndDimensions(frame)
    local position=chatPositions[frame.id]
    frame:ClearAllPoints(); frame:SetPoint(position[1],UIParent,position[1],position[2]*GetScreenWidth(),position[3]*GetScreenHeight())
    frame:SetSize(unpack(chatDimensions[frame.id]))
end
for _,kind in ipairs({'Player','Target'}) do
    local owner=CreateFrame('Button',kind..'Frame',UIParent,'SecureUnitButtonTemplate')
    owner:SetAttribute('unit',kind:lower())
    owner:SetSize(232,100)
    local container=CreateFrame('Frame',nil,owner)
    owner[kind..'FrameContainer']=container
    local content=CreateFrame('Frame',nil,owner)
    owner[kind..'FrameContent']=content
    local main=CreateFrame('Frame',nil,content)
    content[kind..'FrameContentMain']=main
    content[kind..'FrameContentContextual']=CreateFrame('Frame',nil,content)
    main.HealthBarsContainer=CreateFrame('Frame',nil,main)
    main.HealthBarsContainer.DeadText=main.HealthBarsContainer:CreateFontString(nil,'OVERLAY','GameFontNormal')
    main.HealthBarsContainer.DeadText:SetText('Dead'); main.HealthBarsContainer.DeadText:Hide()
    main.LevelText=main:CreateFontString(nil,'OVERLAY','GameFontNormal')
    main.LevelText:SetText('6')
    owner.name=main:CreateFontString(nil,'OVERLAY','GameFontNormal')
    owner.name:SetText('Test unit')
    if kind=='Player' then
        PlayerLevelText=main.LevelText
        main.AlternatePowerBarArea=CreateFrame('Frame',nil,main)
    end
end
PetFrame=CreateFrame('Button','PetFrame',PlayerFrame,'SecureUnitButtonTemplate')
PetFrame:SetSize(120,49); PetFrame:SetAttribute('unit','pet'); PetFrame.unit='pet'
PetFrame:SetHitRectInsets(7,66,6,7)
for _,name in ipairs({'PetPortrait','PetFrameTexture','PetFrameFlash','PetAttackModeTexture','PetName','PetFrameHealthBar','PetFrameManaBar'}) do
    local region=CreateFrame('Frame',name,PetFrame); region:SetText('Pet'); region:SetAlpha(0.8)
end
PartyFrame=CreateFrame('Frame','PartyFrame',UIParent)
PartyFrame.Background=CreateFrame('Frame',nil,PartyFrame)
function PartyFrame:InitializePartyMemberFrames()
    for _,frame in ipairs(self.members or {}) do frame:Hide() end
    self.members={}
    for index=1,4 do
        local owner=CreateFrame('Button',nil,self,'SecureUnitButtonTemplate')
        owner:SetSize(120,53); owner:SetAttribute('unit','party'..index); owner.unit='party'..index; owner.layoutIndex=index
        self.members[index]=owner
        for _,key in ipairs({'Portrait','Texture','VehicleTexture','Flash','Name','HealthBarContainer','ManaBar','PartyMemberOverlay','AuraFrameContainer','PetFrame','ReadyCheck'}) do
            owner[key]=CreateFrame('Frame',nil,owner)
            owner[key]:SetAlpha(0.75)
            owner[key]:SetPoint('TOPLEFT',owner,'TOPLEFT',23,-43)
        end
        owner.Name:SetText('Party '..index)
        owner.PartyMemberOverlay.Status=CreateFrame('Texture',nil,owner.PartyMemberOverlay)
        owner.PartyMemberOverlay.RoleIcon=CreateFrame('Texture',nil,owner.PartyMemberOverlay)
        owner.PartyMemberOverlay.Disconnect=CreateFrame('Texture',nil,owner.PartyMemberOverlay)
    end
end
function PartyFrame:GetPartyMemberFrame(index) return self.members[index] end
function PartyFrame:Layout()
    -- Native vertical layout only sees direct children with layoutIndex.
    local children={}
    for _,child in ipairs(frames) do
        if child.parent==self and child.layoutIndex and child:IsShown() then children[#children+1]=child end
    end
    table.sort(children,function(a,b) return a.layoutIndex<b.layoutIndex end)
    local top=0
    for _,child in ipairs(children) do
        child:ClearAllPoints(); child:SetPoint('TOPLEFT',self,'TOPLEFT',0,-top)
        top=top+child:GetHeight()+10
    end
end
PartyFrame:InitializePartyMemberFrames()
GameTooltip=CreateFrame('Frame','GameTooltip')
function GameTooltip:SetOwner() end
EditModeManagerFrame={IsInitialized=function() return true end,IsShown=function() return editing end}
Settings={values={PROXY_SHOW_ACTIONBAR_2=false,PROXY_SHOW_ACTIONBAR_3=true,PROXY_SHOW_ACTIONBAR_4=false}, registered={}}
Settings.VarType={String='string',Number='number',Boolean='boolean'}
function Settings.GetSetting(k) return Settings.values[k]~=nil end
function Settings.GetValue(k) return Settings.values[k] end
function Settings.SetValue(k,v) safe(); Settings.values[k]=v end
function Settings.RegisterVerticalLayoutCategory() return {GetID=function() return 42 end} end
function Settings.RegisterAddOnSetting(_,variable,key,db)
    local setting={key=key,db=db}
    function setting:SetValueChangedCallback(fn) self.callback=fn end
    Settings.registered[key]=setting
    return setting
end
function Settings.CreateControlTextContainer() return {Add=function() end,GetData=function() return {} end} end
function Settings.CreateDropdown(_,_,fn) fn() end
function Settings.CreateSliderOptions() return {SetLabelFormatter=function() end} end
function Settings.CreateSlider() end
function Settings.CreateCheckbox() end
function Settings.RegisterAddOnCategory() end
function Settings.OpenToCategory(id) openCategory=id end
MinimalSliderWithSteppersMixin={Label={Right=1}}
Enum={EditModePresetLayouts={Modern=1}}
APIDocumentation={AddDocumentationTable=function(_,doc)
    for _,entry in ipairs(doc.Tables or {}) do
        if entry.Type=='Enumeration' then
            Enum[entry.Name]={}
            for _,field in ipairs(entry.Fields) do Enum[entry.Name][field.Name]=field.EnumValue end
        end
    end
end}
'''


def boot(combat=False, before=""):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(STUBS)
    # Execute native docking orchestration, including its click-through changes.
    chat_source=(REFERENCE/'Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua').read_text()
    for name in ['FCF_DockFrame','FCF_UnDockFrame','FCF_SetExpandedUninteractable']:
        start=chat_source.index('function '+name+'(')
        end=chat_source.index('\nfunction ',start+10)
        lua.execute(chat_source[start:end])
    lua.execute((REFERENCE / "Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua").read_text())
    lua.execute((REFERENCE / "Blizzard_APIDocumentationGenerated/DamageMeterConstantsDocumentation.lua").read_text())
    # Source-backed setting conversions: values saved by the client are slider
    # offsets, not percentages. Parse current Blizzard display metadata.
    metadata = (REFERENCE / "Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua").read_text()
    maps = {}
    system = None
    for line in metadata.splitlines():
        match = re.search(r"\[Enum.EditModeSystem\.(\w+)\] =", line)
        if match:
            system = match.group(1)
            maps.setdefault(system, {})
        match = re.search(r"setting = Enum\.(\w+)\.(\w+),", line)
        if match:
            enum, key = match.groups()
            # Capture only this setting's block, including nested option tables.
            pos = metadata.index(line)
            block = metadata[pos:metadata.find("\n\t\t},", pos)]
            if "ConvertValue = ConvertValueDefault" in block or "ConvertValue = ConvertValueDiffFromMin" in block:
                minimum = int(re.search(r"minValue = (\d+)", block)[1])
                step = 1 if "ConvertValue = ConvertValueDiffFromMin" in block else int(re.search(r"stepSize = (\d+)", block)[1])
                if system and lua.globals().Enum[enum] is not None:
                    maps[system][int(lua.globals().Enum[enum][key])] = (minimum, step)
    lua.execute("settingMaps={}; EditModeSettingDisplayInfoManager={GetSystemSettingDisplayInfoMap=function(_,s) return settingMaps[s] or {} end}")
    for system, settings in maps.items():
        system_id = lua.globals().Enum.EditModeSystem[system]
        table = lua.table()
        for key, (minimum, step) in settings.items():
            entry = lua.table()
            entry.ConvertValue = lua.eval(f"function(self,value) return (value-{minimum})/{step} end")
            table[key] = entry
        lua.globals().settingMaps[system_id] = table
    ns = lua.table()
    for path in SOURCES:
        text = (ADDON / path).read_text(encoding="utf-8")
        lua.execute("return assert(loadstring(...))", text)("MazzleUI", ns)
    lua.globals().M = ns
    lua.execute(r'''
        Constants={EditModeConsts={EditModeMaxLayoutsPerType=5},ChatFrameConstants={MaxChatWindows=4}}
        preset={layoutName='Modern',layoutType=Enum.EditModeLayoutType.Preset,systems={}}
        for name,id in pairs(Enum.EditModeSystem) do
            local count=name=='ActionBar' and 13 or (name=='UnitFrame' and 8 or (name=='AuraFrame' and 3 or 1))
            for index=1,count do
                table.insert(preset.systems,{system=id,systemIndex=index,isInDefaultPosition=true,settings={},
                    anchorInfo={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',offsetX=0,offsetY=0}})
            end
        end
        EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return {M.Copy(preset)} end}
        stored={activeLayout=1,layouts={}}
        C_EditMode={
            GetLayouts=function() return M.Copy(stored) end,
            SaveLayouts=function(info)
                safeSave=not combat and not editing; assert(safeSave,'unsafe save'); saves=saves+1
                stored=M.Copy(info); table.remove(stored.layouts,1)
            end,
            OnLayoutAdded=function(index,activate) assert(not combat); if activate then stored.activeLayout=index end end,
            SetActiveLayout=function(index) assert(not combat); stored.activeLayout=index end,
        }
        -- Distinct opaque objects throw if Lua tries arithmetic/concatenation.
        local forbidden=function() error('secret used in Lua arithmetic') end
        health=setmetatable({}, {__add=forbidden,__div=forbidden,__mul=forbidden,__sub=forbidden,__concat=forbidden,__lt=forbidden,__le=forbidden})
        maximum=setmetatable({}, getmetatable(health))
        fire('ADDON_LOADED','MazzleUI')
    ''')
    lua.execute(before)
    lua.globals().combat = combat
    lua.execute("fire('PLAYER_LOGIN'); flush()")
    return lua, ns


lua, ns = boot()
assert lua.eval("saves") == 1
assert len(ns.skinNames) == 14
lua.execute(r'''
    assert(stored.activeLayout==2 and #stored.layouts==1)
    assert(preset.systems[1].isInDefaultPosition==true, 'modified preset table')
    assert(M.character.previousLayout.name=='Modern')
    assert(not ChatFrame2.isDocked and not ChatFrame3.isDocked and not ChatFrame4.isDocked)
    assert(ChatFrame1.isUninteractable==true, 'combat log must not alter the main chat flags')
    assert(#chatInfo[2].filters==2 and chatInfo[2].filters[1]=='SAY')
    SlashCmdList.MAZZLEUIFOREVER(''); assert(openCategory==42)
    assert(not MazzleUIForeverContext:IsShown())
    assert(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain:GetAlpha()==0)
    assert(TargetFrame.TargetFrameContent.TargetFrameContentMain:GetAlpha()==0)
    assert(TargetFrame.TargetFrameContent.TargetFrameContentContextual:GetAlpha()==1)
    assert(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.AlternatePowerBarArea:IsIgnoringParentAlpha())
    for i=1,32 do
        local button=_G['MazzleUIForeverContextAction'..i]
        assert(button.template=='ActionBarButtonTemplate' and button:GetID()==0)
        assert(button:GetAttribute('action')==144+i)
    end
    local previous=saves
    combat=true
    secureSnippet(MazzleUIForeverContextToggle,'OnClick')
    assert(MazzleUIForeverContext:IsShown())
    secureSnippet(MazzleUIForeverContextPage2,'OnClick')
    assert(not MazzleUIForeverContext:GetFrameRef('page1'):IsShown())
    assert(MazzleUIForeverContext:GetFrameRef('page2'):IsShown())
    secureSnippet(MazzleUIForeverContextAction17,'OnMouseWheel',1)
    assert(MazzleUIForeverContext:GetFrameRef('page1'):IsShown())
    assert(not MazzleUIForeverContext:GetFrameRef('page2'):IsShown())
    secureSnippet(MazzleUIForeverContextToggle,'OnClick')
    assert(not MazzleUIForeverContext:IsShown())
    UIParent.w=1800
    fire('DISPLAY_SIZE_CHANGED'); flush(); assert(saves==previous)
    fire('UNIT_HEALTH','player'); fire('UNIT_POWER_UPDATE','target')
    MazzleUIForeverPlayerPanel.scripts.OnUpdate(nil,0.2)
    MazzleUIForeverTargetPanel.scripts.OnUpdate(nil,0.2)
    PlayerFrame.attributes.unit='vehicle'
    MazzleUIForeverPlayerPanel.scripts.OnUpdate(nil,0.2)
    PlayerFrame.attributes.unit='player'
    PlayerFrame.name:SetText(nil)
    PlayerLevelText:SetText(nil)
    MazzleUIForeverPlayerPanel.scripts.OnUpdate(nil,0.2)
    PlayerFrame.name:SetText(health)
    PlayerLevelText:SetText(health)
    MazzleUIForeverPlayerPanel.scripts.OnUpdate(nil,0.2)
    SlashCmdList.MAZZLEUIFOREVER('restore'); assert(M.character.enabled)
    combat=false; fire('PLAYER_REGEN_ENABLED'); flush(); assert(saves==previous+1)
    editing=true; UIParent.h=1100; fire('UI_SCALE_CHANGED'); flush(); assert(saves==previous+1)
    editing=false; EventRegistry['EditMode.Exit'](); flush(); assert(saves==previous+2)
    assert(#stored.layouts==1, 'duplicate layout')
    SlashCmdList.MAZZLEUIFOREVER('viewport'); flush()
    assert(WorldFrame:GetNumPoints()==2 and WorldFrame.points[2][5]>0)
    SlashCmdList.MAZZLEUIFOREVER('restore')
    assert(stored.activeLayout==1 and not M.character.enabled)
    assert(Settings.values.PROXY_SHOW_ACTIONBAR_2==false and Settings.values.PROXY_SHOW_ACTIONBAR_3==true)
    assert(WorldFrame.points[2][5]==0 and MazzleUIForeverPortrait.watched==false)
    assert(not MazzleUIForeverContextToggle:IsShown())
    secureSnippet(MazzleUIForeverContextToggle,'OnClick')
    assert(not MazzleUIForeverContext:IsShown(), 'hidden binding reopened disabled grid')
    assert(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain:GetAlpha()==1)
    assert(TargetFrame.TargetFrameContent.TargetFrameContentMain:GetAlpha()==1)
    assert(not PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.AlternatePowerBarArea:IsIgnoringParentAlpha())
    assert(PlayerFrame:GetWidth()==232 and PlayerFrame:GetHeight()==100)
    assert(TargetFrame:GetWidth()==232 and TargetFrame:GetHeight()==100)
    assert(Minimap.maskPath=='native-mask' and MinimapCompassTexture:GetAlpha()==1)
    assert(MinimapCluster.MinimapContainer.ignoreInLayout==nil)
    assert(not ChatFrame2.isDocked and ChatFrame2:GetWidth()==350)
    assert(math.abs(ChatFrame2:GetLeft()/GetScreenWidth()-450/1920)<0.000001)
    assert(math.abs(ChatFrame2:GetBottom()/GetScreenHeight()-380/1200)<0.000001 and ChatFrame2:IsShown())
    assert(ChatFrame1.isUninteractable==true and ChatFrame2.isUninteractable==false)
    assert(ChatFrame2.isLocked==false and M.character.chatDock==nil)
    SlashCmdList.MAZZLEUIFOREVER('enable'); flush(); assert(stored.activeLayout==2)
    SlashCmdList.MAZZLEUIFOREVER('scale 0'); assert(M.db.scale==1)
    SlashCmdList.MAZZLEUIFOREVER('skin Diablo'); flush(); assert(M.db.skin=='MazzleUI_Skin_Diablo')
    identitySecret=true; fire('PLAYER_TARGET_CHANGED')
    for _,frame in ipairs(frames) do if frame.kind=='PlayerModel' then assert(frame.unit==nil) end end
''')

# Group presentation must follow native pool/vehicle changes without replacing
# secure buttons or changing their public unit attributes.
lua, ns = boot()
lua.execute(r'''
    local function View(owner)
        for _,frame in ipairs(frames) do if frame.owner==owner and frame.fittedBounds then return frame end end
        error('Missing original group panel')
    end
    local function CheckBounds(view)
        local b=view.fittedBounds
        assert(math.abs((b.right-b.left)*b.scale-view.owner:GetWidth())<0.00001)
        assert(math.abs((b.top-b.bottom)*b.scale-view.owner:GetHeight())<0.00001)
        assert(math.abs(b.scale-M.SelectUnitStyle()[view.kind].scale*M.geometry.scale)<0.00001,
            'original panel shrunk to a native portrait size')
    end
    local pet=View(PetFrame)
    CheckBounds(pet)
    assert(PetFrameHealthBar:GetAlpha()==0 and PetFrame:GetHitRectInsets()==0)
    pet.scripts.OnUpdate(nil,0.2)
    assert(pet.model.unit=='pet' and pet.labels[3].arguments[1]==health)
    local owner=PartyFrame.members[1]
    local party=View(owner)
    CheckBounds(party)
    assert(owner:GetAttribute('unit')=='party1' and owner.HealthBarContainer:GetAlpha()==0)
    assert(owner.PartyMemberOverlay.RoleIcon:GetAlpha()==1 and owner.PartyMemberOverlay.Disconnect:GetAlpha()==1)
    assert(owner.AuraFrameContainer:GetPoint(1)=='BOTTOMLEFT' and owner.AuraFrameContainer.points[1][3]=='TOPLEFT')
    assert(owner.PetFrame.points[1][3]=='TOPLEFT')
    local x,y=owner.points[1][4],owner.points[1][5]
    PartyFrame:Layout()
    assert(MazzleUIForeverPartyStrip.parent==UIParent and MazzleUIForeverPartyStrip.layoutIndex==nil,
        'addon layout data leaked into the native party layout tree')
    assert(owner.parent==MazzleUIForeverPartyStrip and owner.points[1][4]==x and owner.points[1][5]==y,
        'native layout stacked the original party strip')
    owner.unit='partypet1'
    party.scripts.OnEvent(); party.scripts.OnUpdate(nil,0.2)
    assert(party.model.unit=='partypet1' and owner:GetAttribute('unit')=='party1')
    owner.Name:SetText(health)
    party.scripts.OnUpdate(nil,0.2)
    assert(party.labels[1].text==health)
    identitySecret=true
    party.scripts.OnUpdate(nil,0.2); pet.scripts.OnUpdate(nil,0.2)
    assert(party.model.unit==nil and pet.model.unit==nil)
    identitySecret=false
    local previous=saves
    -- A native pool replacement during combat keeps native art until safe.
    combat=true; restricted=true; PartyFrame:InitializePartyMemberFrames(); restricted=false
    flush(); assert(PartyFrame.members[1].HealthBarContainer:GetAlpha()==0.75)
    combat=false; fire('PLAYER_REGEN_ENABLED'); flush()
    assert(PartyFrame.members[1].HealthBarContainer:GetAlpha()==0 and saves==previous)
    CheckBounds(View(PartyFrame.members[1]))
    editing=true; PartyFrame:InitializePartyMemberFrames(); flush()
    assert(PartyFrame.members[1].HealthBarContainer:GetAlpha()==0 and saves==previous)
    assert(PartyFrame.members[1].parent==MazzleUIForeverPartyStrip)
    editing=false; EventRegistry['EditMode.Exit'](); flush()
    assert(PartyFrame.members[1].HealthBarContainer:GetAlpha()==0 and saves==previous)
    SlashCmdList.MAZZLEUIFOREVER('groupframes'); flush()
    assert(PetFrameHealthBar:GetAlpha()==0.8 and not pet:IsShown())
    local a,b,c,d=PetFrame:GetHitRectInsets(); assert(a==7 and b==66 and c==6 and d==7)
    for _,member in ipairs(PartyFrame.members) do
        assert(member.HealthBarContainer:GetAlpha()==0.75 and member.Texture:GetAlpha()==0.75)
        assert(member.parent==PartyFrame and member:GetWidth()==120 and member:GetHeight()==53)
        assert(member.AuraFrameContainer.points[1][3]=='TOPLEFT' and member.AuraFrameContainer.points[1][4]==23)
        assert(member.PetFrame.points[1][3]=='TOPLEFT' and member.PetFrame.points[1][5]==-43)
    end
    PartyFrame:InitializePartyMemberFrames(); flush()
    assert(PartyFrame.members[1].HealthBarContainer:GetAlpha()==0.75)
''')

# Preserve a native Edit Mode customization through ordinary events, cosmetic
# settings, and a new login; only a deliberate reset or geometry change rebuilds.
lua, ns = boot()
lua.execute(r'''
    stored.layouts[1].systems[1].anchorInfo.offsetX=137
    Settings.values.PROXY_SHOW_ACTIONBAR_2=false
    local previous=saves
    fire('PLAYER_REGEN_ENABLED'); EventRegistry['EditMode.Exit'](); flush()
    assert(saves==previous and #timers==0)
    SlashCmdList.MAZZLEUIFOREVER('hud'); flush()
    SlashCmdList.MAZZLEUIFOREVER('skin Diablo'); flush()
    fire('DISPLAY_SIZE_CHANGED'); flush()
    assert(saves==previous and stored.layouts[1].systems[1].anchorInfo.offsetX==137)
    assert(Settings.values.PROXY_SHOW_ACTIONBAR_2==false)
''')
saved_character = literal(plain(ns.character))
saved_preferences = literal(plain(ns.db))
saved_layouts = literal(plain(lua.globals().stored))
lua, ns = boot(before=f'M.character={saved_character}; M.db={saved_preferences}; stored={saved_layouts}')
assert lua.eval('saves') == 0, 'login rewrote a customized native layout'
lua.execute(r'''
    assert(stored.layouts[1].systems[1].anchorInfo.offsetX==137)
    SlashCmdList.MAZZLEUIFOREVER('apply'); flush()
    assert(saves==1 and stored.layouts[1].systems[1].anchorInfo.offsetX~=137)
    -- A forced rebuild requested in combat survives until combat has ended.
    combat=true; M.RequestLayout(true); flush(); assert(saves==1)
    combat=false; fire('PLAYER_REGEN_ENABLED'); flush(); assert(saves==2)
    fire('PLAYER_REGEN_ENABLED'); flush(); assert(saves==2)
''')
for width, height in ((1024,768),(1280,1024),(1920,1080),(2560,1440),(3440,1440)):
    lua, ns = boot(before=f"UIParent:SetSize({width},{height})")
    assert ns.geometry.inner >= 140 - 0.001
    target=ns.SelectUnitStyle().target
    assert target.TextBox[8].yoffset*target.scale*ns.geometry.scale >= ns.geometry.mapBottom+ns.geometry.mapSize-0.001
    assert ns.geometry.partyBottom >= ns.geometry.actionTop+8-0.001
    assert ns.geometry.partyLeft >= 0 and ns.geometry.partyRight <= width
    g=ns.geometry
    assert g.chatWidth>=250 and g.chatHeight>=120
    assert g.chatX-34*g.chatScale>=0
    assert g.chatBottom-34*g.chatScale>=0, 'chat edit box below screen'
    assert g.chatBottom+g.chatHeight*g.chatScale+26<=g.height+0.001, 'chat tabs exceed panel'
    assert g.chatX+g.chatWidth*g.chatScale+12*g.chatScale<=385*g.edge/470, 'chat spills past tall artwork'
    assert abs(g.damageWidth+g.logGap+g.combatWidth-g.sideWidth)<0.0001
    assert g.combatWidth/g.combatScale>=250-0.001
    assert (g.logHeight-g.logHeader)/g.combatScale>=120-0.001
    assert g.bagsBottom+45*g.bagsScale<=g.height-10*g.scale-2*g.infoLine
    assert g.bagsBottom>g.logBottom+g.logHeight
    assert g.meterBottom>g.height and g.statusBottom>=g.menuBottom+30
    assert abs(lua.eval('Minimap:GetEffectiveScale()/UIParent:GetEffectiveScale()')*198 - ns.geometry.mapSize)<0.00001
    for system in lua.globals().stored.layouts[1].systems.values():
        if system.system == lua.globals().Enum.EditModeSystem.ActionBar and system.systemIndex <= 4:
            settings = {v.setting: v.value for v in system.settings.values()}
            size = settings[lua.globals().Enum.EditModeActionBarSetting.IconSize]
            assert 0 <= size <= 3, "native icon size must be encoded, not a percentage"

# Check physical text size at the user's small window dimensions.
lua, ns = boot(before='UIParent:SetSize(1368,768); UIParent:SetScale(0.625)')
lua.execute(r'''
    for _,frame in ipairs(frames) do
        if frame.font and not frame.fontInherited then assert(frame.font[2]*frame:GetEffectiveScale()>=7-0.00001) end
    end
    local previous=saves
    assert(ChatFrame1:GetScale()==M.geometry.chatScale)
    assert(ChatFrame1.font[2]*ChatFrame1:GetEffectiveScale()>=9)
    assert(ChatFrame1.editBox.font[2]*ChatFrame1.editBox:GetEffectiveScale()>=9)
    assert(StatusTrackingBarManager.barContainers[1]:GetWidth()==M.geometry.sideWidth)
    StatusTrackingBarManager.barContainers[2].sizeSetting=75
    M.ApplyStatusPanels()
    assert(StatusTrackingBarManager.barContainers[2]:GetWidth()==M.geometry.sideWidth*1.5)
    assert(MinimapZoneText.font[2]*MinimapZoneText:GetEffectiveScale()>=8)
    assert(MinimapCluster.ZoneTextButton:GetPoint(1)=='TOP')
    assert(MinimapCluster.ZoneTextButton.points[1][2]==Minimap)
    assert(MinimapZoneText:GetWidth()<M.geometry.mapSize)
    assert(MinimapCluster.MinimapContainer.PlayerCoords:GetEffectiveScale()==UIParent:GetEffectiveScale())
    combat=true; MinimapCluster:UpdateMinimapConfig(); flush(); assert(saves==previous)
    combat=false; fire('PLAYER_REGEN_ENABLED'); flush()
    assert(Minimap.maskPath==M.path..'Art\\MazzleUIMinimapMask.blp' and saves==previous)
    M.Restore()
    assert(ChatFrame1:GetScale()==1 and ChatFrame1.font[2]==14)
    assert(DamageMeter:GetScale()==1)
    assert(ChatFrame1.editBox.font[2]==14)
    assert(StatusTrackingBarManager.barContainers[1]:GetWidth()==596)
    assert(MinimapCluster.ZoneTextButton:GetWidth()==152 and MinimapZoneText:GetWidth()==110)
    assert(MinimapCluster.ZoneTextButton.points[1][2]==MinimapCluster)
    assert(MinimapCluster.ZoneTextButton.ignoreInLayout==nil)
    assert(MinimapCluster.MinimapContainer.PlayerCoords:GetScale()==1)
    assert(TimeManagerClockButton:GetWidth()==40 and TimeManagerClockButton:GetHeight()==16)
''')

# Native log restoration covers existing docks, hidden windows and the preview-6
# migration. No window is renamed and no message filter is replaced.
lua, ns = boot(before="FCF_DockFrame(ChatFrame2,2,false)")
lua.execute(r'''
    assert(not ChatFrame2.isDocked and ChatFrame2Tab:GetParent()~=UIParent)
    M.Restore()
    assert(ChatFrame2.isDocked and ChatFrame2Tab:GetParent()==UIParent)
    assert(M.character.combatLog==nil and #chatInfo[2].filters==2)
''')
lua, ns = boot(before="SetChatWindowShown(2,false); ChatFrame2:Hide()")
lua.execute("assert(ChatFrame2:IsShown()); M.Restore(); assert(not ChatFrame2:IsShown())")
lua, ns = boot(before=r'''
    M.character.chatDock={windows={[2]={name='Window 2',shown=true,locked=false,docked=false,uninteractable=false}},
        changed={[2]={name='Window 2',point='BOTTOMLEFT',x=0.25,y=0.3,width=370,height=200}}}
    FCF_DockFrame(ChatFrame2,2,false)
''')
lua.execute(r'''
    assert(M.character.chatDock.changed[2]==nil)
    M.Restore()
    assert(not ChatFrame2.isDocked and ChatFrame2:GetWidth()==370 and ChatFrame2:GetHeight()==200)
    assert(ChatFrame2:GetLeft()==480 and ChatFrame2:GetBottom()==360)
''')
lua, ns = boot()
lua.execute(r'''
    local p=MazzleUIForeverInfo
    damageSession={combatSources={{isLocalPlayer=false,totalAmount=1,amountPerSecond=2},
        {isLocalPlayer=true,totalAmount=health,amountPerSecond=maximum}}}
    combat=true
    p.scripts.OnUpdate(nil,1)
    assert(p.amount.text==health and p.rate.text==maximum, 'damage values must reach text widgets unchanged')
    assert(memoryReads==nil, 'memory scan must wait for combat to end')
    combat=false; p.scripts.OnUpdate(nil,1)
    assert(memoryReads==1 and p.bags.arguments[1]==30 and p.bags.arguments[2]==40)
    damageSession={combatSources={}}; M.UpdatePanelInfo()
    assert(p.amount.text=='—' and p.rate.text=='—', 'do not leave stale encounter damage')
    DamageMeter:Hide(); M.ToggleDamageMeter(); assert(DamageMeter:IsShown())
    M.ToggleDamageMeter(); assert(not DamageMeter:IsShown())
    M.Restore(); assert(not p:IsShown() and BagsBar:GetScale()==0.75)
''')

lua, ns = boot(combat=True)
assert lua.eval("saves") == 0
lua.execute("combat=false; fire('PLAYER_REGEN_ENABLED'); flush()")
assert lua.eval("saves") == 1
lua, ns = boot(before="M.character.enabled=false")
assert lua.eval("saves") == 0
lua.execute(r'''
    assert(MazzleUIForeverSetup:IsShown(), 'fresh character must see setup')
    local original=M.db.skin
    for _,frame in ipairs(frames) do
        if frame.kind=='Button' and frame.text=='Next' then frame.scripts.OnClick() end
    end
    assert(M.db.skin==original, 'draft modified settings before applying')
    for _,frame in ipairs(frames) do
        if frame.kind=='Button' and frame.text=='Apply layout' then frame.scripts.OnClick() end
    end
    flush()
    assert(M.character.enabled and M.db.skin~=original and saves==1)
    assert(not MazzleUIForeverSetup:IsShown())
    SlashCmdList.MAZZLEUIFOREVER('restore')
    assert(not M.character.enabled)
''')
lua, ns = boot(before="Constants.EditModeConsts.EditModeMaxLayoutsPerType=0")
assert lua.eval("saves") == 0
lua, ns = boot(before="GetBuildInfo=function() return '99','1','',990000 end")
assert lua.eval("saves") == 0

with ZipFile(ROOT / "MazzleUI-Forever.zip") as package:
    names = set(package.namelist())
    assert package.read("MazzleUI/MazzleUI.toc") == TOC.read_bytes()
    assert package.read("MazzleUI/Bindings.xml") == (ADDON / 'Forever/Bindings.xml').read_bytes()
    for name in names:
        assert not name.startswith(("Bongos/", "Mazzifier/", "MazzleOptions/", ".validation/"))
    for name in SOURCES:
        assert package.read("MazzleUI/" + name) == (ADDON / name).read_bytes()
    for skin in ns.skins.values():
        for path in skin.values():
            archive_path = path.replace("\\", "/").removeprefix("Interface/AddOns/")
            assert archive_path in names, archive_path
    for path in (ADDON / "Forever").glob("*.lua"):
        lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8"))

# Compare derived masks with the original pixels, including the mana crop.
for stem, visible_height in [('HL',256),('ML',140)]:
    original=Image.open(ADDON/'Art'/f'{stem}.blp').convert('RGBA').getchannel('A')
    width,height=original.size
    left=Image.open(ADDON/'Forever/Textures'/f'{stem}-left.tga').convert('RGBA').getchannel('A')
    right=Image.open(ADDON/'Forever/Textures'/f'{stem}-right.tga').convert('RGBA').getchannel('A')
    assert left.size==original.size
    assert left.crop((0,height-visible_height,width,height)).tobytes()==original.crop((0,0,width,visible_height)).tobytes()
    assert right.tobytes()==left.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()
    assert left.getbbox()[1]>=height-visible_height
    rgba=Image.open(ADDON/'Forever/Textures'/f'{stem}-left.tga').convert('RGBA')
    assert all(channel.getextrema()==(255,255) for channel in rgba.split()[:3])
for ratio,file,function in [(1.6,'DUF_1_6.lua','Setup_DUF16'),(4/3,'DUF_1_33.lua','Setup_DUF133'),(1.25,'DUF_1_25.lua','Setup_DUF125')]:
    original_lua, profile, _ = original_profile(file,function)
    # Lua's serialized numeric key is rounded by its parser; choose the nearest.
    style=min(ns.unitStyles.items(),key=lambda entry:abs(entry[0]-ratio))[1]
    for unit in ['player','target']:
        for index in [1,2]:
            for key in ['width','height','direction','xoffset','yoffset']:
                assert style[unit].bars[index][key]==profile[unit].StatusBar[index][key]
for font in ['ARIALN.ttf','FRIZQT__.ttf']:
    assert (ADDON/'Forever/Fonts'/font).read_bytes()==(ROOT/'Fonts'/font).read_bytes()

print("PASS: Lua 5.1 syntax; original skins/assets; startup; encoded native settings;")
print("combat/Edit Mode deferral; opaque values; model restrictions; layout/viewport")
print("restore; 5 aspect ratios; profile reuse; unsupported-client guard; ZIP contents.")
print("PASS: original mask pixels, mirrored crops and fonts; extracted DUF dimensions;")
print("unit-panel updates with opaque values and missing native text; native restoration;")
print("action-grid slot mapping and secure snippets; per-character setup draft/apply.")
print("PASS: customized native layouts persist through login and cosmetic updates;")
print("original pet/party panels retain full size, survive native column layout, defer new")
print("pool members during combat, refresh Edit Mode previews, and restore native")
print("parents, dimensions, artwork, anchors and hit areas.")
print("PASS: chat/input gutters and physical text size; side-pane bounds; native")
print("minimum sizes; map-control placement/restoration; status-bar width preferences.")
print("PASS: split combat log preserves filters, restores dock/hidden state, migrates")
print("preview 6 backups; damage display accepts opaque values; bags fit the header.")
print("Not validated: real rendering, combat taint, hardware input, party/raid sessions.")
