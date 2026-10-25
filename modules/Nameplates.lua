--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Blizzard's nameplates in one of several looks, switched live:
--   slim     a flat health bar with a 1px border, at Blizzard's height
--   framed   the name and bar together in a kit window
--   thick    a taller bar
--   minimal  a thin line under the name
-- The empty part of the bar is a dim shade of the color Blizzard gives it, and the cast bar is flat
-- and colored by cast type. Blizzard's border turns light for your target, soft target or a mob off
-- its tank; that shows as a 1px line just outside the bar, or as the framed window's border.
-- Friendly NPCs can be set to show only their name, centered where the bar would be.
-- Plates are made as units come into view, so each is skinned as it first shows one. Friendly
-- plates in instances are forbidden to addons, and calling into one errors; they keep Blizzard's
-- look.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

-- scale is the bar's height against the one Blizzard gives it, which follows its nameplate size.
local STYLES = {
    { value = "slim",    text = "Slim",    scale = 1 },
    { value = "framed",  text = "Framed",  scale = 1 },
    { value = "thick",   text = "Thick",   scale = 1.75 },
    { value = "minimal", text = "Minimal", scale = 0.5 },
}

RUI.nameplateStyles = STYLES

-- Below this, a border color is Blizzard's plain black edge rather than a state.
local PLAIN = 0.05
local PANEL_PAD = 3
local NAME_GAP = 4 -- Blizzard's own gap between the name and the bar

local looks = {}                                       -- unit frame -> its look
local units = setmetatable({}, { __mode = "k" })       -- unit frame -> the unit it last showed
local nameOnly = setmetatable({}, { __mode = "k" })    -- unit frames showing only their name
local wanted = setmetatable({}, { __mode = "k" })      -- bar -> whether Blizzard last had it shown
local namePlaces = setmetatable({}, { __mode = "k" })  -- name -> the anchors Blizzard last gave it
local hiding, placing = false, false
local current = STYLES[1]

local function styleOf(value)
    for _, style in ipairs(STYLES) do
        if (style.value == value) then return style end
    end

    return STYLES[1]
end

local function unitFrameOf(plate)
    local frame = plate and plate.UnitFrame

    if (type(frame) ~= "table" or (frame.IsForbidden and frame:IsForbidden())) then return nil end

    return frame
end

-- Retail keeps the health bar in a container with its border; WoW Forever and older Retail keep
-- the border on the bar itself.
local function healthOf(frame)
    local container = frame.HealthBarsContainer
    local bar = (container and container.healthBar) or frame.healthBar

    return bar, (bar and bar.border) or (container and container.border), container
end

local function castOf(frame)
    return frame.castBar or (frame.CastBarsContainer and frame.CastBarsContainer.castBar)
end

local function isPlain(r, g, b)
    return r < PLAIN and g < PLAIN and b < PLAIN
end

-- Look ------------------------------------------------------------------------------------------

local function setPanelShown(look, shown)
    local panel = look.panel

    panel.area:SetShown(shown)
    panel.shade:SetShown(shown)

    for _, edge in ipairs(panel.border.edges) do edge:SetShown(shown) end
end

-- What Blizzard's border last said: look.target is nil while it is plain, or its color and
-- whether it is the soft target's underline. A secret color is passed on, never read.
local function showTarget(look)
    local target, framed = look.target, look.style.value == "framed"

    for i, edge in ipairs(look.outline.edges) do
        edge:SetShown(target ~= nil and not framed and (not target.underline or i == 2))
    end

    if (target) then look.outline:SetColor(unpack(target.color, 1, 4)) end

    if (target and framed) then
        look.panel:SetBorderColor(unpack(target.color, 1, 4))
    else
        look.panel:SetBorderColor(UI:rgb("borderLight"))
    end
end

-- Each sizer is the bar or its container, with the height Blizzard last gave it as its base.
local function resize(look)
    for _, sizer in ipairs(look.sizers) do
        local base = sizer.base

        if (type(base) == "number" and not S:isSecret(base) and base > 0) then
            local px, scale = S:pixel(sizer.frame), look.style.scale

            -- At its own size the bar keeps Blizzard's height, which Blizzard already snaps.
            local height = scale == 1 and base or math.max(px, math.floor(base * scale / px + 0.5) * px)

            look.sizing = true
            sizer.frame:SetHeight(height)
            look.sizing = false
        end
    end
end

local function layout(look, style)
    look.style = style

    resize(look)
    setPanelShown(look, style.value == "framed" and look.health:IsShown())
    showTarget(look)
end

