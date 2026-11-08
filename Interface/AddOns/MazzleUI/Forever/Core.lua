-- MazzleUI Forever: an independent port of the original MazzleUI compilation.
-- Original MazzleUI artwork/code notices remain with the supplied files.
local addon, M = ...
M.version = "1.18-forever.7"
M.defaults = { skin = "MazzleUI_Skin_Noob123_BlackMetal",
    scale = 1, hud = true, models = true, viewport = false, context = true, unitframes = true, groupframes = true, chatdock = true }
M.path = "Interface\\AddOns\\MazzleUI\\"
M.events = CreateFrame("Frame")
local pending, pendingReset, scheduled, applying, initialized

function M.Print(message)
    print("|cff3399ccMazzleUI|r " .. message)
end

function M.Run(label, callback)
    return xpcall(callback, function(message)
        if M.character then
            M.character.lastError = label .. ": " .. tostring(message)
            if M.reportedError ~= M.character.lastError then
                M.reportedError = M.character.lastError
                M.Print(M.reportedError)
            end
        end
        geterrorhandler()(message)
    end)
end

function M.SafeToLayout()
    return not InCombatLockdown() and not (EditModeManagerFrame and EditModeManagerFrame:IsShown())
end

function M.ResumeLayout()
    if not pending or not initialized or scheduled or applying or not M.SafeToLayout() then return end
    scheduled = true
    C_Timer.After(0, function()
        scheduled = false
        if not pending or not M.SafeToLayout() then return end
        local reset = pendingReset
        pending, pendingReset = false, false
        if not M.character.enabled then return end
        applying = true
        local ok = M.Run("Layout", function()
            if not M.created then M.CreateArt(); M.CreateHUD(); M.CreateContext(); M.created = true end
            M.LayoutArt()
            M.LayoutContext()
            M.ApplyPanelScaling()
            if M.ApplyNativeLayout(reset) then
                M.ApplyStatusPanels()
                M.ApplyMinimap()
                M.ApplyChat()
                M.ApplyPanelInfo()
                M.ApplyUnitFrames()
                M.ApplyGroupFrames()
                M.ShowArt(true)
                M.ApplyViewport()
                M.character.lastError = nil
            else
                M.RestorePanelScaling()
                M.RestoreChat()
                M.RestorePanelInfo()
                M.RestoreUnitFrames()
                M.RestoreGroupFrames()
                M.ShowArt(false)
                M.RestoreViewport()
            end
        end)
        applying = false
        if not ok then
            M.RestorePanelScaling()
            M.RestoreChat()
            M.RestorePanelInfo()
            M.RestoreUnitFrames()
            M.RestoreGroupFrames()
            M.ShowArt(false)
            M.RestoreViewport()
            M.Print("Setup failed; copy the Lua error, then /reload before retrying /mazzify.")
        end
    end)
end

function M.RequestLayout(reset)
    pending = true
    if reset == true then pendingReset = true end
    M.ResumeLayout()
end

function M.Command(message)
    local command, value = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "diagnose" then M.HUDReport(); return end
    if command == "status" then
        local version, build, _, interface = GetBuildInfo()
        M.Print(string.format("%s; WoW %s (%s), interface %s. %s. Skin: %s.",
            M.version, version, build, interface, M.character.enabled and "Enabled" or "Disabled", M.db.skin))
        return
    end
    if M.compatible ~= true then M.Print("Layout changes require Forever interface 16001."); return end
    if not M.SafeToLayout() then M.Print("Finish combat and close Edit Mode before changing the layout."); return end
    if command == "" or command == "options" then M.OpenOptions(); return
    elseif command == "setup" then M.OpenInstaller(); return
    elseif command == "restore" then M.Restore(); return
    elseif command == "actions" then M.ToggleContext(); return
    elseif command == "enable" or command == "apply" then M.character.enabled = true
    elseif command == "skin" then
        local found
        for _, name in ipairs(M.skinNames) do
            if name:lower() == value:lower() or name:lower():gsub("^mazzleui_skin_", "") == value:lower()
                or (value:lower() == "default" and name == "MazzleUI_Default_Skin") then found = name end
        end
        if not found then M.Print("Skins: " .. table.concat(M.skinNames, ", ")); return end
        M.db.skin = found
    elseif command == "scale" then
        local number = tonumber(value)
        if not number or number ~= number or number < 0.75 or number > 1.25 then
            M.Print("Use /mazzle scale 0.75 through 1.25."); return
        end
        M.db.scale = number
    elseif command == "hud" or command == "models" or command == "viewport" or command == "context" or command == "unitframes" or command == "groupframes" or command == "chatdock" then
        M.db[command] = not M.db[command]
    elseif command == "reset" then
        for key, default in pairs(M.defaults) do M.db[key] = default end
        M.character.enabled = true
    else
        M.Print("/mazzify: setup. /mazzle options, apply, skin <name>, scale <0.75-1.25>, hud, models, actions, context, viewport, status, restore, reset.")
        return
    end
    M.RequestLayout(command == "apply" or command == "reset")
