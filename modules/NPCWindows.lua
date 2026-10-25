--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The windows an NPC opens, quest, gossip, merchant and mail, as kit windows with kit buttons, tabs
-- and edit boxes. Items in them become square slots bordered in the item's quality color. The
-- parchment pages stay: quest and gossip text is written in dark ink for them.

local _, ns = ...

local RUI, UI, S = ns.RUI, ns.UI, ns.Skin

local MERCHANT_SLOTS = 12   -- the buyback page's twelve; the merchant's own page shows ten of them
local PROGRESS_ITEMS = 6
local INBOX_ITEMS = 7
local SEND_ATTACHMENTS = 16
local OPEN_ATTACHMENTS = 16

local QUEST_BUTTONS = { "QuestFrameAcceptButton", "QuestFrameCompleteButton", "QuestFrameCompleteQuestButton",
    "QuestFrameDeclineButton", "QuestFrameGoodbyeButton", "QuestFrameGreetingGoodbyeButton",
    "QuestLogPopupDetailFrameAbandonButton", "QuestLogPopupDetailFrameShareButton",
    "QuestLogPopupDetailFrameTrackButton" }

local MAIL_BUTTONS = { "SendMailMailButton", "SendMailCancelButton", "OpenMailReplyButton", "OpenMailDeleteButton",
    "OpenMailCancelButton", "OpenMailReportSpamButton", "OpenAllMail" }

local MAIL_EDIT_BOXES = { "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold", "SendMailMoneySilver",
    "SendMailMoneyCopper" }

-- The parts of a quest page: the parchment and the stone, marble or bronze a quest can be written on.
local PAGE_PARTS = { "Bg", "SealMaterialBG", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft",
    "MaterialBotRight" }

local function wantQuality()
    return RUI.db.npc.qualityBorders
end

local function pageOf(frame)
    local keep = {}

    for _, key in ipairs(PAGE_PARTS) do
        if (frame[key]) then keep[frame[key]] = true end
    end

    return keep
end

-- How far a card stops short of its button's right end. Blizzard's buttons run a little wider than
-- their name, past the page's edge in the right-hand column, and into the next column's icon.
local CARD_RIGHT_GAP = 4

-- A card under each reward, so a page of them reads as separate entries. The names are written in
-- dark ink for the parchment, so the card only darkens it a little and its edge is soft. It is as
-- tall as the icon, which Blizzard's rows leave a gap between; the buttons themselves touch.
local function rewardCard(button, icon)
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetPoint("TOPLEFT", icon, "TOPLEFT")
    fill:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
    fill:SetPoint("RIGHT", button, "RIGHT", -CARD_RIGHT_GAP, 0)
    fill:SetColorTexture(0, 0, 0, 0.08)

    -- One pixel outside the fill, where the icon's own border runs, so the two meet in one line.
    S:lines(button, fill, 1, "BACKGROUND", -8):SetColor(0, 0, 0, 0.3)
end

-- A quest reward or required item: an icon with its name beside it, on a card of its own. The slot
-- goes around the icon only, and Blizzard's label art behind the name is gone.
local function rewardSlot(button)
    local icon = button and button.Icon

    if (not icon or not S:once(button, "reward")) then return end

    S:unmask(icon)
    S:cropIcon(icon)
    S:kill(button.NameFrame)
    S:kill(button.CircleBackground)
    S:kill(button.CircleBackgroundGlow)

    S:font(button.Count, 12, true, UI.fontNumber)

    rewardCard(button, icon)

    local look = S:iconBackdrop(button, icon)

    S:qualityBorder(button, look, wantQuality)
end

local function eachActive(pool, fn)
    if (pool and pool.EnumerateActive) then
        for item in pool:EnumerateActive() do fn(item) end
    end
end

-- Items and currencies are reward buttons; spells and renown come from pools of their own.
local function skinRewards()
    local rewards = QuestInfoRewardsFrame

    if (not rewards) then return end

    for _, button in ipairs(rewards.RewardButtons or {}) do rewardSlot(button) end

    eachActive(rewards.spellRewardPool, rewardSlot)
    eachActive(rewards.reputationRewardPool, rewardSlot)
end

local function skinQuest()
    local frame = QuestFrame

    if (not frame or not S:once(frame, "quest")) then return end

    S:window(frame)

    for _, name in ipairs(QUEST_BUTTONS) do S:panelButton(_G[name]) end

    for i = 1, PROGRESS_ITEMS do rewardSlot(_G["QuestProgressItem" .. i]) end

    skinRewards()

    if (type(QuestInfo_Display) == "function") then
        hooksecurefunc("QuestInfo_Display", function() RUI:safe("Quest window", skinRewards) end)
    end

    -- The quest log's detail popup is a page of its own, parchment included.
    local popup = QuestLogPopupDetailFrame

    if (popup) then S:window(popup, nil, pageOf(popup)) end
end

local function skinGossip()
    local frame = GossipFrame

    if (not frame or not S:once(frame, "gossip")) then return end

    -- The parchment is the frame's own Background texture; it stays under the dark text.
    S:window(frame, nil, frame.Background and { [frame.Background] = true })

    local greeting = frame.GreetingPanel

    if (greeting) then S:panelButton(greeting.GoodbyeButton) end
