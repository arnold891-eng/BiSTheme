--[[
  BiSTheme — one palette for every BiS* addon.

  Taken from the Dreamscythe Loot Ledger page: a violet-biased near-black ground with the
  game's own epic purple as the single accent. Semantic colours (good / warn / highlight)
  are separate from the accent so the accent never has to mean anything.

  Usage from any addon:

      local T = BiSTheme
      frame:SetBackdropColor(T.rgb("surface"))
      frame:SetBackdropBorderColor(T.rgb("line2"))
      fontString:SetTextColor(T.rgb("ink"))
      fontString:SetText(T.text("accent", "Ready"))          -- |cff...|r wrapped
      local r, g, b, a = T.rgba("accent", 0.4)              -- with alpha
      local classR, classG, classB = T.classRGB("SHAMAN")   -- Blizzard's class colour

  Every colour is stored once as hex; rgb() converts on demand and caches.
]]

BiSTheme = BiSTheme or {}
local T = BiSTheme

-- Ground and text ---------------------------------------------------------------------
T.hex = {
  bg       = "121020",  -- window background
  surface  = "1a1730",  -- panels, rows, tooltips
  sunken   = "221d3c",  -- hover / selected row / input wells
  line     = "2a2446",  -- hairline dividers
  line2    = "3a3260",  -- borders, stronger dividers

  ink      = "ece8f6",  -- primary text
  ink2     = "c6bedd",  -- secondary text, numbers
  muted    = "968ead",  -- labels, captions, disabled

  -- Accent: the game's epic purple, lifted for a dark ground
  accent   = "b980ff",
  accentSoft = "2c2148", -- accent tint for selected backgrounds

  -- Semantic. These never share a hue with the accent.
  good     = "4fd0cf",  -- teal: healthy, present, done, ≥80%
  warn     = "f08cb0",  -- rose: low, missing, <40%, needs attention
  gold     = "e5c04a",  -- highlight: tier token, main spec, "you"
  slate    = "8fb4d6",  -- neutral info: offspec, secondary
  dim      = "8e86a6",  -- de-emphasised: disenchant, inactive

  -- Item quality, matched to the game but readable on this ground
  epic     = "c08cff",
  rare     = "5fa8f0",
  uncommon = "5fd06f",
  common   = "ece8f6",
  poor     = "8e86a6",
}

-- Light variant, for anyone who wants it (same roles, same hues) ------------------------
T.hexLight = {
  bg = "f6f4fa", surface = "ffffff", sunken = "efecf6", line = "e2dcef", line2 = "cfc6e4",
  ink = "191527", ink2 = "453d5e", muted = "6d6584",
  accent = "8b3fd6", accentSoft = "efe3fc",
  good = "0f7d7f", warn = "a3416b", gold = "9a7400", slate = "4a6b8a", dim = "7c7590",
  epic = "7b3fd4", rare = "1b63b5", uncommon = "1a7a2e", common = "191527", poor = "7c7590",
}

-- Helpers -----------------------------------------------------------------------------
local cache = {}

local function hexToRGB(hex)
  local c = cache[hex]
  if c then return c[1], c[2], c[3] end
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  cache[hex] = { r, g, b }
  return r, g, b
end

--- r, g, b for a named colour. Unknown names fall back to ink so nothing renders invisible.
function T.rgb(name)
  return hexToRGB(T.hex[name] or T.hex.ink)
end

--- r, g, b, a with an explicit alpha.
function T.rgba(name, alpha)
  local r, g, b = T.rgb(name)
  return r, g, b, alpha or 1
end

--- "|cffRRGGBBtext|r" for chat and fontstrings.
function T.text(name, s)
  return "|cff" .. (T.hex[name] or T.hex.ink) .. tostring(s) .. "|r"
end

--- Blizzard's class colour, as r, g, b. Falls back to ink for unknown tokens.
function T.classRGB(classToken)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  if c then return c.r, c.g, c.b end
  return T.rgb("ink")
end

--- Pick a semantic colour for a percentage: good ≥ 80, warn < 40, muted between.
function T.pctColor(pct)
  if pct == nil then return "muted" end
  if pct >= 80 then return "good" end
  if pct < 40 then return "warn" end
  return "ink2"
end

--- One-call backdrop for a plain panel. Pass the frame; optional border name.
function T.skin(frame, borderName)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(T.rgba("surface", 0.96))
  frame:SetBackdropBorderColor(T.rgb(borderName or "line2"))
end

