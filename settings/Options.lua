--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Every RustyUI option, in AceConfig's shape: the top level's loose options make the General
-- page and each group a page of its own. A new option needs only a new entry here.

local _, ns = ...

local RUI, UI = ns.RUI, ns.UI

local function setting(section, key, live)
    return function() return RUI.db[section][key] end, function(_, value)
        RUI.db[section][key] = value

        if (live) then
            RUI:refresh(live)
        else
            RUI:markReload()
        end
    end
end

local function moduleToggle(key, name, desc, order)
    return {
        type = "toggle",
        name = name,
        desc = desc,
        order = order,
        get = function() return RUI:isEnabled(key) end,
        set = function(_, value)
            RUI.db.modules[key] = value
            RUI:markReload()
        end,
    }
end

local function moduleOff(key)
    return function() return not RUI:isEnabled(key) end
end

local hotkeysGet, hotkeysSet = setting("actionbars", "hotkeys", "actionbars")
local macroGet, macroSet = setting("actionbars", "macroNames", "actionbars")
local emptyGet, emptySet = setting("actionbars", "emptySlots", "actionbars")
local classGet, classSet = setting("unitframes", "classColors", "unitframes")
local bagQualityGet, bagQualitySet = setting("bags", "qualityBorders", "bags")
local tipQualityGet, tipQualitySet = setting("tooltips", "qualityBorders", "tooltips")

-- Each XP bar look keeps a height of its own; only the selected look's slider shows.
local function xpHeight(style, order)
    return {
        type = "range", order = order, name = "Height", min = style.min, max = style.max, step = 1,
        desc = "How tall the " .. style.text:lower() .. " bar is. Each style keeps its own height.",
        get = function() return RUI:xpHeight(style.value) end,
        set = function(_, value)
            RUI.db.xpbar.heights[style.value] = value
            RUI:refresh("xpbar")
        end,
        disabled = moduleOff("xpbar"),
        hidden = function() return RUI.db.xpbar.style ~= style.value end,
    }
end

