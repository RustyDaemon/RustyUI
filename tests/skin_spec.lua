local wow = require("tests.support.wow")

describe("Skin's helpers", function()
    local S

    before_each(function()
        S = wow.load().Skin
    end)

    it("answers true only the first time for an object and tag", function()
        local object = {}

        assert.is_true(S:once(object, "flat"))
        assert.is_false(S:once(object, "flat"))
        assert.is_true(S:once(object, "track"))
        assert.is_false(S:once(nil, "flat"))
    end)

    it("looks up a dotted path, nil when any step is missing", function()
        _G.TestFrame = { Container = { Texture = "found" } }

        assert.are.equal("found", S:get("TestFrame.Container.Texture"))
        assert.is_nil(S:get("TestFrame.Missing.Texture"))
        assert.is_nil(S:get("NoSuchFrame"))

        _G.TestFrame = nil
    end)

    it("knows a secret from an ordinary value", function()
        assert.is_true(S:isSecret(wow.secret()))
        assert.is_false(S:isSecret({}))
        assert.is_false(S:isSecret("Interface\\Buttons\\WHITE8X8"))
    end)
end)

describe("one-pixel lines", function()
    local S

    before_each(function()
        S = wow.load().Skin
    end)

    it("measure one physical pixel in the region's own units", function()
        local region = wow.frames.new("Frame")

        wow.screenHeight = 1080
        assert.are.equal(768 / 1080, S:pixel(region))

        region.scale = 0.5
        assert.are.equal(768 / 1080 / 0.5, S:pixel(region))
    end)

    it("fall back to one unit when the screen size cannot be read", function()
        wow.screenHeight = 0

        assert.are.equal(1, S:pixel(wow.frames.new("Frame")))
    end)

    it("are not snapped to the pixel grid, which can round a side of a border away", function()
        local texture = wow.frames.new("Texture")

        S:crisp(texture)

        assert.are.equal(1, texture.calls.SetSnapToPixelGrid)
    end)
end)

describe("killed textures", function()
    local S

    before_each(function()
        S = wow.load().Skin
    end)

    it("stay hidden when Blizzard shows them again", function()
        local texture = wow.frames.new("Texture")

        S:kill(texture)
        texture:Show()

        assert.is_false(texture:IsShown())
    end)

    it("stay hidden through SetShown, even with a secret flag it may not test", function()
        local texture = wow.frames.new("Texture")

        S:kill(texture)
        texture:SetShown(true)
        assert.is_false(texture:IsShown())

        assert.has_no.errors(function() texture:SetShown(wow.secret()) end)
        assert.is_false(texture:IsShown())
    end)
end)

describe("flat bars", function()
    local S

    before_each(function()
        S = wow.load().Skin
    end)

    local function bar()
        local b = wow.frames.new("StatusBar")

        b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

        return b
    end

    it("take the flat texture, and take it back when Blizzard swaps art in", function()
        local b = bar()

        S:flatBar(b)
        assert.are.equal(S.FLAT, b:GetStatusBarTexture().texture)

        b:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
        assert.are.equal(S.FLAT, b:GetStatusBarTexture().texture)
    end)

    it("take it back when the art is set on the fill texture itself", function()
        local b = bar()

        S:flatBar(b)
        b:GetStatusBarTexture():SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")

        assert.are.equal(S.FLAT, b:GetStatusBarTexture().texture)
    end)

    it("keep Blizzard's secret art, which can be the only sign of an uninterruptible cast", function()
        local b = bar()
        local secret = wow.secret()

        S:flatBar(b)
        b:SetStatusBarTexture(secret)

        assert.are.equal(secret, b:GetStatusBarTexture().texture)
    end)

    it("replace even secret art when forced, so health is never tinted into Blizzard's green", function()
        local b = bar()

        S:flatBar(b, nil, true)
        b:SetStatusBarTexture(wow.secret())
        assert.are.equal(S.FLAT, b:GetStatusBarTexture().texture)

        b:GetStatusBarTexture():SetTexture(wow.secret())
        assert.are.equal(S.FLAT, b:GetStatusBarTexture().texture)
    end)

    it("are recolored after every swap, but not by their own painting", function()
        local b = bar()
        local calls = 0

        S:flatBar(b, function(self)
            calls = calls + 1
            S:paintBar(self, 1, 0, 0)
        end)

        assert.are.equal(1, calls)

        b:SetStatusBarTexture("SomeAtlas")
        assert.are.equal(2, calls)

        b:SetStatusBarColor(0, 1, 0)   -- Blizzard's own color
        assert.are.equal(3, calls)
        assert.are.same({ 1, 0, 0, 1 }, b.barColor)
    end)

    it("tint their empty track a dim shade of the fill", function()
        local b = bar()

        S:barBackdrop(b)
        S:paintTrack(b, 1, 0.5, 0)

        local track = b.regions[#b.regions]

        assert.are.equal(0.22, track.color[1])
        assert.are.equal(0.11, track.color[2])
        assert.are.equal(0, track.color[3])
    end)
end)
