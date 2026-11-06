-- Global cooldown bar

local OC = InkCast
local mod = OC:NewModule("gcd", "GCD")

-- index of a spellbook spell known to show the GCD, so we rarely rescan
local refIndex

local function CheckSpell(i)
  local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
  if start and start > 0 and duration and duration > 0 and duration <= 1.5 then
    return start, duration
  end
end

local function FindGCD()
  if refIndex then
    local start, duration = CheckSpell(refIndex)
    if start then return start, duration end
  end
  local i = 1
  while GetSpellName(i, BOOKTYPE_SPELL) do
    local start, duration = CheckSpell(i)
    if start then
      refIndex = i
      return start, duration
    end
    i = i + 1
  end
end

function mod:OnEnable()
  self.bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  self.bar:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  self.bar:RegisterEvent("SPELLS_CHANGED")
end

function mod:SPELL_UPDATE_COOLDOWN()
  local bar = self.bar
  if bar.unlocked then return end
  local start, duration = FindGCD()
  if not start or start == self.start then return end
  self.start, self.duration = start, duration
  bar:SetColor(OC.db.colors.gcd)
  bar.text:SetText("")
  bar.timer:SetText("")
  bar:SetProgress(0)
  bar:Begin()
end

mod.ACTIONBAR_UPDATE_COOLDOWN = mod.SPELL_UPDATE_COOLDOWN

function mod:SPELLS_CHANGED()
  refIndex = nil
end

function mod:OnUpdate()
  if not self.start then return end
  local v = (GetTime() - self.start) / self.duration
  if v >= 1 then
    self.bar:Finish(false)
    return
  end
  self.bar:SetProgress(v)
end