local options = {
    args = {
        intro = {
            type = "description",
            order = 1,
            name = "RustyUI is a clean, flat reskin of Blizzard's own action bars, bags, unit frames and "
                .. "more. Frames keep their places and behavior; only their look changes.",
        },
        accentHeader = { type = "header", order = 2, name = "Accent color" },
        accent = {
            type = "accents",
            order = 3,
            name = "Accent color",
            get = function() return RUI.db.accent end,
            set = function(_, value)
                RUI.db.accent = value
                RUI:markReload()
            end,
        },
        accentBorders = {
            type = "toggle",
            order = 4,
            name = "Accent-colored borders",
            desc = "Borders take the accent color instead of grey. Takes effect after a reload.",
            get = function() return RUI.db.accentBorders end,
            set = function(_, value)
                RUI.db.accentBorders = value
                RUI:markReload()
            end,
        },
        fontHeader = { type = "header", order = 5, name = "Font" },
        font = {
            type = "select",
            order = 6,
            name = "Font",
            desc = "The font of RustyUI's windows and the numbers on skinned frames. Takes effect after a reload.",
            values = function()
                local values = {}

                for _, preset in ipairs(UI.fonts) do values[preset.value] = preset.text end

                return values
            end,
            sorting = { "blizzard", "pixel" },
            get = function() return RUI.db.font end,
            set = function(_, value)
                RUI.db.font = value
                RUI:markReload()
            end,
        },
        fontSize = {
            type = "range",
            order = 7,
            name = "Font size (%)",
            min = 80, max = 140, step = 5,
            desc = "Scales all of RustyUI's text, 100 being its normal size. Sizes round to whole "
                .. "pixels, which keeps Rusty Pixel sharp. Takes effect after a reload.",
            get = function() return RUI.db.fontSize end,
            set = function(_, value)
                RUI.db.fontSize = value
                RUI:markReload()
            end,
        },
        modulesHeader = { type = "header", order = 10, name = "Modules" },
        modulesNote = {
            type = "description",
            order = 11,
            name = "A skin cannot be taken off a frame while the game runs, so turning a module off takes "
                .. "effect after a reload.",
        },
        actionbarsModule = moduleToggle("actionbars", "Action bars",
            "Square buttons, flat press and highlight, no bar art", 12),
        menubarModule = moduleToggle("menubar", "Menu and bags",
            "The micro menu as kit tiles and the bag bar as square slots", 12.5),
        xpbarModule = moduleToggle("xpbar", "XP bar",
            "RustyUI's own experience and reputation bar in place of Blizzard's", 12.6),
        bagsModule = moduleToggle("bags", "Bags", "Bag windows and slots", 13),
        unitframesModule = moduleToggle("unitframes", "Unit frames",
            "Player, target, focus, pet, party and boss frames", 14),
        minimapModule = moduleToggle("minimap", "Minimap", "A square minimap with a thin border", 15),
        tooltipsModule = moduleToggle("tooltips", "Tooltips", "Flat tooltips with quality-colored borders", 16),
        castbarsModule = moduleToggle("castbars", "Cast bars", "Flat cast bars, colored by cast type", 17),
        aurasModule = moduleToggle("auras", "Buffs and debuffs", "Square aura icons", 18),
        chatModule = moduleToggle("chat", "Chat", "Chat tabs and the input box", 19),
        trackerModule = moduleToggle("tracker", "Objective tracker",
            "Kit headings and square quest item buttons", 20),
        popupsModule = moduleToggle("popups", "Popups and game menu",
            "Confirmation popups and the Escape menu as kit windows", 21),
        timersModule = moduleToggle("timers", "Timers and extra button",
            "Flat breath, fatigue and countdown bars; square extra action and zone ability buttons", 22),
        talentsModule = moduleToggle("talents", "Talents window",
            "The talents window and its tabs; square talents bordered in their state color", 23),
        resetHeader = { type = "header", order = 30, name = "Reset" },
        reset = {
            type = "execute",
            order = 31,
            name = "Reset settings",
            desc = "Puts every RustyUI setting back to its default and reloads the UI",
            func = function()
                UI:confirm({
                    title = "Reset RustyUI settings?",
                    text = "Every module comes back on, with the gold accent, and the UI reloads.",
                    acceptText = "Reset and reload",
                    cancelText = CANCEL,
                    danger = true,
                    onAccept = function()
                        RustyUIDB = nil
                        ReloadUI()
                    end,
                })
            end,
        },

        actionbars = {
            type = "group",
            order = 100,
            name = "Action bars",
            args = {
                hotkeys = {
                    type = "toggle", order = 1, name = "Show keybindings",
                    desc = "The key bound to each button, in its top right corner",
                    get = hotkeysGet, set = hotkeysSet, disabled = moduleOff("actionbars"),
                },
                macroNames = {
                    type = "toggle", order = 2, name = "Show macro names",
                    desc = "The name of a macro along the bottom of its button",
                    get = macroGet, set = macroSet, disabled = moduleOff("actionbars"),
                },
                emptySlots = {
                    type = "toggle", order = 3, name = "Show empty slots",
                    desc = "Buttons with nothing on them keep their slot. Without this, empty slots "
                        .. "show only while a spell or item is being dragged.",
                    get = emptyGet, set = emptySet, disabled = moduleOff("actionbars"),
                },
                spacingHeader = { type = "header", order = 10, name = "Spacing" },
                editModeNote = {
                    type = "description",
                    order = 11,
                    name = "Bars are placed by Edit Mode here: open it from the game menu, select a bar "
                        .. "and change its Padding, or drag the bars apart.",
                    hidden = function() return not RUI:barsUseEditMode() end,
                },
                spacing = {
                    type = "range", order = 12, name = "Button spacing", min = 0, max = 12, step = 1,
                    desc = "The gap between the buttons of each bar. Wider gaps make the bars longer.",
                    get = function() return RUI.db.actionbars.spacing or 6 end,
                    set = function(_, value)
                        RUI.db.actionbars.spacing = value
                        RUI:refresh("actionbars")
                    end,
                    disabled = moduleOff("actionbars"),
                    hidden = function() return RUI:barsUseEditMode() end,
                },
                barGap = {
                    type = "range", order = 13, name = "Gap between bars", min = 0, max = 24, step = 1,
                    desc = "Extra room above the main bar, so the bars stacked on it, and the pet and "
                        .. "stance bars, sit further apart.",
                    get = function() return RUI.db.actionbars.barGap or 0 end,
                    set = function(_, value)
                        RUI.db.actionbars.barGap = value
                        RUI:refresh("actionbars")
                    end,
                    disabled = moduleOff("actionbars"),
                    hidden = function() return RUI:barsUseEditMode() end,
                },
                defaultSpacing = {
                    type = "execute", order = 14, name = "Blizzard's spacing",
                    desc = "Puts the bars and buttons back where Blizzard places them",
                    func = function()
                        RUI.db.actionbars.spacing = nil
                        RUI.db.actionbars.barGap = 0
                        RUI:refresh("actionbars")
                    end,
                    disabled = moduleOff("actionbars"),
                    hidden = function() return RUI:barsUseEditMode() end,
                },
            },
        },
        minimap = {
            type = "group",
            order = 105,
            name = "Minimap",
            args = {
                style = {
                    type = "previews", order = 1, name = "Style", columns = 5, cardHeight = 112,
                    items = function() return RUI.minimapStyles end,
                    draw = function(holder, value) RUI:drawMinimapPreview(holder, value) end,
                    get = function() return RUI.db.minimap.style end,
                    set = function(_, value)
                        RUI.db.minimap.style = value
                        RUI:refresh("minimap")
                    end,
                    disabled = moduleOff("minimap"),
                },
                styleNote = {
                    type = "description",
                    order = 2,
                    name = "Click a style to switch to it; it changes right away. Window adds the zone "
                        .. "above the map and coordinates and time below it.",
                },
                dayNight = {
                    type = "toggle", order = 3, name = "Show day/night indicator",
                    desc = "The sun dial at the minimap's edge",
                    get = function() return RUI.db.minimap.dayNight end,
                    set = function(_, value)
                        RUI.db.minimap.dayNight = value
                        RUI:refresh("minimap")
                    end,
                    disabled = moduleOff("minimap"),
                    hidden = function() return not RUI:dayNightIndicator() end,
                },
                edgeDistance = {
                    type = "range", order = 4, name = "Edge distance", min = 0, max = 30, step = 1,
                    desc = "How far the zone, clock and tracking above the map, coordinates under it "
                        .. "and minimap buttons stand off the map's edge.",
                    get = function() return RUI.db.minimap.edgeDistance or 5 end,
                    set = function(_, value)
                        RUI.db.minimap.edgeDistance = value
                        RUI:refresh("minimap")
                    end,
                    disabled = moduleOff("minimap"),
                },
                defaultEdge = {
                    type = "execute", order = 5, name = "Blizzard's placement",
                    desc = "Puts everything around the map back where Blizzard and the addons place it",
                    func = function()
                        RUI.db.minimap.edgeDistance = nil
                        RUI:refresh("minimap")
                    end,
                    disabled = moduleOff("minimap"),
                },
            },
        },
        xpbar = {
            type = "group",
            order = 107,
            name = "XP bar",
            args = {
                style = {
                    type = "previews", order = 1, name = "Style", columns = 2, cardHeight = 64,
                    items = function() return RUI.xpStyles end,
                    draw = function(holder, value) RUI:drawXPPreview(holder, value) end,
                    get = function() return RUI.db.xpbar.style end,
                    set = function(_, value)
                        RUI.db.xpbar.style = value
                        RUI:refresh("xpbar")
                    end,
                    disabled = moduleOff("xpbar"),
                },
                styleNote = {
                    type = "description",
                    order = 2,
                    name = "Click a style to switch to it; it changes right away. The previews show "
                        .. "sample numbers, so they can be compared at any level. Hover the real bar for "
                        .. "the full numbers. At the level cap it shows your watched reputation instead.",
                },
                slimHeight = xpHeight(RUI.xpStyles[1], 3),
                segmentedHeight = xpHeight(RUI.xpStyles[2], 3),
                panelHeight = xpHeight(RUI.xpStyles[3], 3),
                edgeHeight = xpHeight(RUI.xpStyles[4], 3),
                defaultHeight = {
                    type = "execute", order = 4, name = "Default height",
                    desc = "Puts the selected style back to its own height",
                    func = function()
                        RUI.db.xpbar.heights[RUI.db.xpbar.style] = nil
                        RUI:refresh("xpbar")
                    end,
                    disabled = moduleOff("xpbar"),
                },
            },
        },
        castbars = {
            type = "group",
            order = 108,
            name = "Cast bars",
            args = {
                style = {
                    type = "previews", order = 1, name = "Style", columns = 4, cardHeight = 76,
                    items = function() return RUI.castStyles end,
                    draw = function(holder, value) RUI:drawCastPreview(holder, value) end,
                    get = function() return RUI.db.castbars.style end,
                    set = function(_, value)
                        RUI.db.castbars.style = value
                        RUI:refresh("castbars")
                    end,
                    disabled = moduleOff("castbars"),
                },
                styleNote = {
                    type = "description",
                    order = 2,
                    name = "Click a style to switch to it; it changes right away. Framed, Thick and "
                        .. "Minimal show the time left; the player's bar marks your latency at its end, "
                        .. "where a spell can already be queued.",
                },
            },
        },
        unitframes = {
            type = "group",
            order = 110,
            name = "Unit frames",
            args = {
                classColors = {
                    type = "toggle", order = 1, name = "Class-colored health",
                    desc = "Players' health bars in their class color; everyone else by reaction",
                    get = classGet, set = classSet, disabled = moduleOff("unitframes"),
                },
            },
        },
        bags = {
            type = "group",
            order = 120,
            name = "Bags",
            args = {
                qualityBorders = {
                    type = "toggle", order = 1, name = "Quality borders",
                    desc = "Slots of uncommon and better items bordered in the item's quality color",
                    get = bagQualityGet, set = bagQualitySet, disabled = moduleOff("bags"),
                },
            },
        },
        tooltips = {
            type = "group",
            order = 130,
            name = "Tooltips",
            args = {
                qualityBorders = {
                    type = "toggle", order = 1, name = "Quality borders",
                    desc = "Item tooltips bordered in the item's quality color",
                    get = tipQualityGet, set = tipQualitySet, disabled = moduleOff("tooltips"),
                },
            },
        },
    },
}

RUI.options = options
