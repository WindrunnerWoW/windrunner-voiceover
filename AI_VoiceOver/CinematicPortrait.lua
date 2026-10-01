setfenv(1, VoiceOver)

-- Loaded after Compatibility.lua so wrapping the final legacy model functions
-- does not get overwritten. Native SetPortraitTexture has a circular alpha mask.
-- Capture each NPC while its dialog is open; keep that image with its queue item
-- rather than following the player's target after the conversation ends.
local portraitPool = {}
local CreateModel = Utils.CreateNPCModelFrame
local FreeModel = Utils.FreeNPCModelFrame

function SoundQueueUI:CapturePortrait(soundData)
    if soundData.portraitTexture or soundData.unitIsObjectOrItem then return end
    if not SetPortraitTexture or not UnitExists("npc") then return end
    if soundData.name and UnitName("npc") ~= soundData.name then return end
    local guidType = soundData.unitGUID and Utils:GetGUIDType(soundData.unitGUID)
    if guidType == Enums.GUID.Item or guidType == Enums.GUID.GameObject then return end

    local image
    for _, pooled in ipairs(portraitPool) do
        if not pooled.inUse then image = pooled break end
    end
    if not image then
        image = self.frame.portrait.imageFrame:CreateTexture(nil, "ARTWORK")
        image:SetPoint("CENTER")
        image:SetSize(74, 74)
        table.insert(portraitPool, image)
    end
    SetPortraitTexture(image, "npc")
    image.inUse = true
    image:Hide()
    soundData.portraitTexture = image
end

function SoundQueueUI:ReleasePortrait(soundData)
    local image = soundData.portraitTexture
    if not image then return end
    if self.frame.portrait.activeImage == image then self.frame.portrait.activeImage = nil end
    image:Hide()
    image:SetTexture(nil)
    image.inUse = nil
    soundData.portraitTexture = nil
end

function Utils:CreateNPCModelFrame(soundData)
    CreateModel(self, soundData)
    SoundQueueUI:CapturePortrait(soundData)
end

function Utils:FreeNPCModelFrame(soundData)
    SoundQueueUI:ReleasePortrait(soundData)
    FreeModel(self, soundData)
end
