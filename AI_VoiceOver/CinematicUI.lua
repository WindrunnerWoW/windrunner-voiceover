setfenv(1, VoiceOver)

-- Compact cinematic skin. Playback stays with the original sound queue.
-- The legacy client uses native circular portraits, not square model viewports.
local WIDTH, MAX_WIDTH, HEADER_HEIGHT, PORTRAIT_SIZE = 380, 480, 82, 82
local PANEL_TOP, PANEL_HEIGHT, PANEL_LEFT, QUEUE_LEFT = 9, 64, 40, 80
local ROW_HEIGHT, MAX_ROWS = 30, 4
local RIGHT_PADDING = 8
local TEXTURES = [[Interface\AddOns\AI_VoiceOver\Textures\]]
local InitPortrait = SoundQueueUI.InitPortrait
local Layout

local function SetGlyph(texture, name)
    texture:SetTexture(TEXTURES .. "Cinematic" .. name)
    texture:SetDesaturated(true)
    texture:SetVertexColor(0.96, 0.93, 0.86)
end

local function AddPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.left = panel:CreateTexture(nil, "BACKGROUND")
    panel.middle = panel:CreateTexture(nil, "BACKGROUND")
    panel.right = panel:CreateTexture(nil, "BACKGROUND")
    for _, texture in ipairs({ panel.left, panel.middle, panel.right }) do
        texture:SetTexture(TEXTURES .. "CinematicPanel")
        texture:SetAlpha(0.9)
    end
    -- Trim the transparent top/bottom atlas padding so adjoining panels touch.
    panel.left:SetTexCoord(0, 32 / 512, 7 / 128, 121 / 128)
    panel.left:SetPoint("TOPLEFT")
    panel.left:SetPoint("BOTTOMLEFT")
    panel.left:SetWidth(12)
    panel.right:SetTexCoord(480 / 512, 1, 7 / 128, 121 / 128)
    panel.right:SetPoint("TOPRIGHT")
    panel.right:SetPoint("BOTTOMRIGHT")
    panel.right:SetWidth(12)
    panel.middle:SetTexCoord(32 / 512, 480 / 512, 7 / 128, 121 / 128)
    panel.middle:SetPoint("TOPLEFT", panel.left, "TOPRIGHT")
    panel.middle:SetPoint("BOTTOMRIGHT", panel.right, "BOTTOMLEFT")
    return panel
end

local function Tooltip(button, text)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

local function Control(parent, glyph, tooltip, onClick, plain)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(plain and 16 or 28, plain and 24 or 28)
    if not plain then
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetTexture(TEXTURES .. "CinematicButton")
        button.background:SetAllPoints()
    end
    button:SetNormalTexture(TEXTURES .. "Cinematic" .. glyph)
    button:SetPushedTexture(TEXTURES .. "Cinematic" .. glyph)
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER")
        texture:SetSize(plain and 10 or 14, plain and 10 or 14)
        SetGlyph(texture, glyph)
    end
    button:GetPushedTexture():SetSize(plain and 9 or 12, plain and 9 or 12)
    button.tooltip = tooltip
    button:HookScript("OnEnter", function(self)
        self:GetNormalTexture():SetVertexColor(1, 0.83, 0.49)
        Tooltip(self, self.tooltip)
    end)
    button:HookScript("OnLeave", function(self)
        self:GetNormalTexture():SetVertexColor(0.96, 0.93, 0.86)
        GameTooltip_Hide()
    end)
    button:HookScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        onClick()
    end)
    return button
end

local function SoundTitle(soundData)
    if not soundData then return "" end
    return soundData.title or (Enums.SoundEvent:IsGossipEvent(soundData.event) and "Conversation" or "VoiceOver")
end

local function QuestIcon(texture, soundData)
    local event = soundData.event
    local name = "SoundQueueBulletGossip"
    if event == Enums.SoundEvent.QuestAccept then
        name = "SoundQueueBulletAccept"
    elseif event == Enums.SoundEvent.QuestProgress then
        name = "SoundQueueBulletProgress"
    elseif event == Enums.SoundEvent.QuestComplete then
        name = "SoundQueueBulletComplete"
    end
    texture:SetTexture(TEXTURES .. name)
end

