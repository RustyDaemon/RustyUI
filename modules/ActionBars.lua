--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Square, bordered action buttons with flat press and highlight tints, and the bar art taken away.
-- Empty slots stay out of sight until a spell is being dragged. On Retail, Edit Mode places the bars
-- and sets their padding; on WoW Forever, which has no Edit Mode, the spacing options do.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local BARS = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "MultiBar5Button", 12 },
    { "MultiBar6Button", 12 },
    { "MultiBar7Button", 12 },
    { "PetActionButton", 10 },
    { "StanceButton", 10 },
    { "ShapeshiftButton", 10 },
    { "PossessButton", 2 },
    { "OverrideActionBarButton", 6 },
}

local ART = {
    -- Retail: the frame around the main bar and its gryphons. 12.0 renamed MainMenuBar to MainActionBar.
    "MainActionBar.BorderArt",
    "MainActionBar.EndCaps.LeftEndCap",
    "MainActionBar.EndCaps.RightEndCap",
    "MainMenuBar.BorderArt",
    "MainMenuBar.EndCaps.LeftEndCap",
    "MainMenuBar.EndCaps.RightEndCap",

    -- WoW Forever: the classic bar strip, its gryphons and the pet and stance bar backings.
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuMaxLevelBar0",
    "MainMenuMaxLevelBar1",
    "MainMenuMaxLevelBar2",
    "MainMenuMaxLevelBar3",
    "MainMenuBarArtFrame.LeftEndCap",
    "MainMenuBarArtFrame.RightEndCap",
    "MainMenuBarArtFrameBackground.BackgroundLarge",
    "MainMenuBarArtFrameBackground.BackgroundSmall",
    "SlidingActionBarTexture0",
    "SlidingActionBarTexture1",
    "StanceBarLeft",
    "StanceBarMiddle",
    "StanceBarRight",
    "ShapeshiftBarLeft",
    "ShapeshiftBarMiddle",
    "ShapeshiftBarRight",
    "PossessBackground1",
    "PossessBackground2",
}

-- The bars stacked above the main bar, which the gap between bars moves up. Blizzard places the pet
-- and stance bars itself, assuming no gap, so they move by it too.
local STACKED = {
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "PetActionBarFrame",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PossessBarFrame",
    "MultiCastActionBarFrame",
}

local buttons = {}
local looks = {}   -- button -> its slot backdrop
local dragging = false

local function part(button, key, suffix)
    local name = button:GetName()

    return button[key] or (name and _G[name .. suffix])
end

-- Only Retail bars that Edit Mode manages carry a system; those are laid out there, not here.
function RUI:barsUseEditMode()
    return EditModeManagerFrame ~= nil and MultiBarBottomLeft ~= nil and MultiBarBottomLeft.system ~= nil
end

-- A slot is empty when its icon is: every client hides the icon of a button with nothing on it,
-- whatever kind of button it is or however it tracks its action.
local function isEmpty(button)
    local icon = part(button, "icon", "Icon")

    return not (icon and icon:IsShown() and icon:GetTexture())
end

-- The parts Blizzard puts back whenever it redraws a button, so this runs again after each redraw.
local function applyArt(button)
    S:hideNormalTexture(button)
    S:buttonStates(button)

    S:kill(button.SlotArt)
    S:kill(button.SlotBackground)
    S:kill(button.FlyoutBorderShadow)
    S:kill(part(button, "Border", "Border"))
    S:kill(part(button, "FloatingBG", "FloatingBG"))
end

-- An empty slot shows nothing, keybinding included, unless empty slots are wanted or a spell is
-- being dragged and needs somewhere to land.
local function applyState(button)
    local db = RUI.db.actionbars
    local shown = db.emptySlots or dragging or not isEmpty(button)
    local hotkey = part(button, "HotKey", "HotKey")
    local macro = part(button, "Name", "Name")

    if (looks[button]) then looks[button]:SetShown(shown) end
    if (hotkey) then hotkey:SetAlpha((db.hotkeys and shown) and 1 or 0) end
    if (macro) then macro:SetAlpha(db.macroNames and 1 or 0) end
end

local function refreshStates()
    for _, button in ipairs(buttons) do applyState(button) end
end

