--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Bags as kit windows: flat slots with a border in the item's quality color. Works with Retail's
-- combined bag and separate bags, and with WoW Forever's classic bag frames.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local slots = setmetatable({}, { __mode = "k" })   -- item button -> its backdrop
local windows = setmetatable({}, { __mode = "k" }) -- bag frame -> its backdrop

local function containerFrames()
    local frames = {}

    if (ContainerFrameCombinedBags) then frames[#frames+1] = ContainerFrameCombinedBags end

    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]

        if (frame) then frames[#frames+1] = frame end
    end

    return frames
end

local function eachItem(frame, fn)
    if (frame.EnumerateValidItems) then
        for key, value in frame:EnumerateValidItems() do
            local button = type(value) == "table" and value or key

            if (type(button) == "table") then fn(button) end
        end

        return
    end

    local name = frame:GetName()

    for i = 1, (frame.size or 0) do
        local button = _G[name .. "Item" .. i]

        if (button) then fn(button) end
    end
end

local function itemQuality(button)
    local bag = button.GetBagID and button:GetBagID() or button:GetParent():GetID()
    local slot = button:GetID()

    if (C_Container and C_Container.GetContainerItemInfo) then
        local info = C_Container.GetContainerItemInfo(bag, slot)

        return info and info.quality
    end

    if (GetContainerItemInfo) then
        local _, _, _, quality = GetContainerItemInfo(bag, slot)

        return quality
    end
end

local function paintSlot(button)
    local look = slots[button]

    if (not look) then return end

    local quality = RUI.db.bags.qualityBorders and itemQuality(button)
    local color = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]

    if (color) then
        look:SetBorderColor(color.r, color.g, color.b)
    else
        look:SetBorderColor(UI:rgb("border"))
    end
end

local function skinSlot(button)
    local look = S:itemSlot(button)

    if (look) then slots[button] = look end
end

-- WoW Forever's bag art is wider than its slots and hangs the portrait off a corner. The backdrop
-- follows the slots instead, leaving room for the title above and the money below.
local function fitToSlots(frame, look)
    local left, right, bottom

    eachItem(frame, function(button)
        if (not button:IsShown()) then return end

        local l, r, b = button:GetLeft(), button:GetRight(), button:GetBottom()

        if (l) then
            left = math.min(left or l, l)
            right = math.max(right or r, r)
            bottom = math.min(bottom or b, b)
        end
    end)

    local frameLeft, frameRight, frameBottom = frame:GetLeft(), frame:GetRight(), frame:GetBottom()

    if (not left or not frameLeft) then return end

    local money = _G[frame:GetName() .. "MoneyFrame"]

    if (money and money:IsShown() and money:GetBottom()) then
        bottom = math.min(bottom, money:GetBottom())
    end

    look.area:ClearAllPoints()
    look.area:SetPoint("TOPLEFT", frame, "TOPLEFT", left - frameLeft - 7, -4)
    look.area:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right - frameRight + 7, bottom - frameBottom - 7)
end

local function refresh(frame)
    if (not frame:IsShown()) then return end

    if (not windows[frame]) then
        windows[frame] = S:window(frame) or true
    end

    eachItem(frame, function(button)
        skinSlot(button)
        paintSlot(button)
    end)

    -- Retail's bag windows draw a NineSlice and fit their own rect; Forever's do not.
    if (not frame.NineSlice and type(windows[frame]) == "table") then
        fitToSlots(frame, windows[frame])
    end
end

local function refreshAll()
    for _, frame in ipairs(containerFrames()) do
        RUI:safe("Bags", refresh, frame)
    end
end

RUI:registerModule("bags", "Bags", function()
    for _, frame in ipairs(containerFrames()) do
        frame:HookScript("OnShow", function(self)
            -- Slots are laid out after OnShow; wait a frame so they have their places.
            C_Timer.After(0, function() RUI:safe("Bags", refresh, self) end)
        end)

        for _, method in ipairs({ "UpdateItems", "UpdateItemLayout" }) do
            if (frame[method]) then
                hooksecurefunc(frame, method, function(self) RUI:safe("Bags", refresh, self) end)
            end
        end
    end

    if (type(ContainerFrame_Update) == "function") then
        hooksecurefunc("ContainerFrame_Update", function(frame) RUI:safe("Bags", refresh, frame) end)
    end

    S:editBox(BagItemSearchBox)

    local events = CreateFrame("Frame")

    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", refreshAll)
end, refreshAll)
