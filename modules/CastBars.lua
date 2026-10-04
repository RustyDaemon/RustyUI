--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Blizzard's cast bars in one of several looks, switched live:
--   slim     the flat bordered bar, with the text and icon where Blizzard puts them
--   framed   the bar in a kit window: spell name and time in a title bar, icon in its own slot
--   thick    a tall bar with the name and time on it and the icon fused to its left end
--   minimal  a thin line with the name and time above it and no icon
-- The bars stay Blizzard's: they keep their own update logic (and the secret values Midnight hands
-- them for enemy casts); only their look, size and the place of their text and icon change.
-- Retail's bars name their state, so it picks the color; WoW Forever's keep Blizzard's own cast
-- colors on the flat texture.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local STYLES = {
    { value = "slim",    text = "Slim" },
    { value = "framed",  text = "Framed",  height = 12 },
    { value = "thick",   text = "Thick",   height = 20 },
    { value = "minimal", text = "Minimal", height = 4 },
}

RUI.castStyles = STYLES

local BARS = {
    "PlayerCastingBarFrame", -- Retail
    "CastingBarFrame",       -- WoW Forever
    "PetCastingBarFrame",
    "TargetFrameSpellBar",
    "FocusFrameSpellBar",
}

local PLAYER_BARS = { PlayerCastingBarFrame = true, CastingBarFrame = true }

local STATE_COLORS = {
    standard = "accent",
    empowered = "accent",
    applyingcrafting = "accent",
    applyingtalents = "accent",
    channel = "good",
    uninterruptable = "textDim",
    interrupted = "bad",
}

local HEADER = 15 -- the framed style's title bar
local FRAME_PAD = 4

local looks = {} -- bar -> its look
local current = STYLES[1]

local function styleOf(value)
    for _, style in ipairs(STYLES) do
        if (style.value == value) then return style end
    end

    return STYLES[1]
end

local function paint(bar)
    local state = bar.barType

    -- An enemy's cast state is secret in Midnight; Blizzard's own colored fill shows it instead.
    if (S:isSecret(state) or not state) then return end

    S:paintBar(bar, UI:rgb(STATE_COLORS[state] or "accent"))
end

local function part(bar, key, suffix)
    local name = bar:GetName()

    return bar[key] or (name and _G[name .. suffix])
end

local function savePoints(region)
    local points = {}

    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end

    return points
end

local function restorePoints(region, points)
    region:ClearAllPoints()

    for _, point in ipairs(points) do region:SetPoint(unpack(point)) end
end

-- Seconds left on the bar as text, or nil when Blizzard keeps them from addons (enemy casts in Midnight).
local function remaining(bar)
    -- Reading a secret throws; every comparison stays inside the pcall.
    local ok, left = pcall(function()
        local value, max = bar.value, bar.maxValue
        local left = (bar.channeling and not bar.reverseChanneling) and value or (max - value)

        if (left >= 0) then return ("%.1f"):format(left) end
    end)

    if (ok) then return left end
end

-- Look ------------------------------------------------------------------------------------------

