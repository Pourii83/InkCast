-- InkCast: Quartz-style cast bars for OctoWoW (1.12 client, Lua 5.0)

InkCast = {}
local OC = InkCast

OC.version = "0.1.0"
OC.modules = {}
OC.moduleOrder = {}

local FADE_TIME = 0.4
local FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

OC.textures = {
  smooth = "Interface\\AddOns\\InkCast\\Textures\\Smooth",
  gloss = "Interface\\AddOns\\InkCast\\Textures\\Gloss",
  minimal = "Interface\\AddOns\\InkCast\\Textures\\Minimal",
  banto = "Interface\\AddOns\\InkCast\\Textures\\Banto",
  blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
  flat = WHITE,
}

OC.defaults = {
  locked = true,
  texture = "smooth",
  player = {
    enabled = true, width = 260, height = 22,
    point = { "CENTER", "UIParent", "CENTER", 0, -180 },
    showIcon = true, showTimer = true, showLatency = true, hideBlizzard = true,
  },
  gcd = {
    enabled = true, width = 260, height = 4,
    point = { "CENTER", "UIParent", "CENTER", 0, -197 },
  },
  swing = {
    enabled = true, width = 260, height = 10,
    point = { "CENTER", "UIParent", "CENTER", 0, -208 },
    showTimer = true,
  },
  target = {
    enabled = true, width = 220, height = 18,
    point = { "CENTER", "UIParent", "CENTER", 0, -120 },
    showIcon = true, showTimer = true,
  },
  colors = {
    cast = { 1, 0.7, 0 },
    channel = { 0.3, 0.6, 1 },
    success = { 0.2, 0.9, 0.2 },
    failed = { 0.9, 0.1, 0.1 },
    latency = { 1, 0, 0, 0.6 },
    gcd = { 0.9, 0.9, 0.9 },
    swing = { 0.9, 0.8, 0.4 },
    ranged = { 0.55, 0.85, 0.35 },
    target = { 0.9, 0.3, 0.3 },
    unlocked = { 0.3, 0.3, 0.3 },
  },
}

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function OC:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99InkCast|r: " .. msg)
end

----------------------------------------------------------------------
-- Bar widget
----------------------------------------------------------------------

local Bar = {}

function Bar:ApplySettings()
  local cfg = self.cfg
  self:SetWidth(cfg.width)
  self:SetHeight(cfg.height)
  self:ClearAllPoints()
  local p = cfg.point
  self:SetPoint(p[1], UIParent, p[3], p[4], p[5])

  local texture = OC.textures[OC.db.texture] or OC.textures.smooth
  self.status:SetStatusBarTexture(texture)
  self.bg:SetTexture(texture)
  if self.color then self:SetColor(self.color) end

  local size = math.floor(cfg.height * 0.55)
  if size < 8 then size = 8 elseif size > 13 then size = 13 end
  self.text:SetFont(FONT, size)
  self.timer:SetFont(FONT, size)
  self.total:SetFont(FONT, math.max(7, size - 3))
  if cfg.height >= 10 then self.textFrame:Show() else self.textFrame:Hide() end

  -- icon sits outside the bar and matches the bar's outer height (border included)
  self.icon:SetWidth(cfg.height)
  self.icon:SetHeight(cfg.height)
  if not cfg.showIcon then self.icon:Hide() end

  self.spark:SetHeight(cfg.height * 2)
end

function Bar:SetColor(c)
  self.color = c
  self.status:SetStatusBarColor(c[1], c[2], c[3])
  self.bg:SetVertexColor(c[1] * 0.25, c[2] * 0.25, c[3] * 0.25)
end

function Bar:SetIcon(texture)
  if self.cfg.showIcon and texture then
    self.icon:SetTexture(texture)
    self.icon:Show()
  else
    self.icon:Hide()
  end
end

