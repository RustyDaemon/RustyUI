--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The talents window in the kit's window look, with kit tabs. On the classic-style talent frame the
-- talents themselves become square slots whose border takes Blizzard's state color: green while
-- points can go in, gold when full, gray while locked. The tree's background art stays.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

-- The window is load-on-demand, under a different name on each generation of the talent UI.
local WINDOWS = {
    { addon = "Blizzard_TalentUI",      frames = { "PlayerTalentFrame", "TalentFrame" } },
    { addon = "Blizzard_ClassTalentUI", frames = { "ClassTalentFrame" } },
    { addon = "Blizzard_PlayerSpells",  frames = { "PlayerSpellsFrame" } },
}

local MAX_TALENTS = 100
local MAX_TABS = 5

-- Classic-style panels draw their art larger than the window, with a margin on the right and below.
local CLASSIC_INSETS = { 12, 34, 13, 76 }

-- Strips the frame's own art but keeps the talent tree's background, which is what the tree is.
local function stripKeepingTree(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if (region:IsObjectType("Texture")) then
            local name = region:GetName() or ""

            if (not name:find("Background") and not name:find("Branch") and not name:find("Arrow")) then
                S:kill(region)
            end
        end
    end
end

local function skinTalent(button)
    if (not S:once(button, "talent")) then return end

    local name = button:GetName()
    local icon = button.icon or button.Icon or (name and _G[name .. "IconTexture"])

    S:unmask(icon)
    S:cropIcon(icon)
    S:hideNormalTexture(button)
    S:buttonStates(button)

    local look = S:iconBackdrop(button, icon or button)

    -- Blizzard colors the slot to say whether the talent is available, full or locked.
    local slot = button.Slot or (name and _G[name .. "Slot"])

    if (slot) then
        slot:SetAlpha(0)

        hooksecurefunc(slot, "SetVertexColor", function(_, r, g, b) look:SetBorderColor(r, g, b) end)
        look:SetBorderColor(slot:GetVertexColor())
    end

    S:kill(button.RankBorder or (name and _G[name .. "RankBorder"]))
    S:font(button.Rank or (name and _G[name .. "Rank"]), 11, true, UI.fontNumber)
end

local function skinTalents(frame)
    local name = frame:GetName()

    if (not name) then return end

    for i = 1, MAX_TALENTS do
        local button = _G[name .. "Talent" .. i]

        if (button) then skinTalent(button) end
    end
end

local function skinTabs(frame)
    local name = frame:GetName()

    for i = 1, MAX_TABS do
        S:tab(name and _G[name .. "Tab" .. i])
    end

    -- Newer windows hold their tabs in a tab system.
    if (frame.TabSystem) then
        for _, tab in ipairs({ frame.TabSystem:GetChildren() }) do S:tab(tab) end
    end
end

local function skinWindow(frame)
    if (not frame or not S:once(frame, "talentwindow")) then return end

    if (frame.NineSlice or frame.Inset) then
        -- Newer windows: the frame's own rect is the window.
        S:window(frame)
    else
        stripKeepingTree(frame)
        S:closeButton(frame.CloseButton or _G[frame:GetName() .. "CloseButton"])
        S:backdrop(frame, CLASSIC_INSETS)
        S:fonts(frame, 1)
    end

    skinTabs(frame)
    skinTalents(frame)

    frame:HookScript("OnShow", function(self)
        RUI:safe("Talents", skinTabs, self)
        RUI:safe("Talents", skinTalents, self)
    end)
end

RUI:registerModule("talents", "Talents window", function()
    for _, window in ipairs(WINDOWS) do
        RUI:onAddon(window.addon, function()
            for _, name in ipairs(window.frames) do
                RUI:safe("Talents", skinWindow, _G[name])
            end

            -- Talents are laid out again as tabs change and points go in.
            for _, fn in ipairs({ "TalentFrame_Update", "PlayerTalentFrame_Update" }) do
                if (type(_G[fn]) == "function" and S:once(_G, fn)) then
                    hooksecurefunc(fn, function()
                        for _, name in ipairs(window.frames) do
                            local frame = _G[name]

                            if (frame) then RUI:safe("Talents", skinTalents, frame) end
                        end
                    end)
                end
            end
        end)
    end
end)
