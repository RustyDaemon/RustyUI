--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- RustyUI's own experience bar, in place of Blizzard's. It sits where Blizzard's bar was (or along
-- the screen's bottom edge) in one of several looks, switched live:
--   slim       a thin flat bar with a gradient fill and a tick every tenth
--   segmented  twenty bordered cells, filling like a charge meter
--   panel      a kit card with the level, the bar and the numbers always shown
--   edge       a glowing line along the bottom of the screen
-- At the level cap it shows the watched reputation instead, in its standing's color.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

-- `height` is each look's default; `min` and `max` bound the height setting.
local STYLES = {
    { value = "slim",      text = "Slim",        height = 8,  min = 4,  max = 20 },
    { value = "segmented", text = "Segmented",   height = 10, min = 6,  max = 24 },
    { value = "panel",     text = "Panel",       height = 26, min = 20, max = 40 },
    { value = "edge",      text = "Screen edge", height = 6,  min = 4,  max = 16 },
}

RUI.xpStyles = STYLES

local SEGMENTS = 20
local SEGMENT_GAP = 2
local TICKS = 10

-- The height of Blizzard's bar, which the action bars already leave room for.
local BLIZZARD_HEIGHT = 12

-- Blizzard's bars, hidden while this one shows. The first that exists is where this one goes.
local BLIZZARD_BARS = {
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
    "MainMenuExpBar",
    "ReputationWatchBar",
}

local root = nil
local renderers = {}
local current = nil
local data = nil

local function styleOf(value)
    for _, style in ipairs(STYLES) do
        if (style.value == value) then return style end
    end

    return STYLES[1]
end

-- A style's height as set, kept inside its range.
function RUI:xpHeight(value)
    local style = styleOf(value)
    local saved = RUI.db.xpbar.heights and RUI.db.xpbar.heights[style.value]

    return math.min(math.max(saved or style.height, style.min), style.max)
end

-- How much taller than Blizzard's bar this one is, for the action bars to make room on clients
-- where RustyUI lays them out. The screen-edge line is nowhere near them.
function RUI:xpExtraGap()
    if (not root or not RUI:isEnabled("xpbar")) then return 0 end
    if (not current or current.value == "edge") then return 0 end

    return math.max(RUI:xpHeight(current.value) - BLIZZARD_HEIGHT, 0)
end

-- Data ------------------------------------------------------------------------------------------

local function maxLevel()
    if (GetMaxLevelForPlayerExpansion) then return GetMaxLevelForPlayerExpansion() end
    if (GetMaxPlayerLevel) then return GetMaxPlayerLevel() end

    return MAX_PLAYER_LEVEL or 60
end

local function watchedFaction()
    if (C_Reputation and C_Reputation.GetWatchedFactionData) then
        local faction = C_Reputation.GetWatchedFactionData()

        if (faction and faction.name) then
            return faction.name, faction.reaction, faction.currentReactionThreshold,
                faction.nextReactionThreshold, faction.currentStanding
        end
    end

    if (GetWatchedFactionInfo) then
        local name, standing, low, high, value = GetWatchedFactionInfo()

        if (name) then return name, standing, low, high, value end
    end
end

local function snapshot()
    local level = UnitLevel("player")
    local xpOff = IsXPUserDisabled and IsXPUserDisabled()

    if (level < maxLevel() and not xpOff) then
        local value, max = UnitXP("player"), UnitXPMax("player")

        if (max and max > 0) then
            return { kind = "xp", level = level, value = value, max = max, rested = GetXPExhaustion() or 0 }
        end
    end

    local name, standing, low, high, value = watchedFaction()

    if (name and high and low and high > low) then
        return { kind = "rep", name = name, standing = standing, value = value - low, max = high - low, rested = 0 }
    end
end

local function fillColor(snap)
    if (snap.kind == "rep") then
        local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[snap.standing]

        if (color) then return color.r, color.g, color.b end
    end

    return UI:rgb("accent")
end

local function ratios(snap)
    local filled = math.min(math.max(snap.value / snap.max, 0), 1)
    local withRested = math.min((snap.value + snap.rested) / snap.max, 1)

    return filled, withRested
end

local function percent(value, max)
    return ("%.1f%%"):format(value / max * 100)
end

