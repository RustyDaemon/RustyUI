local wow = require("tests.support.wow")

describe("RustyUI.toc", function()
    it("lists only files that exist", function()
        for _, path in ipairs(wow.tocFiles()) do
            local file = io.open(wow.ROOT .. "/" .. path, "r")

            assert.is_not_nil(file, path .. " is in the .toc but not on disk")
            file:close()
        end
    end)

    it("loads every file in order, each finding what the files before it set up", function()
        local ns = wow.load()

        assert.is_table(ns.RUI)
        assert.is_table(ns.UI)
        assert.is_table(ns.Skin)
        assert.is_table(ns.Settings)
        assert.is_table(ns.RUI.options)
    end)

    it("registers every module under a key the defaults know", function()
        local ns = wow.load()

        assert.is_true(#ns.RUI.modules > 0)

        for _, module in ipairs(ns.RUI.modules) do
            assert.is_not_nil(ns.RUI.defaults.modules[module.key],
                module.key .. " has no entry in the defaults' modules")
        end
    end)
end)