function SoundQueueUI:InitDisplay()
    self.frame = CreateFrame("Frame", "VoiceOverFrame", UIParent, "BackdropTemplate")
    function self.frame:Reset()
        Addon.db.profile.SoundQueueUI.CinematicWidth = WIDTH
        self:SetWidth(WIDTH)
        self:SetHeight(HEADER_HEIGHT)
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", 0, 200)
    end
    -- Position is saved by the client; width belongs to this skin's profile.
    self.frame:SetWidth(Addon.db.profile.SoundQueueUI.CinematicWidth or WIDTH)
    self.frame:SetHeight(HEADER_HEIGHT)
    self.frame:SetPoint("BOTTOM", 0, 200)
    self.frame:SetMovable(true)
    self.frame:SetResizable(true)
    self.frame:SetClampedToScreen(true)
    self.frame:SetUserPlaced(true)
    self.frame:SetFrameStrata(Addon.db.profile.SoundQueueUI.FrameStrata)

    self.frame.background = AddPanel(self.frame)
    self.frame.background:SetFrameLevel(self.frame:GetFrameLevel())
    self.frame.container = CreateFrame("Frame", nil, self.frame)
    local container = self.frame.container
    container:SetPoint("TOPLEFT")
    container:SetPoint("TOPRIGHT")
    container:SetHeight(HEADER_HEIGHT)
    container.buttons = {}
    function container.buttons:Update()
        for _, button in ipairs(self) do button:Update() end
    end
    container.name = container:CreateFontString(nil, "OVERLAY", "VoiceOverNameFont")
    container.name:SetFont(GameFontNormal:GetFont(), 17, "")
    container.name:SetTextColor(0.94, 0.75, 0.41)
    container.name:SetWordWrap(false)
    function container.name:Update() Layout() end
    container.title = container:CreateFontString(nil, "OVERLAY", "VoiceOverButtonFont")
    container.title:SetFont(GameFontNormal:GetFont(), 15, "")
    container.title:SetTextColor(0.94, 0.92, 0.86)
    container.title:SetWordWrap(false)
    container.icon = container:CreateTexture(nil, "ARTWORK")
    container.icon:SetSize(14, 14)

    self.frame.queue = CreateFrame("Frame", nil, self.frame)
    self.frame.queue.background = AddPanel(self.frame.queue)

    self.frame.pause = Control(container, "Pause", "Pause Audio", function() SoundQueue:TogglePauseQueue() end)
    self.frame.skip = Control(container, "Skip", "Skip VoiceOver", function()
        local current = SoundQueue:GetCurrentSound()
        if not current then return end
        if SoundQueue:CanBePaused() then
            SoundQueue:RemoveSoundFromQueue(current)
        else
            -- Vanilla clients without stoppable sound cannot interrupt the
            -- current clip. Match the existing skip behavior for pending clips.
            for i = SoundQueue:GetQueueSize(), 2, -1 do
                SoundQueue:RemoveSoundFromQueue(SoundQueue.sounds[i])
            end
        end
    end)
    self.frame.disclosure = Control(container, "Expand", "Show VoiceOver Queue", function()
        local config = Addon.db.profile.SoundQueueUI
        config.QueueExpanded = not config.QueueExpanded
        self:UpdateSoundQueueDisplay()
    end, true)

    self.frame.resizer = CreateFrame("Button", nil, self.frame)
    self.frame.resizer:SetSize(12, 12)
    self.frame.resizer:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT + 12)
    self.frame.resizer:SetNormalTexture(TEXTURES .. "SizeGrabber-Up")
    self.frame.resizer:GetNormalTexture():SetAlpha(0.3)
    self.frame.resizer:HookScript("OnEnter", function() SetCursor([[Interface\Cursor\UI-Cursor-SizeRight]]) end)
    self.frame.resizer:HookScript("OnLeave", function() SetCursor(nil) end)
    self.frame.resizer:HookScript("OnMouseDown", function()
        self.frame.resizing = true
        self.frame:StartSizing("RIGHT")
    end)
    self.frame.resizer:HookScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        Addon.db.profile.SoundQueueUI.CinematicWidth = self.frame:GetWidth()
        self.frame.resizing = nil
        Layout()
    end)
    self.frame:HookScript("OnSizeChanged", function()
        if self.frame.portrait then Layout() end
    end)
end

-- Pause lives on the header in both portrait modes, so no separate mini frame.
function SoundQueueUI:InitPortraitLine() end