-- Everything the styles draw on a plate, made once; layout() shows and sizes the pieces for the
-- style in use. `owner` is a Blizzard unit frame, or a stand-in for the settings' previews.
local function buildLook(owner, health, name, container)
    local look = { owner = owner, health = health, style = current, sizers = {} }

    for _, frame in ipairs({ health, container }) do
        look.sizers[#look.sizers+1] = { frame = frame, base = frame:GetHeight() }
    end

    S:barBackdrop(health)

    -- Health art shows no state, so it goes even when Blizzard hands it over as a secret.
    S:flatBar(health, function(bar) S:matchTrack(bar) end, true)

    look.outline = S:lines(health, health, 2, "BORDER")

    -- The framed style's window, behind the name and bar. It is drawn on the unit frame, under
    -- both, and shows only while the bar does.
    local panel = S:backdrop(owner, 0, 0.9)

    panel.area:ClearAllPoints()
    panel.area:SetPoint("TOP", name or health, "TOP", 0, PANEL_PAD)
    panel.area:SetPoint("LEFT", health, "LEFT", -PANEL_PAD, 0)
    panel.area:SetPoint("RIGHT", health, "RIGHT", PANEL_PAD, 0)
    panel.area:SetPoint("BOTTOM", health, "BOTTOM", 0, -PANEL_PAD)

    look.panel = panel

    health:HookScript("OnShow", function() setPanelShown(look, look.style.value == "framed") end)
    health:HookScript("OnHide", function() setPanelShown(look, false) end)

    return look
end

-- Blizzard's border, hidden for good; what its color says goes to showTarget.
local function followBorder(look, border)
    if (not border) then return end

    local function paint(_, r, g, b, a)
        local ok, plain = pcall(isPlain, r, g, b)

        look.target = not (ok and plain) and { color = { r, g, b, a or 1 } } or nil
        showTarget(look)
    end

    -- The color Blizzard set before this plate was skinned, from the first of its edges.
    local first = border:GetRegions()

    if (first and first.GetVertexColor) then paint(nil, first:GetVertexColor()) end

    S:stripTextures(border)

    if (border.SetVertexColor) then hooksecurefunc(border, "SetVertexColor", paint) end

    if (border.SetUnderlineColor) then
        hooksecurefunc(border, "SetUnderlineColor", function(_, r, g, b, a)
            look.target = { color = { r, g, b, a or 1 }, underline = true }
            showTarget(look)
        end)
    end
end

-- Blizzard sets the bar's height as it sets a plate up; each time, that is the new base.
local function followHeight(look)
    for _, sizer in ipairs(look.sizers) do
        hooksecurefunc(sizer.frame, "SetHeight", function(_, height)
            if (look.sizing) then return end

            sizer.base = height
            resize(look)
        end)
    end
end

-- Names only ------------------------------------------------------------------------------------

-- Keeps a bar hidden while its plate shows only a name, and notes whether Blizzard wants it shown,
-- so it can come back. A secret flag is never tested; the bar is hidden again either way.
local function guardShown(frame, bar)
    wanted[bar] = bar:IsShown() == true

    local function check(self, shown)
        if (hiding) then return end

        local secret = S:isSecret(shown)

        if (not secret) then wanted[self] = shown and true or false end

        if (nameOnly[frame] and (secret or shown)) then
            hiding = true
            self:Hide()
            hiding = false
        end
    end

    hooksecurefunc(bar, "Show", function(self) check(self, true) end)
    hooksecurefunc(bar, "Hide", function(self) check(self, false) end)
    hooksecurefunc(bar, "SetShown", check)
end

local function pack(...)
    return { n = select("#", ...), ... }
end

-- Blizzard anchors the name along the bar, so it reads as off center once the bar is hidden; a
-- plate showing only its name has it centered above where the bar would be. Blizzard's own anchors
-- come back with the bar.
local function placeName(frame, centered)
    local name, health = frame.name, healthOf(frame)
    local place = name and namePlaces[name]

    if (not place or not health) then return end

    placing = true

    if (centered) then
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", health, "TOP", 0, NAME_GAP)
        name:SetJustifyH("CENTER")
    elseif (#place.points > 0) then
        name:ClearAllPoints()

        for _, point in ipairs(place.points) do name:SetPoint(unpack(point, 1, point.n)) end

        if (place.justify) then name:SetJustifyH(place.justify) end
    end

    placing = false
end

-- Blizzard's anchors are recorded as it sets them rather than read back: once a name holds a secret,
-- asking where it sits can answer in secrets. Ones set before the plate was skinned are read, if
-- they can be.
local function followName(frame)
    local name = frame.name

    if (not name or not name.SetPoint) then return end

    local place = { points = {} }

    namePlaces[name] = place

    pcall(function()
        local points = {}

        for i = 1, name:GetNumPoints() do
            local point = pack(name:GetPoint(i))

            for j = 1, point.n do
                if (S:isSecret(point[j])) then error("secret anchor") end
            end

            points[i] = point
        end

        place.points = points
    end)

    local ok, justify = pcall(name.GetJustifyH, name)

    if (ok and type(justify) == "string") then place.justify = justify end

    hooksecurefunc(name, "ClearAllPoints", function()
        if (not placing) then place.points = {} end
    end)

    hooksecurefunc(name, "SetPoint", function(_, ...)
        if (placing) then return end

        local point = pack(...)

        -- A point set again replaces the one it names.
        for i, old in ipairs(place.points) do
            if (old[1] == point[1]) then
                table.remove(place.points, i)
                break
            end
        end

        place.points[#place.points+1] = point

        if (nameOnly[frame]) then placeName(frame, true) end
    end)

    hooksecurefunc(name, "SetJustifyH", function(_, value)
        if (placing) then return end

        place.justify = value

        if (nameOnly[frame]) then placeName(frame, true) end
    end)
end

-- Unit data can be a secret value in Midnight; one that cannot be read keeps the bars.
local function isFriendlyNPC(unit)
    return (UnitExists(unit) and not UnitIsPlayer(unit) and UnitIsFriend("player", unit)
        and not UnitCanAttack("player", unit)) and true or false
end

local function setNameOnly(frame, on)
    if ((nameOnly[frame] or false) == on) then return end

    nameOnly[frame] = on or nil

    local health = healthOf(frame)

    for _, bar in ipairs({ health, castOf(frame) }) do
        if (on) then
            hiding = true
            bar:Hide()
            hiding = false
        elseif (wanted[bar]) then
            bar:Show()
        end
    end

    placeName(frame, on)
end

local function applyNameOnly(frame)
    local unit = units[frame]
    local on = false

    if (unit and RUI.db.nameplates.friendlyNames) then
        local ok, friendly = pcall(isFriendlyNPC, unit)

        on = ok and friendly
    end

    setNameOnly(frame, on)
end

-- Blizzard plates -------------------------------------------------------------------------------

local function skinCast(frame, bar)
    if (not bar) then return end

    S:flatBar(bar, RUI.paintCast)
    S:barBackdrop(bar)

    S:kill(bar.Background)
    S:kill(bar.Border)
    S:kill(bar.TextBorder)
    S:kill(bar.Flash)

    if (bar.border) then S:stripTextures(bar.border) end

    -- The shield stays: it is how a nameplate shows a cast that cannot be interrupted.
    S:cropIcon(bar.Icon)

    guardShown(frame, bar)
end

local function skinHealth(frame)
    local health, border, container = healthOf(frame)

    if (not health) then return end

    S:kill(health.background)
    if (container) then S:kill(container.background) end

    local look = buildLook(frame, health, frame.name, container)

    followBorder(look, border)
    followHeight(look)
    guardShown(frame, health)

    -- The target's bar is lit by an additive copy of Blizzard's bar art; flat, it lights it evenly.
    local highlight = frame.selectionHighlight

    if (highlight and highlight.SetTexture) then highlight:SetTexture(S.FLAT) end

    looks[frame] = look

    layout(look, current)
end

local function skinPlate(plate, unit)
    local frame = unitFrameOf(plate)

    if (not frame) then return end

    local cast = castOf(frame)

    -- Blizzard sets the fonts again each time a plate is given a unit.
    S:font(frame.name, nil, true)
    S:font(cast and cast.Text, nil, true)

    if (S:once(frame, "nameplate")) then
        skinHealth(frame)
        skinCast(frame, cast)
        followName(frame)
    end

    if (unit) then units[frame] = unit end

    applyNameOnly(frame)
end

local function refresh()
    current = styleOf(RUI.db.nameplates.style)

    for _, look in pairs(looks) do RUI:safe("Nameplates", layout, look, current) end

    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local frame = unitFrameOf(plate)

        if (frame) then RUI:safe("Nameplates", applyNameOnly, frame) end
    end
end

-- Previews --------------------------------------------------------------------------------------

-- A style drawn with a sample hostile mob into `holder`, for the settings' preview cards. It is a
-- stand-in plate going through the same look as the real ones.
function RUI:drawNameplatePreview(holder, value)
    local health = CreateFrame("StatusBar", nil, holder)
    health:SetStatusBarTexture(S.FLAT)
    health:SetMinMaxValues(0, 1)
    health:SetValue(0.64)
    health:SetHeight(8)
    health:SetPoint("LEFT", 20, -6)
    health:SetPoint("RIGHT", -20, -6)

    local name = UI:text(holder, 11, "text")
    name:SetPoint("BOTTOM", health, "TOP", 0, 4)
    name:SetText("Kobold Tunneler")
    S:font(name, nil, true)

    local look = buildLook(holder, health, name)

    health:SetStatusBarColor(0.85, 0.2, 0.15)

    layout(look, styleOf(value))
end

RUI:registerModule("nameplates", "Nameplates", function()
    current = styleOf(RUI.db.nameplates.style)

    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local frame = unitFrameOf(plate)

        RUI:safe("Nameplates", skinPlate, plate, frame and frame.unit)
    end

    -- Blizzard sets each plate up for its unit before this runs; its handler registered first.
    local events = CreateFrame("Frame")

    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("UNIT_FACTION")
    events:SetScript("OnEvent", function(_, event, unit)
        if (type(unit) ~= "string" or not unit:find("^nameplate")) then return end

        local plate = C_NamePlate.GetNamePlateForUnit(unit)

        if (event == "NAME_PLATE_UNIT_ADDED") then
            RUI:safe("Nameplates", skinPlate, plate, unit)
        else
            -- A friendly NPC can turn hostile, and back, as a quest goes.
            local frame = unitFrameOf(plate)

            if (frame and looks[frame]) then RUI:safe("Nameplates", applyNameOnly, frame) end
        end
    end)
end, refresh)
