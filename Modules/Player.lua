-- Player cast bar with latency, pushback and channel support

local OC = OctoCast
local mod = OC:NewModule("player", "Player")

local BLIZZARD_EVENTS = {
  "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED",
  "SPELLCAST_DELAYED", "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_UPDATE",
  "SPELLCAST_CHANNEL_STOP",
}

-- The 1.12 client has no UNIT_SPELLCAST_SENT, so we time casts from the
-- moment a spell is requested until the server answers with SPELLCAST_START.
local sendTime, sendTexture

local function MarkSent(texture)
  if mod.casting or mod.channeling then return end
  sendTime = GetTime()
  sendTexture = texture
end

local origCastSpell = CastSpell
function CastSpell(id, book)
  if id and book then MarkSent(GetSpellTexture(id, book)) end
  return origCastSpell(id, book)
end

local origCastSpellByName = CastSpellByName
function CastSpellByName(name, onSelf)
  MarkSent(nil)
  return origCastSpellByName(name, onSelf)
end

local origUseAction = UseAction
function UseAction(slot, checkCursor, onSelf)
  MarkSent(GetActionTexture(slot))
  return origUseAction(slot, checkCursor, onSelf)
end

local function TakeLatency()
  local lag, texture
  if sendTime and GetTime() - sendTime < 1.5 then
    lag, texture = GetTime() - sendTime, sendTexture
  else
    local _, _, ms = GetNetStats()
    lag = (ms or 0) / 1000
  end
  sendTime, sendTexture = nil, nil
  return lag, texture
end

local iconCache = {}

local function SpellIcon(name)
  local cached = iconCache[name]
  if cached ~= nil then return cached or nil end
  local i = 1
  while true do
    local spell = GetSpellName(i, BOOKTYPE_SPELL)
    if not spell then break end
    if spell == name then
      iconCache[name] = GetSpellTexture(i, BOOKTYPE_SPELL)
      return iconCache[name]
    end
    i = i + 1
  end
  iconCache[name] = false
  return nil
end

function mod:OnEnable()
  for _, e in ipairs(BLIZZARD_EVENTS) do self.bar:RegisterEvent(e) end
  self.bar:RegisterEvent("SPELLS_CHANGED")
  if SUPERWOW_VERSION then self.bar:RegisterEvent("UNIT_CASTEVENT") end
  if self.db.hideBlizzard then
    CastingBarFrame:UnregisterAllEvents()
    CastingBarFrame:Hide()
  end
end

function mod:OnDisable()
  self.casting, self.channeling, self.testing = nil, nil, nil
  if self.db.hideBlizzard then
    for _, e in ipairs(BLIZZARD_EVENTS) do CastingBarFrame:RegisterEvent(e) end
  end
end

function mod:StartBar(name, duration, channel)
  local bar = self.bar
  if bar.unlocked then return end
  local colors = OC.db.colors
  local lag, texture = TakeLatency()
  local now = GetTime()

  self.startTime = now
  self.endTime = now + duration
  self.duration = duration
  self.delay = 0
  self.casting = not channel
  self.channeling = channel
  self.fromCastEvent = nil

  bar:SetColor(channel and colors.channel or colors.cast)
  bar.text:SetText(name)
  bar:SetIcon(SpellIcon(name) or texture)
  if self.db.showLatency and duration > 0 then
    bar:SetLatency(lag / duration, channel and "LEFT" or "RIGHT")
  else
    bar:SetLatency(nil)
  end
  bar:SetProgress(channel and 1 or 0)
  if channel then self:SetTimer(duration, duration) else self:SetTimer(0, duration) end
  bar:Begin()
end

-- casts show elapsed/total, channels show remaining/total (matching the draining bar)
function mod:SetTimer(value, total)
  if self.db.showTimer then
    self.bar:SetTime(value, total, self.delay)
  else
    self.bar:ClearTime()
  end
end

function mod:Succeed()
  local bar = self.bar
  self.casting, self.testing = nil, nil
  bar:SetProgress(1)
  bar:SetColor(OC.db.colors.success)
  bar:ClearTime()
  bar:Finish(true)
