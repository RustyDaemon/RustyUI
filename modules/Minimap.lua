--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The minimap in one of several looks, switched live from the settings:
--   square   a flat square with a thin border
--   rounded  a square with soft corners and a light outline
--   round    a circle with an accent ring
--   hexagon  a flat-topped hexagon with an accent outline
--   window   the map inside a kit window, with the zone in its title bar and coordinates below
-- The shaped masks, outlines and shadows are made by tools/make-minimap-masks.py.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local MEDIA = "Interface\\AddOns\\RustyUI\\media\\minimap\\"
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"

-- The shadow textures draw the shape across 200 of their 256 pixels, leaving room for the falloff.
local SHADOW_SCALE = 256 / 200

local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 20
local WINDOW_PAD = 5

local STYLES = {
    { value = "square",  text = "Square",  mask = SQUARE_MASK,                shape = "SQUARE" },
    { value = "rounded", text = "Rounded", mask = MEDIA .. "mask-rounded",    shape = "SQUARE",
        outline = "borderLight" },
    { value = "round",   text = "Round",   mask = MEDIA .. "mask-round",      shape = "ROUND",
        outline = "accentDim" },
    { value = "hexagon", text = "Hexagon", mask = MEDIA .. "mask-hexagon",    shape = "ROUND",
        outline = "accent" },
    { value = "window",  text = "Window",  mask = SQUARE_MASK,                shape = "SQUARE" },
}

RUI.minimapStyles = STYLES

local ART = {
    "MinimapCompassTexture",
    "MinimapBorder",
    "MinimapBorderTop",
    "MinimapNorthTag",
    "MinimapCluster.BorderTop",
}

local ZONE_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    friendly  = { 0.10, 1.00, 0.10 },
    hostile   = { 1.00, 0.10, 0.10 },
    combat    = { 1.00, 0.10, 0.10 },
    arena     = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 },
}

local current = STYLES[1]
local parts = nil

local applyEdge -- defined with the edge distance, below

local function styleOf(value)
    for _, style in ipairs(STYLES) do
        if (style.value == value) then return style end
    end

    return STYLES[1]
end

-- Minimap button addons (LibDBIcon among them) ask this to place their buttons along the edge.
function GetMinimapShape()
    return current.shape
end

local function zoneTextButton()
    return MinimapZoneTextButton or (MinimapCluster and MinimapCluster.ZoneTextButton)
end

local function playerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")

    if (not position) then return nil end

    local x, y = position:GetXY()

    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

-- Another coordinate readout under the map (WoW Forever's own, or another addon's) would repeat the
-- window's footer. It has no name to look it up by, so it is found by what it shows.
local hiddenCoords = {}
local scanTick = 0

local function isCoordinates(text)
    return type(text) == "string" and text:find("^%s*%d+%.?%d*%s*,%s*%d+%.?%d*%s*$") ~= nil
end

local function eachCoordinates(frame, ours, depth, fn)
    for _, region in ipairs({ frame:GetRegions() }) do
        if (region:IsObjectType("FontString") and not ours[region] and isCoordinates(region:GetText())) then
            fn(region)
        end
    end

    if (depth < 5) then
        for _, child in ipairs({ frame:GetChildren() }) do
            eachCoordinates(child, ours, depth + 1, fn)
        end
    end
end

local function findCoordinates(frame, ours)
    eachCoordinates(frame, ours, 0, function(region)
        hiddenCoords[region] = true
        region:SetAlpha(0)
    end)
end

local function showOtherCoordinates()
    for region in pairs(hiddenCoords) do region:SetAlpha(1) end

    wipe(hiddenCoords)
end