local function number(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

-- Pieces ----------------------------------------------------------------------------------------

local function paintGradient(texture, r, g, b)
    texture:SetGradient("HORIZONTAL", CreateColor(r * 0.55, g * 0.55, b * 0.55, 1), CreateColor(r, g, b, 1))
end

-- A fill growing from the left of `track`, with a rested extension after it.
local function fillPair(owner, track, inset)
    local fill = owner:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(1, 1, 1, 1)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", inset, inset)

    local rested = owner:CreateTexture(nil, "ARTWORK", nil, -1)
    rested:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    rested:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")

    local function set(snap)
        local width = track:GetWidth() - inset * 2
        local filled, withRested = ratios(snap)
        local r, g, b = fillColor(snap)

        paintGradient(fill, r, g, b)
        fill:SetWidth(math.max(width * filled, 0.01))
        fill:SetShown(filled > 0)

        rested:SetColorTexture(r, g, b, 0.25)
        rested:SetWidth(math.max(width * (withRested - filled), 0.01))
        rested:SetShown(withRested > filled)
    end

    return set
end

local function ticks(owner, track)
    local marks = {}

    for i = 1, TICKS - 1 do
        local mark = owner:CreateTexture(nil, "OVERLAY")
        mark:SetWidth(1)
        mark:SetColorTexture(1, 1, 1, 0.1)
        marks[i] = mark
    end

    return function()
        local width = track:GetWidth()

        for i, mark in ipairs(marks) do
            mark:ClearAllPoints()
            mark:SetPoint("TOP", track, "TOPLEFT", width * i / TICKS, -1)
            mark:SetPoint("BOTTOM", track, "BOTTOMLEFT", width * i / TICKS, 1)
        end
    end
end

-- Renderers: each builds its look on a frame of its own and redraws it from a snapshot ----------

function renderers.slim(frame)
    local look = S:backdrop(frame, 0, 0.9)

    look:SetBorderColor(UI:rgb("border"))
    look.shade:SetAlpha(0.6)

    local set = fillPair(frame, look.area, 1)
    local place = ticks(frame, look.area)

    return function(snap)
        place()
        set(snap)
    end
end

function renderers.segmented(frame)
    local cells = {}

    for i = 1, SEGMENTS do
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        edge:SetColorTexture(UI:rgb("border"))

        local track = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        track:SetColorTexture(UI:rgb("window", 0.92))

        S:crisp(edge)
        S:crisp(track)

        -- The edge shows one physical pixel past the track, not one UI unit.
        S:pixelPerfect(function()
            local px = S:pixel(frame)

            track:ClearAllPoints()
            track:SetPoint("TOPLEFT", edge, "TOPLEFT", px, -px)
            track:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -px, px)
        end)

        local rested = frame:CreateTexture(nil, "ARTWORK", nil, -1)
        rested:SetPoint("TOPLEFT", track, "TOPLEFT")
        rested:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")

        local fill = frame:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")

        cells[i] = { edge = edge, track = track, fill = fill, rested = rested }
    end

    S:shadow(frame, frame, 0.6)

    return function(snap)
        local width = frame:GetWidth()
        local cellWidth = (width - SEGMENT_GAP * (SEGMENTS - 1)) / SEGMENTS
        local inner = cellWidth - 2 * S:pixel(frame)
        local filled, withRested = ratios(snap)
        local r, g, b = fillColor(snap)

        for i, cell in ipairs(cells) do
            local x = (i - 1) * (cellWidth + SEGMENT_GAP)

            cell.edge:ClearAllPoints()
            cell.edge:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
            cell.edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
            cell.edge:SetWidth(cellWidth)

            local start = (i - 1) / SEGMENTS
            local part = math.min(math.max((filled - start) * SEGMENTS, 0), 1)
            local restedPart = math.min(math.max((withRested - start) * SEGMENTS, 0), 1)

            cell.fill:SetColorTexture(r, g, b, 1)
            cell.fill:SetWidth(math.max(inner * part, 0.01))
            cell.fill:SetShown(part > 0)

            cell.rested:SetColorTexture(r, g, b, 0.25)
            cell.rested:SetWidth(math.max(inner * restedPart, 0.01))
            cell.rested:SetShown(restedPart > part)

            -- A full cell gets its border lit, so the run of done cells reads as one block.
            if (part >= 1) then
                cell.edge:SetColorTexture(r * 0.6, g * 0.6, b * 0.6, 1)
            else
                cell.edge:SetColorTexture(UI:rgb("border"))
            end
        end
    end
end

