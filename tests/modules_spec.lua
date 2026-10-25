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

describe("the main action bar's dividers", function()
    it("are faded out, and stay so when Blizzard shows them again", function()
        local ns = wow.load()

        wow.addonLoaded(nil)

        local button = CreateFrame("CheckButton", "ActionButton1")

        button.RightDivider = CreateFrame("Frame", nil, button)
        button.BottomDivider = CreateFrame("Frame", nil, button)
        button.UpdateButtonArt = function(self) self.RightDivider:Show() end

        applyModule(ns, "actionbars")
        button:UpdateButtonArt()

        assert.are.equal(0, button.RightDivider.alpha)
        assert.are.equal(0, button.BottomDivider.alpha)

        _G.ActionButton1 = nil
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

local EPIC = { 0.64, 0.21, 0.93 }

local function stubQualities()
    _G.ITEM_QUALITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },
        [1] = { r = 1, g = 1, b = 1 },
        [2] = { r = 0.12, g = 1, b = 0 },
        [4] = { r = EPIC[1], g = EPIC[2], b = EPIC[3] },
    }
end

-- An item button as Blizzard builds one: an icon, and the IconBorder it tints by quality.
local function itemButton(name, parent)
    local button = CreateFrame("ItemButton", name, parent)

    button.icon = button:CreateTexture()
    button.IconBorder = button:CreateTexture()
    button.IconBorder:Hide()

    return button
end

-- The slot's 1px border is the one flat texture a skinned item button draws.
local function slotBorder(ns, button)
    for _, region in ipairs(button.regions) do
        if (region.texture == ns.Skin.FLAT) then return region.vertex end
    end
end

-- Blizzard's own quality paint: the border shown and tinted, or hidden for no quality.
local function paintQuality(button, color)
    if (color) then
        button.IconBorder:SetVertexColor(color[1], color[2], color[3])
        button.IconBorder:Show()
    else
        button.IconBorder:Hide()
    end
end

describe("the character window", function()
    local ns, slot, plain

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)
        stubQualities()

        CreateFrame("Frame", "CharacterFrame")
        CreateFrame("Frame", "PaperDollItemsFrame", CharacterFrame)
        slot = itemButton("CharacterHeadSlot", PaperDollItemsFrame)
        _G.CharacterHeadSlotFrame = slot:CreateTexture("CharacterHeadSlotFrame", "BACKGROUND")

        applyModule(ns, "character")

        plain = { ns.UI:rgb("border") }
        plain[4] = 1
    end)

    after_each(function()
        _G.ITEM_QUALITY_COLORS, _G.CharacterFrame, _G.PaperDollItemsFrame = nil, nil, nil
        _G.CharacterHeadSlot, _G.CharacterHeadSlotFrame = nil, nil
    end)

    it("border a piece of gear in its quality color, as Blizzard paints it", function()
        paintQuality(slot, EPIC)

        assert.are.same({ EPIC[1], EPIC[2], EPIC[3], 1 }, slotBorder(ns, slot))
        assert.are.equal(0, slot.IconBorder.alpha)
    end)

    it("leave common gear and an empty slot with the plain border", function()
        paintQuality(slot, { 1, 1, 1 })
        assert.are.same(plain, slotBorder(ns, slot))

        paintQuality(slot, EPIC)
        paintQuality(slot, nil)
        assert.are.same(plain, slotBorder(ns, slot))
    end)

    it("take the slot's frame art away, but keep the icon that shows which piece goes there", function()
        assert.are.equal(0, CharacterHeadSlotFrame.alpha)
        assert.are.equal(1, slot.icon.alpha)
    end)

    it("drop the quality borders at once when they are turned off, and bring them back when on", function()
        local option = ns.RUI.options.args.character.args.qualityBorders

        paintQuality(slot, EPIC)

        option.set(nil, false)
        assert.are.same(plain, slotBorder(ns, slot))

        option.set(nil, true)
        assert.are.same({ EPIC[1], EPIC[2], EPIC[3], 1 }, slotBorder(ns, slot))
    end)
end)