local function refreshWindowText()
    local window = parts.window

    window.zone:SetText(GetMinimapZoneText() or "")

    local zonePvPInfo = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
    local color = ZONE_COLORS[zonePvPInfo() or ""]

    if (color) then
        window.zone:SetTextColor(color[1], color[2], color[3])
    else
        window.zone:SetTextColor(UI:rgb("text"))
    end

    -- Inside instances, and in Midnight combat, there may be no position to show.
    local ok, coords = pcall(playerPosition)

    window.coords:SetText(ok and coords or "")

    local hour, minute = GetGameTime()

    window.clock:SetText(("%02d:%02d"):format(hour, minute))

    -- A readout can appear later, as its addon loads; look again every couple of seconds.
    scanTick = (scanTick + 1) % 8

    if (scanTick == 1) then findCoordinates(MinimapCluster or Minimap:GetParent(), window.own) end
end

-- The window's panel draws on the map's parent, under the map; its text sits on a child of the
-- map, outside the map's own rect.
local function buildWindow(map, parent, overlay)
    local window = {}
    local textures = {}

    local area = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    area:SetPoint("TOPLEFT", map, "TOPLEFT", -WINDOW_PAD, WINDOW_PAD + HEADER_HEIGHT)
    area:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", WINDOW_PAD, -(WINDOW_PAD + FOOTER_HEIGHT))
    area:SetColorTexture(UI:rgb("window", 0.96))
    textures[#textures+1] = area

    textures[#textures+1] = S:shadow(parent, area)

    local lr, lg, lb = UI:rgb("accentLit")
    local header = UI:gradient(parent, "BACKGROUND", "VERTICAL",
        0.055, 0.059, 0.070, 1, lr * 0.6 + 0.04, lg * 0.6 + 0.04, lb * 0.6 + 0.04, 1)
    header:SetDrawLayer("BACKGROUND", -5)
    header:SetPoint("TOPLEFT", area, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", area, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT)
    textures[#textures+1] = header

    local rule = parent:CreateTexture(nil, "BACKGROUND", nil, -4)
    rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(UI:rgb("accentDim", 0.6))
    textures[#textures+1] = rule

    local border = S:lines(parent, area, 0, "BACKGROUND", -3)

    border:SetColor(UI:rgb("borderLight"))

    for _, line in ipairs(border.edges) do textures[#textures+1] = line end

    window.zone = UI:text(overlay, 12, "text")
    window.zone:SetPoint("LEFT", header, "LEFT", 8, 0)
    window.zone:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    window.zone:SetWordWrap(false)

    window.coords = UI:text(overlay, 11, "textDim")
    window.coords:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 8, 5)

    window.clock = UI:text(overlay, 11, "textDim")
    window.clock:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -8, 5)

    textures[#textures+1] = window.zone
    textures[#textures+1] = window.coords
    textures[#textures+1] = window.clock

    window.own = { [window.zone] = true, [window.coords] = true, [window.clock] = true }

    local ticker = nil

    window.SetShown = function(_, shown)
        for _, texture in ipairs(textures) do texture:SetShown(shown) end

        if (ticker) then ticker:Cancel() end

        ticker = nil

        if (shown) then
            refreshWindowText()
            ticker = C_Timer.NewTicker(0.25, refreshWindowText)
        else
            showOtherCoordinates()
        end
    end

    return window
end

local function build(map)
    local parent = map:GetParent()

    -- Lines on a child of the map draw over it, so the square border sits just outside the map;
    -- shadows go on the parent, which draws under it.
    local overlay = CreateFrame("Frame", nil, map)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(map:GetFrameLevel() + 5)

    local lines = S:lines(overlay, map, 1, "OVERLAY")

    -- Outside the border, which sits a pixel outside the map.
    local squareShade = S:shadow(parent, map, nil, 1)

    local outline = overlay:CreateTexture(nil, "OVERLAY")
    outline:SetAllPoints(map)

    local shapeShade = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    shapeShade:SetVertexColor(0, 0, 0, 0.7)

    local function fitShade()
        local outset = map:GetWidth() * (SHADOW_SCALE - 1) / 2

        shapeShade:ClearAllPoints()
        shapeShade:SetPoint("TOPLEFT", map, "TOPLEFT", -outset, outset)
        shapeShade:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", outset, -outset)
    end

    fitShade()
    map:HookScript("OnSizeChanged", fitShade)

    return {
        lines = lines,
        squareShade = squareShade,
        outline = outline,
        shapeShade = shapeShade,
        window = buildWindow(map, parent, overlay),
    }
end

local function setHybridMask(mask)
    if (HybridMinimap and HybridMinimap.CircleMask) then
        HybridMinimap.CircleMask:SetTexture(mask)
    end
end

-- WoW Forever's sun dial at the minimap's edge; Retail has none. (GameTimeFrame is the calendar.)
function RUI:dayNightIndicator()
    return MinimapCluster and MinimapCluster.DielFrame
end

-- Blizzard shows the dial again as the time of day changes, so while it is off each show is undone.
local function applyDayNight()
    local indicator = RUI:dayNightIndicator()

    if (not indicator) then return end

    if (S:once(indicator, "daynight")) then
        hooksecurefunc(indicator, "Show", function(self)
            if (not RUI.db.minimap.dayNight) then self:Hide() end
        end)
    end

    indicator:SetShown(RUI.db.minimap.dayNight and true or false)
end

local function applyStyle()
    if (not parts) then return end

    applyDayNight()

    current = styleOf(RUI.db.minimap.style)

    local map = Minimap
    local shaped = current.outline ~= nil
    local framed = current.value == "window"

    map:SetMaskTexture(current.mask)
    setHybridMask(current.mask)

    for _, line in ipairs(parts.lines.edges) do line:SetShown(not shaped) end

    parts.lines:SetColor(UI:rgb(framed and "border" or "borderLight"))
    parts.squareShade:SetShown(not shaped and not framed)

    parts.outline:SetShown(shaped)
    parts.shapeShade:SetShown(shaped)

    if (shaped) then
        parts.outline:SetTexture(MEDIA .. "border-" .. current.value)
        parts.outline:SetVertexColor(UI:rgb(current.outline))
        parts.shapeShade:SetTexture(MEDIA .. "shadow-" .. current.value)
    end

    parts.window:SetShown(framed)

    -- The window has the zone in its title bar; Blizzard's own zone line would repeat it.
    local zone = zoneTextButton()

    if (zone) then zone:SetAlpha(framed and 0 or 1) end

    RUI:safe("Minimap edge distance", applyEdge)
end

-- Edge distance ---------------------------------------------------------------------------------

-- How far what sits around the map stands off its edge, in the map's units: the header row with the
-- zone, clock and tracking, a coordinate readout under the map, and minimap button addons. Unset,
-- Blizzard's own layout stands.

local LIBDBICON_RADIUS = 5 -- LibDBIcon's own default

local moved = {} -- frame or region -> its anchor before it was moved

local function restoreMoved()
    for object, anchor in pairs(moved) do
        object:ClearAllPoints()
        object:SetPoint(unpack(anchor))
    end

    wipe(moved)
end

-- Moves a singly anchored frame or region up by `pixels` screen pixels (down when negative).
local function shiftUp(object, pixels)
    if (object:GetNumPoints() ~= 1) then return end

    local point, relativeTo, relativePoint, x, y = object:GetPoint(1)
    local owner = object.GetEffectiveScale and object or object:GetParent()

    moved[object] = { point, relativeTo, relativePoint, x, y }
    object:ClearAllPoints()
    object:SetPoint(point, relativeTo, relativePoint, x, y + pixels / owner:GetEffectiveScale())
end

-- Screen-pixel top and bottom of a frame or region.
local function verticalEdges(object)
    local top, bottom = object:GetTop(), object:GetBottom()

    if (not (top and bottom)) then return nil end

    local scale = (object.GetEffectiveScale and object or object:GetParent()):GetEffectiveScale()

    return top * scale, bottom * scale
end

local function headerFrames()
    local cluster = MinimapCluster

    return {
        cluster and cluster.BorderTop, zoneTextButton(), cluster and cluster.Tracking, MiniMapTracking,
        TimeManagerClockButton, GameTimeFrame,
    }
end

local function setButtonRadius(radius)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)

    if (lib and lib.SetButtonRadius) then lib:SetButtonRadius(radius) end
end

function applyEdge()
    restoreMoved()

    local distance = RUI.db.minimap.edgeDistance

    setButtonRadius(distance or LIBDBICON_RADIUS)

    if (not distance) then return end

    local mapTop, mapBottom = verticalEdges(Minimap)

    if (not mapTop) then return end

    local want = distance * Minimap:GetEffectiveScale()
    local slack = 2 * Minimap:GetEffectiveScale()

    -- The header row: the lowest of its frames above the map, or the highest below it when Edit
    -- Mode puts the header underneath. Frames over the map's edge, like the calendar, are left out.
    local above, below

    for _, frame in ipairs(headerFrames()) do
        local top, bottom

        if (frame and frame:IsShown()) then top, bottom = verticalEdges(frame) end

        if (bottom and bottom >= mapTop - slack) then
            above = math.min(above or bottom, bottom)
        elseif (top and top <= mapBottom + slack) then
            below = math.max(below or top, top)
        end
    end

    -- The map moves, not the header: its container is what Blizzard anchors under the header.
    local mover = (MinimapCluster and MinimapCluster.MinimapContainer) or Minimap

    if (above) then
        shiftUp(mover, (above - mapTop) - want)
    elseif (below) then
        shiftUp(mover, want - (mapBottom - below))
    end

    -- Another addon's coordinate readout under the map; the window style hides it for its own.
    if (current.value ~= "window") then
        mapBottom = select(2, verticalEdges(Minimap))

        eachCoordinates(MinimapCluster or Minimap:GetParent(), parts.window.own, 0, function(region)
            local top = verticalEdges(region)

            if (top and mapBottom and top <= mapBottom + slack) then
                shiftUp(region, (mapBottom - top) - want)
            end
        end)
    end
end

-- Previews --------------------------------------------------------------------------------------

local PREVIEW_MAP = 56

-- A stand-in map: grassland with two roads and the player's arrow, under the style's own mask.
local function previewMap(holder, map, mask)
    local ground = holder:CreateTexture(nil, "ARTWORK")
    ground:SetAllPoints(map)
    ground:SetColorTexture(1, 1, 1, 1)
    ground:SetGradient("VERTICAL", CreateColor(0.30, 0.27, 0.15, 1), CreateColor(0.42, 0.40, 0.22, 1))

    local textures = { ground }

    local across = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    across:SetColorTexture(0.62, 0.55, 0.38, 0.8)
    across:SetHeight(3)
    across:SetPoint("LEFT", map, "TOPLEFT", 0, -PREVIEW_MAP * 0.38)
    across:SetPoint("RIGHT", map, "TOPRIGHT", 0, -PREVIEW_MAP * 0.38)

    local down = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    down:SetColorTexture(0.62, 0.55, 0.38, 0.8)
    down:SetWidth(3)
    down:SetPoint("TOP", map, "TOPLEFT", PREVIEW_MAP * 0.66, 0)
    down:SetPoint("BOTTOM", map, "BOTTOMLEFT", PREVIEW_MAP * 0.66, 0)

    textures[#textures+1] = across
    textures[#textures+1] = down

    local arrow = holder:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    arrow:SetSize(16, 16)
    arrow:SetPoint("CENTER", map, "CENTER")

    if (mask) then
        for _, texture in ipairs(textures) do texture:AddMaskTexture(mask) end
    end
end

-- A style drawn small into `holder`, for the settings' preview cards.
function RUI:drawMinimapPreview(holder, value)
    local style = styleOf(value)
    local framed = style.value == "window"

    local map = holder:CreateTexture(nil, "BACKGROUND", nil, 7)
    map:SetSize(PREVIEW_MAP, PREVIEW_MAP)
    map:SetPoint("CENTER", 0, framed and -1 or 0)
    map:SetColorTexture(0, 0, 0, 0)

    local mask = nil

    if (style.outline) then
        mask = holder:CreateMaskTexture()
        mask:SetTexture(style.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(map)

        local outset = PREVIEW_MAP * (SHADOW_SCALE - 1) / 2

        local shade = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
        shade:SetTexture(MEDIA .. "shadow-" .. style.value)
        shade:SetVertexColor(0, 0, 0, 0.7)
        shade:SetPoint("TOPLEFT", map, "TOPLEFT", -outset, outset)
        shade:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", outset, -outset)

        local outline = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        outline:SetTexture(MEDIA .. "border-" .. style.value)
        outline:SetVertexColor(UI:rgb(style.outline))
        outline:SetAllPoints(map)
    elseif (framed) then
        local area = holder:CreateTexture(nil, "BACKGROUND", nil, 2)
        area:SetPoint("TOPLEFT", map, "TOPLEFT", -3, 14)
        area:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 3, -12)
        area:SetColorTexture(UI:rgb("window"))

        local header = holder:CreateTexture(nil, "BACKGROUND", nil, 3)
        header:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
        header:SetHeight(11)
        header:SetColorTexture(UI:rgb("accentLit"))

        local rule = holder:CreateTexture(nil, "BACKGROUND", nil, 4)
        rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT")
        rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT")
        rule:SetHeight(1)
        rule:SetColorTexture(UI:rgb("accentDim"))

        S:lines(holder, area, 0, "BACKGROUND", 5):SetColor(UI:rgb("borderLight"))
        S:lines(holder, map, 0, "OVERLAY"):SetColor(UI:rgb("border"))

        local zone = UI:text(holder, 8, "text")
        zone:SetPoint("CENTER", header, "CENTER", 0, 0)
        zone:SetText("Zone")

        local coords = UI:text(holder, 7, "textDim")
        coords:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 3, 2)
        coords:SetText("42.1, 63.0")

        local clock = UI:text(holder, 7, "textDim")
        clock:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -3, 2)
        clock:SetText("12:00")
    else
        local shade = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
        shade:SetPoint("TOPLEFT", map, "TOPLEFT", -4, 4)
        shade:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 4, -4)
        shade:SetColorTexture(0, 0, 0, 0.45)

        S:lines(holder, map, 1, "OVERLAY"):SetColor(UI:rgb("borderLight"))
    end

    previewMap(holder, map, mask)
end

RUI:registerModule("minimap", "Minimap", function()
    local map = Minimap

    -- The quest and dig-site rings are drawn round; without the scalar they cut the corners.
    if (map.SetArchBlobRingScalar) then map:SetArchBlobRingScalar(0) end
    if (map.SetQuestBlobRingScalar) then map:SetQuestBlobRingScalar(0) end

    S:killAll(ART)
    S:font(MinimapZoneText, 12)

    parts = build(map)
    applyStyle()

    -- Retail swaps in a separate map inside some instances, with its own round mask.
    RUI:onAddon("Blizzard_HybridMinimap", function() setHybridMask(current.mask) end)

    -- Edit Mode re-anchors the map under (or over) the header; that is the new layout to start from.
    if (MinimapCluster and MinimapCluster.SetHeaderUnderneath) then
        hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", function()
            local mover = MinimapCluster.MinimapContainer

            if (mover) then moved[mover] = nil end

            RUI:safe("Minimap edge distance", applyEdge)
        end)
    end

    -- Layout settles after login, and coordinate readouts and minimap buttons arrive with their
    -- addons; the distance is set again once things are in place.
    local events = CreateFrame("Frame")

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function()
        C_Timer.After(0, function() RUI:safe("Minimap edge distance", applyEdge) end)
        C_Timer.After(3, function() RUI:safe("Minimap edge distance", applyEdge) end)
    end)
end, applyStyle)
