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