-- Everything the styles draw on a bar, made once; layout() shows and places the pieces for the
-- style in use. `bar` is a Blizzard cast bar, or a stand-in for the settings' previews.
local function buildLook(bar, icon, text)
    local look = { bar = bar, icon = icon, text = text }

    look.height = bar:GetHeight()
    look.textFont = text and { text:GetFont() }
    look.textPoints = text and savePoints(text)
    look.iconPoints = icon and savePoints(icon)
    look.iconSize = icon and { icon:GetSize() }

    if (icon) then
        S:cropIcon(icon)
        look.iconSlot = S:iconBackdrop(bar, icon, false)
    end

    -- The framed style's window, on a frame under the bar.
    local frame = CreateFrame("Frame", nil, bar)
    frame:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
    frame:SetPoint("TOPLEFT")
    frame:SetPoint("BOTTOMRIGHT")

    local window = S:backdrop(frame, 0, 0.94)

    window:SetBorderColor(UI:rgb("borderLight"))

    local lr, lg, lb = UI:rgb("accentLit")
    local header = UI:gradient(frame, "BACKGROUND", "VERTICAL",
        0.055, 0.059, 0.070, 1, lr * 0.6 + 0.04, lg * 0.6 + 0.04, lb * 0.6 + 0.04, 1)
    header:SetDrawLayer("BACKGROUND", -5)
    header:SetPoint("TOPLEFT", window.area, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", window.area, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)

    look.frame = frame
    look.window = window

    -- Time left, for the styles that show it; the rest leave Blizzard's own cast time alone.
    look.timer = UI:text(bar, 10, "textDim")
    look.timer:SetDrawLayer("OVERLAY", 7)

    -- The player's latency: the end of the bar the server takes back, so a key pressed there queues.
    if (PLAYER_BARS[bar:GetName() or ""]) then
        look.latency = bar:CreateTexture(nil, "OVERLAY", nil, -1)
        look.latency:SetColorTexture(UI:rgb("bad", 0.45))
        look.latency:Hide()
    end

    looks[bar] = look

    return look
end

local function setFont(look, size, outline)
    if (look.text) then S:font(look.text, size, outline) end

    S:font(look.timer, size - 1, outline, UI.fontNumber)
    look.timer:SetTextColor(UI:rgb(outline and "text" or "textDim"))
end

local function iconShown(look)
    return look.icon and look.icon:IsShown()
end

local function layout(look, style)
    local bar, icon, text, timer = look.bar, look.icon, look.text, look.timer
    local value = style.value

    if (style.height) then
        bar:SetHeight(style.height)
    elseif (look.height and look.height > 0) then
        bar:SetHeight(look.height)
    end

    look.frame:SetShown(value == "framed")
    timer:SetShown(value ~= "slim")

    -- Edit Mode's own cast time would repeat ours.
    if (bar.CastTimeText) then bar.CastTimeText:SetAlpha(value == "slim" and 1 or 0) end

    if (icon) then
        icon:SetAlpha(value == "minimal" and 0 or 1)
        look.iconSlot:SetShown(value ~= "minimal" and iconShown(look))
    end

    if (value == "slim") then
        if (text) then
            S:font(text, 11)
            restorePoints(text, look.textPoints)
        end

        if (icon) then
            restorePoints(icon, look.iconPoints)
            icon:SetSize(unpack(look.iconSize))
        end

        return
    end

    timer:ClearAllPoints()

    if (value == "framed") then
        local height = style.height + HEADER + 2
        local left = iconShown(look) and icon or bar

        if (icon) then
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -FRAME_PAD, 0)
            icon:SetSize(height, height)
        end

        look.window.area:ClearAllPoints()
        look.window.area:SetPoint("TOPLEFT", left, "TOPLEFT", -FRAME_PAD, FRAME_PAD + (left == bar and HEADER + 2 or 0))
        look.window.area:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", FRAME_PAD, -FRAME_PAD)

        setFont(look, 11)

        if (text) then
            text:ClearAllPoints()
            text:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 1, 4)
            text:SetPoint("RIGHT", timer, "LEFT", -6, 0)
            text:SetJustifyH("LEFT")
        end

        timer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -1, 4)
    elseif (value == "thick") then
        if (icon) then
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", bar, "LEFT", -2 * S:pixel(bar), 0)
            icon:SetSize(style.height, style.height)
        end

        setFont(look, 11, true)

        if (text) then
            text:ClearAllPoints()
            text:SetPoint("LEFT", bar, "LEFT", 5, 0)
            text:SetPoint("RIGHT", timer, "LEFT", -6, 0)
            text:SetJustifyH("LEFT")
        end

        timer:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    else -- minimal
        setFont(look, 10)

        if (text) then
            text:ClearAllPoints()
            text:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
            text:SetPoint("RIGHT", timer, "LEFT", -6, 0)
            text:SetJustifyH("LEFT")
        end

        timer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 3)
    end

    if (text) then text:SetWordWrap(false) end
end

-- Blizzard bars -------------------------------------------------------------------------------

