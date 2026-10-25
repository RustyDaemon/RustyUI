--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Blizzard's raid frames, and its party frames when they are raid-style: flat health and power
-- bars with a 1px border along each frame's edge, and the empty part of the health bar a dim shade
-- of whatever color Blizzard gives it. The target and aggro glows become 1px borders. Nameplates
-- are built from the same frames; the nameplates module skins those.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local GROUPS = { "^CompactRaid", "^CompactParty" }

-- Blizzard's separators, drawn eight pixels wide around and inside each frame.
local SEPARATORS = { "horizTopBorder", "horizBottomBorder", "vertLeftBorder", "vertRightBorder", "horizDivider" }

-- The containers' own borders, shown with Edit Mode's Display Border.
local CONTAINER_BORDERS = { "CompactPartyFrameBorderFrame", "CompactRaidFrameContainerBorderFrame" }

local MAX_RAID_FRAMES = 80
local MAX_GROUPS = 8

local pending = {} -- frames that turned up mid-fight, skinned once it is over

-- Nameplates are forbidden in instances, and calling into one errors; they are never touched.
local function isGroupFrame(frame)
    if (type(frame) ~= "table" or not frame.healthBar) then return false end
    if (frame.IsForbidden and frame:IsForbidden()) then return false end

    local name = frame:GetName()

    if (not name) then return false end

    for _, pattern in ipairs(GROUPS) do
        if (name:find(pattern)) then return true end
    end

    return false
end

-- A glow Blizzard shows and hides, as 1px lines on the frame that follow it. Its color is passed on,
-- not read, so a secret threat color still shows.
local function glowLines(frame, glow, outset, color)
    if (not glow) then return end

    glow:SetAlpha(0)

    local lines = S:lines(frame, frame, outset, "OVERLAY", 7)

    local function show(shown)
        for _, edge in ipairs(lines.edges) do edge:SetShown(shown) end
    end

    if (color) then
        lines:SetColor(UI:rgb(color))
    else
        hooksecurefunc(glow, "SetVertexColor", function(_, r, g, b) lines:SetColor(r, g, b) end)
    end

    hooksecurefunc(glow, "Show", function() show(true) end)
    hooksecurefunc(glow, "Hide", function() show(false) end)
    hooksecurefunc(glow, "SetShown", function(_, shown) show(shown) end)

    show(glow:IsShown())
end

local function skinAuras(list)
    for _, aura in ipairs(list or {}) do
        S:cropIcon(aura.icon or aura.Icon)
    end
end

local function skinFrame(frame)
    if (not isGroupFrame(frame)) then return end

    -- They are secure frames; one that turns up mid-fight waits for the fight to end.
    if (InCombatLockdown()) then
        pending[frame] = true
        return
    end

    if (not S:once(frame, "raidframe")) then return end

    S:kill(frame.background)

    for _, key in ipairs(SEPARATORS) do S:kill(frame[key]) end

    local health, power = frame.healthBar, frame.powerBar

    S:kill(health.background)
    S:barBackdrop(health)

    -- Health art shows no state, so it goes even when Blizzard hands it over as a secret.
    S:flatBar(health, function(bar) S:matchTrack(bar) end, true)

    if (power) then
        S:kill(power.background)
        S:barBackdrop(power)
        S:flatBar(power)
    end

    -- Aggro on the frame's edge, the target just inside it, so both show at once.
    glowLines(frame, frame.aggroHighlight, 0)
    glowLines(frame, frame.selectionHighlight, -1, "text")

    S:font(frame.name)
    S:font(frame.statusText, nil, true, UI.fontNumber)

    skinAuras(frame.buffFrames)
    skinAuras(frame.debuffFrames)
    skinAuras(frame.dispelDebuffFrames)
end

local function skinContainers()
    for _, name in ipairs(CONTAINER_BORDERS) do
        local border = _G[name]

        if (border) then S:stripTextures(border) end
    end

    for i = 1, MAX_GROUPS do
        local border = _G["CompactRaidGroup" .. i .. "BorderFrame"]

        if (border) then S:stripTextures(border) end
    end
end

local function skinAll()
    skinContainers()

    for i = 1, 5 do
        RUI:safe("Raid frames", skinFrame, _G["CompactPartyFrameMember" .. i])
        RUI:safe("Raid frames", skinFrame, _G["CompactPartyFramePet" .. i])

        for group = 1, MAX_GROUPS do
            RUI:safe("Raid frames", skinFrame, _G["CompactRaidGroup" .. group .. "Member" .. i])
        end
    end

    for i = 1, MAX_RAID_FRAMES do
        RUI:safe("Raid frames", skinFrame, _G["CompactRaidFrame" .. i])
    end
end

local function skinPending()
    for frame in pairs(pending) do
        pending[frame] = nil
        RUI:safe("Raid frames", skinFrame, frame)
    end

    RUI:safe("Raid frames", skinContainers)
end

RUI:registerModule("raidframes", "Raid frames", function()
    skinAll()

    -- Every frame is set up through one of these as Blizzard builds it, and again as its layout changes.
    for _, fn in ipairs({ "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup" }) do
        if (type(_G[fn]) == "function") then
            hooksecurefunc(fn, function(frame) RUI:safe("Raid frames", skinFrame, frame) end)
        end
    end

    local events = CreateFrame("Frame")

    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:SetScript("OnEvent", function()
        if (InCombatLockdown()) then return end

        skinPending()
    end)
end)
