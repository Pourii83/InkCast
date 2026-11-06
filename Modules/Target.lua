-- Target cast bar
-- The 1.12 client exposes no other unit's casts; this needs SuperWoW's UNIT_CASTEVENT.

local OC = InkCast
local mod = OC:NewModule("target", "Target")

local casts = {}

local function Prune(now)
  for guid, c in pairs(casts) do
    if c.finish < now - 1 then casts[guid] = nil end
  end
end

local function TargetGUID()
  local _, guid = UnitExists("target")
  return guid
end

function mod:OnEnable()
  if not SUPERWOW_VERSION then
    OC:Print("Target cast bar needs SuperWoW; it stays inactive without it.")
    return
  end
  self.bar:RegisterEvent("UNIT_CASTEVENT")
  self.bar:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function mod:Refresh()
  local bar = self.bar
  if bar.unlocked then return end
  local guid = TargetGUID()
  local c = guid and casts[guid]
  if c and c.finish > GetTime() then
    local colors = OC.db.colors
    self.current = c
    bar:SetColor(c.channel and colors.channel or colors.target)
    bar.text:SetText(c.name)
    bar:SetIcon(c.icon)
    bar:Begin()
    self:OnUpdate()
  else
    self.current = nil
    if bar.active then bar:Finish(false) end
  end
end

function mod:EndCurrent(color, text)
  local bar = self.bar
  self.current = nil
  if not bar.active then return end
  bar:SetProgress(1)
  bar:SetColor(color)
  if text then bar.text:SetText(text) end
  bar:ClearTime()
  bar:Finish(true)
end

function mod:UNIT_CASTEVENT()
  local caster, kind, spellId, duration = arg1, arg3, arg4, arg5
  local now = GetTime()
  local isTarget = caster == TargetGUID()

  if kind == "START" or kind == "CHANNEL" then
    if not duration or duration <= 0 then return end
    Prune(now)
    local name, _, icon = SpellInfo(spellId)
    casts[caster] = {
      name = name or "?", icon = icon, start = now,
      finish = now + duration / 1000, channel = kind == "CHANNEL",
    }
    if isTarget then self:Refresh() end
  elseif kind == "CAST" then
    local c = casts[caster]
    if c and not c.channel then
      casts[caster] = nil
      if isTarget and self.current == c then self:EndCurrent(OC.db.colors.success) end
    end
  elseif kind == "FAIL" then
    local c = casts[caster]
    if c then
      casts[caster] = nil
      if isTarget and self.current == c then
        self:EndCurrent(OC.db.colors.failed, INTERRUPTED or "Interrupted")
      end
    end
  end
end

function mod:PLAYER_TARGET_CHANGED()
  self:Refresh()
end

function mod:OnUpdate()
  local c = self.current
  if not c then
    self.bar:Finish(false)
    return
  end
  local now = GetTime()
  local left = c.finish - now
  if left <= 0 then
    -- channels end on their own; casts wait briefly for the CAST event
    if c.channel or left < -0.5 then
      self.current = nil
      self.bar:Finish(true)
    end
    return
  end
  local total = c.finish - c.start
  local value = now - c.start
  if c.channel then value = left end
  self.bar:SetProgress(value / total)
  if self.db.showTimer then
    self.bar:SetTime(value, total)
  else
    self.bar:ClearTime()
  end
end
