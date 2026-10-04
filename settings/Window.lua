--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- The settings window, laid out like My Loot History's: a sidebar of pages, each a stack of rows
-- built from RUI.options.

local _, ns = ...

local RUI, UI, L = ns.RUI, ns.UI, ns.Settings
local resolve, builders = L.resolve, L.builders
local WIDTH, HEIGHT, PAD, TITLE_HEIGHT = L.WIDTH, L.HEIGHT, L.PAD, L.TITLE_HEIGHT
local SIDEBAR_WIDTH, NAV_HEIGHT, SCROLLBAR_WIDTH = L.SIDEBAR_WIDTH, L.NAV_HEIGHT, L.SCROLLBAR_WIDTH
local CONTENT_WIDTH, GAP, WHEEL_STEP = L.CONTENT_WIDTH, L.GAP, L.WHEEL_STEP

local window = nil

local function sortedArgs(args)
    local list = {}

    for key, option in pairs(args or {}) do
        list[#list+1] = { key = key, option = option }
    end

    table.sort(list, function(l, r)
        local lo, ro = l.option.order or 100, r.option.order or 100

        if (lo == ro) then return l.key < r.key end

        return lo < ro
    end)

    return list
end

-- The top level's loose options are the General page; every group is a page of its own.
local function collectPages()
    local general = { name = "General", entries = {} }
    local pages = { general }

    for _, arg in ipairs(sortedArgs(RUI.options.args)) do
        if (arg.option.type == "group") then
            pages[#pages+1] = { name = arg.option.name, entries = sortedArgs(arg.option.args) }
        else
            general.entries[#general.entries+1] = arg
        end
    end

    return pages
end

local function buildPage(page, changed)
    local frame = CreateFrame("Frame", nil, window.scroll)
    frame:SetWidth(CONTENT_WIDTH)
    frame:Hide()

    local title = UI:text(frame, 15, "text")
    title:SetPoint("TOPLEFT", 2, -2)
    title:SetText(page.name)

    local rows = {}

    for _, arg in ipairs(page.entries) do
        local option = arg.option
        local build = builders[option.type]

        if (build) then
            local info = { arg.key, option = option, type = option.type }
            local row = build(frame, option, info, changed)

            row:SetWidth(CONTENT_WIDTH)
            L.addDisabledCover(row, option, info)

            row.option = option
            row.info = info
            rows[#rows+1] = row
        end
    end

    frame.Layout = function()
        local y = 34

        -- Hidden options drop out of the stack; descriptions change height as their text changes.
        for _, row in ipairs(rows) do
            local hidden = resolve(row.option.hidden, row.info)

            row:SetShown(not hidden)

            if (not hidden) then
                row.Refresh()

                y = y + (row.topGap or 0)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)

                y = y + row:GetHeight() + GAP
            end
        end

        frame:SetHeight(y + PAD)
    end

    return frame
end

local function updateScroll(offset)
    local page = window.pages[window.current]
    local visible = window.scroll:GetHeight()

    window.offset = window.scrollbar:Update(visible, page.frame:GetHeight(), offset)
    window.scroll:SetVerticalScroll(window.offset)
end

local function refreshPage()
    if (not window or not window:IsShown()) then return end

    window.reload:SetShown(RUI.reloadPending and true or false)
    window.pages[window.current].frame.Layout()
    updateScroll(window.offset)
end

local function selectPage(index)
    local previous = window.pages[window.current]

    if (previous and previous.frame) then previous.frame:Hide() end

    window.current = index
    window.offset = 0

    local page = window.pages[index]

    page.frame = page.frame or buildPage(page, refreshPage)
    page.frame:Show()
    window.scroll:SetScrollChild(page.frame)

    for i, nav in ipairs(window.nav) do nav:SetActive(i == index) end

    RUI.db.ui.settingsPage = index

    refreshPage()
end

local function createNavButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(NAV_HEIGHT)

    UI:attachHover(button, "raised", 1, "BACKGROUND")

    local lit = button:CreateTexture(nil, "BORDER")
    lit:SetAllPoints()
    lit:SetColorTexture(UI:rgb("accentLit"))
    lit:Hide()

    local stripe = button:CreateTexture(nil, "OVERLAY")
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    stripe:SetWidth(2)
    stripe:SetColorTexture(UI:rgb("accent"))
    stripe:Hide()

    local label = UI:text(button, 12, "textDim")
    label:SetPoint("LEFT", 14, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)

    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)

    button.SetActive = function(_, active)
        lit:SetShown(active)
        stripe:SetShown(active)
        label:SetTextColor(UI:rgbIf(active, "accent", "textDim"))
    end

    return button
end

local function savePosition()
    local point, _, relativePoint, x, y = window:GetPoint()

    RUI.db.ui.settings = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function buildWindow()
    local frame = CreateFrame("Frame", "RustyUISettingsFrame", UIParent)

    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(WIDTH, HEIGHT)
    frame:Hide()

    UI:addShadow(frame, 6, 0.45)

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(UI:rgb("window", 0.97))

    UI:addBorder(frame, UI:rgb("borderLight"))

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")

    local lr, lg, lb = UI:rgb("accentLit")
    local titleFill = UI:gradient(titleBar, "BACKGROUND", "VERTICAL",
        0.055, 0.059, 0.070, 1, lr * 0.6 + 0.04, lg * 0.6 + 0.04, lb * 0.6 + 0.04, 1)
    titleFill:SetAllPoints()

    local titleLine = titleBar:CreateTexture(nil, "ARTWORK")
    titleLine:SetPoint("BOTTOMLEFT")
    titleLine:SetPoint("BOTTOMRIGHT")
    titleLine:SetHeight(1)
    titleLine:SetColorTexture(UI:rgb("accentDim", 0.6))

    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)

    local logo = titleBar:CreateTexture(nil, "ARTWORK")
    logo:SetSize(24, 24)
    logo:SetPoint("LEFT", PAD, 0)
    logo:SetTexture("Interface\\Icons\\inv_ore_iron_01")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local logoBorder = titleBar:CreateTexture(nil, "BACKGROUND")
    logoBorder:SetPoint("TOPLEFT", logo, "TOPLEFT", -1, 1)
    logoBorder:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", 1, -1)
    logoBorder:SetColorTexture(UI:rgb("accentDim"))

    local title = UI:text(titleBar, 15, "text")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 1)
    title:SetText("RustyUI")

    local subtitle = UI:text(titleBar, 11, "textFaint")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subtitle:SetText(SETTINGS or "Settings")

    local close = UI:iconButton(titleBar, 28, "Interface\\Buttons\\UI-StopButton",
        function() frame:Hide() end)
    close:SetPoint("RIGHT", -6, 0)
    UI:tooltip(close, CLOSE or "Close")

    -- Shown once a change waits for a reload, so the player can take it right away.
    local reload = UI:button(titleBar, "Reload UI", 100, 24, function() ReloadUI() end)
    reload:SetPoint("RIGHT", close, "LEFT", -8, 0)
    reload:SetAccent(true)
    reload:Hide()
    UI:tooltip(reload, "Reload UI", "Some changes take effect only after a reload.")

    local sidebar = UI:panel(frame, "panel", true)
    sidebar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PAD - 1, -PAD)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    local version = UI:text(sidebar, 11, "textFaint")
    version:SetPoint("BOTTOMLEFT", 14, 10)
    version:SetText("v" .. RUI.version)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", PAD, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)

    local scroll = CreateFrame("ScrollFrame", nil, content)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -(SCROLLBAR_WIDTH + PAD), 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        updateScroll((window.offset or 0) - delta * WHEEL_STEP)
    end)

    local scrollbar = UI:scrollbar(content, function(offset)
        window.offset = offset
        scroll:SetVerticalScroll(offset)
    end)
    scrollbar:SetPoint("TOPRIGHT", 0, 0)
    scrollbar:SetPoint("BOTTOMRIGHT", 0, 0)

    frame.scroll = scroll
    frame.scrollbar = scrollbar
    frame.reload = reload
    frame.pages = collectPages()
    frame.nav = {}

    for i, page in ipairs(frame.pages) do
        local nav = createNavButton(sidebar, page.name, function() selectPage(i) end)

        nav:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 1, -(6 + (i - 1) * NAV_HEIGHT))
        nav:SetPoint("RIGHT", sidebar, "RIGHT", -1, 0)

        frame.nav[i] = nav
    end

    if (not tContains(UISpecialFrames, "RustyUISettingsFrame")) then
        tinsert(UISpecialFrames, "RustyUISettingsFrame")
    end

    return frame
end

function RUI:openSettings(pageIndex)
    if (not window) then window = buildWindow() end

    local saved = self.db.ui.settings or {}

    window:ClearAllPoints()

    if (saved.point) then
        window:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        window:SetPoint("CENTER")
    end

    window:Show()
    window:Raise()

    local page = pageIndex or self.db.ui.settingsPage or 1

    selectPage(window.pages[page] and page or 1)

    -- Lay out again next frame, once the scroll frame has its size.
    C_Timer.After(0, refreshPage)
end

function RUI:refreshSettings()
    refreshPage()
end

function RUI:toggleSettings()
    if (window and window:IsShown()) then
        window:Hide()
    else
        self:openSettings()
    end
end
