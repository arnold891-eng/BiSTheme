-- BiSTheme / dev / tests.lua -- headless checks for the palette and the BiS> prompt
--   cd BiSTheme && lua5.1 dev/tests.lua
local now = 1000
_G.GetTime = function() return now end
_G.STANDARD_TEXT_FONT = "font"
_G.RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 } }

local parent
local function FontString()
  local s = { alpha = 1 }
  function s:GetParent() return parent end
  function s:SetPoint(...) self.point = { ... } end
  function s:SetAlpha(a) self.alpha = a end
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
parent = { CreateFontString = function() return FontString() end }
_G.CreateFrame = function() return { SetBackdrop = function() end, SetBackdropColor = function() end, SetBackdropBorderColor = function() end } end

local n, fails = 0, 0
local function ok(c, msg, ...)
  n = n + 1
  if c then return end
  fails = fails + 1
  print("FAIL: " .. msg, ...)
end
local function plain(c) return (tostring(c:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- move the clock and let a fade finish: dt, then the two fade legs
local function adv(c, dt) now = now + dt c:Paint() now = now + 0.3 c:Paint() now = now + 0.3 c:Paint() end

-- 1. embedded copy alone: the palette fallback stands in
assert(loadfile("Console.lua"))()
local T = BiSTheme
ok(T.CONSOLE_MINOR == 3 and T.rgb and T.text, "Console.lua alone brings a palette fallback (minor 3)")
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

-- 4. the prompt: slots rotate, events jump in and hold, cursor blinks, width kept,
--    words fade out and in (Arn: "fade in and out animations, not hard cuts")
local title = FontString() title:SetFont(nil, 8)
local con = T.Console(title, { width = 106 })
ok(con.words and con.words.point[2] == title, "the words are their own FontString, anchored to the title")
ok(plain(con):find("^BiS> [_ ]$"), "empty prompt is BiS> and the cursor", plain(con))
con:Set("name", "Summon", "accent")
ok(con.fading == "out" and not plain(con):find("Summon", 1, true), "new words: the old ones fade out first, no hard cut")
now = now + 0.1 con:Paint()
ok(con.words.alpha > 0 and con.words.alpha < 1, "alpha on the way down", con.words.alpha)
now = now + 0.2 con:Paint()
ok(con.words.alpha == 0 and con.fading == "in" and plain(con):find("Summon", 1, true), "at zero the words swap and start coming up")
now = now + 0.1 con:Paint()
ok(con.words.alpha > 0 and con.words.alpha < 1, "alpha on the way up", con.words.alpha)
now = now + 0.2 con:Paint()
ok(con.words.alpha == 1 and not con.fading, "solid")
ok(plain(con):find("^BiS> Summon[_ ]$"), "one slot shows at once", plain(con))
ok(title:GetText() == T.text("accent", "BiS> "), "the prompt itself never changes")
con:Set("stone", "2 at stone", "good")
now = now + 0.6 con:Paint()
ok(plain(con):find("Summon", 1, true), "a new slot waits its turn")
adv(con, 3)
ok(plain(con):find("2 at stone", 1, true), "after a cycle the next slot", plain(con))
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "round again", plain(con))
con:Set("stone", nil)
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "a cleared slot leaves the rotation", plain(con))
-- the order quirk (minor 3): clear + set again must not append the key twice. With two
-- live slots the rotation is exactly Summon, stone, Summon, stone - a duplicate key would
-- show stone twice in a row and stretch #order every toggle.
for _ = 1, 5 do con:Set("stone", nil) con:Set("stone", "2 at stone", "good") end
ok(#con.order == 2, "toggling a slot five times leaves order at 2 keys", #con.order)
local seen = {}
for _ = 1, 4 do adv(con, 3) seen[#seen + 1] = plain(con):find("Summon", 1, true) and "S" or "T" end
ok(table.concat(seen) == "STST" or table.concat(seen) == "TSTS", "and the rotation alternates, no slot hogs it", table.concat(seen))
con:Set("stone", nil)
adv(con, 3)
con:Say("Druid asks", "gold")
adv(con, 0)
ok(plain(con):find("Druid asks", 1, true) and con.line.colour == "gold", "Say jumps in, keeps its colour")
con:Say("Druid accepted", "good")
ok(plain(con):find("Druid asks", 1, true) and #con.queue == 1, "a second Say queues")
adv(con, 3)
ok(plain(con):find("Druid accepted", 1, true), "shows after the hold")
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "then the slots resume")
now = now + 0.5 con:Paint() local c1 = plain(con):sub(-1)
now = now + 0.5 con:Paint() local c2 = plain(con):sub(-1)
ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks at 2 Hz", c1, c2)
con:Say("Averyveryverylongname accepted the summon")
adv(con, 0)
ok(con:Width() <= 106 and plain(con):find("%.%.%.[_ ]$"), "a long line is trimmed and the cursor survives", plain(con))
ok(con.words:GetText():find("|cff", 1, true) and select(2, con.words:GetText():gsub("|r", "")) == 1, "colour escapes stay whole after the trim")
con:Clear() adv(con, 3)
ok(#con.queue == 0 and plain(con):find("Summon", 1, true), "Clear drops the queue")

if fails > 0 then error(fails .. " failed of " .. n) end
print("ALL OK (" .. n .. " checks)")