end

function M.Restore()
    if not M.SafeToLayout() then M.Print("Finish combat and close Edit Mode first."); return end
    M.character.enabled = false
    M.character.installerSeen = true
    pending, pendingReset = false, false
    M.RestorePanelScaling()
    M.RestoreChat()
    M.RestorePanelInfo()
    M.RestoreUnitFrames()
    M.RestoreGroupFrames()
    if M.created then M.ShowArt(false); M.RestoreViewport() end
    M.RestoreNativeLayout()
    M.Print("Previous layout and action-bar preferences restored. /reload releases cosmetic changes; /mazzle enable returns.")
end

local function Initialize()
    if initialized then return end
    local _, _, _, interface = GetBuildInfo()
    if interface ~= 16001 or not C_EditMode or not C_EditMode.GetLayouts then
        M.compatible = false
        M.Print("This port targets Forever interface 16001. This client needs a compatibility review; setup was not applied.")
        return
    end
    M.compatible = true
    initialized = true
    M.CreateOptions()
    EventRegistry:RegisterCallback("EditMode.Exit", M.ResumeLayout, M)
    if M.character.enabled then M.RequestLayout()
    elseif not M.character.installerSeen then M.OpenInstaller() end
    M.Print("Forever port loaded. /mazzify opens setup; /mazzle restore restores your previous layout.")
end

M.events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addon then
        if type(MazzleUIForeverDB) ~= "table" then MazzleUIForeverDB = {} end
        M.db = MazzleUIForeverDB
        if type(MazzleUIForeverCharacter) ~= "table" then MazzleUIForeverCharacter = {} end
        M.character = MazzleUIForeverCharacter
        -- Temporary milestone diagnostics were archived in the development tree.
        M.character.guiSecurity, M.character.guiErrors, M.character.guiGroupCount = nil, nil, nil
        -- Preview 1 stored enablement account-wide. Only migrate characters
        -- that actually have a MazzleUI layout; do not alter other characters.
        if type(M.character.enabled) ~= "boolean" then
            M.character.enabled = type(M.character.layoutName) == "string" and M.db.enabled ~= false
        end
        for key, default in pairs(M.defaults) do
            if type(M.db[key]) ~= type(default) then M.db[key] = default end
        end
        if not M.skins[M.db.skin] then M.db.skin = M.defaults.skin end
        if M.db.scale ~= M.db.scale then M.db.scale = 1 end
        M.db.scale = math.max(0.75, math.min(1.25, M.db.scale))
        SlashCmdList.MAZZLEUIFOREVER = M.Command
        SLASH_MAZZLEUIFOREVER1, SLASH_MAZZLEUIFOREVER2 = "/mazzle", "/mazzleui"
        SlashCmdList.MAZZIFIERFOREVER = M.OpenInstaller
        SLASH_MAZZIFIERFOREVER1 = "/mazzify"
        -- Bindings.xml is loaded independently by WoW; keep its legacy entrypoints valid.
        MazzleUI = M
        MazzleUI_Settings = MazzleUI_Settings or {}
        M.BindContextMenu = M.ToggleContext
        M.nQuestToggle = function() ToggleQuestLog() end
        M.NextView = function() M.OpenOptions() end
        M.RaidViewSet = function() M.OpenOptions() end
    elseif initialized and event=="ADDON_LOADED" and (name=="Blizzard_DamageMeter" or name=="Blizzard_TimeManager") then
        M.RequestLayout()
    elseif event == "PLAYER_LOGIN" then Initialize()
    elseif initialized and event == "PLAYER_REGEN_ENABLED" then
        M.ResumeLayout()
    elseif initialized and (event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") then
        M.RequestLayout()
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
    M.events:RegisterEvent(event)
end