function renderers.panel(frame)
    local look = S:backdrop(frame, 0, 0.94)

    look:SetBorderColor(UI:rgb("borderLight"))

    local badge = frame:CreateTexture(nil, "ARTWORK")
    badge:SetPoint("LEFT", 4, 0)
    badge:SetWidth(30)
    badge:SetColorTexture(UI:rgb("accentLit"))

    local badgeEdge = S:lines(frame, badge, 0, "OVERLAY")

    local level = UI:text(frame, 12, "accent")
    level:SetPoint("CENTER", badge, "CENTER", 0, 0)

    local label = UI:text(frame, 11, "textDim")
    label:SetPoint("RIGHT", -8, 0)

    local track = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    track:SetPoint("LEFT", badge, "RIGHT", 8, 0)
    track:SetPoint("RIGHT", label, "LEFT", -10, 0)
    track:SetColorTexture(0, 0, 0, 0.55)

    local trackEdge = S:lines(frame, track, 1, "BORDER")

    trackEdge:SetColor(UI:rgb("border"))

    local set = fillPair(frame, track, 0)
    local place = ticks(frame, track)

    return function(snap)
        local r, g, b = fillColor(snap)
        local height = frame:GetHeight()

        -- At the default 26 the badge is 18 high and the track 8.
        badge:SetHeight(height - 8)
        track:SetHeight(math.max(math.floor((height - 10) / 2), 4))

        badgeEdge:SetColor(r * 0.7, g * 0.7, b * 0.7)
        level:SetTextColor(r, g, b)

        if (snap.kind == "xp") then
            level:SetText(snap.level)

            local text = percent(snap.value, snap.max)

            if (snap.rested > 0) then
                text = text .. "  ·  +" .. percent(math.min(snap.rested, snap.max - snap.value), snap.max) .. " rested"
            end

            label:SetText(text)
        else
            level:SetText("Rep")
            label:SetText(snap.name .. "  ·  " .. percent(snap.value, snap.max))
        end

        place()
        set(snap)
    end
end

function renderers.edge(frame)
    local track = frame:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("BOTTOMLEFT")
    track:SetPoint("BOTTOMRIGHT")
    track:SetColorTexture(0, 0, 0, 0.6)

    local set = fillPair(frame, track, 0)

    -- A soft glow rising off the filled part.
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetPoint("BOTTOMLEFT", track, "TOPLEFT")

    return function(snap)
        local filled = ratios(snap)
        local r, g, b = fillColor(snap)
        local height = frame:GetHeight()

        -- The line is the frame's height less a little room to hover it by: 3 at the default 6.
        track:SetHeight(math.max(height - 3, 1))
        glow:SetHeight(height + 4)

        set(snap)

        glow:SetGradient("VERTICAL", CreateColor(r, g, b, 0.28), CreateColor(r, g, b, 0))
        glow:SetWidth(math.max(track:GetWidth() * filled, 0.01))
        glow:SetShown(filled > 0)
    end
end

-- Previews --------------------------------------------------------------------------------------

local SAMPLE = { kind = "xp", level = 42, value = 6500, max = 10000, rested = 1500 }

-- A style drawn with sample numbers into `holder`, for the settings' preview cards. It uses the
-- style's own renderer, so the preview is the bar, only smaller.
function RUI:drawXPPreview(holder, value)
    local style = styleOf(value)
    local frame = CreateFrame("Frame", nil, holder)

    frame:SetHeight(style.height)

    if (style.value == "edge") then
        frame:SetPoint("BOTTOMLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", 0, 0)
    else
        frame:SetPoint("LEFT", 10, 0)
        frame:SetPoint("RIGHT", -10, 0)
    end

    local draw = renderers[style.value](frame)

    frame:SetScript("OnSizeChanged", function() draw(SAMPLE) end)
    draw(SAMPLE)
end

-- The bar itself --------------------------------------------------------------------------------

local function showTooltip()
    if (not data) then return end

    GameTooltip:SetOwner(root, "ANCHOR_TOP")

    local dr, dg, db = UI:rgb("textDim")

    if (data.kind == "xp") then
        GameTooltip:SetText(LEVEL .. " " .. data.level, 1, 1, 1)
        GameTooltip:AddDoubleLine(XP or "Experience",
            number(data.value) .. " / " .. number(data.max) .. "  (" .. percent(data.value, data.max) .. ")",
            dr, dg, db, 1, 1, 1)
        GameTooltip:AddDoubleLine("Remaining", number(data.max - data.value), dr, dg, db, 1, 1, 1)

        if (data.rested > 0) then
            local ar, ag, ab = UI:rgb("accent")

            GameTooltip:AddDoubleLine("Rested", number(data.rested) .. "  (" .. percent(data.rested, data.max) .. ")",
                dr, dg, db, ar, ag, ab)
        end
    else
        local r, g, b = fillColor(data)

        GameTooltip:SetText(data.name, 1, 1, 1)
        GameTooltip:AddLine(_G["FACTION_STANDING_LABEL" .. (data.standing or 0)] or "", r, g, b)
        GameTooltip:AddDoubleLine(REPUTATION or "Reputation",
            number(data.value) .. " / " .. number(data.max) .. "  (" .. percent(data.value, data.max) .. ")",
            dr, dg, db, 1, 1, 1)
    end

    GameTooltip:Show()
