--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- Square buff and debuff icons. A debuff's border keeps the color Blizzard gives it for its type.
-- Timers are written short, and turn red in their last seconds.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local ENCHANT = { 0.62, 0.35, 0.86 }

local EXPIRING = 5 -- seconds left when a timer turns red

local skinned = setmetatable({}, { __mode = "k" }) -- the aura buttons skinned here, as a set

-- Blizzard's own unit letters ("%d m"), in the client's language, with the space taken out.
local function unit(format, fallback)
    if (type(format) ~= "string") then return fallback end

    return (format:gsub("%s", ""):gsub("\194\160", ""))
end

local DAYS = unit(DAY_ONELETTER_ABBR, "%dd")
local HOURS = unit(HOUR_ONELETTER_ABBR, "%dh")
local MINUTES = unit(MINUTE_ONELETTER_ABBR, "%dm")

-- The time left as "2d", "3h", "12m" or "45": Blizzard's own steps, without the space or the seconds'
-- unit, so a timer fits under its icon.
function RUI:shortDuration(seconds)
    if (seconds >= 86400 * 1.5) then return DAYS:format(math.ceil(seconds / 86400)) end
    if (seconds >= 3600 * 1.5) then return HOURS:format(math.ceil(seconds / 3600)) end
    if (seconds >= 60 * 1.5) then return MINUTES:format(math.ceil(seconds / 60)) end

    return ("%d"):format(math.max(math.floor(seconds), 0))
end

-- Blizzard writes the timer again every frame; this runs after each time. A secret time left, as in
-- Midnight combat, keeps Blizzard's text.
local function followTimer(button, timeLeft)
    local duration = button.Duration or (button.GetName and button:GetName() and _G[button:GetName() .. "Duration"])

    if (not duration or button.isExample or type(timeLeft) ~= "number" or S:isSecret(timeLeft)) then return end

    local db = RUI.db.auras

    if (db.shortTimers) then duration:SetText(RUI:shortDuration(timeLeft)) end
    if (db.expiringRed and timeLeft < EXPIRING) then duration:SetVertexColor(UI:rgb("bad")) end
end

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

    -- Retail's buttons write their own timer; Forever's are written by AuraButton_UpdateDuration.
    skinned[button] = true

    if (type(button.UpdateDuration) == "function") then hooksecurefunc(button, "UpdateDuration", followTimer) end

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

    if (type(AuraButton_UpdateDuration) == "function") then
        hooksecurefunc("AuraButton_UpdateDuration", function(button, timeLeft)
            if (skinned[button]) then followTimer(button, timeLeft) end
        end)
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