function SoundQueueUI:InitPortrait()
    InitPortrait(self)
    local portrait = self.frame.portrait
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT")
    portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    -- Keep the whole portrait stack above the overlapping dialogue panel.
    local portraitLevel = math.max(self.frame.background:GetFrameLevel(), self.frame.container:GetFrameLevel()) + 3
    portrait:SetFrameLevel(portraitLevel)
    portrait.model:SetFrameLevel(portraitLevel + 1)
    portrait.pause:SetFrameLevel(portraitLevel + 2)
    portrait.border:SetFrameLevel(portraitLevel + 3)
    portrait.background:Hide()

    -- Opaque black circle made from native solid textures. The existing disc
    -- has translucent pixels; 1.12 cannot apply a circular texture mask.
    portrait.blackBackground = {}
    local radius = PORTRAIT_SIZE / 2 - 2
    for y = -radius, radius - 1 do
        local edge = math.max(math.abs(y), math.abs(y + 1))
        local width = 2 * math.sqrt(math.max(0, radius * radius - edge * edge))
        if width > 0 then
            local strip = portrait:CreateTexture(nil, "BACKGROUND")
            strip:SetTexture(0, 0, 0, 1)
            strip:SetPoint("CENTER", portrait, "CENTER", 0, y + 0.5)
            strip:SetWidth(width)
            strip:SetHeight(1)
            table.insert(portrait.blackBackground, strip)
        end
    end
    portrait.border.texture:ClearAllPoints()
    portrait.border.texture:SetAllPoints()
    portrait.border.texture:SetTexture(TEXTURES .. "CinematicPortraitRing")
    portrait.border.texture:SetTexCoord(0, 1, 0, 1)
    portrait.book:ClearAllPoints()
    portrait.book:SetPoint("CENTER")
    portrait.book:SetSize(48, 48)
    portrait.pause.background:SetTexture(TEXTURES .. "CinematicDisc")
    portrait.imageFrame = CreateFrame("Frame", nil, portrait)
    portrait.imageFrame:SetAllPoints()
    portrait.imageFrame:SetFrameLevel(portrait.pause:GetFrameLevel() - 1)
    function portrait:Configure(soundData)
        if soundData and not soundData.portraitTexture then
            SoundQueueUI:CapturePortrait(soundData)
        end
        local image = soundData and soundData.portraitTexture
        if self.activeImage and self.activeImage ~= image then self.activeImage:Hide() end
        self.activeImage = image
        self.model:Hide()
        if soundData and soundData.modelFrame then soundData.modelFrame:Hide() end
        self.book:SetShown(soundData ~= nil and image == nil)
        if image then image:Show() end
    end
end

function SoundQueueUI:InitMover()
    self.frame.mover = CreateFrame("Button", nil, self.frame.container)
    self.frame.mover:SetFrameLevel(self.frame.container:GetFrameLevel())
    self.frame.mover:HookScript("OnEnter", function(self)
        if Addon.db.profile.SoundQueueUI.LockFrame then return end
        SetCursor([[Interface\Cursor\UI-Cursor-Move]])
    end)
    self.frame.mover:HookScript("OnLeave", function() SetCursor(nil) end)
    self.frame.mover:HookScript("OnMouseDown", function()
        if not Addon.db.profile.SoundQueueUI.LockFrame then self.frame:StartMoving() end
    end)
    self.frame.mover:HookScript("OnMouseUp", function() self.frame:StopMovingOrSizing() end)
    -- Playback buttons remain above the invisible drag area.
    for _, button in ipairs({ self.frame.pause, self.frame.skip, self.frame.disclosure }) do
        button:SetFrameLevel(self.frame.container:GetFrameLevel() + 2)
    end
end

