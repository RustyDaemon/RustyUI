--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The breath and fatigue bars and battleground countdowns as flat kit bars, and the extra action
-- and zone ability buttons as square kit slots without their ornate frames.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

-- Mirror bars --------------------------------------------------------------------------------------

-- Each timer knows its kind (breath, fatigue, feign death); its color comes from Blizzard's table,
-- since some clients color the bar through its atlas, which the flat texture drops.
local function paintMirror(bar)
    local timer = bar:GetParent()
    local kind = timer and (timer.timer or timer.timerType)
    local color = kind and MirrorTimerColors and MirrorTimerColors[kind]

    if (color) then S:paintBar(bar, color.r, color.g, color.b) end
end

local function skinTimerFrame(frame, bar, text)
    if (not frame or not bar or not S:once(frame, "timer")) then return end

    S:stripTextures(frame)

    for _, key in ipairs({ "Border", "border", "Background", "BG" }) do
        S:kill(frame[key])
        S:kill(bar[key])
    end

    S:flatBar(bar, paintMirror)
    S:barBackdrop(bar)
    S:font(text, 11, true)
end

local function skinMirrorTimers()
    -- WoW Forever and older clients name their three timers.
    for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
        local name = "MirrorTimer" .. i
        local frame = _G[name]

        if (frame) then
            skinTimerFrame(frame, frame.StatusBar or _G[name .. "StatusBar"], frame.Text or _G[name .. "Text"])
        end
    end

    -- Retail keeps them in a container and makes them as needed.
    local container = MirrorTimerContainer

    if (container) then
        for _, frame in ipairs({ container:GetChildren() }) do
            skinTimerFrame(frame, frame.StatusBar, frame.Text)
        end
    end
end

-- Battleground and arena countdowns: TimerTracker makes a bar per timer as they start.
local function skinCountdowns()
    for _, timer in ipairs(TimerTracker and TimerTracker.timerList or {}) do
        local bar = timer.bar

        if (bar and S:once(bar, "countdown")) then
            S:stripTextures(bar)
            S:kill(bar.border)
            S:kill(bar.Border)
            S:flatBar(bar)
            S:barBackdrop(bar)
            S:font(bar.timeText or bar.TimeText, 11, true)
        end
    end
end

-- Extra action and zone ability ----------------------------------------------------------------------

local function skinAbilityButton(button)
    if (not button or not S:once(button, "extrabutton")) then return end

    local icon = button.icon or button.Icon

    S:unmask(icon)
    S:cropIcon(icon)
    S:hideNormalTexture(button)
    S:buttonStates(button)
    S:iconBackdrop(button, button)

    S:font(button.HotKey, 12, true, UI.fontNumber)
    S:font(button.Count, 13, true, UI.fontNumber)
end

local function skinZoneAbilities()
    local frame = ZoneAbilityFrame

    if (not frame) then return end

    S:kill(frame.Style)

    local container = frame.SpellButtonContainer

    if (container) then
        for _, button in ipairs({ container:GetChildren() }) do skinAbilityButton(button) end
    end
end

RUI:registerModule("timers", "Timers and extra button", function()
    skinMirrorTimers()
    skinCountdowns()

    -- The extra action button's big ornate frame is a texture of its own, set per encounter.
    local extra = ExtraActionButton1

    if (extra) then
        S:kill(extra.style)
        skinAbilityButton(extra)
    end

    skinZoneAbilities()

    if (ZoneAbilityFrame and ZoneAbilityFrame.UpdateDisplayedZoneAbilities) then
        hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", function()
            if (not InCombatLockdown()) then RUI:safe("Zone ability", skinZoneAbilities) end
        end)
    end

    if (MirrorTimerContainer and MirrorTimerContainer.SetupTimer) then
        hooksecurefunc(MirrorTimerContainer, "SetupTimer", function() RUI:safe("Mirror timers", skinMirrorTimers) end)
    end

    if (type(MirrorTimer_Show) == "function") then
        hooksecurefunc("MirrorTimer_Show", function() RUI:safe("Mirror timers", skinMirrorTimers) end)
    end

    if (TimerTracker) then
        TimerTracker:HookScript("OnEvent", function() RUI:safe("Countdowns", skinCountdowns) end)
    end

    local events = CreateFrame("Frame")

    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() RUI:safe("Zone ability", skinZoneAbilities) end)
end)
