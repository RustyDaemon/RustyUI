--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Blizzard's confirmation popups and the Escape game menu in the kit's window look: dark panel,
-- light border, an accent stripe along the top and kit buttons.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local POPUP_COUNT = 4

-- The kit's dialog: shadowed panel with a 2px accent stripe, like RustyUI's own confirmations.
local function dialog(frame)
    S:stripTextures(frame)

    for _, key in ipairs({ "Border", "NineSlice", "BG", "Bg", "Background" }) do
        S:kill(frame[key])
    end

    local look = S:backdrop(frame, 0, 0.97)

    look:SetBorderColor(UI:rgb("borderLight"))

    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", look.area, "TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", look.area, "TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    stripe:SetColorTexture(UI:rgb("accent"))

    return look
end

local function skinPopup(index)
    local name = "StaticPopup" .. index
    local popup = _G[name]

    if (not popup or not S:once(popup, "popup")) then return end

    dialog(popup)

    for i = 1, 4 do
        S:panelButton(popup["button" .. i] or _G[name .. "Button" .. i]
            or (popup.ButtonContainer and popup.ButtonContainer["Button" .. i]))
    end

    S:panelButton(popup.extraButton or _G[name .. "ExtraButton"])
    S:closeButton(popup.CloseButton or _G[name .. "CloseButton"])

    local editBox = popup.editBox or popup.EditBox or _G[name .. "EditBox"]

    if (editBox) then S:editBox(editBox, { -4, -4, 2, 2 }) end

    S:fonts(popup, 2)
end

-- The game menu's header is a banner of three slices with the title on it; the title stays.
local function skinHeader(header)
    if (not header) then return end

    -- Older clients draw the banner as one texture rather than a frame of slices.
    if (header:IsObjectType("Texture")) then
        S:kill(header)
        return
    end

    S:stripTextures(header)

    for _, key in ipairs({ "LeftBG", "CenterBG", "RightBG" }) do S:kill(header[key]) end

    S:font(header.Text, 14)

    if (header.Text) then header.Text:SetTextColor(UI:rgb("text")) end
end

local function skinMenuButtons(menu)
    for _, child in ipairs({ menu:GetChildren() }) do
        if (child:IsObjectType("Button") and child ~= menu.CloseButton) then S:panelButton(child) end
    end
end

local function skinGameMenu()
    local menu = GameMenuFrame

    if (not menu) then return end

    if (S:once(menu, "gamemenu")) then
        dialog(menu)
        skinHeader(menu.Header or GameMenuFrameHeader)

        -- Retail builds its buttons from a pool each time the menu opens.
        menu:HookScript("OnShow", function(self) RUI:safe("Game menu", skinMenuButtons, self) end)
    end

    skinMenuButtons(menu)
end

-- Each popup and the game menu are skinned on their own, so one that fails is named in chat and the
-- others are skinned anyway.
RUI:registerModule("popups", "Popups and game menu", function()
    for i = 1, POPUP_COUNT do RUI:safe("Popup " .. i, skinPopup, i) end

    RUI:safe("Game menu", skinGameMenu)

    -- Some clients build popups only as they are first needed.
    if (type(StaticPopup_Show) == "function") then
        hooksecurefunc("StaticPopup_Show", function()
            for i = 1, POPUP_COUNT do RUI:safe("Popup " .. i, skinPopup, i) end
        end)
    end
end)