Layout = function()
    local frame = SoundQueueUI.frame
    if not frame or not frame.portrait or frame.layingOut then return end
    frame.layingOut = true
    local config = Addon.db.profile.SoundQueueUI
    local left = config.HidePortrait and 16 or 88
    local minWidth = config.HidePortrait and 220 or 280
    -- Old layout-cache sizes must not restore the previous fixed 340 width.
    -- Manual resizing remains possible and is remembered per profile.
    local requestedWidth = frame.resizing and frame:GetWidth() or (config.CinematicWidth or WIDTH)
    local width = math.max(minWidth, math.min(MAX_WIDTH, requestedWidth))
    if frame:GetWidth() ~= width then frame:SetWidth(width) end
    local container = frame.container
    frame.background:ClearAllPoints()
    frame.background:SetPoint("TOPLEFT", config.HidePortrait and 0 or PANEL_LEFT, -PANEL_TOP)
    frame.background:SetPoint("TOPRIGHT", 0, -PANEL_TOP)
    frame.background:SetHeight(PANEL_HEIGHT)
    container.name:ClearAllPoints()
    container.name:SetPoint("TOPLEFT", left, -22)
    container.name:SetWidth(math.max(1, width - left - 88 - RIGHT_PADDING))
    container.title:ClearAllPoints()
    container.title:SetPoint("TOPLEFT", left + 20, -45)
    container.title:SetWidth(math.max(1, width - left - 108 - RIGHT_PADDING))
    container.icon:ClearAllPoints()
    container.icon:SetPoint("TOPLEFT", left, -46)
    frame.disclosure:ClearAllPoints()
    frame.disclosure:SetPoint("TOPRIGHT", -3 - RIGHT_PADDING, -29)
    frame.skip:ClearAllPoints()
    frame.skip:SetPoint("TOPRIGHT", -22 - RIGHT_PADDING, -27)
    frame.pause:ClearAllPoints()
    frame.pause:SetPoint("TOPRIGHT", -54 - RIGHT_PADDING, -27)
    frame.queue:ClearAllPoints()
    -- The two-pixel seam overlaps the texture's transparent edge padding.
    frame.queue:SetPoint("TOPLEFT", frame.background, "BOTTOMLEFT", config.HidePortrait and 0 or QUEUE_LEFT - PANEL_LEFT, 2)
    frame.queue:SetPoint("TOPRIGHT", frame.background, "BOTTOMRIGHT", 0, 2)
    local rows = config.QueueExpanded and math.min(MAX_ROWS, SoundQueue:GetQueueSize()) or 0
    local queueHeight = math.max(1, rows * ROW_HEIGHT + 4)
    frame.queue:SetHeight(queueHeight)
    frame.queue.background:SetAllPoints()
    frame.queue:SetShown(rows > 0)
    local height = math.max(HEADER_HEIGHT, rows > 0 and PANEL_TOP + PANEL_HEIGHT - 2 + queueHeight or 0)
    local previousHeight = frame:GetHeight()
    local previousLeft, previousTop = frame:GetLeft(), frame:GetTop()
    frame:SetResizeBounds(minWidth, height, MAX_WIDTH, height)
    frame:SetHeight(height)
    -- Saved positions may be anchored at the bottom or center. Preserve the
    -- header's top edge so the queue grows downward rather than lifting it.
    if previousHeight ~= height and previousLeft and previousTop then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", previousLeft, previousTop)
    end
    if frame.mover then
        frame.mover:ClearAllPoints()
        frame.mover:SetPoint("TOPLEFT", config.HidePortrait and 0 or 82, -9)
        frame.mover:SetSize(math.max(1, width - (config.HidePortrait and 0 or 82) - 88 - RIGHT_PADDING), PANEL_HEIGHT)
    end
    for _, button in ipairs(container.buttons) do
        button.textWidget:SetWidth(math.max(1, width - (config.HidePortrait and 0 or QUEUE_LEFT) - 56))
    end
    frame.layingOut = nil
end

function SoundQueueUI:RefreshConfig()
    local config = Addon.db.profile.SoundQueueUI
    self.frame.portrait:SetShown(not config.HidePortrait)
    self.frame.mover:SetShown(not config.LockFrame)
    self.frame.resizer:SetShown(not config.LockFrame)
    self.frame:SetScale(config.FrameScale)
    self:UpdateSoundQueueDisplay()
    LibStub("LibDBIcon-1.0"):Refresh("VoiceOver", Addon.db.profile.MinimapButton.LibDBIcon)
end

