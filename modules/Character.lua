--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The character window in the kit's window look: gear slots as square slots bordered in the item's
-- quality color, kit tabs, and the stats as kit headings over an accent rule. The model and the
-- race art behind it stay. Retail keeps its tabs along the bottom; WoW Forever splits the window
-- into two panes with icon tabs down the side.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local MAX_TABS = 6
local MAX_SIDEBAR_TABS = 4

local STAT_CATEGORIES = { "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }

local function wantQuality()
    return RUI.db.character.qualityBorders
end

-- The art around the model: a frame of corners and edges, and a rule between the model and the weapons.
local MODEL_BORDERS = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom",
    "Bottom2" }

-- A slot's own art sits under its icon: the slot frame, and the brackets beside the weapon slots.
-- The empty slot's silhouette is the icon itself, and stays: it says which piece goes there.
local function killSlotArt(slot)
    local icon = slot.icon or slot.Icon

    for _, region in ipairs({ slot:GetRegions() }) do
        if (region:IsObjectType("Texture") and region ~= icon and region:GetDrawLayer() == "BACKGROUND") then
            S:kill(region)
        end
    end
end

local function skinSlot(slot)
    if (not S:once(slot, "gearslot")) then return end

    -- Before the slot's own backdrop, which is drawn under the icon too.
    killSlotArt(slot)
    S:itemSlot(slot, wantQuality)
end

local function skinSlots()
    local items = PaperDollItemsFrame

    if (not items) then return end

    for _, child in ipairs({ items:GetChildren() }) do
        local isButton = child:IsObjectType("Button") or child:IsObjectType("ItemButton")

        if (isButton and (child.icon or child.Icon)) then skinSlot(child) end
    end
end

-- A category's banner becomes its title over a thin accent rule, like the objective tracker's.
local function skinCategory(category)
    if (not category or not S:once(category, "statcategory")) then return end

    S:kill(category.Background)
    S:font(category.Title, 13)

    local rule = category:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", category, "BOTTOMLEFT", 8, 2)
    rule:SetPoint("BOTTOMRIGHT", category, "BOTTOMRIGHT", -8, 2)
    rule:SetHeight(1)
    rule:SetColorTexture(UI:rgb("accentDim", 0.7))
end

-- Every other stat row carries a stripe; Blizzard shows and hides it, and it is drawn flat here.
local function skinStatRows(pane)
    local pool = pane and pane.statsFramePool

    if (not pool or not pool.EnumerateActive) then return end

    for row in pool:EnumerateActive() do
        if (S:once(row, "statrow")) then
            if (row.Background) then row.Background:SetColorTexture(1, 1, 1, 0.04) end

            S:fonts(row, 1)
        end
    end
end

local function skinStats()
    local pane = CharacterStatsPane

    if (not pane) then return end

    -- The class's stone art, with its own ornate frame, behind the stats.
    S:kill(pane.ClassBackground)

    for _, key in ipairs(STAT_CATEGORIES) do skinCategory(pane[key]) end

    local itemLevel = pane.ItemLevelFrame

    if (itemLevel and S:once(itemLevel, "itemlevel")) then
        S:kill(itemLevel.Background)
        S:font(itemLevel.Value, 18, false, UI.fontNumber)
    end

    skinStatRows(pane)
end

-- The flyout of items that fit a slot, shown with Alt held over it, as a kit panel of slots.
local function skinFlyout()
    local flyout = EquipmentFlyoutFrame
    local frame = flyout and flyout.buttonFrame

    if (not frame) then return end

    if (S:once(frame, "flyout")) then
        S:stripTextures(frame)
        S:backdrop(frame, 0, 0.97)
    end

    for _, button in ipairs(flyout.buttons or {}) do
        S:itemSlot(button, wantQuality)
    end
end

local function skinTabs(frame)
    local name = frame:GetName()

    for i = 1, MAX_TABS do
        S:tab(_G[name .. "Tab" .. i])
    end

    -- Retail's sidebar tabs sit on a strip with decor at both ends.
    if (PaperDollSidebarTabs) then S:stripTextures(PaperDollSidebarTabs) end

    -- Their icons are the portrait and pieces of a sheet Blizzard cuts by coordinates; a crop would
    -- show the wrong piece.
    for i = 1, MAX_SIDEBAR_TABS do
        S:sideTab(_G["PaperDollSidebarTab" .. i], true)
    end

    -- Forever's pages are picked from icon tabs down the window's side.
    local modeTabs = frame.ModeTabs

    if (modeTabs and modeTabs.Tabs) then
        for _, tab in ipairs(modeTabs.Tabs) do S:sideTab(tab) end
    end
end

-- Forever splits the window into two panes, each with art of its own.
local function skinPanes(frame)
    if (frame.LeftPaneHost) then S:stripTextures(frame.LeftPaneHost) end

    local right = frame.RightPaneHost

    if (right) then
        S:stripTextures(right)
        S:kill(right.StoneBg)

        -- The strip between the panes is the right pane's first child, an unnamed frame of art.
        local divider = right:GetChildren()

        if (divider) then S:stripTextures(divider) end
    end

    local strip = PaperDollFrame and PaperDollFrame.TopBackgroundStripHost

    if (strip) then strip:SetAlpha(0) end
end

local function skinWindow()
    local frame = CharacterFrame

    if (not frame or not S:once(frame, "character")) then return end

    S:window(frame)

    for _, inset in ipairs({ "CharacterFrameInset", "CharacterFrameInsetRight" }) do
        S:inset(_G[inset])
    end

    S:font(CharacterLevelText)

    -- The model keeps its background art; Blizzard's frame around it gives way to a 1px border.
    for _, part in ipairs(MODEL_BORDERS) do S:kill(_G["PaperDollInnerBorder" .. part]) end

    if (CharacterModelScene) then S:lines(CharacterModelScene, CharacterModelScene, 0, "OVERLAY", 7) end

    skinPanes(frame)
    skinTabs(frame)
    skinSlots()
    skinStats()

    -- Tabs and slots that are built late, and stats laid out again, as the window opens.
    frame:HookScript("OnShow", function(self)
        RUI:safe("Character window", skinTabs, self)
        RUI:safe("Character window", skinSlots)
        RUI:safe("Character window", skinStats)
    end)

    if (type(PaperDollFrame_UpdateStats) == "function") then
        hooksecurefunc("PaperDollFrame_UpdateStats", function() RUI:safe("Character window", skinStats) end)
    end

    if (type(EquipmentFlyout_UpdateItems) == "function") then
        hooksecurefunc("EquipmentFlyout_UpdateItems", function() RUI:safe("Character window", skinFlyout) end)
    end
end

local function refresh()
    S:repaintQualities()
end

RUI:registerModule("character", "Character window", function()
    -- The window is load-on-demand on the current clients, and part of the base UI on older ones.
    RUI:safe("Character window", skinWindow)
    RUI:onAddon("Blizzard_UIPanels_Game", skinWindow)
end, refresh)
