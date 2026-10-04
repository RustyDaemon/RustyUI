local wow = require("tests.support.wow")

local PIXEL_FONT = "Interface\\AddOns\\RustyUI\\media\\fonts\\RustyPixel.ttf"

describe("the kit's palette", function()
    local UI

    before_each(function()
        UI = wow.load().UI
    end)

    it("swaps in an accent preset by its key", function()
        UI:setAccent("teal")

        local r, g, b = UI:rgb("accent")

        assert.are.same({ 0.345, 0.827, 0.784 }, { r, g, b })
    end)

    it("keeps the current accent for a key it does not know", function()
        UI:setAccent("teal")
        UI:setAccent("chartreuse")

        assert.are.equal(0.345, (UI:rgb("accent")))
    end)

    it("draws borders in a shade of the accent while accent borders are on, grey again when off", function()
        local grey = { UI:rgb("border") }

        UI:setAccent("violet")
        UI:setAccentBorders(true)

        assert.are_not.same(grey, { UI:rgb("border") })
        assert.are.same({ UI:rgb("accentDim") }, { UI:rgb("borderLight") })

        UI:setAccentBorders(false)

        assert.are.same(grey, { UI:rgb("border") })
    end)

    it("hands back alpha, 1 when none is asked for", function()
        assert.are.equal(1, select(4, UI:rgb("text")))
        assert.are.equal(0.5, select(4, UI:rgb("text", 0.5)))
    end)
end)

describe("the kit's font", function()
    local UI

    before_each(function()
        UI = wow.load().UI
    end)

    it("is Blizzard's until another is chosen", function()
        assert.are.equal("Fonts\\FRIZQT__.TTF", UI.font)
        assert.are.equal("Fonts\\FRIZQT__.TTF", UI.fontNumber)
    end)

    it("is Rusty Pixel, for text and numbers alike, once chosen", function()
        UI:setFont("pixel")

        assert.are.equal(PIXEL_FONT, UI.font)
        assert.are.equal(PIXEL_FONT, UI.fontNumber)
    end)

    it("falls back to Blizzard's for a key it does not know", function()
        UI:setFont("pixel")
        UI:setFont("comic sans")

        assert.are.equal("Fonts\\FRIZQT__.TTF", UI.font)
    end)

    it("ships every font file it offers", function()
        for _, preset in ipairs(UI.fonts) do
            if (preset.file) then
                local path = preset.file:gsub("^Interface\\AddOns\\RustyUI\\", ""):gsub("\\", "/")
                local file = io.open(wow.ROOT .. "/" .. path, "rb")

                assert.is_not_nil(file, preset.text .. " points at " .. path .. ", which is not in the addon")
                file:close()
            end
        end
    end)

    it("gives new text the chosen font", function()
        UI:setFont("pixel")

        local text = UI:text(UIParent, 12)

        assert.are.equal(PIXEL_FONT, text.font)
    end)
end)

describe("the kit's font size", function()
    local UI

    before_each(function()
        UI = wow.load().UI
    end)

    it("leaves sizes alone at 100%", function()
        UI:setFontScale(100)

        assert.are.equal(12, UI:fontSize(12))
    end)

    it("scales and rounds to whole pixels, so a pixel font stays sharp", function()
        UI:setFontScale(115)

        assert.are.equal(14, UI:fontSize(12))   -- 13.8
        assert.are.equal(13, UI:fontSize(11))   -- 12.65
    end)

    it("never goes below 6", function()
        UI:setFontScale(10)

        assert.are.equal(6, UI:fontSize(12))
    end)

    it("treats a missing or broken setting as 100%", function()
        UI:setFontScale(nil)
        assert.are.equal(12, UI:fontSize(12))

        UI:setFontScale("big")
        assert.are.equal(12, UI:fontSize(12))
    end)

    it("reaches new text", function()
        UI:setFontScale(125)

        assert.are.equal(15, UI:text(UIParent, 12).fontSize)
        assert.are.equal(15, UI:text(UIParent).fontSize)   -- the default 12
    end)
end)
