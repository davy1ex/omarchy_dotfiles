-- Personal Hyprland keybinding overrides.
--
-- The niri-style window management now lives in the Niri Extras plugin
-- (~/.config/omarchy/plugins/io.github.davy1ex.niri-extras), toggled from the
-- bar:
--   SUPER+H/J/K/L         focus
--   SUPER+SHIFT+H/J/K/L   move window
--   SUPER+-/=             column width
--   SUPER+C               center column
--   SUPER+F / ALT+F       fake / true fullscreen
--   SUPER+ALT+L           scrolling <-> dwindle
--
-- Deliberately NOT duplicated here: with nothing in this file rebinding those
-- keys, turning the plugin OFF falls back to Omarchy's stock bindings
-- (SUPER+J split, SUPER+K keybindings, SUPER+L layout, SUPER+C copy).
--
-- Add personal, non-niri overrides below.

-- Alternative launcher/file-manager bindings (in addition to stock
-- SUPER+SPACE for the menu and SUPER+SHIFT+F for the file manager).
o.bind("SUPER + D", "Omarchy menu", "omarchy-menu toggle")
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
-- Replace Omarchy's Super+V universal-paste binding with clipboard history.
o.rebind("SUPER + V", "Clipboard history", { panel = "omarchy.clipboard" })

-- Consume every event in a bound scroll gesture instead of passing the tail
-- of a wheel burst through to the focused app. Throttle each action below.
hl.config({ binds = { scroll_event_delay = 0 } })

local function throttle_scroll(interval, action)
  local locked = false
  return function()
    if locked then
      return
    end
    locked = true
    action()
    hl.timer(function()
      locked = false
    end, { timeout = interval, type = "oneshot" })
  end
end

-- Match macOS-style zoom modifiers and avoid Super+wheel workspace switching.
local function adjust_screen_zoom(delta)
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  local next_zoom = math.max(1, math.floor((zoom + delta) * 100 + 0.5) / 100)
  if delta > 0 then
    next_zoom = zoom >= 3 and zoom or math.min(3, next_zoom)
  end
  hl.config({ cursor = { zoom_factor = next_zoom } })
end

o.bind("CTRL + ALT + mouse_up", "Zoom in with scroll", throttle_scroll(100, function()
  adjust_screen_zoom(0.25)
end))
o.bind("CTRL + ALT + mouse_down", "Zoom out with scroll", throttle_scroll(100, function()
  adjust_screen_zoom(-0.25)
end))

-- Keep Omarchy's existing Super+wheel navigation, but throttle it since the
-- global scroll-event delay is disabled to consume bound scroll gestures.
o.rebind("SUPER + mouse_up", "Scroll active workspace backward", throttle_scroll(250, function()
  hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
end))
o.rebind("SUPER + mouse_down", "Scroll active workspace forward", throttle_scroll(250, function()
  hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
end))
o.rebind("SUPER + ALT + mouse_up", "Previous window in group", throttle_scroll(250, function()
  hl.dispatch(hl.dsp.group.prev())
end))
o.rebind("SUPER + ALT + mouse_down", "Next window in group", throttle_scroll(250, function()
  hl.dispatch(hl.dsp.group.next())
end))
