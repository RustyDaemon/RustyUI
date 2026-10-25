local wow = require("tests.support.wow")

-- The kit is RustyKit's, synced in, and RustyKit's own specs cover it; these are the parts that are
-- RustyUI's: where its copy of the font lives, what its skins draw when that file cannot load, and
-- the kit's borders drawn the way the skins draw their lines.

describe("the kit in RustyUI", function()
    local ns

    before_each(function()
        ns = wow.load()
    end)

    it("draws Rusty Pixel from RustyUI's own kit folder, which ships the file", function()
        ns.UI:setFont("pixel")

        local path = ns.UI.font:gsub("^Interface\\AddOns\\RustyUI\\", ""):gsub("\\", "/")
        local file = io.open(wow.ROOT .. "/" .. path, "rb")

        assert.are.equal("Interface\\AddOns\\RustyUI\\kit\\fonts\\RustyPixel.ttf", ns.UI.font)
        assert.is_not_nil(file, path .. " is not in the addon")
        file:close()
    end)

    it("skins text in the game's font when Rusty Pixel's file cannot be loaded, rather than none", function()
        wow.frames.unloadable["Interface\\AddOns\\RustyUI\\kit\\fonts\\RustyPixel.ttf"] = true

        ns.UI:setFont("pixel")

        local text = wow.frames.new("FontString")
        ns.Skin:font(text, 12)

        assert.are.equal("Fonts\\FRIZQT__.TTF", text.font)
        assert.are.equal("Fonts\\FRIZQT__.TTF", ns.UI.fontNumber)
    end)

    it("draws its borders one physical pixel thick and unsnapped, as the skins draw their lines", function()
        wow.screenHeight = 1080

        local panel = ns.UI:panel(UIParent, "panel", true)
        local px = ns.Skin:pixel(panel)
        local edges = panel.borderTextures

        assert.are.equal(768 / 1080, px)
        assert.are.same({ px, px, px, px }, { edges[1].height, edges[2].height, edges[3].width, edges[4].width })
        assert.are.equal(1, edges[1].calls.SetSnapToPixelGrid)
    end)
end)
