--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The strip along the action bars: the micro menu as kit tiles on a panel, and the bag bar as square
-- slots on a panel of its own. Blizzard's micro button art bakes the icon into its frame, so each
-- tile draws an icon of its own. The experience bar is XPBar.lua's.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local PAD = 4
local TILE_GAP = 1

-- Used when the client keeps no list of its own; buttons a client lacks are skipped.
local MICRO_FALLBACK = {
    "CharacterMicroButton", "SpellbookMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton",
    "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "HousingMicroButton",
    "GuildMicroButton", "SocialsMicroButton", "LFDMicroButton", "LFGMicroButton",
    "CollectionsMicroButton", "EJMicroButton", "WorldMapMicroButton", "StoreMicroButton",
    "MainMenuMicroButton", "HelpMicroButton",
}

-- Each tile's icon, first one the client has. Character shows the player's portrait instead.
local MICRO_ICONS = {
    SpellbookMicroButton    = { "INV_Misc_Book_09" },
    ProfessionMicroButton   = { "INV_Pick_02" },
    PlayerSpellsMicroButton = { "Ability_Marksmanship" },
    TalentMicroButton       = { "Ability_Marksmanship" },
    AchievementMicroButton  = { "Achievement_Quests_Completed_08", "INV_Misc_Coin_17" },
    QuestLogMicroButton     = { "INV_Misc_Note_01" },
    HousingMicroButton      = { "INV_Misc_Key_14", "INV_Misc_Key_03" },
    GuildMicroButton        = { "INV_Shirt_GuildTabard_01", "INV_Misc_Head_Human_01" },
    SocialsMicroButton      = { "Spell_Holy_PrayerOfFortitude" },
    LFDMicroButton          = { "INV_Misc_GroupLooking", "Spell_Holy_PrayerOfSpirit" },
    LFGMicroButton          = { "INV_Misc_GroupLooking", "Spell_Holy_PrayerOfSpirit" },
    CollectionsMicroButton  = { "Ability_Mount_RidingHorse" },
    EJMicroButton           = { "INV_Misc_Book_11" },
    WorldMapMicroButton     = { "INV_Misc_Map_01" },
    StoreMicroButton        = { "INV_Misc_Coin_01" },
    MainMenuMicroButton     = { "INV_Gizmo_02" },
    HelpMicroButton         = { "INV_Misc_QuestionMark" },
}

local BAG_BUTTONS = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
}

local PANEL_GAP = 2  -- space kept between two panels squeezed side by side

local panels = {}  -- name -> kit panel behind a group of buttons

