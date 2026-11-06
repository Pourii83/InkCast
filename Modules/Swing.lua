-- Swing timer: main-hand melee plus ranged Auto Shot / wand Shoot
-- Uses SuperWoW's UNIT_CASTEVENT when available, otherwise the combat log.

local OC = InkCast
local mod = OC:NewModule("swing", "Swing")

local AUTO_SHOT_ID, SHOOT_ID = 75, 5019
local RANGED_NAMES = { "Auto Shot", "Shoot" }

function mod:OnEnable()
  local bar = self.bar
  if SUPERWOW_VERSION then
    bar:RegisterEvent("UNIT_CASTEVENT")
  else
    bar:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    bar:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
    bar:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
  end
  bar:RegisterEvent("UNIT_ATTACK_SPEED")
  bar:RegisterEvent("UNIT_RANGEDDAMAGE")
end

local function RangedSpeed()
  return UnitRangedDamage("player")
end

function mod:Start(kind, speed)
  local bar = self.bar
  if bar.unlocked or not speed or speed <= 0 then return end
  self.kind, self.start, self.speed = kind, GetTime(), speed
  bar:SetColor(kind == "ranged" and OC.db.colors.ranged or OC.db.colors.swing)
  bar.text:SetText("")
  bar:SetProgress(0)
  bar:Begin()
end

function mod:Swing()
  self:Start("melee", UnitAttackSpeed("player"))
end

function mod:Shot()
  self:Start("ranged", RangedSpeed())
end

function mod:UNIT_CASTEVENT()
  local _, guid = UnitExists("player")
  if arg1 ~= guid then return end
  if arg3 == "MAINHAND" then
    self:Swing()
  elseif arg3 == "CAST" and (arg4 == AUTO_SHOT_ID or arg4 == SHOOT_ID) then
    self:Shot()
  end
end

mod.CHAT_MSG_COMBAT_SELF_HITS = mod.Swing
mod.CHAT_MSG_COMBAT_SELF_MISSES = mod.Swing

-- without SuperWoW the shot is seen when it lands, so the bar starts a little late
function mod:CHAT_MSG_SPELL_SELF_DAMAGE()
  for _, name in ipairs(RANGED_NAMES) do
    if string.find(arg1, name, 1, true) then
      self:Shot()
      return
    end
  end
end

-- keep the swing's progress when haste changes mid-swing
function mod:Rescale(speed)
  if not speed or speed <= 0 then return end
  local now = GetTime()
  local frac = (now - self.start) / self.speed
  self.speed = speed
  self.start = now - frac * speed
end

function mod:UNIT_ATTACK_SPEED()
  if arg1 == "player" and self.bar.active and self.kind == "melee" then
    self:Rescale(UnitAttackSpeed("player"))
  end
end

function mod:UNIT_RANGEDDAMAGE()
  if arg1 == "player" and self.bar.active and self.kind == "ranged" then
    self:Rescale(RangedSpeed())
  end
end

function mod:OnUpdate()
  if not self.start then return end
  local now = GetTime()
  local left = self.start + self.speed - now
  if left <= 0 then
    self.bar:Finish(false)
    return
  end
  self.bar:SetProgress((now - self.start) / self.speed)
  if self.db.showTimer then
    self.bar.timer:SetText(string.format("%.1f", left))
  else
    self.bar.timer:SetText("")
  end
end