local function showLatency(look)
    local latency = look.latency

    if (not latency) then return end

    latency:Hide()

    local bar = look.bar
    -- name, text, texture, startMs, endMs, isTradeSkill, ...
    local _, _, _, startMs, endMs = UnitCastingInfo("player")
    local channel = false

    if (not startMs) then
        _, _, _, startMs, endMs = UnitChannelInfo("player")
        channel = true
    end

    local _, _, _, worldMs = GetNetStats()

    if (not (startMs and endMs and worldMs)) then return end

    -- Midnight may hand the times over as secrets, which cannot be compared; no marker then.
    if (S:isSecret(startMs) or S:isSecret(endMs)) then return end

    if (type(startMs) ~= "number" or type(endMs) ~= "number" or endMs <= startMs) then return end

    local share = math.min(worldMs / (endMs - startMs), 1)

    if (share <= 0) then return end

    -- A channel counts down from the left, so the part taken back is at the left end.
    latency:ClearAllPoints()
    latency:SetPoint(channel and "TOPLEFT" or "TOPRIGHT")
    latency:SetPoint(channel and "BOTTOMLEFT" or "BOTTOMRIGHT")
    latency:SetWidth(math.max(bar:GetWidth() * share, 0.01))
    latency:Show()
end

local function tickTimer(bar, elapsed)
    local look = looks[bar]

    if (not look or not look.timer:IsShown()) then return end

    look.elapsed = (look.elapsed or 0) + elapsed

    if (look.elapsed < 0.05) then return end

    look.elapsed = 0

    look.timer:SetText(remaining(bar) or "")
end

local function skinBar(bar)
    if (not bar or not S:once(bar, "castbar")) then return end

    S:flatBar(bar, paint)
    S:barBackdrop(bar)

    S:kill(part(bar, "Border", "Border"))
    S:kill(part(bar, "BorderShield", "BorderShield"))
    S:kill(part(bar, "TextBorder", "TextBorder"))
    S:kill(part(bar, "Flash", "Flash"))
    S:kill(bar.Background)

    local text = part(bar, "Text", "Text")

    S:font(text, 11)

    local look = buildLook(bar, part(bar, "Icon", "Icon"), text)

    bar:HookScript("OnUpdate", tickTimer)

    -- Blizzard shows the icon per cast, and only some bars show it at all; the window follows.
    bar:HookScript("OnShow", function(self)
        layout(look, current)
        if (look.latency) then look.latency:Hide() end
    end)

    bar:HookScript("OnHide", function()
        if (look.latency) then look.latency:Hide() end
    end)

    -- Retail's player bar changes size and text place when it is locked to the player frame; that
    -- is the new layout to come back to.
    if (bar.SetLook) then
        hooksecurefunc(bar, "SetLook", function(self)
            look.height = self:GetHeight()
            look.textPoints = text and savePoints(text)
            look.iconPoints = look.icon and savePoints(look.icon)
            look.iconSize = look.icon and { look.icon:GetSize() }
            layout(look, current)
        end)
    end

    layout(look, current)
end

local function applyStyle()
    current = styleOf(RUI.db.castbars.style)

    for _, look in pairs(looks) do RUI:safe("Cast bars", layout, look, current) end
end

-- Previews --------------------------------------------------------------------------------------

-- A style drawn with a sample cast into `holder`, for the settings' preview cards. It is a stand-in
-- bar going through the same look as the real ones.
function RUI:drawCastPreview(holder, value)
    local style = styleOf(value)

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetStatusBarTexture(S.FLAT)
    bar:SetStatusBarColor(UI:rgb("accent"))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.62)
    bar:SetHeight(10)
    bar:SetPoint("LEFT", 44, value == "framed" and -8 or (value == "minimal" and -4 or 0))
    bar:SetPoint("RIGHT", -12, 0)

    S:barBackdrop(bar)

    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)

    local text = UI:text(bar, 11, "text")
    text:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    text:SetText("Fireball")

    local look = buildLook(bar, icon, text)

    looks[bar] = nil -- a preview follows no setting
    look.timer:SetText("1.4")

    layout(look, style)
end

RUI:registerModule("castbars", "Cast bars", function()
    current = styleOf(RUI.db.castbars.style)

    for _, name in ipairs(BARS) do
        RUI:safe("Cast bars", skinBar, _G[name])
    end

    local events = CreateFrame("Frame")

    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_DELAYED" }) do
        pcall(events.RegisterUnitEvent, events, event, "player")
    end

    events:SetScript("OnEvent", function()
        for bar, look in pairs(looks) do
            if (look.latency) then RUI:safe("Cast bar latency", showLatency, look) end
        end
    end)
end, applyStyle)