function Bar:SetProgress(v)
  if v < 0 then v = 0 elseif v > 1 then v = 1 end
  self.status:SetValue(v)
  if v > 0 and v < 1 then
    self.spark:ClearAllPoints()
    self.spark:SetPoint("CENTER", self.status, "LEFT", v * (self.cfg.width - 2), 0)
    self.spark:Show()
  else
    self.spark:Hide()
  end
end

-- frac: latency as a fraction of the bar; side: "RIGHT" for casts, "LEFT" for channels
function Bar:SetLatency(frac, side)
  local lat = self.latency
  if not frac or frac <= 0 then
    lat:Hide()
    return
  end
  if frac > 1 then frac = 1 end
  lat:ClearAllPoints()
  if side == "LEFT" then
    lat:SetPoint("TOPLEFT", self.status, "TOPLEFT")
    lat:SetPoint("BOTTOMLEFT", self.status, "BOTTOMLEFT")
  else
    lat:SetPoint("TOPRIGHT", self.status, "TOPRIGHT")
    lat:SetPoint("BOTTOMRIGHT", self.status, "BOTTOMRIGHT")
  end
  lat:SetWidth(frac * (self.cfg.width - 2))
  lat:Show()
end

-- "value/total" in the right corner, total in a smaller font
function Bar:SetTime(value, total, delay)
  if value < 0 then value = 0 end
  if delay and delay > 0 then
    self.timer:SetText(string.format("|cffff4444+%.1f|r %.1f", delay, value))
  else
    self.timer:SetText(string.format("%.1f", value))
  end
  self.total:SetText(string.format("/%.1f", total))
end

function Bar:ClearTime()
  self.timer:SetText("")
  self.total:SetText("")
end

function Bar:Begin()
  if self.unlocked then return end
  self.fadeLeft = nil
  self.active = true
  self:SetAlpha(1)
  self:Show()
end

function Bar:Finish(fade)
  if self.unlocked then return end
  self.active = nil
  self.spark:Hide()
  if fade and self:IsShown() then
    self.fadeLeft = FADE_TIME
  else
    self.fadeLeft = nil
    self:Hide()
  end
end

function Bar:SetUnlocked(flag)
  if flag then
    self.unlocked = true
    self.active = nil
    self.fadeLeft = nil
    self:EnableMouse(true)
    self:SetAlpha(1)
    self:SetColor(OC.db.colors.unlocked)
    self:SetProgress(1)
    self:SetLatency(nil)
    self.icon:Hide()
    self.text:SetText("InkCast: " .. self.label)
    self:ClearTime()
    self:Show()
  else
    self.unlocked = nil
    self:EnableMouse(false)
    self:Hide()
  end
end