function SoundQueueUI:CreateButton(i)
    local button = CreateFrame("Button", nil, self.frame.queue)
    self.frame.container.buttons[i] = button
    button:SetID(i)
    button:SetPoint("TOPLEFT", 8, -2 - (i - 1) * ROW_HEIGHT)
    button:SetPoint("TOPRIGHT", -8, -2 - (i - 1) * ROW_HEIGHT)
    button:SetHeight(ROW_HEIGHT)
    button.textWidget = button:CreateFontString(nil, "OVERLAY", "VoiceOverButtonFont")
    button.textWidget:SetPoint("LEFT", 22, 0)
    button.textWidget:SetWordWrap(false)
    button.iconWidget = button:CreateTexture(nil, "ARTWORK")
    button.iconWidget:SetPoint("LEFT", 0, 0)
    button.iconWidget:SetSize(14, 14)
    button.remove = button:CreateTexture(nil, "ARTWORK")
    button.remove:SetTexture(TEXTURES .. "SoundQueueBulletDelete")
    button.remove:SetPoint("RIGHT", -2, 0)
    button.remove:SetSize(12, 12)
    button.rule = button:CreateTexture(nil, "BACKGROUND")
    button.rule:SetTexture(1, 1, 1)
    button.rule:SetVertexColor(0.48, 0.36, 0.19, 0.25)
    button.rule:SetPoint("BOTTOMLEFT")
    button.rule:SetPoint("BOTTOMRIGHT")
    button.rule:SetHeight(1)
    function button:Configure(soundData)
        self.soundData = soundData
        self:Update()
    end
    function button:Update(pushed, hovered)
        if hovered ~= nil then self.hovered = hovered end
        if not self.soundData then self:Hide() return end
        self:Show()
        local isCurrent = self.soundData == SoundQueue:GetCurrentSound()
        self:EnableMouse(not isCurrent or SoundQueue:CanBePaused())
        self.textWidget:SetText(SoundTitle(self.soundData))
        self.textWidget:SetTextColor(0.94, 0.92, 0.86)
        QuestIcon(self.iconWidget, self.soundData)
        self.remove:SetShown(self.hovered and (not isCurrent or SoundQueue:CanBePaused()))
        self.rule:SetShown(self:GetID() < math.min(MAX_ROWS, SoundQueue:GetQueueSize()))
        self:SetAlpha(isCurrent and 1 or 0.85)
    end
    button:HookScript("OnEnter", function(self)
        self:Update(nil, true)
        Tooltip(self, SoundTitle(self.soundData) .. "\nClick to remove from the queue")
    end)
    button:HookScript("OnLeave", function(self) self:Update(nil, false) GameTooltip_Hide() end)
    button:HookScript("OnClick", function(self)
        if self.soundData then SoundQueue:RemoveSoundFromQueue(self.soundData) end
    end)
    return button
end

function SoundQueueUI:UpdateSoundQueueDisplay()
    local current = SoundQueue:GetCurrentSound()
    self.frame:SetShown(not Addon.db.profile.SoundQueueUI.HideFrame and current ~= nil)
    self.frame.container.name:SetText(current and current.name or "")
    self.frame.container.title:SetText(SoundTitle(current))
    self.frame.container.icon:SetShown(current ~= nil)
    if current then QuestIcon(self.frame.container.icon, current) end
    self.frame.portrait:Configure(current)
    for i = 1, math.min(MAX_ROWS, SoundQueue:GetQueueSize()) do
        local button = self.frame.container.buttons[i] or self:CreateButton(i)
        button:Configure(SoundQueue.sounds[i])
    end
    for i = SoundQueue:GetQueueSize() + 1, getn(self.frame.container.buttons) do
        self.frame.container.buttons[i]:Configure(nil)
    end
    local expanded = Addon.db.profile.SoundQueueUI.QueueExpanded
    local glyph = expanded and "Collapse" or "Expand"
    SetGlyph(self.frame.disclosure:GetNormalTexture(), glyph)
    SetGlyph(self.frame.disclosure:GetPushedTexture(), glyph)
    self.frame.disclosure.tooltip = expanded and "Hide VoiceOver Queue" or "Show VoiceOver Queue"
    self:UpdatePauseDisplay()
    Layout()
end

function SoundQueueUI:UpdatePauseDisplay()
    local glyph = Addon.db.char.IsPaused and "Play" or "Pause"
    SetGlyph(self.frame.pause:GetNormalTexture(), glyph)
    SetGlyph(self.frame.pause:GetPushedTexture(), glyph)
    self.frame.pause.tooltip = Addon.db.char.IsPaused and "Resume Audio" or "Pause Audio"
    self.frame.skip.tooltip = SoundQueue:CanBePaused() and "Skip VoiceOver" or "Skip Pending VoiceOvers"
    self.frame.portrait.pause:Update()
end
