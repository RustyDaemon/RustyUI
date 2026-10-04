--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- One row per option type: a frame holding the control, with Refresh() and its height.

local _, ns = ...

local UI, L = ns.UI, ns.Settings
local resolve, builders = L.resolve, L.builders
local CONTENT_WIDTH, CONTROL_WIDTH = L.CONTENT_WIDTH, L.CONTROL_WIDTH

local function selectItems(option, info)
    local values = resolve(option.values, info) or {}
    local items = {}

    for _, value in ipairs(option.sorting) do
        if (values[value] ~= nil) then items[#items+1] = { value = value, text = values[value] } end
    end

    return items
end

function builders.header(parent, option)
    local row = UI:sectionHeading(parent, option.name)

    row.topGap = 8
    row.Refresh = function() end

    return row
end

function builders.description(parent, option, info)
    local row = CreateFrame("Frame", nil, parent)
    local text = UI:text(row, 12, "textDim")

    text:SetPoint("TOPLEFT", 2, 0)
    text:SetWidth(CONTENT_WIDTH - 4)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)

    row.Refresh = function()
        text:SetText(resolve(option.name, info) or "")
        row:SetHeight(text:GetStringHeight() + 4)
    end

    return row
end

function builders.toggle(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)

    local toggle = UI:toggle(row, option.name,
        function() return resolve(option.get, info) and true or false end,
        function(value)
            option.set(info, value)
            changed()
        end)
    toggle:SetPoint("LEFT", 0, 0)

    UI:tooltip(toggle, option.name, option.desc, "ANCHOR_RIGHT")

    row.Refresh = function() toggle:Refresh() end

    return row
end

function builders.select(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(44)

    local dropdown = UI:dropdown(row, CONTROL_WIDTH, 26, option.name,
        function() return selectItems(option, info) end,
        function() return resolve(option.get, info) end,
        function(value)
            option.set(info, value)
            changed()
        end)
    dropdown:SetPoint("BOTTOMLEFT", 0, 0)

    UI:tooltip(dropdown, option.name, option.desc, "ANCHOR_RIGHT")

    row.Refresh = function()
        local values = resolve(option.values, info) or {}

        dropdown:SetText(values[resolve(option.get, info)] or "")
    end

    return row
end

function builders.range(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(44)

    local slider = UI:slider(row, CONTROL_WIDTH, option.name, option.min, option.max, option.step or 1,
        function() return resolve(option.get, info) end,
        function(value)
            option.set(info, value)
            changed()
        end)
    slider:SetPoint("BOTTOMLEFT", 0, 0)

    UI:tooltip(slider.track, option.name, option.desc, "ANCHOR_RIGHT")

    row.Refresh = function() slider:Refresh() end

    return row
end

function builders.execute(parent, option, info, changed)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(28)

    local button = UI:button(row, option.name, 120, 26, function()
        option.func(info)
        changed()
    end)
    button:SetWidth(math.max(button.label:GetStringWidth() + 32, 120))
    button:SetPoint("LEFT", 0, 0)

    UI:tooltip(button, option.name, option.desc, "ANCHOR_RIGHT")

    row.Refresh = function() end

    return row
end

-- Dims a row and stops it taking clicks while its option is disabled.
function L.addDisabledCover(row, option, info)
    if (option.disabled == nil) then return end

    local cover = CreateFrame("Frame", nil, row)
    cover:SetAllPoints()
    cover:SetFrameLevel(row:GetFrameLevel() + 20)
    cover:EnableMouse(true)
    cover:Hide()

    local refresh = row.Refresh

    row.Refresh = function()
        local disabled = resolve(option.disabled, info) and true or false

        cover:SetShown(disabled)
        row:SetAlpha(disabled and 0.4 or 1)
        refresh()
    end
end