local function iconPath(choices)
    for _, name in ipairs(choices) do
        local path = "Interface\\Icons\\" .. name

        if (not GetFileIDFromPath or GetFileIDFromPath(path)) then return path end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function shown(names)
    local list = {}

    for _, name in ipairs(names) do
        local button = _G[name]

        if (button and button:IsShown()) then list[#list+1] = button end
    end

    return list
end

-- Sets a panel around its buttons with the given side padding. A side padded less than usual is
-- squeezed against another panel, and drops its shadow.
local function placePanel(panel, padLeft, padRight)
    local first, last = panel.first, panel.last

    -- Classic-style micro buttons are drawn in the lower part of a taller frame; the unclickable
    -- top is left out.
    local _, _, topInset = first:GetHitRectInsets()

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", first, "TOPLEFT", -padLeft, -(topInset or 0) + PAD)
    panel:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", padRight, -PAD)

    panel.look.shade:SetSides(padLeft >= PAD, padRight >= PAD, true, true)
end

-- A kit panel behind a group of buttons, anchored to the top-left and bottom-right ones so it
-- follows them wherever Blizzard moves them, and covers a group wrapped onto two rows.
local function panelBehind(key, buttons)
    local panel = panels[key]

    if (#buttons == 0) then
        if (panel) then panel:Hide() end
        return
    end

    local first, last

    for _, button in ipairs(buttons) do
        local left, top = button:GetLeft(), button:GetTop()
        local right, bottom = button:GetRight(), button:GetBottom()

        if (left and top) then
            if (not first or left < first:GetLeft() or (left == first:GetLeft() and top > first:GetTop())) then
                first = button
            end

            if (not last or right > last:GetRight() or (right == last:GetRight() and bottom < last:GetBottom())) then
                last = button
            end
        end
    end

    if (not first) then return end

    if (not panel) then
        local parent = first:GetParent()

        panel = CreateFrame("Frame", nil, parent)
        panel:SetFrameLevel(parent:GetFrameLevel())
        panel.look = S:backdrop(panel, 0, 0.92)
        panels[key] = panel
    end

    panel.first, panel.last = first, last
    placePanel(panel, PAD, PAD)
    panel:Show()
end

-- Edges of a panel's buttons in screen pixels: left, right, bottom, top.
local function buttonEdges(panel)
    local first, last = panel.first, panel.last
    local left, top = first:GetLeft(), first:GetTop()
    local right, bottom = last:GetRight(), last:GetBottom()

    if (not (left and top and right and bottom)) then return nil end

    local a, b = first:GetEffectiveScale(), last:GetEffectiveScale()

    return left * a, right * b, bottom * b, top * a
end

-- Blizzard sets the micro menu and the bag bar close side by side, nearer than two panels' padding;
-- the sides facing each other give up padding so the panels keep a small gap instead of running
-- into each other.
local function separatePanels()
    local micro, bags = panels.micro, panels.bags

    if (not (micro and bags and micro:IsShown() and bags:IsShown())) then return end

    local mLeft, mRight, mBottom, mTop = buttonEdges(micro)
    local bLeft, bRight, bBottom, bTop = buttonEdges(bags)

    if (not (mLeft and bLeft)) then return end
    if (mBottom >= bTop or bBottom >= mTop) then return end -- different rows: nothing to share

    local leftPanel, rightPanel, gap

    if (mRight <= bLeft) then
        leftPanel, rightPanel, gap = micro, bags, bLeft - mRight
    elseif (bRight <= mLeft) then
        leftPanel, rightPanel, gap = bags, micro, mLeft - bRight
    else
        return -- the buttons themselves overlap
    end

    -- Each panel's share of the gap, in its own units, after the space kept between them. A side
    -- that gives up padding drops its shadow too, or it would darken the neighbour.
    local function share(panel)
        local half = gap / panel:GetEffectiveScale() / 2

        if (half >= PAD + PANEL_GAP) then return PAD end

        return math.max(math.min(half - PANEL_GAP / 2, PAD), 0)
    end

    placePanel(leftPanel, PAD, share(leftPanel))
    placePanel(rightPanel, share(rightPanel), PAD)
end

-- Micro menu ------------------------------------------------------------------------------------

local tiles = setmetatable({}, { __mode = "k" }) -- micro button -> its tile

local function paintTile(button)
    local tile = tiles[button]

    if (not tile) then return end

    local enabled = button:IsEnabled()
    local open = button:GetButtonState() == "PUSHED"

    tile.icon:SetDesaturated(not enabled)
    tile.icon:SetAlpha(enabled and 1 or 0.4)

    if (open) then
        tile.bg:SetColorTexture(UI:rgb("accentLit"))
        tile:SetBorderColor(UI:rgb("accent"))
    else
        tile.bg:SetColorTexture(UI:rgb("raised"))
        tile:SetBorderColor(UI:rgb("border"))
    end
end

local function placeIcon(tile)
    local size = math.max(math.min(tile:GetWidth(), tile:GetHeight()) - 6, 8)

    tile.icon:SetSize(size, size)
end

local function skinMicroButton(button, name)
    if (not S:once(button, "micro")) then return end

    -- Every texture the button draws is its old art: normal, pushed, highlight, flash, portrait.
    S:stripTextures(button)
    S:kill(button.Flash)
    S:kill(button.FlashBorder)
    S:kill(button.FlashContent)

    local top, bottom = select(3, button:GetHitRectInsets())

    local tile = CreateFrame("Frame", nil, button)
    tile:SetPoint("TOPLEFT", TILE_GAP, -((top or 0) + TILE_GAP))
    tile:SetPoint("BOTTOMRIGHT", -TILE_GAP, (bottom or 0) + TILE_GAP)

    tile.bg = tile:CreateTexture(nil, "BACKGROUND")
    tile.bg:SetAllPoints()

    UI:addBorder(tile, UI:rgb("border"))

    local hover = tile:CreateTexture(nil, "BORDER")
    hover:SetAllPoints()
    hover:SetColorTexture(UI:rgb("borderLight", 0.35))
    hover:Hide()

    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("CENTER")
    tile.icon:SetTexCoord(unpack(S.ICON_CROP))

    if (name == "CharacterMicroButton") then
        tile.portrait = true
        SetPortraitTexture(tile.icon, "player")
        tile.icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    else
        tile.icon:SetTexture(iconPath(MICRO_ICONS[name] or {}))
    end

    tile:SetScript("OnSizeChanged", placeIcon)
    placeIcon(tile)

    -- Blizzard's alert glow is gone with the art; a pulsing accent dot in the corner says the same.
    local alert = tile:CreateTexture(nil, "OVERLAY", nil, 2)
    alert:SetSize(6, 6)
    alert:SetPoint("TOPRIGHT", -2, -2)
    alert:SetColorTexture(UI:rgb("accent"))
    alert:Hide()

    local pulse = alert:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")

    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.6)

    tile.alert = alert
    tile.pulse = pulse

    tiles[button] = tile

    button:HookScript("OnEnter", function() hover:Show() end)
    button:HookScript("OnLeave", function() hover:Hide() end)
    button:HookScript("OnMouseDown", function() tile.icon:SetPoint("CENTER", 0, -1) end)
    button:HookScript("OnMouseUp", function() tile.icon:SetPoint("CENTER", 0, 0) end)

    -- Blizzard holds a button pushed while its panel is open, and disables ones not yet unlocked.
    hooksecurefunc(button, "SetButtonState", paintTile)
    hooksecurefunc(button, "Enable", paintTile)
    hooksecurefunc(button, "Disable", paintTile)

    paintTile(button)
end

local function setAlert(button, on)
    local tile = tiles[button]

    if (not tile) then return end

    tile.alert:SetShown(on)

    if (on) then
        tile.pulse:Play()
    else
        tile.pulse:Stop()
    end
end

-- The queue eye (dungeon finder, battlegrounds) keeps its animated eye, in a kit slot instead of
-- its gold ring. Each client names it differently.
local QUEUE_BUTTONS = {
    { "QueueStatusButton", "QueueStatusButton.Border" },
    { "QueueStatusMinimapButton", "QueueStatusMinimapButtonBorder" },
    { "MiniMapLFGFrame", "MiniMapLFGFrameBorder" },
    { "MiniMapBattlefieldFrame", "MiniMapBattlefieldBorder" },
}

local function skinQueueButtons()
    for _, entry in ipairs(QUEUE_BUTTONS) do
        local button = S:get(entry[1])

        if (button and S:once(button, "queue")) then
            S:kill(S:get(entry[2]))
            S:kill(button.Border)

            local look = S:iconBackdrop(button, button)

            look.fill:SetAlpha(0.85)
        end
    end
end

local function microNames()
    return MICRO_BUTTONS or MICRO_FALLBACK
end

local function refreshMicro()
    for _, name in ipairs(microNames()) do
        local button = _G[name]

        if (button) then
            skinMicroButton(button, name)
            paintTile(button)
        end
    end

    -- The backing art the micro menu and bags sit on, whatever frame holds them.
    local holder = CharacterMicroButton and CharacterMicroButton:GetParent()

    if (holder and holder ~= UIParent and S:once(holder, "microholder")) then
        S:stripTextures(holder)
        S:kill(holder.MicroBagBar)
    end

    panelBehind("micro", shown(microNames()))
end

local function refreshPortrait()
    for _, tile in pairs(tiles) do
        if (tile.portrait) then SetPortraitTexture(tile.icon, "player") end
    end
end

-- Bags ------------------------------------------------------------------------------------------

local function refreshBags()
    for _, name in ipairs(BAG_BUTTONS) do
        S:itemSlot(_G[name])
    end

    local holder = MainMenuBarBackpackButton and MainMenuBarBackpackButton:GetParent()

    if (holder and holder ~= UIParent and S:once(holder, "bagholder")) then
        S:stripTextures(holder)
    end

    panelBehind("bags", shown(BAG_BUTTONS))
end

local function refreshAll()
    RUI:safe("Menu bar", refreshMicro)
    RUI:safe("Bag bar", refreshBags)
    RUI:safe("Menu and bag panels", separatePanels)
    RUI:safe("Queue button", skinQueueButtons)
end

RUI:registerModule("menubar", "Menu and bags", function()
    refreshAll()

    -- Buttons come and go (vehicles, pet battles, level-gated ones) and the menu moves with them.
    for _, fn in ipairs({ "UpdateMicroButtons", "MoveMicroButtons", "UpdateMicroButtonsParent" }) do
        if (type(_G[fn]) == "function") then hooksecurefunc(fn, refreshAll) end
    end

    -- Blizzard pulses a button to flag something new: unspent talent points, a new mount, mail.
    if (type(MicroButtonPulse) == "function") then
        hooksecurefunc("MicroButtonPulse", function(button) setAlert(button, true) end)
    end

    if (type(MicroButtonPulseStop) == "function") then
        hooksecurefunc("MicroButtonPulseStop", function(button) setAlert(button, false) end)
    end

    -- Opening the flagged panel answers the alert.
    for button in pairs(tiles) do
        button:HookScript("OnClick", function(self) setAlert(self, false) end)
    end

    local events = CreateFrame("Frame")

    -- Edit Mode moves the bars; the panels' anchors follow, the squeeze between them is redone.
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "UNIT_PORTRAIT_UPDATE",
        "EDIT_MODE_LAYOUTS_UPDATED" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function(_, event, unit)
        if (event == "UNIT_PORTRAIT_UPDATE") then
            if (unit == "player") then refreshPortrait() end
            return
        end

        refreshAll()
    end)
end)
