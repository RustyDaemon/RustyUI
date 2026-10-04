--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Blizzard's buttons, tabs, edit boxes and windows in the kit's look.

local _, ns = ...

local UI, S = ns.UI, ns.Skin

-- Pushed, highlight and checked states as flat tints instead of Blizzard's glows.
function S:buttonStates(button)
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()

    if (pushed) then
        S:unmask(pushed)
        pushed:SetColorTexture(1, 1, 1, 0.18)
    end

    if (highlight) then
        S:unmask(highlight)
        highlight:SetColorTexture(1, 1, 1, 0.12)
    end

    if (checked) then
        S:unmask(checked)
        checked:SetColorTexture(UI:rgb("accent", 0.3))
    end
end

-- Keeps a button's normal texture invisible, however often Blizzard sets a new one.
function S:hideNormalTexture(button)
    local normal = button:GetNormalTexture()

    if (normal) then normal:SetAlpha(0) end

    if (S:once(button, "normal")) then
        local function hide(self)
            local texture = self:GetNormalTexture()

            if (texture) then texture:SetAlpha(0) end
        end

        hooksecurefunc(button, "SetNormalTexture", hide)

        if (button.SetNormalAtlas) then hooksecurefunc(button, "SetNormalAtlas", hide) end
    end
end

-- An item button (a bag slot, a bag in the bag bar) as a square, bordered slot. Returns the slot's
-- backdrop, whose border can be painted in the item's quality color.
function S:itemSlot(button)
    if (not button or not S:once(button, "itemslot")) then return nil end

    local name = button:GetName()
    local icon = button.icon or button.Icon or (name and _G[name .. "IconTexture"])

    S:unmask(icon)
    S:cropIcon(icon)
    S:hideNormalTexture(button)
    S:buttonStates(button)
    S:kill(button.IconBorder)
    S:kill(button.ItemSlotBackground)
    S:kill(button.CircleMask)

    S:font(button.Count or (name and _G[name .. "Count"]), 12, true, UI.fontNumber)

    return S:iconBackdrop(button, button, false)
end

-- Blizzard's red panel button (popups, the game menu) as a kit button: raised fill, 1px border and a
-- hover tint. Its art is three slices Blizzard swaps on press, so those are killed for good.
function S:panelButton(button)
    if (not button or not button.GetObjectType or not S:once(button, "panelbutton")) then return end

    local name = button:GetName()

    for _, key in ipairs({ "Left", "Middle", "Right", "Center" }) do
        S:kill(button[key])

        if (name) then S:kill(_G[name .. key]) end
    end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local texture = button[getter] and button[getter](button)

        if (texture) then texture:SetAlpha(0) end
    end

    S:hideNormalTexture(button)

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(UI:rgb("raised"))

    local border = S:lines(button, button, 0, "BACKGROUND", -6)

    local hover = button:CreateTexture(nil, "BACKGROUND", nil, -5)
    hover:SetAllPoints()
    hover:SetColorTexture(UI:rgb("borderLight", 0.45))
    hover:Hide()

    button:HookScript("OnEnter", function(self)
        if (self:IsEnabled()) then hover:Show() end
    end)
    button:HookScript("OnLeave", function() hover:Hide() end)

    local function paintEnabled(self)
        bg:SetAlpha(self:IsEnabled() and 1 or 0.5)
        border:SetColor(UI:rgb(self:IsEnabled() and "border" or "panel"))
    end

    hooksecurefunc(button, "Enable", paintEnabled)
    hooksecurefunc(button, "Disable", paintEnabled)
    paintEnabled(button)
end

local TAB_PARTS = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight" }

-- A window tab as a kit tab: raised fill and border, an accent underline and lit fill when selected.
-- Classic-style tabs mark the selected one by disabling it; newer ones keep an isSelected flag.
function S:tab(tab)
    if (not tab or not S:once(tab, "tab")) then return end

    local name = tab:GetName()

    for _, key in ipairs(TAB_PARTS) do
        S:kill(tab[key])

        if (name) then S:kill(_G[name .. key]) end
    end

    local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()

    if (highlight) then highlight:SetAlpha(0) end

    local bg = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)

    local border = S:lines(tab, bg, 0, "BACKGROUND", -6)

    local hover = tab:CreateTexture(nil, "BACKGROUND", nil, -5)
    hover:SetAllPoints(bg)
    hover:SetColorTexture(UI:rgb("borderLight", 0.35))
    hover:Hide()

    local underline = tab:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 1, 1)
    underline:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
    underline:SetHeight(2)
    underline:SetColorTexture(UI:rgb("accent"))

    local function paint()
        local selected = tab.isSelected or not tab:IsEnabled()

        bg:SetColorTexture(UI:rgb(selected and "accentLit" or "raised"))
        border:SetColor(UI:rgb(selected and "accentDim" or "border"))
        underline:SetShown(selected and true or false)
    end

    tab:HookScript("OnEnter", function() hover:Show() end)
    tab:HookScript("OnLeave", function() hover:Hide() end)

    for _, method in ipairs({ "Enable", "Disable", "SetTabSelected", "SetSelected" }) do
        if (tab[method]) then hooksecurefunc(tab, method, paint) end
    end

    paint()
end

-- Blizzard's red X becomes the kit's close icon.
function S:closeButton(button)
    if (not button or not S:once(button, "close")) then return end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local texture = button[getter] and button[getter](button)

        if (texture) then texture:SetAlpha(0) end
    end

    local x = button:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(14, 14)
    x:SetPoint("CENTER")
    x:SetVertexColor(UI:rgb("textDim"))

    button:HookScript("OnEnter", function() x:SetVertexColor(UI:rgb("text")) end)
    button:HookScript("OnLeave", function() x:SetVertexColor(UI:rgb("textDim")) end)
end

local EDIT_PARTS = { "Left", "Middle", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight",
    "focusLeft", "focusMid", "focusRight" }

-- An edit box in the kit's field look, with the border lit while it has focus.
function S:editBox(editBox, insets)
    if (not editBox or not S:once(editBox, "edit")) then return end

    local name = editBox:GetName()

    for _, part in ipairs(EDIT_PARTS) do
        S:kill(editBox[part])

        if (name) then S:kill(_G[name .. part]) end
    end

    local look = S:backdrop(editBox, insets, 0.9)

    look.shade:Hide()

    editBox:HookScript("OnEditFocusGained", function() look:SetBorderColor(UI:rgb("accentDim")) end)
    editBox:HookScript("OnEditFocusLost", function() look:SetBorderColor(UI:rgb("border")) end)

    return look
end

-- A portrait-and-title Blizzard window (bags, mostly) with the kit's window look.
function S:window(frame, insets)
    if (not frame or not S:once(frame, "window")) then return end

    S:stripTextures(frame)
    S:kill(frame.NineSlice)
    S:kill(frame.Bg)
    S:kill(frame.TopTileStreaks)

    if (frame.Inset) then
        S:stripTextures(frame.Inset)
        S:kill(frame.Inset.NineSlice)
    end

    local name = frame:GetName()

    S:closeButton(frame.CloseButton or (name and _G[name .. "CloseButton"]))

    local container = frame.PortraitContainer
    local portrait = (container and container.portrait) or frame.portrait

    -- A portrait in its own container stays, squared; one drawn on the frame itself went with the art.
    if (container and portrait and portrait.GetNumMaskTextures) then
        S:kill(container.CircleMask)
        S:unmask(portrait)
        S:cropIcon(portrait)
        S:iconBackdrop(container, portrait)
    end

    S:fonts(frame, 2)

    return S:backdrop(frame, insets)
end
