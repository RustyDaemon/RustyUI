--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Player, target, focus, pet, party and boss frames with the ornate art taken off: flat bordered
-- health and power bars, a square portrait on Retail, and class or reaction colored health.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT", "PetFrame" }

for i = 1, 4 do
    FRAMES[#FRAMES+1] = "PartyFrame.MemberFrame" .. i -- Retail
    FRAMES[#FRAMES+1] = "PartyMemberFrame" .. i       -- WoW Forever
end

for i = 1, 5 do
    FRAMES[#FRAMES+1] = "Boss" .. i .. "TargetFrame"
end

-- Art Retail draws as plain textures, which the atlas sweep below cannot recognize.
local ORNAMENTS = {
    "PlayerFrame.PlayerFrameContainer.FrameTexture",
    "PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture",
    "PlayerFrame.PlayerFrameContainer.VehicleFrameTexture",
    "PlayerFrame.PlayerFrameContainer.FrameFlash",
    "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture",
    "PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerPortraitCornerIcon",
    "TargetFrame.TargetFrameContainer.FrameTexture",
    "TargetFrame.TargetFrameContainer.Flash",
    "TargetFrame.TargetFrameContainer.BossPortraitFrameTexture",
    "TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor",
    "FocusFrame.TargetFrameContainer.FrameTexture",
    "FocusFrame.TargetFrameContainer.Flash",
    "FocusFrame.TargetFrameContainer.BossPortraitFrameTexture",
    "FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor",
    "TargetFrameToT.FrameTexture",
    "FocusFrameToT.FrameTexture",

    -- WoW Forever
    "PlayerFrameTexture",
    "PlayerFrameBackground",
    "PlayerFrameVehicleTexture",
    "PlayerFrameFlash",
    "PlayerStatusTexture",
    "PlayerAttackBackground",
    "TargetFrameTextureFrameTexture",
    "TargetFrameBackground",
    "TargetFrameNameBackground",
    "TargetFrameFlash",
    "FocusFrameTextureFrameTexture",
    "FocusFrameBackground",
    "FocusFrameNameBackground",
    "FocusFrameFlash",
    "TargetFrameToTTextureFrameTexture",
    "TargetFrameToTBackground",
    "FocusFrameToTTextureFrameTexture",
    "FocusFrameToTBackground",
    "PetFrameTexture",
    "PetFrameFlash",
    "PetAttackModeTexture",
}

for i = 1, 4 do
    ORNAMENTS[#ORNAMENTS+1] = "PartyMemberFrame" .. i .. "Texture"
    ORNAMENTS[#ORNAMENTS+1] = "PartyMemberFrame" .. i .. "Flash"
    ORNAMENTS[#ORNAMENTS+1] = "PartyMemberFrame" .. i .. "VehicleTexture"
end

local healthBars = {}
local powerBars = {}
local portraits = {} -- unit frame -> its portrait backdrop

-- Retail's frame art is atlases named after the frame ("...-PortraitOn", "...-PortraitOff-Vehicle"),
-- so matching the name catches every variant, elite and rare included, without listing them.
local function isOrnament(texture)
    local atlas = texture.GetAtlas and texture:GetAtlas()

    if (type(atlas) ~= "string") then return false end

    atlas = atlas:lower()

    return (atlas:find("portraiton", 1, true) or atlas:find("portraitoff", 1, true))
        and not atlas:find("-bar", 1, true)
end

local function sweep(frame, depth)
    for _, region in ipairs({ frame:GetRegions() }) do
        if (region:IsObjectType("Texture") and isOrnament(region)) then S:kill(region) end
    end

    if (depth < 4) then
        for _, child in ipairs({ frame:GetChildren() }) do
            sweep(child, depth + 1)
        end
    end
end

local function unitOf(bar)
    local node = bar

    for _ = 1, 5 do
        if (not node) then return nil end
        if (node.unit) then return node.unit end

        node = node:GetParent()
    end
end

-- Unit data can be a secret value in Midnight combat; anything that cannot be read falls back.
local function healthColor(bar)
    local unit = unitOf(bar)

    if (not unit or not UnitExists(unit)) then return nil end

    if (RUI.db.unitframes.classColors and UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        local color = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]

        if (color) then return color.r, color.g, color.b end
    end

    if (UnitIsTapDenied and UnitIsTapDenied(unit)) then return 0.5, 0.5, 0.5 end

    local reaction = UnitReaction(unit, "player")
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]

    if (color) then return color.r, color.g, color.b end
end

local function paintHealth(bar)
    local ok, r, g, b = pcall(healthColor, bar)

    if (not ok or not r) then r, g, b = UI:rgb("good") end

    S:paintBar(bar, r, g, b)
    S:paintTrack(bar, r, g, b)
end

local function powerColor(bar)
    local unit = unitOf(bar)

    if (not unit) then return nil end

    local powerType, token = UnitPowerType(unit)
    local color = (token and PowerBarColor[token]) or PowerBarColor[powerType]

    if (color) then return color.r, color.g, color.b end
end

local function paintPower(bar)
    local ok, r, g, b = pcall(powerColor, bar)

    if (ok and r) then S:paintBar(bar, r, g, b) end
end

-- Elites and bosses get an accent border, rares a silver one: the dragon art is gone with the frame.
local function rankColor(unit)
    local class = unit and UnitClassification(unit)

    if (class == "elite" or class == "worldboss" or class == "rareelite") then return UI:rgb("accent") end
    if (class == "rare") then return 0.78, 0.80, 0.86 end
end

local function paintPortrait(frame)
    local look = portraits[frame]

    if (not look) then return end

    local ok, r, g, b = pcall(rankColor, frame.unit)

    if (not ok or not r) then r, g, b = UI:rgb("border") end

    look:SetBorderColor(r, g, b)
end

local function skinBar(bar, list, paint, force)
    if (not S:flatBar(bar, paint, force)) then return end

    S:barBackdrop(bar)
    -- flatBar painted before the track existed; this pass tints it too.
    paint(bar)

    for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
        S:font(bar[key], nil, true, UI.fontNumber)
    end

    list[#list+1] = bar
end

local function healthBarOf(frame)
    return frame.healthbar or frame.HealthBar
        or (frame.HealthBarContainer and frame.HealthBarContainer.HealthBar)
end

local function powerBarOf(frame)
    return frame.manabar or frame.ManaBar
end

-- Retail portraits are square art under a round mask; with the mask gone they sit in a bordered
-- slot. Forever's portraits are drawn round, so they stay as they are.
local function squarePortrait(frame)
    local portrait = frame.portrait or frame.Portrait

    if (not portrait or not portrait.GetNumMaskTextures or portrait:GetNumMaskTextures() == 0) then return end

    S:unmask(portrait)
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    portraits[frame] = S:iconBackdrop(portrait:GetParent(), portrait)
end

local FIT_GAP = 3

-- Overlaps smaller than this are rounding, not Blizzard's layout; fitting them would creep.
local FIT_SLACK = 0.5

-- Frames whose portrait is drawn the player's size; Blizzard's are a little smaller, which reads as
-- a mismatch once the frame art no longer frames them.
local MATCH_PLAYER = { TargetFrame = true, FocusFrame = true }

local owners = {}                                      -- bar -> the unit frame it belongs to
local narrowed = setmetatable({}, { __mode = "k" })    -- bars fitBar has pulled in at least once

local function portraitOf(frame)
    return frame and (frame.portrait or frame.Portrait)
end

-- True when any of the values is missing or a secret, which must not be compared.
local function unreadable(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)

        if (value == nil or S:isSecret(value)) then return true end
    end

    return false
end

local function matchPortrait(frame)
    local portrait, reference = portraitOf(frame), portraitOf(PlayerFrame)

    if (not portrait or not reference or portrait == reference) then return end

    local width, height = reference:GetSize()

    if (unreadable(width, height, portrait:GetWidth(), portrait:GetHeight()) or width <= 0) then return end

    -- Edit Mode can size each frame on its own; match what shows on screen, not the raw numbers.
    local ratio = reference:GetEffectiveScale() / portrait:GetEffectiveScale()

    width, height = width * ratio, height * ratio

    if (math.abs(portrait:GetWidth() - width) > FIT_SLACK or math.abs(portrait:GetHeight() - height) > FIT_SLACK) then
        portrait:SetSize(width, height)
    end
end

-- Where each of a bar's texts sits on the bar itself, with the inset Blizzard's own anchors use.
local TEXT_SPOTS = {
    LeftText = { "LEFT", 2 },
    RightText = { "RIGHT", -2 },
    TextString = { "CENTER", 0 },
}

-- Blizzard anchors some bars' numbers to the bars' container, not the bar, so a fitted bar would
-- leave them where its old end was. They are moved onto the bar. Their anchors are never read:
-- the texts show secret health in Midnight, and asking where they sit answers in secrets too.
local function anchorTexts(bar)
    for key, spot in pairs(TEXT_SPOTS) do
        local text = bar[key]

        if (text and text.SetPoint) then
            text:ClearAllPoints()
            text:SetPoint(spot[1], bar, spot[1], spot[2], 0)
        end
    end
end

-- Blizzard's bars run on under the frame art and into the portrait's space; with the art gone that
-- part shows. The bar's side facing the portrait is pulled in to stop just short of it. Blizzard
-- anchors the bars again as targets change, so this runs each time; a bar that fits is left be.
local function fitBar(bar, portrait)
    if (not portrait or not portrait:IsShown()) then return end

    local left, right, top, bottom = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom()
    local pl, pr, pt, pb = portrait:GetLeft(), portrait:GetRight(), portrait:GetTop(), portrait:GetBottom()

    if (unreadable(left, right, top, bottom, pl, pr, pt, pb)) then return end

    -- Each measures in its own scale; bring the portrait's into the bar's.
    local ratio = portrait:GetEffectiveScale() / bar:GetEffectiveScale()

    pl, pr, pt, pb = pl * ratio, pr * ratio, pt * ratio, pb * ratio

    if (bottom >= pt or top <= pb) then return end

    local portraitLeft = (pl + pr) / 2 < (left + right) / 2
    local overlap = portraitLeft and (pr + FIT_GAP - left) or (right - (pl - FIT_GAP))

    if (overlap <= FIT_SLACK) then
        -- Blizzard can put the texts back on their own, without moving the bar.
        if (narrowed[bar]) then anchorTexts(bar) end

        return
    end

    narrowed[bar] = true

    local near, far = "LEFT", "RIGHT"
    local sign = 1

    if (not portraitLeft) then
        near, far, sign = "RIGHT", "LEFT", -1
    end

    local points, hasNear, hasFar = {}, false, false

    for i = 1, bar:GetNumPoints() do
        local point = { bar:GetPoint(i) }

        points[i] = point
        hasNear = hasNear or point[1]:find(near) ~= nil
        hasFar = hasFar or point[1]:find(far) ~= nil
    end

    local width = bar:GetWidth()

    bar:ClearAllPoints()

    -- Anchored on both sides, the near side moves in. Otherwise the bar narrows, shifting so its
    -- far side stays put.
    for _, point in ipairs(points) do
        local anchor, relativeTo, relativePoint, x, y = unpack(point)

        if (hasNear and hasFar) then
            if (anchor:find(near)) then x = x + sign * overlap end
        elseif (anchor:find(near)) then
            x = x + sign * overlap
        elseif (not anchor:find(far)) then
            x = x + sign * overlap / 2
        end

        bar:SetPoint(anchor, relativeTo, relativePoint, x, y)
    end

    if (not (hasNear and hasFar)) then bar:SetWidth(width - overlap) end

    anchorTexts(bar)
end

-- Frames that are hidden have no place yet; each is fitted the first time it shows.
local function fitAll()
    if (InCombatLockdown()) then return end

    for name in pairs(MATCH_PLAYER) do
        local frame = _G[name]

        if (frame and frame:IsVisible()) then RUI:safe("Unit frames", matchPortrait, frame) end
    end

    for bar, frame in pairs(owners) do
        if (frame:IsVisible()) then RUI:safe("Unit frames", fitBar, bar, portraitOf(frame)) end
    end
end

local function skinFrame(frame)
    if (not frame or not S:once(frame, "unitframe")) then return end

    sweep(frame, 0)
    S:fonts(frame)

    local health, power = healthBarOf(frame), powerBarOf(frame)

    -- Health art shows no state, so it goes even when Blizzard hands it over as a secret.
    skinBar(health, healthBars, paintHealth, true)
    skinBar(power, powerBars, paintPower)

    if (health) then owners[health] = frame end
    if (power) then owners[power] = frame end

    squarePortrait(frame)
    paintPortrait(frame)
end

local function repaint()
    for _, bar in ipairs(healthBars) do paintHealth(bar) end
    for _, bar in ipairs(powerBars) do paintPower(bar) end
    for frame in pairs(portraits) do paintPortrait(frame) end
end

local function skinAll()
    S:killAll(ORNAMENTS)

    for _, path in ipairs(FRAMES) do
        RUI:safe("Unit frames", skinFrame, S:get(path))
    end
end

RUI:registerModule("unitframes", "Unit frames", function()
    skinAll()

    -- Vehicle art arrives with the vehicle; sweep the player frame again when it changes.
    for _, fn in ipairs({ "PlayerFrame_ToVehicleArt", "PlayerFrame_ToPlayerArt", "PlayerFrame_UpdateArt" }) do
        if (type(_G[fn]) == "function") then
            hooksecurefunc(fn, function()
                sweep(PlayerFrame, 0)
                repaint()

                -- The swap re-anchors the player's bars; fit them again once it is done.
                C_Timer.After(0, fitAll)
            end)
        end
    end

    local events = CreateFrame("Frame")

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE", "UNIT_PET", "UNIT_FACTION", "UNIT_DISPLAYPOWER", "UNIT_TARGET",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_CONNECTION",
        "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function(_, event, unit)
        -- Only a change of target's or focus's target moves a frame shown here.
        if (event == "UNIT_TARGET" and unit ~= "target" and unit ~= "focus") then return end

        -- Party and boss frames are built as the group or encounter fills.
        -- They are secure frames, so one that turns up mid-fight is skinned once the fight is over.
        if (event == "GROUP_ROSTER_UPDATE" or event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
            or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED") then
            if (InCombatLockdown()) then
                events:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                events:UnregisterEvent("PLAYER_REGEN_ENABLED")
                skinAll()
            end
        end

        repaint()

        -- A target or pet frame that just appeared is laid out by the next frame.
        C_Timer.After(0, fitAll)
    end)

    C_Timer.After(0, fitAll)
end, repaint)