function OC:CreateBar(key, label, mod)
  local cfg = self.db[key]
  local f = CreateFrame("Frame", "InkCastBar_" .. key, UIParent)
  for k, v in pairs(Bar) do f[k] = v end
  f.cfg = cfg
  f.label = label
  f.module = mod

  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(false)
  f:RegisterForDrag("LeftButton")
  local level = f:GetFrameLevel()

  -- soft dark halo behind a crisp 1px border
  local shadow = CreateFrame("Frame", nil, f)
  shadow:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
  shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
  shadow:SetFrameLevel(level)
  shadow:SetBackdrop({ bgFile = WHITE })
  shadow:SetBackdropColor(0, 0, 0, 0.3)

  local border = CreateFrame("Frame", nil, f)
  border:SetAllPoints(f)
  border:SetFrameLevel(level + 1)
  border:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  border:SetBackdropColor(0, 0, 0, 0)
  border:SetBackdropBorderColor(0, 0, 0, 1)

  local status = CreateFrame("StatusBar", nil, f)
  status:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  status:SetFrameLevel(level + 2)
  status:SetMinMaxValues(0, 1)
  status:SetValue(0)
  f.status = status

  local bg = status:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(status)
  bg:SetAlpha(0.85)
  f.bg = bg

  local lat = status:CreateTexture(nil, "OVERLAY")
  local lc = self.db.colors.latency
  lat:SetTexture(lc[1], lc[2], lc[3], lc[4])
  lat:Hide()
  f.latency = lat

  local spark = status:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  spark:SetWidth(12)
  spark:SetAlpha(0.8)
  spark:Hide()
  f.spark = spark

  local textFrame = CreateFrame("Frame", nil, status)
  textFrame:SetAllPoints(status)
  textFrame:SetFrameLevel(level + 4)
  f.textFrame = textFrame

  local text = textFrame:CreateFontString(nil, "OVERLAY")
  text:SetFont(FONT, 12, "OUTLINE")
  text:SetJustifyH("LEFT")
  f.text = text

  local total = textFrame:CreateFontString(nil, "OVERLAY")
  total:SetFont(FONT, 9, "OUTLINE")
  total:SetPoint("BOTTOMRIGHT", textFrame, "BOTTOMRIGHT", -3, 2)
  total:SetJustifyH("RIGHT")
  total:SetTextColor(0.75, 0.75, 0.75)
  f.total = total

  local timer = textFrame:CreateFontString(nil, "OVERLAY")
  timer:SetFont(FONT, 12, "OUTLINE")
  timer:SetPoint("RIGHT", total, "LEFT", 0, 0)
  timer:SetPoint("TOP", textFrame, "TOP", 0, 0)
  timer:SetPoint("BOTTOM", textFrame, "BOTTOM", 0, 0)
  timer:SetJustifyH("RIGHT")
  f.timer = timer

  text:SetPoint("LEFT", textFrame, "LEFT", 4, 0)
  text:SetPoint("RIGHT", timer, "LEFT", -4, 0)

  for _, fs in ipairs({ text, timer, total }) do
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
  end

  -- bordered icon frame; SetTexture forwards to the inner texture
  local icon = CreateFrame("Frame", nil, f)
  icon:SetPoint("RIGHT", f, "LEFT", -4, 0)
  icon:SetFrameLevel(level + 1)
  icon:SetBackdrop({ bgFile = WHITE })
  icon:SetBackdropColor(0, 0, 0, 1)
  local iconTex = icon:CreateTexture(nil, "ARTWORK")
  iconTex:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
  iconTex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon.SetTexture = function(self, texture) iconTex:SetTexture(texture) end
  icon:Hide()
  f.icon = icon

  f:SetScript("OnDragStart", function()
    if this.unlocked then this:StartMoving() end
  end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relPoint, x, y = this:GetPoint()
    this.cfg.point = { point, "UIParent", relPoint, x, y }
  end)
  f:SetScript("OnEvent", function()
    local handler = this.module[event]
    if handler then handler(this.module) end
  end)
  f:SetScript("OnUpdate", function()
    if this.unlocked then return end
    if this.fadeLeft then
      this.fadeLeft = this.fadeLeft - arg1
      if this.fadeLeft <= 0 then
        this.fadeLeft = nil
        this:Hide()
        this:SetAlpha(1)
      else
        this:SetAlpha(this.fadeLeft / FADE_TIME)
      end
      return
    end
    if this.module.OnUpdate then this.module:OnUpdate(arg1) end
  end)

  f:ApplySettings()
  f:Hide()
  return f
end

----------------------------------------------------------------------
-- Modules
----------------------------------------------------------------------

function OC:NewModule(key, label)
  local mod = { key = key, label = label }
  self.modules[key] = mod
  table.insert(self.moduleOrder, key)
  return mod
end

function OC:EnableModule(mod)
  if mod.enabled then return end
  mod.enabled = true
  mod.db.enabled = true
  if mod.OnEnable then mod:OnEnable() end
end

function OC:DisableModule(mod)
  if not mod.enabled then return end
  mod.enabled = nil
  mod.db.enabled = false
  mod.bar:UnregisterAllEvents()
  mod.bar:SetUnlocked(false)
  mod.bar:Finish(false)
  if mod.OnDisable then mod:OnDisable() end
end

