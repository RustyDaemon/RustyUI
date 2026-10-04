--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Status bars made flat, colored by the modules and given a track behind their fill.

local _, ns = ...

local UI, S = ns.UI, ns.Skin

local painting = setmetatable({}, { __mode = "k" })

-- Colors a flat bar without its own color hook reacting to it.
function S:paintBar(bar, r, g, b, a)
    painting[bar] = true
    bar:SetStatusBarColor(r, g, b, a or 1)
    painting[bar] = nil
end

-- Keeps a status bar flat. Blizzard swaps atlases in as units and states change; each swap is
-- undone here, and recolor(bar), if given, decides the color again.
--
-- A secret texture carries a state this code may not read, such as an enemy cast being
-- uninterruptible; Blizzard's own fill stays then, since it is the only one that shows it. A bar
-- whose art shows no state (health) passes force, and is flattened even then: its color is
-- multiplied into Blizzard's art otherwise, and a red over the green fill reads as dark olive.
function S:flatBar(bar, recolor, force)
    if (not bar or not bar.SetStatusBarTexture or not S:once(bar, "flat")) then return false end

    -- Whether a texture Blizzard set should be replaced; a secret one is never compared.
    local function replaces(texture)
        if (S:isSecret(texture)) then return force end

        return texture ~= S.FLAT
    end

    local guardFill

    local function flatten(self)
        self:SetStatusBarTexture(S.FLAT)

        local fill = self:GetStatusBarTexture()

        S:unmask(fill)
        guardFill(self, fill)
    end

    -- Blizzard also sets art on the fill texture itself, past the bar's own setters.
    guardFill = function(self, fill)
        if (not fill or not S:once(fill, "flatfill")) then return end

        local function restore(texture)
            if (not replaces(texture)) then return end

            fill:SetTexture(S.FLAT)

            if (recolor) then recolor(self) end
        end

        hooksecurefunc(fill, "SetTexture", function(_, texture) restore(texture) end)

        if (fill.SetAtlas) then hooksecurefunc(fill, "SetAtlas", function(_, atlas) restore(atlas) end) end
    end

    flatten(bar)

    hooksecurefunc(bar, "SetStatusBarTexture", function(self, texture)
        if (not replaces(texture)) then return end

        flatten(self)

        if (recolor) then recolor(self) end
    end)

    if (bar.SetStatusBarAtlas) then
        hooksecurefunc(bar, "SetStatusBarAtlas", function(self, atlas)
            if (not replaces(atlas)) then return end

            flatten(self)

            if (recolor) then recolor(self) end
        end)
    end

    if (recolor) then
        hooksecurefunc(bar, "SetStatusBarColor", function(self)
            if (not painting[self]) then recolor(self) end
        end)

        recolor(bar)
    end

    return true
end

local tracks = setmetatable({}, { __mode = "k" })
local TRACK_SHADE = 0.22

-- A border and dark fill just outside a bar, so the empty part reads as a track.
function S:barBackdrop(bar)
    if (not bar or not S:once(bar, "track")) then return end

    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    edge:SetColorTexture(UI:rgb("border"))
    S:crisp(edge)

    S:pixelPerfect(function()
        local px = S:pixel(bar)

        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", -px, px)
        edge:SetPoint("BOTTOMRIGHT", px, -px)
    end)

    local fill = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetAllPoints()
    fill:SetColorTexture(UI:rgb("window", 0.9))

    tracks[bar] = fill
end

-- Tints a bar's empty part as a dim shade of its fill, so where the fill ends reads at a glance.
function S:paintTrack(bar, r, g, b)
    local track = tracks[bar]

    if (track) then track:SetColorTexture(r * TRACK_SHADE, g * TRACK_SHADE, b * TRACK_SHADE, 0.95) end
end
