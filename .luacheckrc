-- luacheck configuration for RustyUI
--
-- Run with:  luacheck .
--
-- Everything is checked against the WoW client's global namespace, declared below: the client
-- provides these, so reading them is fine and writing them is not. RustyUI reaches many of
-- Blizzard's frames by name through Skin:get("PlayerFrame.PlayerFrameContainer...") and _G[name],
-- which luacheck cannot see and does not need to.

std = "lua51"          -- the WoW client runs Lua 5.1
codes = true           -- print the warning code, so it can be looked up or ignored
max_line_length = 120

exclude_files = {
    "dist",            -- build output
}

ignore = {
    "212",             -- unused argument: hooks and scripts are handed (self, event, ...) whether
                       -- or not they need them. 211 (unused local) stays on: it catches dead code.
    "213",             -- unused loop variable (common in `for _, v in pairs`)
    "432/self",        -- a script set inside a kit method takes its own self, the frame it runs
                       -- on: button:SetScript("OnClick", function(self) ...) is the client's idiom
}

-- Written by RustyUI.
globals = {
    "RustyUIDB",                          -- SavedVariables, written by the client
    "SLASH_RUSTYUI1", "SLASH_RUSTYUI2",   -- /rui and /rustyui
    "SlashCmdList",                       -- the slash command is added to this table
    "RustyUI_OnAddonCompartmentClick",    -- named by the .toc's AddonCompartmentFunc
    "GetMinimapShape",                    -- tells minimap button addons the map is square
}

-- WoW client API. Readable, never assigned.
read_globals = {
    -- namespaced client API
    "C_AddOns", "C_Container", "C_Item", "C_Map", "C_PvP", "C_Reputation", "C_Timer", "Enum",
    "LibStub",

    -- frames and UI plumbing
    "CreateColor", "CreateFrame", "GetCursorPosition", "GetPhysicalScreenSize", "hooksecurefunc",
    "InCombatLockdown", "PlaySound", "ReloadUI", "SOUNDKIT", "UIParent", "UISpecialFrames",
    "GameFontNormal", "NumberFontNormal", "GameTooltip", "GameTooltipStatusBar", "TooltipDataProcessor",
    "StaticPopup_Show", "EditModeManagerFrame",

    -- the frames the modules skin
    "ActionButton1", "ActionButton12", "MultiBarBottomLeft", "ExtraActionButton1", "ZoneAbilityFrame",
    "CharacterMicroButton", "MainMenuBarBackpackButton", "MICRO_BUTTONS", "MicroButtonPulse",
    "MicroButtonPulseStop",
    "BagItemSearchBox", "ContainerFrameCombinedBags", "ContainerFrame_Update", "NUM_CONTAINER_FRAMES",
    "PlayerFrame",
    "Minimap", "MinimapCluster", "MiniMapTracking", "MinimapZoneText", "MinimapZoneTextButton",
    "GameTimeFrame", "TimeManagerClockButton", "HybridMinimap",
    "BuffFrame", "DebuffFrame", "AuraButton_Update", "BUFF_MAX_DISPLAY", "DEBUFF_MAX_DISPLAY",
    "DebuffTypeColor",
    "CHAT_FRAMES", "GENERAL_CHAT_DOCK", "FCF_OpenTemporaryWindow", "FCFDock_GetSelectedWindow",
    "FCFDock_SelectWindow",
    "ObjectiveTrackerFrame",
    "GameMenuFrame", "GameMenuFrameHeader",
    "MirrorTimerContainer", "MirrorTimer_Show", "MirrorTimerColors", "MIRRORTIMER_NUMTIMERS", "TimerTracker",

    -- units, colors and the XP bar's numbers
    "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitClassification", "UnitExists", "UnitIsPlayer",
    "UnitIsTapDenied", "UnitLevel", "UnitPowerType", "UnitReaction", "UnitXP", "UnitXPMax",
    "GetXPExhaustion", "IsXPUserDisabled", "GetMaxLevelForPlayerExpansion", "GetMaxPlayerLevel",
    "MAX_PLAYER_LEVEL", "GetWatchedFactionInfo", "SetPortraitTexture",
    "CUSTOM_CLASS_COLORS", "RAID_CLASS_COLORS", "FACTION_BAR_COLORS", "PowerBarColor", "ITEM_QUALITY_COLORS",

    -- the minimap's zone, clock and coordinates
    "GetMinimapZoneText", "GetZonePVPInfo", "GetGameTime", "GetNetStats",

    -- items, for quality borders
    "GetContainerItemInfo", "GetItemInfo", "GetFileIDFromPath",

    -- older clients' names for the C_AddOns calls
    "GetAddOnMetadata", "IsAddOnLoaded",

    -- localised labels
    "CANCEL", "CLOSE", "LEVEL", "NO", "REPUTATION", "SETTINGS", "XP", "YES",

    -- helpers the client keeps from Lua 5.0 and adds of its own
    "BreakUpLargeNumbers", "tContains", "tinsert", "unpack", "wipe",

    -- tells a value the client will not let an addon read from one it will; absent on a client
    -- older than the secret values it answers about
    "issecretvalue",
}

-- The suite runs under busted, not in the client: tests/support/wow.lua installs the client API
-- into _G, and the busted std supplies describe / it / before_each / assert.
files["tests/**/*.lua"] = {
    std = "max+busted",
    read_globals = { "UIParent", "RustyUISettingsFrame" },
    globals = { "print" },              -- settings_spec catches what RUI:safe reports
}

-- The stubs build the fake client, so they write the globals the addon only reads.
files["tests/support/*.lua"] = {
    std = "max+busted",
    globals = {
        "UIParent", "CreateFrame", "CreateColor", "GameFontNormal", "NumberFontNormal", "GameTooltip",
        "issecretvalue", "hooksecurefunc", "C_AddOns", "C_Timer", "GetPhysicalScreenSize",
        "InCombatLockdown", "PlaySound", "SOUNDKIT", "GetCursorPosition", "ReloadUI", "UISpecialFrames",
        "SlashCmdList", "tinsert", "tContains", "wipe", "unpack", "RustyUIDB",
        "CANCEL", "CLOSE", "SETTINGS", "YES", "NO",
    },
}
