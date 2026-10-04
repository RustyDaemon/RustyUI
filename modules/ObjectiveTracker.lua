--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The objective tracker: headers become kit headings (the text over a thin accent rule) and quest
-- item buttons square kit slots. Blizzard builds blocks and buttons as quests are tracked, and has
-- reshaped the tracker between clients, so pieces are found by their parts rather than their names.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local scheduled = false

-- A header carries a text and a collapse button; the art behind it is its own textures.
local function isHeader(frame)
    local text = frame.Text or frame.Title

    return frame.MinimizeButton ~= nil and text ~= nil and text.IsObjectType and text:IsObjectType("FontString")
end

-- A quest item button: a button with an icon and a cooldown, which no other tracker button has.
local function isItemButton(frame)
    return frame:IsObjectType("Button") and (frame.icon or frame.Icon) ~= nil
        and (frame.Cooldown or frame.cooldown) ~= nil
end

-- The collapse button keeps Blizzard's minus and plus, in the kit's quiet gray.
local function tintMinimize(button)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local texture = button[getter] and button[getter](button)

        if (texture) then
            texture:SetDesaturated(true)
            texture:SetVertexColor(UI:rgb("textDim"))
        end
    end
end

local function skinHeader(header)
    if (not S:once(header, "trackerheader")) then return end

    S:stripTextures(header)

    local text = header.Text or header.Title

    S:font(text, 13)

    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 1)
    rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 1)
    rule:SetHeight(1)
    rule:SetColorTexture(UI:rgb("accentDim", 0.7))

    local button = header.MinimizeButton

    tintMinimize(button)

    for _, method in ipairs({ "SetNormalAtlas", "SetPushedAtlas", "SetNormalTexture", "SetPushedTexture" }) do
        if (button[method]) then hooksecurefunc(button, method, tintMinimize) end
    end

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()

    if (highlight) then highlight:SetAlpha(0.3) end
end

local function skinItemButton(button)
    -- Item buttons can be secure; one made mid-fight is skinned on the scan after it.
    if (InCombatLockdown() and button:IsProtected()) then return end
    if (not S:once(button, "trackeritem")) then return end

    local icon = button.icon or button.Icon

    S:unmask(icon)
    S:cropIcon(icon)
    S:hideNormalTexture(button)
    S:buttonStates(button)
    S:iconBackdrop(button, button)

    S:font(button.HotKey, 10, true, UI.fontNumber)
    S:font(button.Count, 11, true, UI.fontNumber)
end

local function scan(frame, depth)
    if (isHeader(frame)) then skinHeader(frame) end
    if (isItemButton(frame)) then skinItemButton(frame) end

    if (depth < 7) then
        for _, child in ipairs({ frame:GetChildren() }) do
            scan(child, depth + 1)
        end
    end
end

local function scanAll()
    scheduled = false

    for _, name in ipairs({ "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
        local tracker = _G[name]

        if (tracker) then RUI:safe("Objective tracker", scan, tracker, 0) end
    end
end

-- Many updates can arrive in one frame; one scan after them is enough.
local function scheduleScan()
    if (scheduled) then return end

    scheduled = true
    C_Timer.After(0, scanAll)
end

RUI:registerModule("tracker", "Objective tracker", function()
    scanAll()

    for _, fn in ipairs({ "ObjectiveTracker_Update", "QuestWatch_Update", "WatchFrame_Update" }) do
        if (type(_G[fn]) == "function") then hooksecurefunc(fn, scheduleScan) end
    end

    local tracker = ObjectiveTrackerFrame

    if (tracker) then
        for _, method in ipairs({ "Update", "MarkDirty" }) do
            if (tracker[method]) then hooksecurefunc(tracker, method, scheduleScan) end
        end
    end

    local events = CreateFrame("Frame")

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "SUPER_TRACKING_CHANGED", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript("OnEvent", scheduleScan)
end)
