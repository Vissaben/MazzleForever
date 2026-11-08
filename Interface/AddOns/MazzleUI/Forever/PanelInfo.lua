-- Independent presentation of the original right panel, using native APIs.
local _, M = ...
local panel, memory, elapsed, memoryElapsed = nil,0,0,30
local microMenu, microParent, microBeforeEdit

local function ApplyMicroMenu()
    if not MicroMenuContainer then return end
    if not microParent then
        microParent=MicroMenuContainer:GetParent()
        MicroMenuContainer:SetParent(microMenu)
        microMenu:Hide()
    end
    panel.menuButton:SetAttribute("enabled",true)
end

local function Text(parent, color)
    local text=parent:CreateFontString(nil,"OVERLAY")
    text:SetFont(M.path.."Forever\\Fonts\\ARIALN.ttf",M.geometry.infoFont,"")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
    text:SetTextColor(unpack(color or {0.9,0.82,0.5}))
    return text
end

local function Place(text,x,y,width,height,size,justify)
    text:SetFont(M.path.."Forever\\Fonts\\ARIALN.ttf",size,"")
    text:SetJustifyH(justify or "LEFT")
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT",panel,"TOPLEFT",x,-y)
    text:SetSize(width,height)
end

function M.UpdatePanelInfo()
    if not panel or not M.character.enabled then return end
    local hour,minute=GetGameTime()
    panel.performance:SetFormattedText("%02d:%02d   %d FPS",hour,minute,GetFramerate())
    local _,_,home,world=GetNetStats()
    panel.network:SetFormattedText("%d ms   %.1f MB",math.max(home,world),memory/1024)
    local copper=GetMoney()
    panel.money:SetFormattedText("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
    local free,total=0,0
    for bag=0,NUM_BAG_SLOTS do
        free=free+C_Container.GetContainerNumFreeSlots(bag)
        total=total+C_Container.GetContainerNumSlots(bag)
    end
    panel.bags:SetFormattedText("Bags: %d/%d",total-free,total)
    panel.amount:SetText("—")
    panel.rate:SetText("—")
    if C_DamageMeter.IsDamageMeterAvailable() then
        local session=C_DamageMeter.GetCombatSessionFromType(Enum.DamageMeterSessionType.Current,Enum.DamageMeterType.DamageDone)
        for _,source in ipairs(session.combatSources) do
            -- isLocalPlayer is explicitly NeverSecret in this client's API.
            -- Amounts remain opaque: native abbreviation -> native text widget.
            if source.isLocalPlayer then
                panel.amount:SetText(AbbreviateLargeNumbers(source.totalAmount))
                panel.rate:SetText(AbbreviateLargeNumbers(source.amountPerSecond))
                break
            end
        end
    end
end

function M.ToggleDamageMeter()
    if not M.SafeToLayout() then M.Print("Open or close the full meter after combat and Edit Mode."); return end
    if not DamageMeter then C_AddOns.LoadAddOn("Blizzard_DamageMeter") end
    if not DamageMeter or not C_DamageMeter.IsDamageMeterAvailable() then
        M.Print("The native damage meter is currently unavailable."); return
    end
    DamageMeter.visibility=DamageMeter:IsShown() and Enum.DamageMeterVisibility.Hidden or Enum.DamageMeterVisibility.Always
    DamageMeter:UpdateShownState()
end

function M.ApplyPanelInfo()
    if not panel then
        panel=CreateFrame("Frame","MazzleUIForeverInfo",UIParent)
        panel:SetFrameStrata("LOW")
        panel.performance=Text(panel); panel.network=Text(panel)
        microMenu=CreateFrame("Frame","MazzleUIForeverMicroMenu",UIParent,"SecureHandlerBaseTemplate")
        microMenu:SetAllPoints(UIParent)
        microMenu:EnableMouse(false)
        microMenu:Hide()
        panel.menuButton=CreateFrame("Button","MazzleUIForeverMenuToggle",panel,"SecureHandlerClickTemplate")
        panel.menuButton:RegisterForClicks("AnyUp")
        panel.menuButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        panel.menuButton:SetFrameRef("menu",microMenu)
        panel.menuButton:SetAttribute("_onclick",[[
            if not self:GetAttribute("enabled") then return end
            local menu=self:GetFrameRef("menu")
            if menu:IsShown() then menu:Hide() else menu:Show() end
        ]])
        panel.menuButton:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:SetText("Show or hide the native game menu buttons.")
            GameTooltip:Show()
        end)
        panel.menuButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
        panel.title=Text(panel.menuButton,{0.78,0.8,0.79}); panel.title:SetText("Menu")
        panel.money=Text(panel); panel.bags=Text(panel)
        panel.amount=Text(panel,{1,0.9,0.55}); panel.rate=Text(panel,{1,0.9,0.55})
        panel.damageLabel=Text(panel,{0.65,0.65,0.65}); panel.damageLabel:SetText("Damage")
        panel.rateLabel=Text(panel,{0.65,0.65,0.65}); panel.rateLabel:SetText("DPS")
        panel.damage=CreateFrame("Button",nil,panel)
        panel.damage.label=Text(panel.damage,{0.8,0.8,0.8}); panel.damage.label:SetText("Dmg Out")
        panel.damage:SetScript("OnClick",M.ToggleDamageMeter)
        panel.damage:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:SetText("Your damage and DPS for the current encounter.\nClick to open or close the full native meter.")
            GameTooltip:Show()
        end)
        panel.damage:SetScript("OnLeave",function() GameTooltip:Hide() end)
        panel.combat=CreateFrame("Button",nil,panel)
        panel.combat:SetID(2)
        panel.combat.label=Text(panel.combat,{0.8,0.8,0.8}); panel.combat.label:SetText("Combat Log")
        panel.combat:SetScript("OnClick",function(self)
            FCF_Tab_OnClick(self,"RightButton")
        end)
        panel.divider=panel:CreateTexture(nil,"BACKGROUND")
        panel.divider:SetColorTexture(0.2,0.22,0.23,0.65)
        panel:SetScript("OnUpdate",function(_,delta)
            elapsed=elapsed+delta; memoryElapsed=memoryElapsed+delta
            if elapsed<1 then return end
            elapsed=0
            if memoryElapsed>=30 and not InCombatLockdown() then
                memoryElapsed=0; memory=0
                UpdateAddOnMemoryUsage()
                for index=1,C_AddOns.GetNumAddOns() do memory=memory+GetAddOnMemoryUsage(index) end
            end
            M.UpdatePanelInfo()
        end)
    end
    local g=M.geometry
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-g.sideInset,g.logBottom)
    panel:SetSize(g.sideWidth,g.height-g.logBottom-10*g.scale)
    local w,h=panel:GetSize()
    local line=g.infoLine
    Place(panel.performance,0,0,w*0.6,line,g.infoFont)
    Place(panel.network,0,line,w*0.64,line,g.infoFont)
    Place(panel.title,w*0.6,0,w*0.4-20,line,g.infoFont,"RIGHT")
    panel.menuButton:ClearAllPoints()
    panel.menuButton:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-20,0)
    panel.menuButton:SetSize(w*0.4-20,line)
    Place(panel.money,w*0.64,line,w*0.36,line,g.infoFont,"RIGHT")
    Place(panel.bags,0,h-g.logHeight-26*g.bagsScale,g.damageWidth,24*g.bagsScale,g.infoFont)
    for _,item in ipairs({{panel.damage,0,g.damageWidth},{panel.combat,g.damageWidth+g.logGap,g.combatWidth}}) do
        local button,x,width=unpack(item)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",panel,"TOPLEFT",x,-(h-g.logHeight))
        button:SetSize(width,g.logHeader)
        Place(button.label,x,h-g.logHeight,width,g.logHeader,g.logFont)
    end
    local bodyTop=h-g.logHeight+g.logHeader+2
    local bodyHeight=g.logHeight-g.logHeader-2
    local row=math.min(g.logFont+2,bodyHeight/4)
    Place(panel.damageLabel,0,bodyTop,g.damageWidth,row,g.infoFont)
    Place(panel.amount,0,bodyTop+row,g.damageWidth,row,g.logFont)
    Place(panel.rateLabel,0,bodyTop+2*row,g.damageWidth,row,g.infoFont)
    Place(panel.rate,0,bodyTop+3*row,g.damageWidth,row,g.logFont)
    panel.divider:ClearAllPoints()
    panel.divider:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",g.damageWidth+g.logGap/2,0)
    panel.divider:SetSize(1,g.logHeight)
    panel:Show()
    ApplyMicroMenu()
    M.UpdatePanelInfo()
end

function M.RestorePanelInfo()
    if panel then
        panel.menuButton:SetAttribute("enabled",false)
        panel:Hide()
    end
    if microParent then MicroMenuContainer:SetParent(microParent); microParent=nil end
    if microMenu then microMenu:Hide() end
    microBeforeEdit=nil
end

EventRegistry:RegisterCallback("EditMode.Enter",function()
    if not microParent or InCombatLockdown() then return end
    microBeforeEdit=microMenu:IsShown()
    microMenu:Show()
end)
EventRegistry:RegisterCallback("EditMode.Exit",function()
    if microParent and not InCombatLockdown() then microMenu:SetShown(microBeforeEdit==true) end
    microBeforeEdit=nil
end)
