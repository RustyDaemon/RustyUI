--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Rows that show a choice as cards: the accent presets, and styles that draw their own preview.

local _, ns = ...

local RUI, UI, L = ns.RUI, ns.UI, ns.Settings
local resolve, builders = L.resolve, L.builders
local CONTENT_WIDTH, GAP = L.CONTENT_WIDTH, L.GAP

local CARD_HEIGHT = 104

-- One card per accent: a small piece of the kit (title bar, selected item, toggle, button, slot)
-- painted in that accent, since the real UI only takes a new accent after a reload.
local function accentCard(parent, preset, width, onPick)
    local accent, dim, lit = preset.accent, preset.dim, preset.lit

    local card = CreateFrame("Button", nil, parent)
    card:SetSize(width, CARD_HEIGHT)

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(UI:rgb("window"))

    UI:addBorder(card, UI:rgb("border"))

    local header = UI:gradient(card, "BACKGROUND", "VERTICAL",
        0.055, 0.059, 0.070, 1, lit[1] * 0.6 + 0.04, lit[2] * 0.6 + 0.04, lit[3] * 0.6 + 0.04, 1)
    header:SetDrawLayer("BACKGROUND", 1)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(22)

    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    rule:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(dim[1], dim[2], dim[3], 0.6)

    local title = UI:text(card, 12, "text")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText(preset.text)

    -- A selected sidebar item.
    local item = card:CreateTexture(nil, "ARTWORK")
    item:SetPoint("TOPLEFT", 8, -31)
    item:SetPoint("RIGHT", -8, 0)
    item:SetHeight(18)
    item:SetColorTexture(lit[1], lit[2], lit[3], 1)

    local stripe = card:CreateTexture(nil, "OVERLAY")
    stripe:SetPoint("TOPLEFT", item, "TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT")
    stripe:SetWidth(2)
    stripe:SetColorTexture(accent[1], accent[2], accent[3], 1)

    local itemText = UI:text(card, 11)
    itemText:SetPoint("LEFT", item, "LEFT", 8, 0)
    itemText:SetText("Selected")
    itemText:SetTextColor(accent[1], accent[2], accent[3])

    -- A toggle that is on, and a slot bordered like an elite's portrait.
    local box = card:CreateTexture(nil, "ARTWORK")
    box:SetPoint("TOPLEFT", 8, -57)
    box:SetSize(13, 13)
    box:SetColorTexture(UI:rgb("border"))

    local fill = card:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(accent[1], accent[2], accent[3], 1)

    local slot = card:CreateTexture(nil, "ARTWORK")
    slot:SetPoint("LEFT", box, "RIGHT", 8, 0)
    slot:SetSize(13, 13)
    slot:SetColorTexture(accent[1], accent[2], accent[3], 1)

    local slotIcon = card:CreateTexture(nil, "OVERLAY")
    slotIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    slotIcon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    slotIcon:SetTexture("Interface\\Icons\\inv_misc_gear_01")
    slotIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- An accent button.
    local button = card:CreateTexture(nil, "ARTWORK")
    button:SetPoint("LEFT", slot, "RIGHT", 8, 0)
    button:SetPoint("RIGHT", -8, 0)
    button:SetHeight(15)
    button:SetColorTexture(dim[1], dim[2], dim[3], 1)

    local buttonFill = card:CreateTexture(nil, "OVERLAY")
    buttonFill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    buttonFill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    buttonFill:SetColorTexture(lit[1], lit[2], lit[3], 1)

    local buttonText = UI:text(card, 10)
    buttonText:SetPoint("CENTER", button, "CENTER")
    buttonText:SetText("OK")
    buttonText:SetTextColor(accent[1], accent[2], accent[3])

    local status = UI:text(card, 11, "textFaint")
    status:SetPoint("BOTTOMLEFT", 8, 9)

    UI:attachHover(card, "panelHover", 0.5, "BACKGROUND")

    card:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onPick(preset.value)
    end)

    card.Refresh = function(_, chosen, active)
        local isChosen = preset.value == chosen

        if (isChosen) then
            card:SetBorderColor(accent[1], accent[2], accent[3], 1)
        else
            card:SetBorderColor(UI:rgb("border"))
        end

        if (preset.value == active and isChosen) then
            status:SetText("In use")
            status:SetTextColor(UI:rgb("textDim"))
        elseif (isChosen) then
            status:SetText("After reload")
            status:SetTextColor(accent[1], accent[2], accent[3])
        elseif (preset.value == active) then
            status:SetText("In use until reload")
            status:SetTextColor(UI:rgb("textFaint"))
        else
            status:SetText("")
        end
    end

    return card
end

-- accents is not an AceConfig type: the accent presets as preview cards, picked by clicking one.
function builders.accents(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    local count = #UI.accents
    local width = math.floor((CONTENT_WIDTH - GAP * (count - 1)) / count)
    local cards = {}

    row:SetHeight(CARD_HEIGHT)

    for i, preset in ipairs(UI.accents) do
        local card = accentCard(row, preset, width, function(value)
            option.set(info, value)
            changed()
        end)

        card:SetPoint("TOPLEFT", (i - 1) * (width + GAP), 0)
        cards[i] = card
    end

    row.Refresh = function()
        local chosen = resolve(option.get, info)

        for _, card in ipairs(cards) do card:Refresh(chosen, RUI.activeAccent) end
    end

    return row
end

-- previews is not an AceConfig type either: a choice shown as cards, each drawing its own preview.
-- items() gives { value, text }; draw(holder, value) fills a card's preview area.
function builders.previews(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    local items = resolve(option.items, info)
    local columns = option.columns or #items
    local width = math.floor((CONTENT_WIDTH - GAP * (columns - 1)) / columns)
    local height = option.cardHeight or 96
    local rows = math.ceil(#items / columns)
    local cards = {}

    row:SetHeight(rows * height + (rows - 1) * GAP)

    for i, item in ipairs(items) do
        local column, line = (i - 1) % columns, math.floor((i - 1) / columns)

        local card = CreateFrame("Button", nil, row)
        card:SetSize(width, height)
        card:SetPoint("TOPLEFT", column * (width + GAP), -line * (height + GAP))

        local bg = card:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints()
        bg:SetColorTexture(UI:rgb("window"))

        UI:addBorder(card, UI:rgb("border"))
        UI:attachHover(card, "panelHover", 0.35, "BACKGROUND")

        local title = UI:text(card, 11, "textDim")
        title:SetPoint("TOPLEFT", 8, -7)
        title:SetText(item.text)

        local holder = CreateFrame("Frame", nil, card)
        holder:SetPoint("TOPLEFT", 1, -22)
        holder:SetPoint("BOTTOMRIGHT", -1, 1)

        RUI:safe("Preview", option.draw, holder, item.value)

        card:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            option.set(info, item.value)
            changed()
        end)

        card.value = item.value
        card.title = title
        cards[i] = card
    end

    row.Refresh = function()
        local chosen = resolve(option.get, info)

        for _, card in ipairs(cards) do
            local selected = card.value == chosen

            card:SetBorderColor(UI:rgb(selected and "accent" or "border"))
            card.title:SetTextColor(UI:rgb(selected and "accent" or "textDim"))
        end
    end

    return row
end
