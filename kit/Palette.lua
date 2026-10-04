--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The My Loot History kit: the same palette and widgets, so RustyUI's own windows and the skins it
-- puts on Blizzard's frames look like the addon people already know.

local _, ns = ...

local UI = {}
ns.UI = UI

local BLIZZARD_FONT = GameFontNormal:GetFont()
local BLIZZARD_NUMBER = (NumberFontNormal and NumberFontNormal:GetFont()) or BLIZZARD_FONT

local FONT, FONT_NUMBER = BLIZZARD_FONT, BLIZZARD_NUMBER

UI.font = FONT
UI.fontNumber = FONT_NUMBER

-- Rusty Pixel is built by My Loot History's tools/font/build_font.py; its digits share one width,
-- so it serves numbers too.
UI.fonts = {
    { value = "blizzard", text = "Blizzard" },
    { value = "pixel",    text = "Rusty Pixel", file = "Interface\\AddOns\\RustyUI\\media\\fonts\\RustyPixel.ttf" },
}

-- Text takes the font when it is made, so call this before any frame is skinned.
function UI:setFont(key)
    FONT, FONT_NUMBER = BLIZZARD_FONT, BLIZZARD_NUMBER

    for _, preset in ipairs(self.fonts) do
        if (preset.value == key and preset.file) then FONT, FONT_NUMBER = preset.file, preset.file end
    end

    UI.font, UI.fontNumber = FONT, FONT_NUMBER
end

local fontScale = 1

-- Every size the kit asks for, scaled by the Font size setting (a percent); like the font, it
-- reaches text made after the call.
function UI:setFontScale(percent)
    fontScale = (tonumber(percent) or 100) / 100
end

-- Whole pixels only: a pixel font between sizes draws soft.
function UI:fontSize(size)
    return math.max(math.floor(size * fontScale + 0.5), 6)
end

local C = {
    shadow      = { 0.00, 0.00, 0.00 },
    window      = { 0.043, 0.047, 0.055 },
    panel       = { 0.082, 0.086, 0.098 },
    panelHover  = { 0.114, 0.122, 0.141 },
    raised      = { 0.129, 0.137, 0.157 },
    border      = { 0.176, 0.188, 0.216 },
    borderLight = { 0.239, 0.255, 0.290 },

    text        = { 0.918, 0.925, 0.945 },
    textDim     = { 0.596, 0.620, 0.678 },
    textFaint   = { 0.396, 0.416, 0.463 },

    accent      = { 1.000, 0.820, 0.300 },
    accentDim   = { 0.600, 0.480, 0.160 },
    accentLit   = { 0.240, 0.190, 0.060 },
    money       = { 1.000, 0.839, 0.286 },
    good        = { 0.400, 0.851, 0.482 },
    bad         = { 0.925, 0.373, 0.373 },
}

UI.color = C

-- Gold is My Loot History's own accent; the others keep its brightness so text stays readable.
UI.accents = {
    { value = "gold",   text = "Gold",
      accent = { 1.000, 0.820, 0.300 }, dim = { 0.600, 0.480, 0.160 }, lit = { 0.240, 0.190, 0.060 } },
    { value = "rust",   text = "Rust",
      accent = { 0.945, 0.522, 0.298 }, dim = { 0.580, 0.298, 0.157 }, lit = { 0.240, 0.118, 0.059 } },
    { value = "teal",   text = "Teal",
      accent = { 0.345, 0.827, 0.784 }, dim = { 0.169, 0.471, 0.447 }, lit = { 0.059, 0.180, 0.169 } },
    { value = "violet", text = "Violet",
      accent = { 0.698, 0.565, 1.000 }, dim = { 0.400, 0.310, 0.639 }, lit = { 0.149, 0.110, 0.251 } },
}

function UI:setAccent(key)
    for _, preset in ipairs(self.accents) do
        if (preset.value == key) then
            C.accent, C.accentDim, C.accentLit = preset.accent, preset.dim, preset.lit
            return
        end
    end
end

local NEUTRAL_BORDER, NEUTRAL_BORDER_LIGHT = C.border, C.borderLight

-- Borders in the accent instead of grey: the plain border a darker shade of it, so the light one
-- (hover, outlines) still stands out. Call after setAccent.
function UI:setAccentBorders(on)
    if (not on) then
        C.border, C.borderLight = NEUTRAL_BORDER, NEUTRAL_BORDER_LIGHT
        return
    end

    local dim = C.accentDim

    C.border = { dim[1] * 0.7, dim[2] * 0.7, dim[3] * 0.7 }
    C.borderLight = dim
end

function UI:rgb(name, alpha)
    local c = C[name]

    return c[1], c[2], c[3], alpha or 1
end

-- Choose the color name first: and/or truncates multiple return values.
function UI:rgbIf(condition, nameTrue, nameFalse, alpha)
    return self:rgb(condition and nameTrue or nameFalse, alpha)
end
