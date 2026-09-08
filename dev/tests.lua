-- BiSTheme / dev / tests.lua -- headless checks for the palette and the BiS> prompt
--   cd BiSTheme && lua5.1 dev/tests.lua
local now = 1000
_G.GetTime = function() return now end
_G.STANDARD_TEXT_FONT = "font"
_G.RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 } }

local function FontString()
  local s = {}
  function s:SetFont(_, size) self.size = size end
  function s:SetText(x) self.text = x end
  function s:GetText() return self.text end
  function s:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
  function s:GetStringWidth()
    local t, tex = tostring(self.text or ""), 0
    t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * (self.size or 9) * 0.6 + tex
  end
  return s
end
_G.CreateFrame = function() return { SetBackdrop = function() end, SetBackdropColor = function() end, SetBackdropBorderColor = function() end } end

local n, fails = 0, 0
local function ok(c, msg, ...)
  n = n + 1
  if c then return end
  fails = fails + 1
  print("FAIL: " .. msg, ...)
end
local function plain(fs) return (tostring(fs:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- 1. embedded copy alone: the palette fallback stands in
assert(loadfile("Console.lua"))()
local T = BiSTheme
ok(T.CONSOLE_MINOR == 2 and T.rgb and T.text, "Console.lua alone brings a palette fallback")
local r, g, b = T.rgb("accent")
ok(math.abs(r - 0xb9 / 255) < 1e-6, "fallback accent is the BiS purple")

-- 2. the real BiSTheme.lua after it: same palette, its own helpers win
BiSTheme = nil
assert(loadfile("BiSTheme.lua"))()
assert(loadfile("Console.lua"))()
T = BiSTheme
ok(T.skin and T.pctColor and T.classRGB, "BiSTheme.lua helpers present")
ok(T.CONSOLE and T.Console and T.Fit, "console API present")
local minor = T.CONSOLE_MINOR
T.CONSOLE.cycle = 99
assert(loadfile("Console.lua"))()
ok(T.CONSOLE_MINOR == minor and T.CONSOLE.cycle == 99, "loading the same minor again is a no-op (guard)")
T.CONSOLE.cycle = 3
ok(select(1, T.classRGB("SHAMAN")) == 0, "classRGB reads Blizzard's table")

-- 3. Fit
local fs = FontString() fs:SetFont(nil, 8)
ok(T.Fit(fs, "short", 100) == "short", "Fit leaves a fitting label alone")
local t = T.Fit(fs, "a label far too long for its little box", 40)
ok(t:find("%.%.%.$") and fs:GetStringWidth() <= 40, "Fit trims with an ellipsis until it fits", t)

-- 4. the prompt: slots rotate, events jump in and hold, cursor blinks, width kept
local title = FontString() title:SetFont(nil, 8)
local con = T.Console(title, { width = 106 })
ok(plain(title):find("^BiS> [_ ]$"), "empty prompt is BiS> and the cursor", plain(title))
con:Set("name", "Summon", "accent")
ok(plain(title):find("^BiS> Summon[_ ]$"), "one slot shows at once", plain(title))
con:Set("stone", "2 at stone", "good")
ok(plain(title):find("Summon", 1, true), "a new slot waits its turn")
now = now + 3 con:Paint()
ok(plain(title):find("2 at stone", 1, true), "after a cycle the next slot", plain(title))
now = now + 3 con:Paint()
ok(plain(title):find("Summon", 1, true), "round again", plain(title))
con:Set("stone", nil)
now = now + 3 con:Paint()
ok(plain(title):find("Summon", 1, true), "a cleared slot leaves the rotation", plain(title))
con:Say("Druid asks", "gold")
ok(plain(title):find("Druid asks", 1, true) and con.line.colour == "gold", "Say jumps in, keeps its colour")
con:Say("Druid accepted", "good")
ok(plain(title):find("Druid asks", 1, true) and #con.queue == 1, "a second Say queues")
now = now + 3 con:Paint()
ok(plain(title):find("Druid accepted", 1, true), "shows after the hold")
now = now + 3 con:Paint()
ok(plain(title):find("Summon", 1, true), "then the slots resume")
now = now + 0.5 con:Paint() local c1 = plain(title):sub(-1)
now = now + 0.5 con:Paint() local c2 = plain(title):sub(-1)
ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks at 2 Hz", c1, c2)
con:Say("Averyveryverylongname accepted the summon")
ok(title:GetStringWidth() <= 106 and plain(title):find("%.%.%.[_ ]$"), "a long line is trimmed and the cursor survives", plain(title))
ok(title:GetText():find("|cff", 1, true) and select(2, title:GetText():gsub("|r", "")) == 2, "colour escapes stay whole after the trim")
con:Clear() now = now + 3 con:Paint()
ok(#con.queue == 0 and plain(title):find("Summon", 1, true), "Clear drops the queue")

if fails > 0 then error(fails .. " failed of " .. n) end
print("ALL OK (" .. n .. " checks)")
