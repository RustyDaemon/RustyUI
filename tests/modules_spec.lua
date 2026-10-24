local wow = require("tests.support.wow")

-- Skins one module the way login does, so its options can refresh it afterwards.
local function applyModule(ns, key)
    for _, module in ipairs(ns.RUI.modules) do
        if (module.key == key) then module.applied = ns.RUI:safe(module.name, module.apply) end
    end
end

describe("short keybindings", function()
    local RUI

    before_each(function()
        RUI = wow.load().RUI
    end)

    it("write each modifier as a letter ahead of the key", function()
        assert.are.equal("1", RUI:shortKey("1"))
        assert.are.equal("s1", RUI:shortKey("SHIFT-1"))
        assert.are.equal("cQ", RUI:shortKey("CTRL-Q"))
        assert.are.equal("acsF10", RUI:shortKey("ALT-CTRL-SHIFT-F10"))
    end)

    it("cut long key names down", function()
        assert.are.equal("M4", RUI:shortKey("BUTTON4"))
        assert.are.equal("sM12", RUI:shortKey("SHIFT-BUTTON12"))
        assert.are.equal("cWU", RUI:shortKey("CTRL-MOUSEWHEELUP"))
        assert.are.equal("N5", RUI:shortKey("NUMPAD5"))
        assert.are.equal("N+", RUI:shortKey("NUMPADPLUS"))
        assert.are.equal("aSp", RUI:shortKey("ALT-SPACE"))
    end)

    it("keep a key that is itself a dash", function()
        assert.are.equal("-", RUI:shortKey("-"))
        assert.are.equal("s-", RUI:shortKey("SHIFT--"))
    end)

    it("leave gamepad buttons and missing keys to Blizzard", function()
        assert.is_nil(RUI:shortKey("PAD1"))
        assert.is_nil(RUI:shortKey("PADLTRIGGER-PADDUP"))
        assert.is_nil(RUI:shortKey(nil))
        assert.is_nil(RUI:shortKey(""))
    end)
end)

describe("keybindings on action buttons", function()
    local ns, button, bindings

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)

        bindings = { ACTIONBUTTON1 = "SHIFT-BUTTON4" }
        _G.GetBindingKey = function(command) return bindings[command] end
        _G.RANGE_INDICATOR = "*"

        button = CreateFrame("CheckButton", "ActionButton1")
        button.HotKey = button:CreateFontString()
        button.HotKey:SetText("s-Mouse Button 4")

        applyModule(ns, "actionbars")
    end)

    after_each(function()
        _G.ActionButton1, _G.GetBindingKey, _G.RANGE_INDICATOR = nil, nil, nil
    end)

    it("are written short once the button is skinned", function()
        assert.are.equal("sM4", button.HotKey:GetText())
    end)

    it("are written short again when Blizzard redraws them for a new binding", function()
        bindings.ACTIONBUTTON1 = "CTRL-NUMPAD5"
        button.HotKey:SetText("c-Num Pad 5")

        assert.are.equal("cN5", button.HotKey:GetText())
    end)

    it("follow the binding Blizzard notes on the button over the bar's own", function()
        bindings.MULTIACTIONBAR1BUTTON1 = "ALT-E"
        button.bindingAction = "MULTIACTIONBAR1BUTTON1"
        button.HotKey:SetText("a-E")

        assert.are.equal("aE", button.HotKey:GetText())
    end)

    it("go back to Blizzard's text when short keys are turned off, and short again when on", function()
        local option = ns.RUI.options.args.actionbars.args.shortKeys

        option.set(nil, false)
        assert.are.equal("s-Mouse Button 4", button.HotKey:GetText())

        option.set(nil, true)
        assert.are.equal("sM4", button.HotKey:GetText())
    end)

    it("leave an unbound button's range dot alone", function()
        bindings = {}
        button.HotKey:SetText(RANGE_INDICATOR)

        assert.are.equal(RANGE_INDICATOR, button.HotKey:GetText())
    end)
end)