local function skinButton(button)
    if (not button or not S:once(button, "actionbutton")) then return end

    local icon = part(button, "icon", "Icon")

    S:unmask(icon)
    S:cropIcon(icon)
    S:kill(button.IconMask)

    -- The slot follows its icon as spells are placed, removed and paged.
    if (icon) then
        local function follow() applyState(button) end

        hooksecurefunc(icon, "Show", follow)
        hooksecurefunc(icon, "Hide", follow)
        hooksecurefunc(icon, "SetTexture", follow)
    end

    looks[button] = S:iconBackdrop(button, button)

    applyArt(button)

    local hotkey = part(button, "HotKey", "HotKey")

    if (hotkey) then
        S:font(hotkey, 11, true, UI.fontNumber)
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", -2, -3)
    end

    S:font(part(button, "Count", "Count"), 13, true, UI.fontNumber)
    S:font(part(button, "Name", "Name"), 10, true)

    if (button.UpdateButtonArt) then hooksecurefunc(button, "UpdateButtonArt", applyArt) end
    if (button.Update) then hooksecurefunc(button, "Update", applyState) end

    buttons[#buttons+1] = button

    applyState(button)
end

local function skinAll()
    for _, bar in ipairs(BARS) do
        local prefix, count = bar[1], bar[2]

        for i = 1, count do
            skinButton(_G[prefix .. i])
        end
    end
end

-- Spacing ---------------------------------------------------------------------------------------

local pending = false
local origins = {} -- button -> its anchor to the button before it, as Blizzard set it

-- Which way a button sits from the one it is anchored to, from the anchor points' names.
local function direction(point, relativePoint)
    if (point:find("LEFT") and relativePoint:find("RIGHT")) then return 1, 0 end
    if (point:find("RIGHT") and relativePoint:find("LEFT")) then return -1, 0 end
    if (point:find("TOP") and relativePoint:find("BOTTOM")) then return 0, -1 end
    if (point:find("BOTTOM") and relativePoint:find("TOP")) then return 0, 1 end
end

-- Each button is anchored to the one before it; only the offset between them changes, so every
-- bar keeps its direction and wrapping. No spacing set means Blizzard's own.
local function applyButtonSpacing()
    local spacing = RUI.db.actionbars.spacing

    for _, bar in ipairs(BARS) do
        local prefix, count = bar[1], bar[2]

        for i = 2, count do
            local button, previous = _G[prefix .. i], _G[prefix .. (i - 1)]

            if (button and previous and button:GetNumPoints() == 1) then
                if (not origins[button]) then
                    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)

                    if (relativeTo == previous) then
                        origins[button] = { point, relativeTo, relativePoint, x, y }
                    else
                        origins[button] = false
                    end
                end

                local origin = origins[button]

                if (origin) then
                    local point, relativeTo, relativePoint, x, y = unpack(origin)
                    local dx, dy = direction(point, relativePoint)

                    if (spacing and dx) then
                        if (dx ~= 0) then x = dx * spacing end
                        if (dy ~= 0) then y = dy * spacing end
                    end

                    button:ClearAllPoints()
                    button:SetPoint(point, relativeTo, relativePoint, x, y)
                end
            end
        end
    end
end

local bases = {}       -- stacked bar -> the anchor Blizzard last gave it
local stacked = {}     -- the stacked bars, as a set
local moving = false

local function placeStacked(frame)
    local base = bases[frame]

    if (not base) then return end

    if (InCombatLockdown()) then
        pending = true
        return
    end

    local point, relativeTo, relativePoint, x, y = unpack(base)

    moving = true
    frame:ClearAllPoints()
    local gap = (RUI.db.actionbars.barGap or 0) + (RUI.xpExtraGap and RUI:xpExtraGap() or 0)

    frame:SetPoint(point, relativeTo, relativePoint, x, y + gap)
    moving = false
end

-- Blizzard re-anchors these bars as others show and hide. Each time, its anchor becomes the new base
-- and the gap goes on top. A bar anchored to another stacked bar already moves with that one.
local function trackStacked(frame)
    if (not frame or frame:GetNumPoints() ~= 1) then return end

    local function capture(self)
        local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
        local parent = relativeTo and relativeTo.GetParent and relativeTo:GetParent()

        if (stacked[relativeTo] or stacked[parent]) then
            bases[self] = nil
        else
            bases[self] = { point, relativeTo, relativePoint, x, y }
        end
    end

    capture(frame)

    hooksecurefunc(frame, "SetPoint", function(self)
        if (moving or self:GetNumPoints() ~= 1) then return end

        capture(self)
        placeStacked(self)
    end)
end

local function applyLayout()
    if (RUI:barsUseEditMode()) then return end

    if (InCombatLockdown()) then
        pending = true
        return
    end

    pending = false

    applyButtonSpacing()

    for frame in pairs(stacked) do placeStacked(frame) end
end

RUI:registerModule("actionbars", "Action bars", function()
    S:killAll(ART)
    skinAll()

    -- WoW Forever redraws buttons through globals rather than methods.
    for _, fn in ipairs({ "ActionButton_Update", "ActionButton_ShowGrid", "ActionButton_HideGrid" }) do
        if (type(_G[fn]) == "function") then
            hooksecurefunc(fn, function(button)
                if (looks[button]) then
                    applyArt(button)
                    applyState(button)
                end
            end)
        end
    end

    if (not RUI:barsUseEditMode()) then
        for _, name in ipairs(STACKED) do
            local frame = _G[name]

            if (frame) then stacked[frame] = true end
        end

        for frame in pairs(stacked) do trackStacked(frame) end

        applyLayout()
    end

    local events = CreateFrame("Frame")

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE",
        "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
        "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PLAYER_REGEN_ENABLED" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", function(_, event)
        if (event == "ACTIONBAR_SHOWGRID") then
            dragging = true
        elseif (event == "ACTIONBAR_HIDEGRID") then
            dragging = false
        end

        -- Pet and stance buttons may only exist once their bar first fills.
        if (not InCombatLockdown()) then skinAll() end

        if (pending and event == "PLAYER_REGEN_ENABLED") then applyLayout() end

        refreshStates()
    end)
end, function()
    refreshStates()
    applyLayout()
end)