function OC:SetLocked(locked)
  self.db.locked = locked
  for _, key in ipairs(self.moduleOrder) do
    local mod = self.modules[key]
    mod.bar:SetUnlocked(mod.enabled and not locked)
  end
end

function OC:Initialize()
  InkCastDB = CopyDefaults(self.defaults, InkCastDB)
  self.db = InkCastDB
  if not self.textures[self.db.texture] then self.db.texture = "smooth" end
  for _, key in ipairs(self.moduleOrder) do
    local mod = self.modules[key]
    mod.db = self.db[key]
    mod.bar = self:CreateBar(key, mod.label, mod)
    if mod.db.enabled then self:EnableModule(mod) end
  end
  if not self.db.locked then self:SetLocked(false) end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------

local function Help()
  OC:Print("v" .. OC.version .. " commands (/inkcast or /ink):")
  OC:Print("  unlock | lock  - move the bars")
  OC:Print("  test  - show a test cast on the player bar")
  OC:Print("  latency  - toggle latency display")
  OC:Print("  texture <name>  - smooth, gloss, minimal, banto, blizzard, flat")
  OC:Print("  <bar> on | off  - bar is player, gcd, swing or target")
  OC:Print("  <bar> width <n> | height <n>")
  OC:Print("  <bar> icon  - toggle spell icon")
  OC:Print("  reset  - reset all settings and reload")
end

function OC:SlashCommand(msg)
  local args = {}
  for word in string.gfind(string.lower(msg or ""), "%S+") do
    table.insert(args, word)
  end
  local cmd = args[1]

  if not cmd or cmd == "help" then
    Help()
  elseif cmd == "unlock" or cmd == "move" then
    self:SetLocked(false)
    self:Print("Bars unlocked. Drag them, then type /ink lock.")
  elseif cmd == "lock" then
    self:SetLocked(true)
    self:Print("Bars locked.")
  elseif cmd == "test" then
    self.modules.player:Test()
  elseif cmd == "latency" then
    self.db.player.showLatency = not self.db.player.showLatency
    self:Print("Latency display " .. (self.db.player.showLatency and "on" or "off") .. ".")
  elseif cmd == "texture" then
    if args[2] and self.textures[args[2]] then
      self.db.texture = args[2]
      for _, key in ipairs(self.moduleOrder) do self.modules[key].bar:ApplySettings() end
      self:Print("Texture set to " .. args[2] .. ".")
      if self.db.locked then self.modules.player:Test() end
    else
      self:Print("Textures: smooth, gloss, minimal, banto, blizzard, flat (now " .. self.db.texture .. ").")
    end
  elseif cmd == "reset" then
    InkCastDB = nil
    ReloadUI()
  elseif self.modules[cmd] then
    local mod = self.modules[cmd]
    local sub, value = args[2], tonumber(args[3])
    if sub == "on" then
      self:EnableModule(mod)
      mod.bar:SetUnlocked(not self.db.locked)
      self:Print(mod.label .. " bar enabled.")
    elseif sub == "off" then
      self:DisableModule(mod)
      self:Print(mod.label .. " bar disabled.")
    elseif (sub == "width" or sub == "height") and value and value > 0 then
      mod.db[sub] = value
      mod.bar:ApplySettings()
      self:Print(mod.label .. " " .. sub .. " set to " .. value .. ".")
    elseif sub == "icon" then
      mod.db.showIcon = not mod.db.showIcon
      mod.bar:ApplySettings()
      self:Print(mod.label .. " icon " .. (mod.db.showIcon and "on" or "off") .. ".")
    else
      Help()
    end
  else
    Help()
  end
end

SLASH_INKCAST1 = "/inkcast"
SLASH_INKCAST2 = "/ink"
SlashCmdList["INKCAST"] = function(msg) OC:SlashCommand(msg) end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if arg1 ~= "InkCast" then return end
  this:UnregisterEvent("ADDON_LOADED")
  OC:Initialize()
end)
