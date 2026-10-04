--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Square buff and debuff icons. A debuff's border keeps the color Blizzard gives it for its type.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local ENCHANT = { 0.62, 0.35, 0.86 }

-- Retail marks debuff types with an atlas rather than a color; its name says which type.
local function typeColor(atlas)
    if (type(atlas) ~= "string" or not DebuffTypeColor) then return nil end

    atlas = atlas:lower()

    for _, kind in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
        if (atlas:find(kind:lower(), 1, true)) then
            local color = DebuffTypeColor[kind]

            return color.r, color.g, color.b
        end
    end
end

local function skinAura(button, harmful)
    if (type(button) ~= "table" or not button.GetName) then return end

    local name = button:GetName()
    local icon = button.Icon or button.icon or (name and _G[name .. "Icon"])

    -- Private aura anchors are placeholders the game draws special auras into; their Icon is a frame,
    -- not a texture, and an empty anchor must stay invisible.
    if (button.isAuraAnchor or not icon or not icon.IsObjectType or not icon:IsObjectType("Texture")) then
        return
    end

    if (not S:once(button, "aura")) then return end

    S:unmask(icon)
    S:cropIcon(icon)

    local look = S:iconBackdrop(button, icon)

    -- Some aura buttons are always shown as anchors and only sometimes hold an icon; the slot shows
    -- with its icon. In Midnight combat the texture can be a secret value; the slot is then left be.
    local function followIcon()
        pcall(function() look:SetShown(icon:IsShown() and icon:GetTexture() ~= nil) end)
    end

    hooksecurefunc(icon, "Show", followIcon)
    hooksecurefunc(icon, "Hide", followIcon)
    hooksecurefunc(icon, "SetTexture", followIcon)
    followIcon()

    S:font(button.Count or (name and _G[name .. "Count"]), 12, true, UI.fontNumber)
    S:font(button.Duration or (name and _G[name .. "Duration"]), 10, true)

    local enchant = button.TempEnchantBorder or (name and name:find("^TempEnchant") and _G[name .. "Border"])

    if (enchant) then
        S:kill(enchant)
        look:SetBorderColor(unpack(ENCHANT))
        return
    end

    local border = button.DebuffBorder or button.Border or (name and _G[name .. "Border"])

    if (not border) then return end

    -- The border texture goes; its color, set as the debuff changes, carries over to ours.
    border:SetAlpha(0)

    -- In Midnight combat the color can be a secret value, which cannot even be tested outside pcall.
    local function follow(r, g, b)
        pcall(function()
            if (r) then look:SetBorderColor(r, g, b) end
        end)
    end

    hooksecurefunc(border, "SetVertexColor", function(_, r, g, b) follow(r, g, b) end)

    if (border.SetAtlas) then
        hooksecurefunc(border, "SetAtlas", function(_, atlas) follow(typeColor(atlas)) end)
    end

    if (harmful or border == button.DebuffBorder) then
        look:SetBorderColor(UI:rgb("bad"))
        follow(typeColor(border.GetAtlas and border:GetAtlas()))
    end
end

local function skinAuraFrame(frame)
    for _, button in ipairs(frame and frame.auraFrames or {}) do
        skinAura(button, frame == DebuffFrame)
    end
end

-- Forever names its aura buttons; Retail keeps them in lists on the aura frames.
local function sweepNamed()
    for i = 1, (BUFF_MAX_DISPLAY or 32) do skinAura(_G["BuffButton" .. i], false) end
    for i = 1, (DEBUFF_MAX_DISPLAY or 16) do skinAura(_G["DebuffButton" .. i], true) end
    for i = 1, 3 do skinAura(_G["TempEnchant" .. i], false) end
end

RUI:registerModule("auras", "Buffs and debuffs", function()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        if (frame and frame.UpdateAuraButtons) then
            hooksecurefunc(frame, "UpdateAuraButtons", skinAuraFrame)
        end

        skinAuraFrame(frame)
    end

    if (type(AuraButton_Update) == "function") then
        hooksecurefunc("AuraButton_Update", function(buttonName, index, filter)
            skinAura(_G[buttonName .. index], filter == "HARMFUL")
        end)
    end

    sweepNamed()

    local events = CreateFrame("Frame")

    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:SetScript("OnEvent", sweepNamed)
end)