-- =========================================================================
-- HARMONISING WITH EllesmereUI (28 Sep 2026)
--
-- Arn installed EllesmereUI 9.3 and asked what it takes to match it. Its
-- SKINNING_API.md offers two doors, and this is deliberately the smaller one.
--
-- The big door is S.Shell(frame): it alphas out every texture on the frame and
-- paints EUI's own backdrop underneath. That works on Blizzard-shaped windows,
-- whose contents are Blizzard widgets EUI also skins. Ours are not: the
-- background and the four borders sit on the frame (Options.lua), while the
-- header, the rows and the switches are child frames with their own art. Shell
-- would erase the first and leave the rest - EUI's backdrop behind BiSTheme's
-- innards - and BiS Healing would stop looking like the other six addons for
-- EUI users only.
--
-- The small door is the getters, which their own guidelines point at for
-- "custom elements you coloured yourself". We keep our shape and take two
-- things from the user's own settings: the accent they chose, and the UI font.
-- Our windows then sit BESIDE EUI's rather than pretending to be them.
--
-- IT GOES THROUGH RegisterSkin ANYWAY, even though no frame is handed over,
-- because that is what respects the user's own switch: EUI lets them turn
-- third-party skinning off per addon, and a callback that never runs is a
-- family that keeps its own purple. Reading the getters directly would work
-- and would ignore them.
-- =========================================================================

T.FONT = nil          -- the user's UI font while EUI is lending it; nil means the client's own

--- Things to redraw when the look changes under them. A window built before the
--- user moved EUI's accent slider is a window with the old purple in its textures.
local looksListeners = {}

function T.RegisterLooks(fn)
  if type(fn) ~= "function" then return false end
  looksListeners[#looksListeners + 1] = fn
  return true
end

function T.LooksChanged()
  for i = 1, #looksListeners do pcall(looksListeners[i]) end
  return #looksListeners
end

local function toHex(r, g, b)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
  return ("%02x%02x%02x"):format(
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
T.toHex = toHex

--- Take the accent and the font from EllesmereUI, if it is there and the user
--- allows it. Answers true when the registration was accepted - not that it has
--- run, which happens at PLAYER_LOGIN.
function T.AdoptEllesmereUI()
  if not (EllesmereUI and EllesmereUI.RegisterSkin) then return false, "no EllesmereUI" end
  T.ownAccent = T.ownAccent or T.hex.accent            -- to give back if it is ever switched off
  local accepted = EllesmereUI.RegisterSkin("BiSTheme", function(S)
    local function adopt()
      -- NOT CACHED ACROSS THE SESSION, per their guidelines: the accent and the
      -- font are live settings, and OnLooksChanged is how we hear about a change.
      -- WRITTEN OUT, NOT `S.f and S.f()`. That idiom is not a multi-value context: it keeps the
      -- FIRST return and drops the rest, so toHex got the red and two nils and the accent never
      -- moved. Third time this trap has cost us something - the header's regen number (23 Sep),
      -- the cells row's colour (26 Sep), and now this.
      local r, g, b
      if S.GetAccentColor then r, g, b = S.GetAccentColor() end
      local hex = toHex(r, g, b)
      if hex then T.hex.accent = hex end
      local path
      if S.GetFont then path = S.GetFont() end
      T.FONT = (type(path) == "string" and path ~= "") and path or nil
      T.adopted = true
      T.LooksChanged()
    end
    adopt()
    if S.OnLooksChanged then S.OnLooksChanged(adopt) end
  end)
  return accepted and true or false
end

--- The font a BiS window draws with: the user's while EUI is lending one, ours
--- otherwise. Handed a FontString it does the SetFont too, and falls back when
--- the path is refused - a FontString whose SetFont failed draws NOTHING, which
--- would be an invisible label rather than an ugly one.
function T.SetFont(fs, size, flags)
  local ok = false
  if T.FONT and fs and fs.SetFont then
    ok = pcall(fs.SetFont, fs, T.FONT, size, flags or "")
  end
  if not ok and fs and fs.SetFont then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
  return ok and T.FONT or STANDARD_TEXT_FONT
end

-- WHEN. BiSTheme loads before EllesmereUI - B before E - so the global is not there yet at file
-- scope, and asking then would answer "no EllesmereUI" on a machine that has it. PLAYER_LOGIN is
-- after every addon has loaded, and is also when EUI dispatches the callbacks it has queued.
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    T.AdoptEllesmereUI()
  end)
  T.looksFrame = f
end
