--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Tooltips as kit panels, with the border in the item's quality color, or for a unit in its class
-- or reaction color, which the health bar under it takes too.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "EmbeddedItemTooltip",
    "WorldMapTooltip",
    "SmallTextTooltip",
}

local looks = setmetatable({}, { __mode = "k" })
local unitColors = setmetatable({}, { __mode = "k" }) -- tooltip -> the color of the unit it shows

local function itemQuality(tooltip)
    local _, link = tooltip:GetItem()

    if (not link) then return nil end

    if (C_Item and C_Item.GetItemQualityByID) then return C_Item.GetItemQualityByID(link) end

    local _, _, quality = GetItemInfo(link)

    return quality
end

local function qualityColor(tooltip)
    local quality = itemQuality(tooltip)
    local color = quality and quality >= 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]

    if (color) then return color.r, color.g, color.b end
end

local function paintBorder(tooltip)
    local look = looks[tooltip]

    if (not look) then return end

    -- In Midnight combat the item can be a secret value; the border then stays plain.
    local ok, r, g, b = false, nil, nil, nil

    if (RUI.db.tooltips.qualityBorders) then ok, r, g, b = pcall(qualityColor, tooltip) end

    if (ok and r) then
        look:SetBorderColor(r, g, b)
    else
        look:SetBorderColor(UI:rgb("borderLight"))
    end
end

-- The health bar under GameTooltip's text. Blizzard colors it green to red by health on every
-- change; this runs after each, and paints over it while a unit color is wanted.
local function paintHealth(bar)
    local color = RUI.db.tooltips.healthColors and unitColors[GameTooltip]

    if (color) then
        S:paintBar(bar, color[1], color[2], color[3])
        S:paintTrack(bar, color[1], color[2], color[3])
    else
        S:paintTrack(bar)
    end
end

local function unitColor(tooltip)
    local _, unit = tooltip:GetUnit()

    return S:unitColor(unit, true)
end

local function paintUnit(tooltip)
    local look = looks[tooltip]

    if (not look) then return end

    -- In Midnight combat the unit can be a secret value; the border and bar then stay plain.
    local ok, r, g, b = pcall(unitColor, tooltip)

    if (not ok or S:isSecret(r)) then r = nil end

    unitColors[tooltip] = r and { r, g, b } or nil

    if (r and RUI.db.tooltips.unitBorders) then
        look:SetBorderColor(r, g, b)
    else
        look:SetBorderColor(UI:rgb("borderLight"))
    end

    if (tooltip == GameTooltip and GameTooltipStatusBar) then paintHealth(GameTooltipStatusBar) end
end

local function resetBorder(tooltip)
    local look = looks[tooltip]

    unitColors[tooltip] = nil

    if (look) then look:SetBorderColor(UI:rgb("borderLight")) end
end

local function skinTooltip(tooltip)
    if (not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden())) then return end
    if (not S:once(tooltip, "tooltip")) then return end

    -- The NineSlice is re-laid out on every show, but a faded frame stays faded.
    S:kill(tooltip.NineSlice)

    local look = S:backdrop(tooltip, 0, 0.94)

    look:SetBorderColor(UI:rgb("borderLight"))
    looks[tooltip] = look

    tooltip:HookScript("OnHide", resetBorder)

    if (tooltip:HasScript("OnTooltipCleared")) then tooltip:HookScript("OnTooltipCleared", resetBorder) end

    -- Without the newer tooltip data hooks, items and units announce themselves through these scripts.
    if (not TooltipDataProcessor) then
        if (tooltip:HasScript("OnTooltipSetItem")) then tooltip:HookScript("OnTooltipSetItem", paintBorder) end
        if (tooltip:HasScript("OnTooltipSetUnit")) then tooltip:HookScript("OnTooltipSetUnit", paintUnit) end
    end
end

RUI:registerModule("tooltips", "Tooltips", function()
    for _, name in ipairs(TOOLTIPS) do
        skinTooltip(S:get(name))
    end

    if (TooltipDataProcessor and Enum.TooltipDataType) then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            skinTooltip(tooltip)
            paintBorder(tooltip)
        end)

        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            skinTooltip(tooltip)
            paintUnit(tooltip)
        end)
    end

    local health = GameTooltipStatusBar

    if (health) then
        S:flatBar(health, paintHealth)
        S:barBackdrop(health)
        health:SetHeight(4)
    end
end)