-- A raid frame as DefaultCompactUnitFrameSetup leaves it: bars, backgrounds, separators and glows.
local function compactFrame(name)
    local frame = CreateFrame("Button", name)

    frame.background = frame:CreateTexture()

    for _, key in ipairs({ "horizTopBorder", "horizBottomBorder", "vertLeftBorder", "vertRightBorder",
        "horizDivider" }) do
        frame[key] = frame:CreateTexture()
    end

    frame.aggroHighlight = frame:CreateTexture()
    frame.selectionHighlight = frame:CreateTexture()
    frame.name = frame:CreateFontString()
    frame.statusText = frame:CreateFontString()

    for _, key in ipairs({ "healthBar", "powerBar" }) do
        local bar = CreateFrame("StatusBar", nil, frame)

        bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        bar.background = bar:CreateTexture()
        frame[key] = bar
    end

    return frame
end

-- The textures on the frame painted in a color, one for each of a glow's four lines.
local function linesIn(frame, r, g, b)
    local found = {}

    for _, region in ipairs(frame.regions) do
        local v = region.vertex

        if (v and region.texture == "Interface\\Buttons\\WHITE8X8" and v[1] == r and v[2] == g and v[3] == b) then
            found[#found+1] = region
        end
    end

    return found
end

describe("raid frames", function()
    local ns, combat

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)

        combat = false
        _G.InCombatLockdown = function() return combat end
        _G.DefaultCompactUnitFrameSetup = function() end

        applyModule(ns, "raidframes")
    end)

    after_each(function()
        _G.DefaultCompactUnitFrameSetup, _G.CompactRaidFrame1, _G.NamePlate1UnitFrame = nil, nil, nil
    end)

    it("are flattened as Blizzard sets them up", function()
        local frame = compactFrame("CompactRaidFrame1")

        DefaultCompactUnitFrameSetup(frame)

        assert.are.equal(ns.Skin.FLAT, frame.healthBar:GetStatusBarTexture().texture)
        assert.are.equal(ns.Skin.FLAT, frame.powerBar:GetStatusBarTexture().texture)
        assert.is_false(frame.background:IsShown())
        assert.is_false(frame.horizTopBorder:IsShown())

        -- Blizzard sets its art again on the next setup; it is flattened again.
        frame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        assert.are.equal(ns.Skin.FLAT, frame.healthBar:GetStatusBarTexture().texture)
    end)

    it("tint the empty part of health a dim shade of the color Blizzard gives it", function()
        local frame = compactFrame("CompactRaidFrame1")
        local health = frame.healthBar

        DefaultCompactUnitFrameSetup(frame)
        health:SetStatusBarColor(1, 0.5, 0)

        local track = health.regions[#health.regions]

        assert.are.same({ 0.22, 0.11, 0, 0.95 }, track.color)
        assert.are.same({ 1, 0.5, 0, 1 }, health.barColor)
    end)

    it("keep the track plain for a color Blizzard hands over as a secret", function()
        local frame = compactFrame("CompactRaidFrame1")
        local health = frame.healthBar
        local secret = wow.secret()

        DefaultCompactUnitFrameSetup(frame)
        health.GetStatusBarColor = function() return secret, secret, secret end

        assert.has_no.errors(function() health:SetStatusBarTexture("SomeAtlas") end)

        local track = health.regions[#health.regions]

        assert.are.same({ ns.UI:rgb("window", 0.9) }, track.color)
    end)

    it("show the aggro glow as lines in its threat color, which follow it on and off", function()
        local frame = compactFrame("CompactRaidFrame1")

        DefaultCompactUnitFrameSetup(frame)

        frame.aggroHighlight:SetVertexColor(1, 0, 0)
        frame.aggroHighlight:Show()

        local lines = linesIn(frame, 1, 0, 0)

        assert.are.equal(4, #lines)
        assert.is_true(lines[1]:IsShown())

        frame.aggroHighlight:Hide()
        assert.is_false(lines[1]:IsShown())
        assert.are.equal(0, frame.aggroHighlight.alpha)
    end)

    it("leave nameplates alone, though they are built from the same frames", function()
        local plate = compactFrame("NamePlate1UnitFrame")

        DefaultCompactUnitFrameSetup(plate)

        assert.are.equal("Interface\\RaidFrame\\Raid-Bar-Hp-Fill", plate.healthBar:GetStatusBarTexture().texture)
    end)

    it("never call into a forbidden frame", function()
        local frame = compactFrame("CompactRaidFrame1")

        frame.forbidden = true
        frame.GetName = function() error("forbidden") end

        assert.has_no.errors(function() DefaultCompactUnitFrameSetup(frame) end)
    end)

    it("wait for a fight to end before skinning a frame that turned up during it", function()
        local frame = compactFrame("CompactRaidFrame1")

        combat = true
        DefaultCompactUnitFrameSetup(frame)
        assert.are_not.equal(ns.Skin.FLAT, frame.healthBar:GetStatusBarTexture().texture)

        combat = false
        wow.fire("PLAYER_REGEN_ENABLED")
        assert.are.equal(ns.Skin.FLAT, frame.healthBar:GetStatusBarTexture().texture)
    end)
end)

-- A nameplate as Blizzard sets one up for a unit: a health bar with its four-edge border, drawn
-- black, and a cast bar.
local function namePlate()
    local plate = CreateFrame("Frame")
    local frame = CreateFrame("Button", nil, plate)

    plate.UnitFrame = frame
    frame.name = frame:CreateFontString()
    frame.selectionHighlight = frame:CreateTexture()

    local health = CreateFrame("StatusBar", nil, frame)

    health:SetStatusBarTexture("Interface/TargetingFrame/UI-TargetingFrame-BarFill")
    health.background = health:CreateTexture()
    frame.healthBar = health

    -- Retail sets the name along the bar's left end.
    frame.name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 4)
    frame.name:SetJustifyH("LEFT")

    local border = CreateFrame("Frame", nil, health)

    for _ = 1, 4 do border:CreateTexture() end

    border.SetVertexColor = function(self, r, g, b, a)
        for _, edge in ipairs(self.regions) do edge:SetVertexColor(r, g, b, a) end
    end
    border.SetUnderlineColor = function(self, r, g, b, a) self.regions[3]:SetVertexColor(r, g, b, a) end
    border:SetVertexColor(0, 0, 0, 1)
    health.border = border

    local cast = CreateFrame("StatusBar", nil, frame)

    cast:SetStatusBarTexture("ui-castingbar-filling-standard")
    cast.Background = cast:CreateTexture()
    cast.BorderShield = cast:CreateTexture()
    cast.Icon = cast:CreateTexture()
    cast.Text = cast:CreateFontString()
    frame.castBar = cast

    return plate
end

local function regionColored(frame, color)
    for _, region in ipairs(frame.regions) do
        if (region.color and table.concat(region.color, ",") == table.concat(color, ",")) then return region end
    end
end

describe("nameplates", function()
    local ns, plates, friendly, plate, frame, health

    local function option(key)
        return ns.RUI.options.args.nameplates.args[key]
    end

    -- The framed style's window: the one texture on the unit frame in the kit's window color.
    local function panelArea()
        return regionColored(frame, { ns.UI:rgb("window", 0.9) })
    end

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)

        plates, friendly = {}, {}
        _G.C_NamePlate = {
            GetNamePlates = function()
                local list = {}

                for _, each in pairs(plates) do list[#list+1] = each end

                return list
            end,
            GetNamePlateForUnit = function(unit) return plates[unit] end,
        }

        _G.UnitExists = function() return true end
        _G.UnitIsPlayer = function() return false end
        _G.UnitIsFriend = function(_, unit) return friendly[unit] == true end
        _G.UnitCanAttack = function(_, unit) return not friendly[unit] end

        applyModule(ns, "nameplates")

        plate = namePlate()
        plates.nameplate1 = plate
        frame = plate.UnitFrame
        health = frame.healthBar

        wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    end)

    after_each(function()
        _G.C_NamePlate, _G.UnitExists, _G.UnitIsPlayer, _G.UnitIsFriend, _G.UnitCanAttack = nil, nil, nil, nil, nil
    end)

    it("grow and shrink the bar against the height Blizzard gives it, whichever style is picked", function()
        health:SetHeight(4)
        assert.are.equal(4, health.height)

        option("style").set(nil, "thick")
        assert.is_true(health.height > 6.5 and health.height < 7.5)

        -- Blizzard sets the plate up again for its next unit; the style holds.
        health:SetHeight(4)
        assert.is_true(health.height > 6.5 and health.height < 7.5)

        option("style").set(nil, "minimal")
        assert.is_true(health.height > 1.5 and health.height < 2.5)
    end)

    it("put the name and bar in a window on Framed, its border taking the target's color", function()
        assert.is_false(panelArea():IsShown())

        option("style").set(nil, "framed")
        assert.is_true(panelArea():IsShown())

        health.border:SetVertexColor(1, 1, 1, 1)

        assert.are.equal(4, #linesIn(frame, 1, 1, 1))
        assert.is_false(linesIn(health, 1, 1, 1)[1]:IsShown())
    end)

    it("show a friendly NPC's name alone while names only is on", function()
        local friend = namePlate()

        friendly.nameplate2 = true
        plates.nameplate2 = friend

        option("friendlyNames").set(nil, true)
        wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")

        local bars = friend.UnitFrame

        assert.is_false(bars.healthBar:IsShown())
        assert.is_true(health:IsShown())

        -- Blizzard shows the bars again as the plate updates and casts; they stay hidden.
        bars.healthBar:SetShown(true)
        bars.castBar:Show()
        assert.is_false(bars.healthBar:IsShown())
        assert.is_false(bars.castBar:IsShown())
    end)

    it("give the bars back when the plate goes to an enemy, or names only is turned off", function()
        option("friendlyNames").set(nil, true)
        friendly.nameplate1 = true
        wow.fire("UNIT_FACTION", "nameplate1")
        assert.is_false(health:IsShown())

        friendly.nameplate1 = nil
        wow.fire("UNIT_FACTION", "nameplate1")
        assert.is_true(health:IsShown())

        friendly.nameplate1 = true
        wow.fire("UNIT_FACTION", "nameplate1")
        option("friendlyNames").set(nil, false)
        assert.is_true(health:IsShown())
    end)

    it("center a name shown alone, and give Blizzard's place back with the bars", function()
        local name = frame.name
        local blizzards = { { "BOTTOMLEFT", health, "TOPLEFT", 0, 4 } }

        option("friendlyNames").set(nil, true)
        friendly.nameplate1 = true
        wow.fire("UNIT_FACTION", "nameplate1")

        assert.are.same({ { "BOTTOM", health, "TOP", 0, 4 } }, name.points)
        assert.are.equal("CENTER", name.justifyH)

        -- Blizzard places the name again as it updates the plate; it stays centered.
        name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 4)
        name:SetJustifyH("LEFT")
        assert.are.same({ { "BOTTOM", health, "TOP", 0, 4 } }, name.points)
        assert.are.equal("CENTER", name.justifyH)

        friendly.nameplate1 = nil
        wow.fire("UNIT_FACTION", "nameplate1")

        assert.are.same(blizzards, name.points)
        assert.are.equal("LEFT", name.justifyH)
    end)

    it("keep the bars of a unit that cannot be read", function()
        _G.UnitIsFriend = function() return wow.secret() end
        option("friendlyNames").set(nil, true)

        assert.has_no.errors(function() wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate1") end)
        assert.is_true(health:IsShown())
    end)

    it("draw a preview of every style", function()
        for _, style in ipairs(ns.RUI.nameplateStyles) do
            assert.has_no.errors(function() ns.RUI:drawNameplatePreview(CreateFrame("Frame"), style.value) end)
        end
    end)

    it("are flattened as each comes into view", function()
        assert.are.equal(ns.Skin.FLAT, health:GetStatusBarTexture().texture)
        assert.are.equal(ns.Skin.FLAT, frame.castBar:GetStatusBarTexture().texture)
        assert.is_false(health.background:IsShown())
        assert.is_false(frame.castBar.Background:IsShown())
        assert.are.equal(0, health.border.regions[1].alpha)
    end)

    it("keep the shield that marks a cast which cannot be interrupted", function()
        frame.castBar.BorderShield:Show()

        assert.is_true(frame.castBar.BorderShield:IsShown())
        assert.are.equal(1, frame.castBar.BorderShield.alpha)
    end)

    it("tint the empty part of health a dim shade of the color Blizzard gives it", function()
        health:SetStatusBarColor(1, 0, 0)

        assert.is_not_nil(regionColored(health, { 0.22, 0, 0, 0.95 }))
        assert.are.same({ 1, 0, 0, 1 }, health.barColor)
    end)

    it("outline the target in the color Blizzard gives its border, and drop it after", function()
        health.border:SetVertexColor(1, 1, 1, 1)

        local lines = linesIn(health, 1, 1, 1)

        assert.are.equal(4, #lines)
        assert.is_true(lines[1]:IsShown())

        health.border:SetVertexColor(0, 0, 0, 1)
        assert.is_false(lines[1]:IsShown())
    end)

    it("only underline a soft target", function()
        health.border:SetUnderlineColor(1, 0.8, 0, 1)

        local lines = linesIn(health, 1, 0.8, 0)

        assert.is_false(lines[1]:IsShown())
        assert.is_true(lines[2]:IsShown())
    end)

    it("set the name's font again each time Blizzard resets it for a new unit", function()
        assert.are.equal("OUTLINE", frame.name.fontFlags)

        frame.name:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")

        assert.are.equal("OUTLINE", frame.name.fontFlags)
    end)

    it("never call into a forbidden plate", function()
        local forbidden = namePlate()

        forbidden.UnitFrame.forbidden = true
        plates.nameplate2 = forbidden

        wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
        wow.fire("NAME_PLATE_UNIT_ADDED", "nameplate3") -- no plate the addon may see

        assert.are.equal("Interface/TargetingFrame/UI-TargetingFrame-BarFill",
            forbidden.UnitFrame.healthBar:GetStatusBarTexture().texture)
    end)
end)

describe("the XP bar at the level cap", function()
    local RUI, watched

    before_each(function()
        RUI = wow.load().RUI
        wow.addonLoaded(nil)

        _G.UnitLevel = function() return 90 end
        _G.GetMaxLevelForPlayerExpansion = function() return 90 end
        _G.FACTION_BAR_COLORS = { [5] = { r = 0, g = 0.6, b = 0.1 }, [8] = { r = 0, g = 0.7, b = 0.6 } }
        _G.FACTION_STANDING_LABEL5, _G.FACTION_STANDING_LABEL8 = "Friendly", "Exalted"

        watched = { name = "Silvermoon Court", factionID = 7, reaction = 5, currentReactionThreshold = 3000,
            nextReactionThreshold = 9000, currentStanding = 4500 }

        _G.C_Reputation = {
            GetWatchedFactionData = function() return watched end,
            IsFactionParagonForCurrentPlayer = function() return false end,
            IsMajorFaction = function() return false end,
        }
    end)

    after_each(function()
        _G.UnitLevel, _G.GetMaxLevelForPlayerExpansion, _G.C_Reputation = nil, nil, nil
        _G.C_MajorFactions, _G.C_GossipInfo, _G.FACTION_BAR_COLORS = nil, nil, nil
        _G.FACTION_STANDING_LABEL5, _G.FACTION_STANDING_LABEL8 = nil, nil
    end)

    it("shows progress through the watched faction's standing", function()
        local snap = RUI.xpSnapshot()

        assert.are.equal("rep", snap.kind)
        assert.are.equal(1500, snap.value)
        assert.are.equal(6000, snap.max)
        assert.are.equal("Friendly", snap.label)
    end)

    it("shows a maxed standing full, rather than hiding", function()
        watched.reaction, watched.currentReactionThreshold, watched.nextReactionThreshold = 8, 42000, 42000

        local snap = RUI.xpSnapshot()

        assert.is_true(snap.full)
        assert.are.equal(snap.max, snap.value)
    end)

    it("counts renown toward the next renown level", function()
        _G.C_Reputation.IsMajorFaction = function() return true end
        _G.C_MajorFactions = {
            GetMajorFactionData = function()
                return { renownLevel = 12, renownLevelThreshold = 2500, renownReputationEarned = 625 }
            end,
            HasMaximumRenown = function() return false end,
        }

        local snap = RUI.xpSnapshot()

        assert.are.equal("Renown 12", snap.label)
        assert.are.equal(625, snap.value)
        assert.are.equal(2500, snap.max)
    end)

    it("counts paragon toward its next reward, ahead of renown", function()
        _G.C_Reputation.IsFactionParagonForCurrentPlayer = function() return true end
        _G.C_Reputation.GetFactionParagonInfo = function() return 23000, 10000 end
        _G.C_Reputation.IsMajorFaction = function() return true end

        local snap = RUI.xpSnapshot()

        assert.are.equal("Paragon", snap.label)
        assert.are.equal(3000, snap.value)
        assert.are.equal(10000, snap.max)
    end)

    it("ranks a friendship by its own name", function()
        _G.C_GossipInfo = {
            GetFriendshipReputation = function()
                return { friendshipFactionID = 7, reaction = "Good Friend", standing = 1200, reactionThreshold = 1000,
                    nextThreshold = 2000 }
            end,
        }

        local snap = RUI.xpSnapshot()

        assert.are.equal("Good Friend", snap.label)
        assert.are.equal(200, snap.value)
        assert.are.equal(1000, snap.max)
    end)

    it("hides with no faction watched, or when set to hide at the cap", function()
        assert.is_not_nil(RUI.xpSnapshot())

        RUI.db.xpbar.atMax = "hide"
        assert.is_nil(RUI.xpSnapshot())

        RUI.db.xpbar.atMax = "reputation"
        watched = nil
        assert.is_nil(RUI.xpSnapshot())
    end)

    it("shows experience below the cap whatever the setting", function()
        _G.UnitLevel = function() return 80 end
        _G.UnitXP, _G.UnitXPMax, _G.GetXPExhaustion = function() return 50 end, function() return 100 end,
            function() return nil end
        RUI.db.xpbar.atMax = "hide"

        assert.are.equal("xp", RUI.xpSnapshot().kind)

        _G.UnitXP, _G.UnitXPMax, _G.GetXPExhaustion = nil, nil, nil
    end)
end)

describe("NPC windows", function()
    local ns

    before_each(function()
        ns = wow.load()
        wow.addonLoaded(nil)
        stubQualities()
    end)

    after_each(function()
        _G.ITEM_QUALITY_COLORS, _G.GossipFrame, _G.MerchantFrame = nil, nil, nil
        _G.MerchantItem1, _G.MerchantItem1ItemButton, _G.MerchantItem1NameFrame = nil, nil, nil
    end)

    it("keep the gossip window's parchment, which its dark text is written for", function()
        CreateFrame("Frame", "GossipFrame")

        local art = GossipFrame:CreateTexture()

        GossipFrame.Background = GossipFrame:CreateTexture()

        applyModule(ns, "npc")

        assert.are.equal(0, art.alpha)
        assert.are.equal(1, GossipFrame.Background.alpha)
        assert.is_true(GossipFrame.Background:IsShown())
    end)

    it("border a merchant's goods in their quality color, while quality borders are on", function()
        CreateFrame("Frame", "MerchantFrame")

        local item = CreateFrame("Frame", "MerchantItem1", MerchantFrame)

        item.SlotTexture = item:CreateTexture()
        _G.MerchantItem1NameFrame = item:CreateTexture()
        item.ItemButton = itemButton("MerchantItem1ItemButton", item)

        applyModule(ns, "npc")

        assert.are.equal(0, item.SlotTexture.alpha)
        assert.are.equal(0, MerchantItem1NameFrame.alpha)

        paintQuality(item.ItemButton, EPIC)
        assert.are.same({ EPIC[1], EPIC[2], EPIC[3], 1 }, slotBorder(ns, item.ItemButton))

        ns.RUI.options.args.npc.args.qualityBorders.set(nil, false)
        assert.are.same({ ns.UI:rgb("border") }, slotBorder(ns, item.ItemButton))
    end)

    it("give each quest reward a card of its own, under its icon's slot", function()
        CreateFrame("Frame", "QuestFrame")

        local reward = CreateFrame("Button", nil, QuestFrame)

        reward.Icon = reward:CreateTexture()
        reward.NameFrame = reward:CreateTexture()
        _G.QuestInfoRewardsFrame = { RewardButtons = { reward } }

        applyModule(ns, "npc")

        local card

        for _, region in ipairs(reward.regions) do
            if (region.color and region.color[4] == 0.08) then card = region end
        end

        assert.is_not_nil(card)
        assert.are.equal(0, reward.NameFrame.alpha)

        _G.QuestFrame, _G.QuestInfoRewardsFrame = nil, nil
    end)
end)
