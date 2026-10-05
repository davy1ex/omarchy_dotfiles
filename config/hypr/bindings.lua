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
