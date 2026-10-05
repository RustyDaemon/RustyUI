--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- RustyUI restyles Blizzard's own frames; it never replaces them. Each module skins one part of the
-- UI once, at login, and keeps it skinned by hooking the places Blizzard redraws it. Retail and
-- WoW Forever name their frames differently, so modules look for both and skin whatever exists.

local ADDON, ns = ...

local RUI = {}
ns.RUI = RUI

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

RUI.version = getMetadata(ADDON, "Version") or ""

local defaults = {
    accent = "gold",
    accentBorders = false,
    font = "blizzard",
    fontSize = 100,
    modules = {
        actionbars = true,
        menubar = true,
        xpbar = true,
        bags = true,
        unitframes = true,
        minimap = true,
        tooltips = true,
        castbars = true,
        auras = true,
        chat = true,
        tracker = true,
        popups = true,
        timers = true,
        talents = true,
    },
    -- spacing is unset by default: Blizzard's own gaps between buttons stand until it is changed.
    actionbars = { hotkeys = true, macroNames = false, emptySlots = false, barGap = 0 },
    minimap = { style = "square", dayNight = true },
    -- heights holds only the styles whose height was changed; the rest use their own default.
    xpbar = { style = "slim", heights = {} },
    castbars = { style = "slim" },
    unitframes = { classColors = true },
    bags = { qualityBorders = true },
    tooltips = { qualityBorders = true },
    ui = {},
}

RUI.defaults = defaults

local function merge(target, source)
    for key, value in pairs(source) do
        if (type(value) == "table") then
            if (type(target[key]) ~= "table") then target[key] = {} end

            merge(target[key], value)
        elseif (target[key] == nil) then
            target[key] = value
        end
    end

    return target
end

-- Modules run in the order they register, which is their order in the .toc.
RUI.modules = {}

function RUI:registerModule(key, name, apply, refresh)
    self.modules[#self.modules+1] = { key = key, name = name, apply = apply, refresh = refresh }
end

function RUI:isEnabled(key)
    return self.db.modules[key] ~= false
end

local reported = {}

-- One broken skin must not take the others with it: a frame a client renamed is reported once and
-- the rest of the UI is skinned anyway.
function RUI:safe(label, fn, ...)
    local ok, err = pcall(fn, ...)

    if (not ok and not reported[label]) then
        reported[label] = true
        print(("|cFFFFD14DRustyUI|r: %s could not be skinned (%s)"):format(label, tostring(err)))
    end

    return ok
end

-- Re-applies a module's live options, such as hiding hotkeys, without a reload.
function RUI:refresh(key)
    for _, module in ipairs(self.modules) do
        if (module.key == key and module.applied and module.refresh) then
            self:safe(module.name, module.refresh)
        end
    end
end

-- Skins cannot be taken off a frame, and the accent is baked into every texture, so turning a
-- module off or changing the accent waits for a reload.
function RUI:markReload()
    self.reloadPending = true

    if (self.refreshSettings) then self:refreshSettings() end
end

local waiting = {}

-- Runs fn once a load-on-demand Blizzard addon is loaded, or now if it already is.
function RUI:onAddon(name, fn)
    if (isAddOnLoaded(name)) then
        self:safe(name, fn)
        return
    end

    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], fn)
end

local function applyModules()
    for _, module in ipairs(RUI.modules) do
        if (RUI:isEnabled(module.key)) then
            module.applied = RUI:safe(module.name, module.apply)
        end
    end
end

local events = CreateFrame("Frame")

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, name)
    if (event == "ADDON_LOADED") then
        if (name == ADDON) then
            RustyUIDB = merge(RustyUIDB or {}, defaults)
            RUI.db = RustyUIDB

            -- Textures take the accent when they are made, so this one stands until a reload.
            RUI.activeAccent = RUI.db.accent
            ns.UI:setAccent(RUI.activeAccent)
            ns.UI:setAccentBorders(RUI.db.accentBorders)
            ns.UI:setFont(RUI.db.font)
            ns.UI:setFontScale(RUI.db.fontSize)
        end

        local queued = waiting[name]

        if (queued) then
            waiting[name] = nil

            for _, fn in ipairs(queued) do RUI:safe(name, fn) end
        end
    elseif (event == "PLAYER_LOGIN") then
        -- Secure frames cannot be touched in combat; a login mid-fight waits for it to end.
        if (InCombatLockdown()) then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            applyModules()
        end
    elseif (event == "PLAYER_REGEN_ENABLED") then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        applyModules()
    end
end)

SLASH_RUSTYUI1 = "/rui"
SLASH_RUSTYUI2 = "/rustyui"

SlashCmdList.RUSTYUI = function()
    RUI:toggleSettings()
end

function RustyUI_OnAddonCompartmentClick()
    RUI:toggleSettings()
end