end

local function skinMerchantItem(index)
    local name = "MerchantItem" .. index
    local item = _G[name]

    if (not item or not S:once(item, "merchantitem")) then return end

    -- The name stays anchored to the slot art, which still has its place once hidden.
    S:kill(item.SlotTexture or _G[name .. "SlotTexture"])
    S:kill(_G[name .. "NameFrame"])

    S:itemSlot(item.ItemButton or _G[name .. "ItemButton"], wantQuality)
end

local function skinMerchant()
    local frame = MerchantFrame

    if (not frame or not S:once(frame, "merchant")) then return end

    S:window(frame)

    for _, name in ipairs({ "MerchantMoneyBg", "MerchantMoneyInset", "MerchantExtraCurrencyBg",
        "MerchantExtraCurrencyInset" }) do
        S:inset(_G[name])
    end

    for i = 1, 2 do S:tab(_G["MerchantFrameTab" .. i]) end

    for i = 1, MERCHANT_SLOTS do skinMerchantItem(i) end

    S:kill(_G.MerchantBuyBackItemSlotTexture)
    S:kill(_G.MerchantBuyBackItemNameFrame)
    S:itemSlot(_G.MerchantBuyBackItemItemButton, wantQuality)
end

-- A send attachment shows its item as the button's normal texture, set anew for each item.
local function sendAttachment(button)
    if (not button or not S:once(button, "attachment")) then return end

    local keep = {}

    for _, key in ipairs({ "IconBorder", "IconOverlay", "IconOverlay2" }) do
        if (button[key]) then keep[button[key]] = true end
    end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local texture = button[getter](button)

        if (texture) then keep[texture] = true end
    end

    S:stripTextures(button, keep)
    S:buttonStates(button)
    S:font(button.Count, 12, true, UI.fontNumber)

    local look = S:iconBackdrop(button, button, false)

    S:qualityBorder(button, look, wantQuality)

    local function crop(self) S:cropIcon(self:GetNormalTexture()) end

    hooksecurefunc(button, "SetNormalTexture", crop)
    crop(button)
end

local function skinMailItems()
    for i = 1, INBOX_ITEMS do
        local item = _G["MailItem" .. i]

        if (item and S:once(item, "mailitem")) then
            S:stripTextures(item)

            local name = "MailItem" .. i .. "Button"
            local button = item.Button or _G[name]

            if (button) then
                S:kill(button.Slot or _G[name .. "Slot"])
                S:itemSlot(button, wantQuality)
            end
        end
    end
end

local function skinAttachments()
    for i = 1, SEND_ATTACHMENTS do sendAttachment(_G["SendMailAttachment" .. i]) end
    for i = 1, OPEN_ATTACHMENTS do S:itemSlot(_G["OpenMailAttachmentButton" .. i], wantQuality) end
end

-- Retail redraws mail through global functions; Forever through the frames' own methods.
local function hookUpdate(fn, frame, method, hook)
    if (type(_G[fn]) == "function") then
        hooksecurefunc(fn, hook)
    elseif (frame and frame[method]) then
        hooksecurefunc(frame, method, hook)
    end
end

local function skinMail()
    local frame = MailFrame

    if (not frame or not S:once(frame, "mail")) then return end

    S:window(frame)

    for i = 1, 2 do S:tab(_G["MailFrameTab" .. i]) end

    if (InboxFrame) then S:stripTextures(InboxFrame) end

    S:inset(_G.SendMailMoneyInset)
    S:kill(_G.SendMailMoneyBg)

    S:window(OpenMailFrame)

    S:itemSlot(_G.OpenMailLetterButton)
    S:itemSlot(_G.OpenMailMoneyButton)

    for _, name in ipairs(MAIL_BUTTONS) do S:panelButton(_G[name]) end
    for _, name in ipairs(MAIL_EDIT_BOXES) do S:editBox(_G[name]) end

    skinMailItems()
    skinAttachments()

    local function attachments() RUI:safe("Mail", skinAttachments) end

    hookUpdate("InboxFrame_Update", InboxFrame, "Update", function() RUI:safe("Mail", skinMailItems) end)
    hookUpdate("OpenMail_Update", OpenMailFrame, "Update", attachments)
    hookUpdate("SendMailFrame_Update", SendMailFrame, "Update", attachments)
end

local function skinPanels()
    RUI:safe("Quest window", skinQuest)
    RUI:safe("Gossip window", skinGossip)
    RUI:safe("Merchant window", skinMerchant)
end

RUI:registerModule("npc", "Quest, gossip, merchant and mail", function()
    -- On the current clients these come with load-on-demand addons; on older ones they are there.
    skinPanels()
    RUI:onAddon("Blizzard_UIPanels_Game", skinPanels)

    RUI:safe("Mail", skinMail)
    RUI:onAddon("Blizzard_MailFrame", skinMail)
end, function()
    S:repaintQualities()
end)