describe("action buttons out of range", function()
    local ns, button, icon, red

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)

        _G.ActionButton_UpdateRangeIndicator = function() end

        button = CreateFrame("CheckButton", "ActionButton1")
        button.icon = button:CreateTexture()
        icon = button.icon

        applyModule(ns, "actionbars")

        red = { ns.UI:rgb("bad") }
        red[4] = 1
    end)

    after_each(function()
        _G.ActionButton1, _G.ActionButton_UpdateRangeIndicator = nil, nil
    end)

    it("turn red, and stay red when Blizzard tints them for being usable", function()
        ActionButton_UpdateRangeIndicator(button, true, false)
        assert.are.same(red, icon.vertex)

        icon:SetVertexColor(1, 1, 1)
        assert.are.same(red, icon.vertex)
    end)

    it("take Blizzard's last tint back once the target is in range", function()
        ActionButton_UpdateRangeIndicator(button, true, false)
        icon:SetVertexColor(0.5, 0.5, 1)   -- not enough power, while out of range

        ActionButton_UpdateRangeIndicator(button, true, true)
        assert.are.same({ 0.5, 0.5, 1, 1 }, icon.vertex)
    end)

    it("stay white for a spell without a range", function()
        ActionButton_UpdateRangeIndicator(button, false, false)

        assert.is_nil(icon.vertex)
    end)

    it("lose the tint at once when it is turned off", function()
        ActionButton_UpdateRangeIndicator(button, true, false)
        ns.RUI.options.args.actionbars.args.rangeTint.set(nil, false)

        assert.are.same({ 1, 1, 1, 1 }, icon.vertex)
    end)

    it("leave buttons RustyUI did not skin alone", function()
        local other = CreateFrame("CheckButton")

        other.icon = other:CreateTexture()
        ActionButton_UpdateRangeIndicator(other, true, false)

        assert.is_nil(other.icon.vertex)
    end)
end)

describe("short aura timers", function()
    local RUI

    before_each(function()
        RUI = wow.load().RUI
    end)

    it("take Blizzard's steps, without the space or the seconds' unit", function()
        assert.are.equal("45", RUI:shortDuration(45.7))
        assert.are.equal("89", RUI:shortDuration(89))
        assert.are.equal("2m", RUI:shortDuration(90))
        assert.are.equal("13m", RUI:shortDuration(725))
        assert.are.equal("2h", RUI:shortDuration(5400))
        assert.are.equal("2d", RUI:shortDuration(86400 * 1.5))
        assert.are.equal("0", RUI:shortDuration(-0.2))
    end)
end)

describe("aura timers", function()
    local ns, button

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)

        button = CreateFrame("Button")
        button.Icon = button:CreateTexture()
        button.Duration = button:CreateFontString()

        -- Blizzard's own: the time with its unit, in yellow. Only the client can write a secret out.
        button.UpdateDuration = function(self, timeLeft)
            if (issecretvalue(timeLeft)) then return self.Duration:SetText("secret") end

            self.Duration:SetText(("%d m"):format(math.ceil(timeLeft / 60)))
            self.Duration:SetVertexColor(1, 0.82, 0)
        end

        _G.BuffFrame = CreateFrame("Frame", "BuffFrame")
        _G.BuffFrame.auraFrames = { button }

        applyModule(ns, "auras")
    end)

    after_each(function()
        _G.BuffFrame = nil
    end)

    it("are written short after Blizzard writes them", function()
        button:UpdateDuration(725)

        assert.are.equal("13m", button.Duration:GetText())
        assert.are.same({ 1, 0.82, 0, 1 }, button.Duration.vertex)
    end)

    it("turn red in their last seconds", function()
        button:UpdateDuration(3.4)

        assert.are.equal("3", button.Duration:GetText())
        assert.are.same({ ns.UI:rgb("bad") }, button.Duration.vertex)
    end)

    it("keep Blizzard's text and color with both options off", function()
        local options = ns.RUI.options.args.auras.args

        options.shortTimers.set(nil, false)
        options.expiringRed.set(nil, false)
        button:UpdateDuration(3.4)

        assert.are.equal("1 m", button.Duration:GetText())
        assert.are.same({ 1, 0.82, 0, 1 }, button.Duration.vertex)
    end)

    it("keep Blizzard's text for a time left that is a secret", function()
        assert.has_no.errors(function() button:UpdateDuration(wow.secret()) end)
        assert.are.equal("secret", button.Duration:GetText())
    end)
end)

-- A warrior player at "mouseover", a hostile mob at "target" and a mob someone else tapped at "focus".
local WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }
local HOSTILE = { r = 0.8, g = 0.3, b = 0.22 }

