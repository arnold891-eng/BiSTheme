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
  function s:GetAlpha() return self.alpha or 1 end
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
ok(T.CONSOLE_MINOR == 4 and T.rgb and T.text, "Console.lua alone brings a palette fallback (minor 4)")
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
-- minor 4: the blink is the cursor's OWN FontString going to alpha 0; the words
-- text is identical in both phases and never carries the "_" -- a swap inside
-- the words moved them a hair on the client every half second
now = now + 0.5 con:Paint() local w1, a1 = con.words:GetText(), con.cur:GetAlpha()
now = now + 0.5 con:Paint() local w2, a2 = con.words:GetText(), con.cur:GetAlpha()
ok(w1 == w2 and not w1:find("_", 1, true), "the words never change between blink phases", w1, w2)
ok((a1 == 0 and a2 == 1) or (a1 == 1 and a2 == 0), "the cursor FontString blinks by alpha", a1, a2)
ok(con.cur:GetText():find("_", 1, true) ~= nil, "the cursor FontString holds the underscore")
con:Say("Averyveryverylongname accepted the summon")
adv(con, 0)
ok(con:Width() <= 106 and plain(con):find("%.%.%.[_ ]$"), "a long line is trimmed and the cursor survives", plain(con))
ok(con.words:GetText():find("|cff", 1, true) and select(2, con.words:GetText():gsub("|r", "")) == 1, "colour escapes stay whole after the trim")
con:Clear() adv(con, 3)
ok(#con.queue == 0 and plain(con):find("Summon", 1, true), "Clear drops the queue")

-- 5. the minimap button, and the menu that replaced twenty-five slash commands.
--    A suite cannot see a button. It CAN see where the button put itself, which rows a click
--    would show, and whether picking one ran the right function - which is every bug this kind
--    of code has.
do
  local function auto(t)
    return setmetatable(t, { __index = function(_, k)
      if type(k) == "string" and k:match("^%u") then return function() end end
      return nil
    end })
  end
  local function Texture()
    return auto({ shown = true,
      SetColorTexture = function(s, r, g, b, a) s.colour = { r, g, b, a } end,
      SetTexture = function(s, t) s.file = t end,
      Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
      IsShown = function(s) return s.shown end })
  end
  local function Frame(kind, name, par)
    local f
    f = auto({ __kind = kind, __name = name, parent = par, points = {}, scripts = {},
               shown = false, enabled = true, w = 0, h = 0,
      CreateTexture = function() return Texture() end,
      CreateFontString = function()
        local s = FontString()
        s.shown = true
        s.Show = function(x) x.shown = true end
        s.Hide = function(x) x.shown = false end
        s.IsShown = function(x) return x.shown end
        return s
      end,
      SetScript = function(s, k, fn) s.scripts[k] = fn end,
      GetScript = function(s, k) return s.scripts[k] end,
      SetPoint = function(s, ...) s.points[#s.points + 1] = { ... } end,
      ClearAllPoints = function(s) s.points = {} end,
      SetSize = function(s, w, h) s.w, s.h = w, h end,
      GetWidth = function(s) return s.w end,
      SetHeight = function(s, h) s.h = h end,
      GetCenter = function(s) return 200, 200 end,
      GetFrameLevel = function() return 2 end,
      Show = function(s) s.shown = true end,
      Hide = function(s)
        s.shown = false
        if s.scripts.OnHide then s.scripts.OnHide(s) end
      end,
      IsShown = function(s) return s.shown end,
      Enable = function(s) s.enabled = true end,
      Disable = function(s) s.enabled = false end,
      Click = function(s, button)
        if s.scripts.OnClick then s.scripts.OnClick(s, button or "LeftButton") end
      end })
    return f
  end
  _G.CreateFrame = function(kind, name, par) return Frame(kind, name, par) end
  _G.Minimap = Frame("Frame", "Minimap")
  _G.Minimap.w = 192            -- NOT the 140 px every minimap button assumes (see Radius)
  _G.UIParent = Frame("Frame", "UIParent")
  _G.UIParent.w = 1024
  _G.UIParent.GetEffectiveScale = function() return 1 end
  _G.GetCursorPosition = function() return 240, 240 end

  assert(loadfile("Minimap.lua"))()
  ok(T.MINIMAP_MINOR == 1 and T.Minimap and T.MinimapItems, "Minimap.lua loads and exports")

  -- the rows: a note and a tick that are FUNCTIONS are asked when the menu opens, not when the
  -- addon loaded - the whole reason a menu can replace a command that printed the answer
  local locked, ran = false, {}
  local spec = function() return {
    { text = "options",     func = function() ran.options = true end },
    { sep = true },
    { text = "lock frames", checked = function() return locked end,
      note = function() return locked and "on" or "off" end,
      func = function() locked = not locked end },
    { text = "not yet", disabled = true },
  } end
  local rows = T.MinimapItems(spec)
  ok(#rows == 4 and rows[2].sep, "the spec resolves to rows, separators and all")
  ok(rows[3].checked == false and rows[3].note == "off", "a live note is asked now, and says off")
  locked = true
  ok(T.MinimapItems(spec)[3].note == "on", "and says on the next time the menu opens")
  locked = false
  ok(#T.MinimapItems(nil) == 0 and #T.MinimapItems(function() error("nope") end) == 0,
     "a missing or throwing menu is an empty menu, not an error at the minimap")

  -- the button
  local db = {}
  local b = T.Minimap("Test", { label = "Healing", db = db, menu = spec,
                                onRight = function() ran.options2 = true end })
  ok(b ~= nil, "the button is built")
  local pt = b.points[#b.points]
  -- The ring is MEASURED off this minimap, not assumed to be the usual 80: a client with a wider
  -- minimap put the button inside the map, where every other addon's button sat on the edge.
  local radius = 192 / 2 + T.MINIMAP.OVER
  ok(b:Radius() == radius, "the ring is measured off the minimap, not hard-coded", b:Radius())
  ok(radius > T.MINIMAP.RADIUS, "which on a wide minimap is further out than the old 80")
  local want = radius * math.cos(math.rad(T.MINIMAP.ANGLE))
  ok(pt and pt[1] == "CENTER" and math.abs(pt[4] - want) < 0.01,
     "a fresh install puts it at the default angle on the minimap's edge")
  _G.Minimap.w = 0
  ok(b:Radius() == T.MINIMAP.RADIUS, "and a minimap that cannot say how wide it is falls back")
  _G.Minimap.w = 192

  -- dragging writes the angle into the addon's db, so a reload finds it again
  b.Follow(b)
  ok(type(db.angle) == "number" and math.abs(db.angle - 45) < 0.01,
     "dragging it writes the angle to the db", tostring(db.angle))
  ok(b:Refresh() == true, "and it is shown by default")
  b:SetHidden(true)
  ok(db.hide == true and b:IsShown() == false, "SetHidden hides it AND remembers")
  b:SetHidden(false)

  -- the menu
  local menu = b:OpenMenu()
  ok(menu:IsShown() and menu.count == 4, "left-clicking opens a menu with every row")
  ok(menu.width >= T.MINIMAP.MIN_W and menu.width <= T.MINIMAP.MAX_W,
     "sized to its longest row, within the clamp", menu.width)
  ok(menu.rows[2].enabled == false and menu.rows[4].enabled == false,
     "a separator and a disabled row cannot be clicked")
  menu.rows[3]:Click()
  ok(locked == true, "clicking a row runs what the slash command ran")
  ok(menu:IsShown() == false, "and the menu closes behind it")
  ok(menu.catcher:IsShown() == false, "with the click-catcher going away too")

  -- reopened, the same row now says what changed
  b:OpenMenu()
  ok(menu.rows[3].note:GetText() == "on" and menu.rows[3].tick:IsShown(),
     "reopening shows the new state, ticked")
  ok(b:ToggleMenu() == false and menu:IsShown() == false, "clicking the button again shuts it")

  -- a row that throws must not take the client down with it
  b.opts.menu = { { text = "boom", func = function() error("kaboom") end } }
  local m2 = b:OpenMenu()
  ok(pcall(function() m2.rows[1]:Click() end), "a row that throws is caught, not raised")
  b.opts.menu = spec

  -- right-click is the options window, without going through the menu
  b:Click("RightButton")
  ok(ran.options2 == true, "right-clicking runs the options window directly")
  ok(menu:IsShown() == false, "and does not leave the menu open behind it")
end

if fails > 0 then error(fails .. " failed of " .. n) end
print("ALL OK (" .. n .. " checks)")
