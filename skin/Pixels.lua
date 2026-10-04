--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- One-pixel lines and the panels built from them, kept a single physical pixel at any UI scale.

local _, ns = ...

local UI, S = ns.UI, ns.Skin

-- One physical screen pixel in a region's own units. The UI is 768 units tall at scale 1, so a
-- "1" line lands between pixels at most UI scales and draws soft or doubled.
function S:pixel(region)
    local _, height = GetPhysicalScreenSize()
    local scale = region and region:GetEffectiveScale()

    if (not height or height <= 0 or not scale or scale <= 0) then return 1 end

    return 768 / height / scale
end

local measurers = {}

-- Runs measure now and again whenever the UI scale or resolution changes.
function S:pixelPerfect(measure)
    measurers[#measurers+1] = measure
    measure()
end

local scaleWatcher = CreateFrame("Frame")

-- Edit Mode scales bars, the minimap and the bags after they are skinned, and a line measured at the
-- old scale draws thinner or thicker than a pixel; the measures run again once a layout is applied.
for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "EDIT_MODE_LAYOUTS_UPDATED" }) do
    pcall(scaleWatcher.RegisterEvent, scaleWatcher, event)
end

scaleWatcher:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        for _, measure in ipairs(measurers) do pcall(measure) end
    end)
end)

-- Snapping rounds each side of a texture to the pixel grid on its own, so a one-pixel line whose
-- frame edge falls on a half pixel rounds to nothing and that side of a border goes missing.
-- Unsnapped, a line exactly a pixel wide always covers exactly one pixel.
local function crisp(texture)
    if (texture.SetSnapToPixelGrid) then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

S.crisp = function(_, texture) crisp(texture) end

-- How many physical pixels of dark rim a shadow draws outside a border.
S.SHADOW_PIXELS = 1

-- A dark rim just outside `anchor`, drawn on `owner` under everything else. A flat shadow several
-- units wide reads as a thick border, so it is a pixel thin: enough to lift the edge off a bright
-- world. `skip` is how many pixels of border outside `anchor` it goes past. Sides can be dropped,
-- where a panel meets a neighbour.
function S:shadow(owner, anchor, alpha, skip)
    local rim = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
    rim:SetTexture(S.FLAT)
    rim:SetVertexColor(0, 0, 0, alpha or 0.75)
    crisp(rim)

    local sides = { left = true, right = true, top = true, bottom = true }

    local function place()
        local out = (S.SHADOW_PIXELS + (skip or 0)) * S:pixel(owner)

        rim:ClearAllPoints()
        rim:SetPoint("TOPLEFT", anchor, "TOPLEFT", sides.left and -out or 0, sides.top and out or 0)
        rim:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", sides.right and out or 0, sides.bottom and -out or 0)
    end

    S:pixelPerfect(place)

    rim.SetSides = function(_, left, right, top, bottom)
        sides.left, sides.right, sides.top, sides.bottom = left, right, top, bottom
        place()
    end

    return rim
end

-- Four one-pixel lines along `anchor`'s edges, `outset` pixels outside it, drawn on `owner`.
function S:lines(owner, anchor, outset, layer, subLevel)
    outset = outset or 0

    local edges = {}

    for i = 1, 4 do
        local line = owner:CreateTexture(nil, layer or "BORDER", nil, subLevel or 0)
        line:SetTexture(S.FLAT)
        line:SetVertexColor(UI:rgb("border"))
        crisp(line)
        edges[i] = line
    end

    S:pixelPerfect(function()
        local px = S:pixel(owner)
        local out = outset * px

        for i = 1, 4 do edges[i]:ClearAllPoints() end

        edges[1]:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
        edges[1]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
        edges[1]:SetHeight(px)

        edges[2]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
        edges[2]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
        edges[2]:SetHeight(px)

        edges[3]:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
        edges[3]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
        edges[3]:SetWidth(px)

        edges[4]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
        edges[4]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
        edges[4]:SetWidth(px)
    end)

    return {
        edges = edges,
        SetColor = function(_, r, g, b, a)
            for i = 1, 4 do edges[i]:SetVertexColor(r, g, b, a or 1) end
        end,
    }
end

-- The kit's window look behind a whole frame: shadow, fill and border. insets is a number or
-- { left, right, top, bottom }; the area texture can be re-anchored later and the rest follows.
function S:backdrop(frame, insets, alpha)
    local left, right, top, bottom = 0, 0, 0, 0

    if (type(insets) == "table") then
        left, right, top, bottom = unpack(insets)
    elseif (insets) then
        left, right, top, bottom = insets, insets, insets, insets
    end

    local area = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    area:SetPoint("TOPLEFT", left, -top)
    area:SetPoint("BOTTOMRIGHT", -right, bottom)
    area:SetColorTexture(UI:rgb("window", alpha or 0.95))

    local shade = S:shadow(frame, area)

    local border = S:lines(frame, area, 0, "BACKGROUND", -6)

    return {
        area = area,
        shade = shade,
        border = border,
        SetBorderColor = function(_, ...) border:SetColor(...) end,
    }
end

-- A square, bordered slot under an icon or portrait: shadow, 1px border and fill, all drawn below
-- `anchor` on `owner`, so an empty slot still shows the panel.
function S:iconBackdrop(owner, anchor, shadow)
    anchor = anchor or owner

    local shade

    -- Outside the one-pixel edge, so edge and rim make two pixels in all.
    if (shadow ~= false) then shade = S:shadow(owner, anchor, nil, 1) end

    -- The border is this texture showing one pixel past the fill on every side.
    local edge = owner:CreateTexture(nil, "BACKGROUND", nil, -7)
    edge:SetTexture(S.FLAT)
    edge:SetVertexColor(UI:rgb("border"))
    crisp(edge)

    S:pixelPerfect(function()
        local px = S:pixel(owner)

        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", anchor, "TOPLEFT", -px, px)
        edge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", px, -px)
    end)

    local fill = owner:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetAllPoints(anchor)
    fill:SetColorTexture(UI:rgb("window"))

    return {
        edge = edge,
        fill = fill,
        SetBorderColor = function(_, r, g, b, a) edge:SetVertexColor(r, g, b, a or 1) end,
        SetShown = function(_, shown)
            edge:SetShown(shown)
            fill:SetShown(shown)

            if (shade) then shade:SetShown(shown) end
        end,
    }
end
