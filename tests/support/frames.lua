-- A stand-in for the client's widget API, enough to build RustyUI's kit, skins and settings
-- window outside the game. Any capitalized method a test does not care about is a no-op that
-- counts its calls; the ones whose results matter are written out below.

local frames = {}

local widget = {}

-- Only names shaped like widget methods are made up; a field such as bar.CastTimeText stays nil,
-- as it is on a real frame that lacks it.
local VERBS = { "Set", "Get", "Is", "Has", "Enable", "Disable", "Register", "Unregister", "Clear", "Raise",
    "Lower", "Start", "Stop", "Play", "Add", "Remove", "Hook", "Highlight", "Lock", "Unlock" }

local function isMethodName(key)
    if (type(key) ~= "string") then return false end

    for _, verb in ipairs(VERBS) do
        if (key:sub(1, #verb) == verb) then return true end
    end

    return false
end

local widgetMeta = {
    __index = function(self, key)
        if (widget[key]) then return widget[key] end

        if (not isMethodName(key)) then return nil end

        local fn = function(s)
            s.calls[key] = (s.calls[key] or 0) + 1

            return s
        end

        rawset(self, key, fn)

        return fn
    end,
}

local function newWidget(kind, name, parent)
    local self = setmetatable({
        kind = kind,
        name = name,
        parent = parent,
        calls = {},
        scripts = {},
        children = {},
        regions = {},
        points = {},
        shown = true,
        alpha = 1,
        width = 100,
        height = 20,
        text = "",
        events = {},
    }, widgetMeta)

    if (parent and parent.children) then
        if (kind == "Texture" or kind == "FontString") then
            parent.regions[#parent.regions + 1] = self
        else
            parent.children[#parent.children + 1] = self
        end
    end

    frames.all[#frames.all + 1] = self

    return self
end

frames.new = newWidget
frames.all = {}

function widget:GetObjectType() return self.kind end
function widget:IsObjectType(kind) return self.kind == kind end
function widget:GetName() return self.name end

function widget:SetWidth(w) self.width = w return self end
function widget:SetHeight(h) self.height = h return self end
function widget:SetSize(w, h) self.width, self.height = w, h return self end
function widget:GetWidth() return self.width end
function widget:GetHeight() return self.height end
function widget:GetSize() return self.width, self.height end
function widget:GetEffectiveScale() return self.scale or 1 end
function widget:GetScale() return self.scale or 1 end
function widget:GetFrameLevel() return 5 end
function widget:GetFrameStrata() return "HIGH" end
function widget:GetLeft() return 0 end

function widget:Show() self.shown = true self:Fire("OnShow") return self end
function widget:Hide() self.shown = false self:Fire("OnHide") return self end
function widget:SetShown(value) if (value) then self:Show() else self:Hide() end return self end
function widget:IsShown() return self.shown end
function widget:IsVisible() return self.shown end
function widget:IsEnabled() return true end

function widget:SetAlpha(a) self.alpha = a return self end
function widget:GetAlpha() return self.alpha end

function widget:SetPoint(point, ...)
    self.points[#self.points + 1] = { point, ... }

    return self
end

function widget:ClearAllPoints() self.points = {} return self end
function widget:SetAllPoints() return self end
function widget:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function widget:GetParent() return self.parent end
function widget:GetNumPoints() return #self.points end
function widget:GetRegions() return unpack(self.regions) end
function widget:GetChildren() return unpack(self.children) end

function widget:SetScript(name, handler)
    self.scripts[name] = { handler }

    return self
end

function widget:HookScript(name, handler)
    self.scripts[name] = self.scripts[name] or {}
    table.insert(self.scripts[name], handler)

    return self
end

function widget:GetScript(name)
    return self.scripts[name] and self.scripts[name][1]
end

function widget:Fire(name, ...)
    local handlers = self.scripts[name]

    if (not handlers) then return end

    for i = 1, #handlers do
        handlers[i](self, ...)
    end
end

function widget:Click(...)
    self:Fire("OnClick", ...)

    return self
end

function widget:RegisterEvent(event) self.events[event] = true return self end
function widget:UnregisterEvent(event) self.events[event] = nil return self end

function widget:SetText(value) self.text = value ~= nil and tostring(value) or "" return self end
function widget:GetText() return self.text end
function widget:GetStringWidth() return #self.text * 6 end
function widget:GetStringHeight() return 12 end

function widget:GetFont()
    return self.font or "Fonts\\FRIZQT__.TTF", self.fontSize or 12, self.fontFlags or ""
end

function widget:SetFont(path, size, flags)
    assert(type(path) == "string", "SetFont wants a font path")
    assert(type(size) == "number" and size > 0, "SetFont wants a size above 0, got "..tostring(size))
    assert(type(flags) == "string", "SetFont wants flags as a string, got "..type(flags))

    self.font, self.fontSize, self.fontFlags = path, size, flags

    return self
end

local function assertColor(method, r, g, b)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number",
        method.." wants three numbers, got "..tostring(r)..", "..tostring(g)..", "..tostring(b))
end

function widget:SetTextColor(r, g, b) assertColor("SetTextColor", r, g, b) return self end

function widget:SetColorTexture(r, g, b, a)
    assertColor("SetColorTexture", r, g, b)

    self.color = { r, g, b, a or 1 }
    self.texture = "color"

    return self
end

function widget:SetVertexColor(r, g, b, a)
    assertColor("SetVertexColor", r, g, b)

    self.vertex = { r, g, b, a or 1 }

    return self
end

function widget:SetTexture(value)
    assert(value ~= nil, "SetTexture(nil)")

    self.texture = value

    return self
end

function widget:GetTexture() return self.texture end
function widget:SetAtlas(atlas) self.texture = atlas return self end

function widget:SetGradient(orientation, from, to)
    assert(orientation == "HORIZONTAL" or orientation == "VERTICAL",
        "bad gradient orientation: "..tostring(orientation))
    assert(type(from) == "table" and type(to) == "table", "SetGradient wants two colours")

    return self
end

function widget:CreateTexture(name)
    return newWidget("Texture", name, self)
end

function widget:CreateFontString(name)
    return newWidget("FontString", name, self)
end

function widget:CreateMaskTexture(name)
    return newWidget("MaskTexture", name, self)
end

function widget:GetNumMaskTextures() return 0 end

-- Status bars keep their fill as a texture of their own, as the client's do.
function widget:SetStatusBarTexture(value)
    self.fill = self.fill or newWidget("Texture", nil, self)
    self.fill.texture = value

    return self
end

function widget:GetStatusBarTexture()
    self.fill = self.fill or newWidget("Texture", nil, self)

    return self.fill
end

function widget:SetStatusBarColor(r, g, b, a)
    assertColor("SetStatusBarColor", r, g, b)

    self.barColor = { r, g, b, a or 1 }

    return self
end

function widget:SetScrollChild(child) self.scrollChild = child return self end

function frames.install()
    _G.UIParent = newWidget("Frame", "UIParent")
    _G.UIParent:SetSize(1920, 1080)

    _G.CreateFrame = function(kind, name, parent)
        local frame = newWidget(kind, name, parent)

        if (name) then _G[name] = frame end

        return frame
    end

    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end

    local function fontObject()
        local font = newWidget("Font")

        font.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end

        return font
    end

    _G.GameFontNormal = fontObject()
    _G.NumberFontNormal = fontObject()

    local tooltip = newWidget("GameTooltip", "GameTooltip")

    tooltip.AddLine = function(self, _, r, g, b)
        if (r ~= nil) then assertColor("AddLine", r, g, b) end

        return self
    end

    _G.GameTooltip = tooltip

    return frames
end

return frames