end

function mod:Fail(text)
  local bar = self.bar
  if bar.unlocked or self.channeling or not bar:IsShown() then return end
  self.casting, self.testing = nil, nil
  bar:SetProgress(1)
  bar:SetColor(OC.db.colors.failed)
  bar:SetLatency(nil)
  bar.text:SetText(text)
  bar:ClearTime()
  bar:Finish(true)
end

function mod:Test()
  if not self.enabled then
    OC:Print("Player bar is disabled (/ocast player on).")
    return
  end
  sendTime, sendTexture = GetTime() - 0.15, "Interface\\Icons\\Spell_Nature_Lightning"
  self:StartBar("OctoCast Test", 2.5, false)
  self.testing = true
end

function mod:OnUpdate()
  local now = GetTime()
  if self.casting then
    -- SPELLCAST_STOP normally ends the cast; the timeout guards against a missed event
    if now >= self.endTime and (self.testing or now >= self.endTime + 0.5) then
      self:Succeed()
      return
    end
    self.bar:SetProgress((now - self.startTime) / (self.endTime - self.startTime))
    self:SetTimer(now - self.startTime, self.endTime - self.startTime)
  elseif self.channeling then
    local left = self.endTime - now
    if left <= 0 then
      self.channeling = nil
      self.bar:Finish(true)
      return
    end
    self.bar:SetProgress(left / self.duration)
    self:SetTimer(left, self.duration)
  end
end

function mod:SPELLCAST_START()
  -- already started from SuperWoW's event for this same cast
  if self.casting and self.fromCastEvent and GetTime() - self.startTime < 0.5 then
    self.fromCastEvent = nil
    return
  end
  self.testing = nil
  self:StartBar(arg1, arg2 / 1000, false)
end

function mod:SPELLCAST_STOP()
  if self.casting and not self.testing then self:Succeed() end
end

function mod:SPELLCAST_FAILED()
  self:Fail(FAILED or "Failed")
end

function mod:SPELLCAST_INTERRUPTED()
  self:Fail(INTERRUPTED or "Interrupted")
end

function mod:SPELLCAST_DELAYED()
  if not self.casting then return end
  local delay = arg1 / 1000
  self.endTime = self.endTime + delay
  self.delay = self.delay + delay
end

function mod:SPELLCAST_CHANNEL_START()
  self.testing = nil
  self:StartBar(arg2, arg1 / 1000, true)
end

function mod:SPELLCAST_CHANNEL_UPDATE()
  if not self.channeling then return end
  if arg1 == 0 then
    self:SPELLCAST_CHANNEL_STOP()
    return
  end
  local newEnd = GetTime() + arg1 / 1000
  if newEnd < self.endTime then self.delay = self.delay + (self.endTime - newEnd) end
  self.endTime = newEnd
end

function mod:SPELLCAST_CHANNEL_STOP()
  if not self.channeling then return end
  self.channeling = nil
  self.bar:Finish(true)
end

function mod:SPELLS_CHANGED()
  iconCache = {}
end

-- Some casts (e.g. Aimed Shot) don't fire SPELLCAST_START on the 1.12 client;
-- SuperWoW's UNIT_CASTEVENT still reports them, so use it as a fallback.
function mod:UNIT_CASTEVENT()
  local _, guid = UnitExists("player")
  if arg1 ~= guid then return end
  if arg3 == "START" then
    if not arg5 or arg5 <= 0 then return end
    if self.casting and not self.testing and GetTime() - self.startTime < 0.5 then return end
    local name, _, icon = SpellInfo(arg4)
    if not name then return end
    self.testing = nil
    if icon then sendTexture = sendTexture or icon end
    self:StartBar(name, arg5 / 1000, false)
    self.fromCastEvent = true
  elseif self.casting and self.fromCastEvent then
    if arg3 == "CAST" then
      self:Succeed()
    elseif arg3 == "FAIL" then
      self:Fail(INTERRUPTED or "Interrupted")
    end
  end
end