end

-- A frame is only worth anchoring to once it has a real place on screen: a holder frame can have no
-- size of its own, or sit somewhere other than the bars it draws.
local function onScreen(frame)
    local bottom, width = frame:GetBottom(), frame:GetWidth()

    return bottom ~= nil and bottom >= 0 and width ~= nil and width > 100
end

local function widestBar(frame, depth, best)
    if (frame:IsObjectType("StatusBar") and onScreen(frame)) then
        if (not best or frame:GetWidth() > best:GetWidth()) then best = frame end
    end

    if (depth < 4) then
        for _, child in ipairs({ frame:GetChildren() }) do
            best = widestBar(child, depth + 1, best)
        end
    end

    return best
end

-- Where Blizzard draws its experience bar: the widest status bar inside its holders, so the anchor is
-- the bar itself rather than a holder around it.
local function blizzardAnchor()
    for _, name in ipairs(BLIZZARD_BARS) do
        local frame = S:get(name)

        if (frame) then
            local bar = widestBar(frame, 0, nil)

            if (bar) then return bar end
        end
    end
end

-- Blizzard's bars stay where they are, invisible and out of the mouse's way, so this bar can take
-- their place without moving anything secure.
local function muteBlizzard(frame, depth)
    if (frame.EnableMouse and frame:IsMouseEnabled()) then frame:EnableMouse(false) end

    if (depth < 4) then
        for _, child in ipairs({ frame:GetChildren() }) do muteBlizzard(child, depth + 1) end
    end
end

local function hideBlizzard()
    for _, name in ipairs(BLIZZARD_BARS) do
        local frame = S:get(name)

        if (frame) then
            frame:SetAlpha(0)

            if (not InCombatLockdown()) then muteBlizzard(frame, 0) end
        end
    end
end

local function place()
    root:ClearAllPoints()

    if (current.value == "edge") then
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    else
        local anchor = blizzardAnchor()

        -- Sitting on the bottom of Blizzard's slot, a taller look grows up into the room the action
        -- bars make for it, never down into the main bar.
        if (anchor) then
            root:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
            root:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        elseif (ActionButton1 and ActionButton12 and onScreen(ActionButton1)) then
            -- No Blizzard bar to stand in for: just above the main action bar.
            root:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", 0, 4)
            root:SetPoint("BOTTOMRIGHT", ActionButton12, "TOPRIGHT", 0, 4)
        else
            root:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 4)
            root:SetWidth(512)
        end
    end

    root:SetHeight(RUI:xpHeight(current.value))
end

local function redraw()
    if (not root) then return end

    data = snapshot()

    if (not data) then
        root:Hide()
        return
    end

    root:Show()

    local view = root.views[current.value]

    if (view) then view.draw(data) end
end

local function applyStyle()
    if (not root) then return end

    current = styleOf(RUI.db.xpbar.style)

    for value, view in pairs(root.views) do view.frame:SetShown(value == current.value) end

    if (not root.views[current.value]) then
        local frame = CreateFrame("Frame", nil, root)
        frame:SetAllPoints()

        root.views[current.value] = { frame = frame, draw = renderers[current.value](frame) }
    end

    place()
    hideBlizzard()
    redraw()

    -- A bar taller than Blizzard's needs the action bars to make room for it.
    RUI:refresh("actionbars")
end

RUI:registerModule("xpbar", "XP bar", function()
    root = CreateFrame("Frame", "RustyUIExperienceBar", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(10)
    root:EnableMouse(true)
    root.views = {}

    root:SetScript("OnEnter", showTooltip)
    root:SetScript("OnLeave", function() GameTooltip:Hide() end)
    root:SetScript("OnSizeChanged", redraw)

    applyStyle()

    local events = CreateFrame("Frame")

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
        "UPDATE_EXHAUSTION", "UPDATE_FACTION", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN",
        "DISABLE_XP_GAIN", "PLAYER_REGEN_ENABLED" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function(_, event)
        -- Blizzard builds its bars as they first show; each new one is hidden too, and the place is
        -- found again once the screen has its final layout.
        if (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED") then
            hideBlizzard()
            C_Timer.After(1, function() RUI:safe("XP bar", place) end)
        end

        redraw()
    end)
end, applyStyle)