local function stubUnits()
    _G.RAID_CLASS_COLORS = { WARRIOR = WARRIOR }
    _G.FACTION_BAR_COLORS = { [2] = HOSTILE, [5] = { r = 0, g = 0.6, b = 0.1 } }

    _G.UnitExists = function(unit)
        if (issecretvalue(unit)) then error("attempt to test a secret value") end

        return unit == "mouseover" or unit == "target" or unit == "focus"
    end

    _G.UnitIsPlayer = function(unit) return unit == "mouseover" end
    _G.UnitClass = function() return "Warrior", "WARRIOR" end
    _G.UnitIsTapDenied = function(unit) return unit == "focus" end
    _G.UnitReaction = function(unit) return unit == "mouseover" and 5 or 2 end
end

local function unstubUnits()
    _G.RAID_CLASS_COLORS, _G.FACTION_BAR_COLORS = nil, nil
    _G.UnitExists, _G.UnitIsPlayer, _G.UnitClass, _G.UnitIsTapDenied, _G.UnitReaction = nil, nil, nil, nil, nil
end

describe("unit colors", function()
    local S

    before_each(function()
        S = wow.load().Skin
        stubUnits()
    end)

    after_each(unstubUnits)

    it("give a player their class color, or their reaction's without class colors", function()
        assert.are.same({ 0.78, 0.61, 0.43 }, { S:unitColor("mouseover", true) })
        assert.are.same({ 0, 0.6, 0.1 }, { S:unitColor("mouseover", false) })
    end)

    it("give a mob its reaction's color, and grey once someone else has tapped it", function()
        assert.are.same({ 0.8, 0.3, 0.22 }, { S:unitColor("target", true) })
        assert.are.same({ 0.5, 0.5, 0.5 }, { S:unitColor("focus", true) })
    end)

    it("are nil without a unit", function()
        assert.is_nil(S:unitColor(nil, true))
        assert.is_nil(S:unitColor("party4", true))
    end)
end)

describe("unit tooltips", function()
    local ns, bar, border, unit

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)
        stubUnits()

        unit = "mouseover"

        GameTooltip.IsForbidden = function() return false end
        GameTooltip.GetUnit = function() return "Rusty", unit end

        bar = CreateFrame("StatusBar", "GameTooltipStatusBar", GameTooltip)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

        -- The tooltip's panel, standing in so its border color can be read back.
        ns.Skin.backdrop = function()
            return { SetBorderColor = function(_, r, g, b) border = { r, g, b } end }
        end

        applyModule(ns, "tooltips")
    end)

    after_each(function()
        unstubUnits()
        _G.GameTooltipStatusBar = nil
    end)

    it("border a player's tooltip in their class color, and color the health bar to match", function()
        GameTooltip:Fire("OnTooltipSetUnit")

        assert.are.same({ 0.78, 0.61, 0.43 }, border)
        assert.are.same({ 0.78, 0.61, 0.43, 1 }, bar.barColor)
    end)

    it("border a mob's tooltip by reaction", function()
        unit = "target"
        GameTooltip:Fire("OnTooltipSetUnit")

        assert.are.same({ 0.8, 0.3, 0.22 }, border)
    end)

    it("keep the health bar in the unit's color when Blizzard recolors it by health", function()
        GameTooltip:Fire("OnTooltipSetUnit")
        bar:SetStatusBarColor(0, 1, 0)

        assert.are.same({ 0.78, 0.61, 0.43, 1 }, bar.barColor)
    end)

    it("leave the border plain and Blizzard's health colors alone with both options off", function()
        local options = ns.RUI.options.args.tooltips.args

        options.unitBorders.set(nil, false)
        options.healthColors.set(nil, false)

        GameTooltip:Fire("OnTooltipSetUnit")
        bar:SetStatusBarColor(0, 1, 0)

        assert.are.same({ ns.UI:rgb("borderLight") }, { border[1], border[2], border[3], 1 })
        assert.are.same({ 0, 1, 0, 1 }, bar.barColor)
    end)

    it("stop coloring the health bar once the tooltip is cleared", function()
        GameTooltip:Fire("OnTooltipSetUnit")
        GameTooltip:Fire("OnTooltipCleared")
        bar:SetStatusBarColor(0, 1, 0)

        assert.are.same({ 0, 1, 0, 1 }, bar.barColor)
    end)

    it("stay plain for a unit that is a secret in Midnight combat", function()
        unit = wow.secret()

        assert.has_no.errors(function() GameTooltip:Fire("OnTooltipSetUnit") end)
        assert.are.same({ ns.UI:rgb("borderLight") }, { border[1], border[2], border[3], 1 })
    end)
end)
