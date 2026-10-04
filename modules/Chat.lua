--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Chat tabs and the input box in the kit's look. The chat window's own background stays under
-- Blizzard's chat settings, where players already set its color and opacity.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local TAB_PARTS = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight", "HighlightLeft", "HighlightMiddle", "HighlightRight" }

local underlines = {} -- chat frame -> its tab's selected marker

local function refreshTabs()
    local selected = FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK
        and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)

    for chat, underline in pairs(underlines) do
        underline:SetShown(chat == selected)
    end
end

local function skinTab(chat)
    local name = chat:GetName()
    local tab = _G[name .. "Tab"]

    if (not tab or not S:once(tab, "chattab")) then return end

    for _, key in ipairs(TAB_PARTS) do
        S:kill(tab[key])
        S:kill(_G[name .. "Tab" .. key])
    end

    UI:attachHover(tab, "raised", 0.8, "BACKGROUND")

    S:font(tab.Text or _G[name .. "TabText"], 12)

    local underline = tab:CreateTexture(nil, "OVERLAY")
    underline:SetPoint("BOTTOMLEFT", 6, 2)
    underline:SetPoint("BOTTOMRIGHT", -6, 2)
    underline:SetHeight(2)
    underline:SetColorTexture(UI:rgb("accent"))
    underline:Hide()

    underlines[chat] = underline
end

local function skinChat(chat)
    if (not chat) then return end

    skinTab(chat)

    local editBox = _G[chat:GetName() .. "EditBox"]

    if (editBox) then
        S:editBox(editBox, { 4, 4, 4, 4 })
        S:font(editBox.header or _G[chat:GetName() .. "EditBoxHeader"])
    end
end

local function skinAll()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        skinChat(_G[name])
    end

    refreshTabs()
end

RUI:registerModule("chat", "Chat", function()
    skinAll()

    -- Whisper windows and the like open later, each with a tab and box of its own.
    if (type(FCF_OpenTemporaryWindow) == "function") then
        hooksecurefunc("FCF_OpenTemporaryWindow", skinAll)
    end

    if (type(FCFDock_SelectWindow) == "function") then
        hooksecurefunc("FCFDock_SelectWindow", refreshTabs)
    end
end)
