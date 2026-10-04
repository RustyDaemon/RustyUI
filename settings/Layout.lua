--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- What the settings files share: the window's measures, resolve() and the row builders table.

local _, ns = ...

local L = {}
ns.Settings = L

L.WIDTH = 720
L.HEIGHT = 520
L.PAD = 14
L.TITLE_HEIGHT = 44
L.SIDEBAR_WIDTH = 176
L.NAV_HEIGHT = 30
L.SCROLLBAR_WIDTH = 8
L.CONTENT_WIDTH = L.WIDTH - L.SIDEBAR_WIDTH - L.PAD * 4 - L.SCROLLBAR_WIDTH
L.CONTROL_WIDTH = 320
L.GAP = 10
L.WHEEL_STEP = 48

-- An option field is a value or a function of the option's info, as in AceConfig.
function L.resolve(value, info)
    if (type(value) == "function") then return value(info) end

    return value
end

-- builders[type](parent, option, info, changed) makes the row for an option of that type.
L.builders = {}
