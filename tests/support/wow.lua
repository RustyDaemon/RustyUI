-- The client RustyUI loads into, for specs run under busted: its globals, its hooks, Midnight's
-- secret values, and a loader that runs the addon's files in .toc order with one shared namespace,
-- as the client does.

local frames = require("tests.support.frames")

local wow = {}

wow.ROOT = os.getenv("RUI_ROOT") or "."
wow.frames = frames

-- Files the .toc lists, in order, with forward slashes.
function wow.tocFiles()
    local files = {}

    for raw in io.lines(wow.ROOT .. "/RustyUI.toc") do
        local line = raw:gsub("\r$", ""):gsub("\\", "/")

        if (line ~= "" and not line:match("^#")) then files[#files+1] = line end
    end

    return files
end

-- Secrets are values an addon may pass on but not read. A spec makes one with wow.secret().
local secrets = setmetatable({}, { __mode = "k" })

function wow.secret()
    local value = {}

    secrets[value] = true

    return value
end

local function install()
    frames.install()

    _G.issecretvalue = function(value) return type(value) == "table" and secrets[value] == true end

    -- hooksecurefunc(table, "method", fn) or hooksecurefunc("global", fn): fn runs after the original.
    _G.hooksecurefunc = function(target, method, hook)
        if (type(target) == "string") then
            target, method, hook = _G, target, method
        end

        local original = target[method]

        assert(type(original) == "function", "hooksecurefunc: no function " .. tostring(method))

        rawset(target, method, function(...)
            local results = { original(...) }

            hook(...)

            return unpack(results)
        end)
    end

    _G.C_AddOns = {
        GetAddOnMetadata = function(_, field) return field == "Version" and "0.0.0" or nil end,
        IsAddOnLoaded = function() return false end,
    }

    _G.C_Timer = { After = function(_, fn) fn() end }

    wow.screenHeight = 1080
    _G.GetPhysicalScreenSize = function() return 1920, wow.screenHeight end

    _G.InCombatLockdown = function() return false end
    _G.PlaySound = function() end
    _G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
    _G.GetCursorPosition = function() return 0, 0 end
    _G.ReloadUI = function() wow.reloaded = true end

    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.tinsert = table.insert
    _G.tContains = function(list, value)
        for i = 1, #list do
            if (list[i] == value) then return true end
        end

        return false
    end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.unpack = unpack

    _G.CANCEL, _G.CLOSE, _G.SETTINGS, _G.YES, _G.NO = "Cancel", "Close", "Settings", "Yes", "No"
end

-- Loads every file the .toc lists, or those up to and including `last`, and returns the namespace.
function wow.load(last)
    install()

    local ns = {}

    for _, path in ipairs(wow.tocFiles()) do
        local chunk = assert(loadfile(wow.ROOT .. "/" .. path))

        chunk("RustyUI", ns)

        if (path == last) then break end
    end

    wow.ns = ns

    return ns
end

-- Fires a client event at every frame registered for it.
function wow.fire(event, ...)
    for _, frame in ipairs(frames.all) do
        if (frame.events and frame.events[event]) then frame:Fire("OnEvent", event, ...) end
    end
end

-- The addon's saved variables arriving, as at login; `saved` is RustyUIDB as the client left it.
function wow.addonLoaded(saved)
    _G.RustyUIDB = saved

    wow.fire("ADDON_LOADED", "RustyUI")

    return wow.ns.RUI.db
end

return wow
