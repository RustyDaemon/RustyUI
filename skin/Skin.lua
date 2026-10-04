--[[
RustyUI addon
Copyright (C) 2026 RustyDaemon (https://github.com/RustyDaemon)

See License file for details.
--]]

-- What every module does to a Blizzard frame: take its art away, and put the kit's flat panels,
-- 1px borders and square icons in its place. Only textures and font strings are changed; secure
-- frames are never moved, resized or hidden, so nothing here can taint combat.

local _, ns = ...

local UI = ns.UI

local S = {}
ns.Skin = S

S.FLAT = "Interface\\Buttons\\WHITE8X8"
S.ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }

-- What has been skinned is kept here, not on Blizzard's frames, so their tables stay untouched.
local done = setmetatable({}, { __mode = "k" })

-- True the first time it is asked about an object and tag, false after.
function S:once(object, tag)
    if (not object) then return false end

    local tags = done[object]

    if (not tags) then
        tags = {}
        done[object] = tags
    end

    tag = tag or "skin"

    if (tags[tag]) then return false end

    tags[tag] = true

    return true
end

-- Looks up "PlayerFrame.PlayerFrameContainer.FrameTexture" or a plain global name; nil when any step
-- is missing, which is how a module asks for a frame only one of the clients has.
function S:get(path)
    local node = _G

    for part in path:gmatch("[^%.]+") do
        if (type(node) ~= "table") then return nil end

        node = node[part]
    end

    return node
end

local function isRegion(object)
    return object.IsObjectType and (object:IsObjectType("Texture") or object:IsObjectType("FontString"))
end

-- Hides a texture for good: Blizzard shows some of them again on updates, and each time it is
-- hidden right back. A frame only fades out, since hiding one might be a protected call.
function S:kill(object)
    if (type(object) ~= "table" or not object.SetAlpha) then return end

    object:SetAlpha(0)

    if (not isRegion(object)) then return end

    object:Hide()

    if (S:once(object, "kill")) then
        -- SetShown's flag can be a secret boolean (target cast bars) that tainted code may not
        -- test; hiding again is harmless whatever it was.
        hooksecurefunc(object, "Show", object.Hide)
        hooksecurefunc(object, "SetShown", object.Hide)
    end
end

function S:killAll(paths)
    for _, path in ipairs(paths) do
        S:kill(S:get(path))
    end
end

-- Kills every texture drawn by the frame itself; its children keep theirs, and a status bar keeps
-- its fill.
function S:stripTextures(frame)
    local fill = frame.GetStatusBarTexture and frame:GetStatusBarTexture()

    for _, region in ipairs({ frame:GetRegions() }) do
        if (region:IsObjectType("Texture") and region ~= fill) then S:kill(region) end
    end
end

-- Retail rounds icons, portraits and bars with mask textures; squares need them gone.
function S:unmask(texture)
    if (not texture or not texture.GetNumMaskTextures) then return end

    for i = texture:GetNumMaskTextures(), 1, -1 do
        texture:RemoveMaskTexture(texture:GetMaskTexture(i))
    end
end

function S:font(fs, size, outline, file)
    if (not fs or not fs.GetFont) then return end

    local _, current = fs:GetFont()

    -- A font string not given a font yet reports its size as 0, which SetFont refuses.
    if (not current or current <= 0) then current = 12 end

    -- Only a size asked for is scaled: the current one may already be, and would grow each call.
    fs:SetFont(file or UI.font, size and UI:fontSize(size) or current, outline and "OUTLINE" or "")

    if (outline) then
        fs:SetShadowOffset(0, 0)
    else
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    end
end

-- Every font string under a frame, children included, in the kit's font at its current size.
function S:fonts(frame, depth)
    depth = depth or 0

    for _, region in ipairs({ frame:GetRegions() }) do
        if (region:IsObjectType("FontString")) then S:font(region) end
    end

    if (depth < 4) then
        for _, child in ipairs({ frame:GetChildren() }) do
            S:fonts(child, depth + 1)
        end
    end
end

-- Midnight hands addons some values as secrets (an enemy's cast state, among others): they can be
-- passed on but not compared or used as keys. Clients without them have nothing secret.
function S:isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) and true or false
end

function S:cropIcon(icon)
    if (icon and icon.SetTexCoord) then icon:SetTexCoord(unpack(S.ICON_CROP)) end
end
