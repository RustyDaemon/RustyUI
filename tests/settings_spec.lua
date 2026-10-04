local wow = require("tests.support.wow")

-- Every option in the table, groups opened up, as { key, option } pairs.
local function allOptions(args, list)
    list = list or {}

    for key, option in pairs(args) do
        if (option.type == "group") then
            allOptions(option.args, list)
        else
            list[#list+1] = { key = key, option = option }
        end
    end

    return list
end

describe("the options table", function()
    local ns

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)
    end)

    it("has a row builder for every option type it uses", function()
        for _, entry in ipairs(allOptions(ns.RUI.options.args)) do
            assert.is_function(ns.Settings.builders[entry.option.type],
                entry.key .. " is a " .. tostring(entry.option.type) .. ", which has no row builder")
        end
    end)

    it("gives every dropdown a sorting that lists exactly its values", function()
        for _, entry in ipairs(allOptions(ns.RUI.options.args)) do
            local option = entry.option

            if (option.type == "select") then
                local values = ns.Settings.resolve(option.values, { entry.key }) or {}

                assert.is_table(option.sorting, entry.key .. " has no sorting, so its dropdown cannot open")

                local listed = {}

                for _, value in ipairs(option.sorting) do
                    assert.is_not_nil(values[value],
                        entry.key .. " sorts " .. tostring(value) .. ", which is not a value")
                    listed[value] = true
                end

                for value in pairs(values) do
                    assert.is_true(listed[value] == true, entry.key .. " never shows the value " .. tostring(value))
                end
            end
        end
    end)

    it("gives every slider a range and a default inside it", function()
        for _, entry in ipairs(allOptions(ns.RUI.options.args)) do
            local option = entry.option

            if (option.type == "range") then
                assert.is_true(option.min < option.max, entry.key .. " has an empty range")

                local value = option.get({ entry.key })

                assert.is_number(value, entry.key .. " has no default")
                assert.is_true(value >= option.min and value <= option.max,
                    entry.key .. "'s default is outside its range")
            end
        end
    end)

    it("can read every option with the defaults", function()
        for _, entry in ipairs(allOptions(ns.RUI.options.args)) do
            if (entry.option.get) then
                assert.has_no.errors(function() entry.option.get({ entry.key }) end, entry.key)
            end
        end
    end)
end)

describe("saved settings at login", function()
    it("fill in every default a new install has not saved yet", function()
        local ns = wow.load()
        local db = wow.addonLoaded({ accent = "rust" })

        assert.are.equal("rust", db.accent)
        assert.are.equal("blizzard", db.font)
        assert.are.equal(100, db.fontSize)
        assert.is_true(db.modules.unitframes)
        assert.are.same(ns.RUI.defaults.minimap, db.minimap)
    end)

    it("apply the saved accent, font and font size before anything is drawn", function()
        local ns = wow.load()

        wow.addonLoaded({ accent = "teal", font = "pixel", fontSize = 125 })

        assert.are.equal(0.345, (ns.UI:rgb("accent")))
        assert.is_truthy(ns.UI.font:find("RustyPixel", 1, true))
        assert.are.equal(15, ns.UI:fontSize(12))
    end)
end)

describe("the settings window", function()
    it("opens every page without an error", function()
        local ns = wow.load()

        wow.addonLoaded(nil)

        local printed = {}

        _G.print = function(...) printed[#printed+1] = table.concat({ ... }, " ") end

        ns.RUI:openSettings(1)

        local window = _G.RustyUISettingsFrame

        assert.is_not_nil(window)

        for i = 1, #window.pages do
            assert.has_no.errors(function() ns.RUI:openSettings(i) end, window.pages[i].name)
            assert.is_not_nil(window.pages[i].frame, window.pages[i].name .. " was not built")
        end

        -- Previews draw through RUI:safe, which reports a failure in chat instead of raising it.
        assert.are.same({}, printed)
    end)

    it("offers a reload once a setting that needs one changes", function()
        local ns = wow.load()

        wow.addonLoaded(nil)
        ns.RUI:openSettings(1)

        assert.is_false(_G.RustyUISettingsFrame.reload:IsShown())

        ns.RUI.options.args.font.set(nil, "pixel")

        assert.are.equal("pixel", ns.RUI.db.font)
        assert.is_true(_G.RustyUISettingsFrame.reload:IsShown())
    end)
end)
