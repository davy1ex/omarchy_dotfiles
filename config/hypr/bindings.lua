-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
-- ==========================================
-- 1. ОТКЛЮЧАЕМ ДЕФОЛТНЫЕ СТРЕЛОЧКИ (Опционально)
-- ==========================================
--hl.unbind("SUPER + LEFT")
-- hl.unbind("SUPER + RIGHT")
-- hl.unbind("SUPER + UP")
-- hl.unbind("SUPER + DOWN")

hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

-- hl.unbind("SUPER + SHIFT + LEFT")
-- hl.unbind("SUPER + SHIFT + RIGHT")
-- hl.unbind("SUPER + SHIFT + UP")
-- hl.unbind("SUPER + SHIFT + DOWN")

-- ==========================================
-- 2. ЧИСТЫЙ ФОКУС ОКНО (ОКНА НЕ ДВИГАЮТСЯ)
-- ==========================================
o.bind("SUPER + H", "Фокус влево", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Фокус вниз",  hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Фокус вверх", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Фокус вправо", hl.dsp.focus({ direction = "r" }))

-- ==========================================
-- 3. ПЕРЕМЕЩЕНИЕ ОКОН В СТИЛЕ i3 (SUPER + SHIFT + HJKL)
-- ==========================================
-- Hyprland отказывается двигать/свапать окно, пока оно во fullscreen или
-- maximized состоянии (в логе: "Can't swap fullscreen window"). Поэтому пока
-- окно в mod+f — двигать его нельзя. Обходим так: на один кадр снимаем
-- fullscreen со всех полноэкранных окон рабочего стола, делаем swap и сразу
-- возвращаем прежнее состояние. Всё синхронно в одном обработчике, поэтому
-- промежуточный кадр не рисуется и мерцания нет.
local function swap_window(direction)
  local active = hl.get_active_window()
  if not active then
    return
  end

  local restore = {}

  for _, window in ipairs(hl.get_windows({ workspace = active.workspace })) do
    if not window.floating and (window.fullscreen ~= 0 or window.fullscreen_client ~= 0) then
      restore[#restore + 1] = { window = window, internal = window.fullscreen, client = window.fullscreen_client }
      hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = window }))
    end
  end

  hl.dispatch(hl.dsp.window.swap({ direction = direction }))

  for _, state in ipairs(restore) do
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = state.internal, client = state.client, window = state.window }))
  end

  hl.dispatch(hl.dsp.focus({ window = active }))
end

o.bind("SUPER + SHIFT + H", "Сдвинуть окно влево", function() swap_window("l") end)
o.bind("SUPER + SHIFT + J", "Сдвинуть окно вниз",  function() swap_window("d") end)
o.bind("SUPER + SHIFT + K", "Сдвинуть окно вверх", function() swap_window("u") end)
o.bind("SUPER + SHIFT + L", "Сдвинуть окно вправо", function() swap_window("r") end)


-- ==========================================
-- 3b. ШИРИНА ОКОН В СТИЛЕ NIRI (SUPER + - / =)
-- ==========================================
-- На scrolling-лейауте colresize меняет ширину текущей колонки шагами по 10%,
-- как Mod+Minus / Mod+Equal в niri.
--
-- Важно: пока окно помечено fullscreen/maximized, Hyprland возвращает ему
-- полную ширину каждый раз, когда оно снова получает фокус. Поэтому от
-- fake-fullscreen при ресайзе надо выйти, иначе ширина не сохранится при
-- переключении на другое окно и обратно. Из mod+f рост делать некуда, поэтому
-- он no-op, а сужение выходит из fullscreen сразу на 90%.
local function resize_window_width(grow)
  local active = hl.get_active_window()
  if not active then
    return
  end

  local layout = active.workspace and active.workspace.tiled_layout
  local fullscreen = active.fullscreen ~= 0 or active.fullscreen_client ~= 0

  if layout == "scrolling" then
    if fullscreen then
      if not grow then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = active }))
        hl.dispatch(hl.dsp.layout("colresize 0.9"))
      end
      return
    end

    hl.dispatch(hl.dsp.layout("colresize " .. (grow and "+0.1" or "-0.1")))
    return
  end

  -- Fallback for dwindle/master. A fullscreen window refuses resize, so leave
  -- fullscreen first; don't re-maximize, or the resize would be undone.
  if fullscreen then
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = active }))
  end

  hl.dispatch(hl.dsp.window.resize({ x = (grow and -100 or 100), y = 0, relative = true }))
end

-- Были: "Expand/Shrink window left" (resize влево/вправо).
hl.unbind("SUPER + code:20")
hl.unbind("SUPER + code:21")
hl.unbind("SUPER + SHIFT + code:21") -- было: "Expand window down"
o.bind("SUPER + code:20", "Сузить окно (niri)", function() resize_window_width(false) end)
o.bind("SUPER + code:21", "Расширить окно (niri)", function() resize_window_width(true) end)
o.bind("SUPER + SHIFT + code:21", "Расширить окно (niri)", function() resize_window_width(true) end)


-- ==========================================
-- 4. F — ТОЛЬКО ТЕКУЩЕЕ ПРИЛОЖЕНИЕ (dwindle-лейаут сохраняется)
-- ==========================================
-- internal = 2 -> compositor fullscreen (window covers the output)
-- client    = 1 -> do NOT tell the app to fullscreen itself (that is the F12 look)
hl.unbind("SUPER + F")
o.bind("SUPER + F", "Развернуть окно", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.unbind("SUPER + ALT + F")
o.bind("SUPER + ALT + F", "Полный экран (niri)", hl.dsp.window.fullscreen_state({ internal = 2, client = 1 }))

hl.unbind("SUPER + ALT + L")
o.bind("SUPER + ALT + L", "Включить Niri макет", "omarchy-hyprland-workspace-layout-toggle")

-- ==========================================
-- 5. SUPER+C — Отцентрировать колонку (как Mod+C в niri)
-- ==========================================
-- Работает только на scrolling-лейауте; на остальных ничего не делает.
hl.unbind("SUPER + C")
o.bind("SUPER + C", "Отцентрировать колонку", "omarchy-hyprland-center-column")