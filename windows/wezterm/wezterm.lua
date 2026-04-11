-- WezTerm configuration — Windows variant
-- Ported from modules/wezterm/wezterm.lua (macOS original)
-- Install location: %USERPROFILE%\.wezterm.lua  (or .config\wezterm\wezterm.lua)
--
-- Differences from macOS version:
--   CMD        → CTRL|SHIFT  (Windows has no CMD key)
--   OPT        → ALT
--   macOS-only options stripped (native_macos_fullscreen_mode, use_ime,
--   send_composed_key_when_*_alt_is_pressed)

local wezterm = require "wezterm"
local act     = wezterm.action
local config  = wezterm.config_builder()

-- ── Font ──────────────────────────────────────────────────────────────────
config.font = wezterm.font_with_fallback {
  { family = "FiraCode Nerd Font" },
  { family = "Segoe UI Emoji" },
}
config.harfbuzz_features = { "cv02", "cv06", "ss01", "ss03", "ss05", "ss07", "ss08" }
config.font_size   = 13.0
config.line_height = 1.1
config.allow_square_glyphs_to_overflow_width = "WhenFollowedBySpace"

-- ── Color Schemes ─────────────────────────────────────────────────────────
config.color_schemes = {
  ["Fluent Dark"] = {
    foreground    = "#d0d0d0",
    background    = "#0a0a0a",
    cursor_bg     = "#d0d0d0",
    cursor_border = "#d0d0d0",
    cursor_fg     = "#0a0a0a",
    selection_bg  = "#1c1c1c",
    selection_fg  = "#f5f5f5",
    ansi = {
      "#0a0a0a", "#ff6b81", "#8cd17d", "#e3c26f",
      "#6fa4ff", "#c792ea", "#6ad5c9", "#d0d0d0",
    },
    brights = {
      "#1c1c1c", "#ff7b91", "#9fe38c", "#f0d78a",
      "#7cb4ff", "#d8a4f0", "#7de3d4", "#f5f5f5",
    },
  },
}
config.color_scheme = "Fluent Dark"

-- ── Window Appearance ─────────────────────────────────────────────────────
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.window_background_opacity      = 0.96
config.win32_system_backdrop          = "Acrylic"
config.window_decorations             = "RESIZE"
config.use_fancy_tab_bar              = true
config.hide_tab_bar_if_only_one_tab   = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width                  = 32
config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.7 }

-- ── Default shell ─────────────────────────────────────────────────────────
-- Default to PowerShell 7; swap to wsl.exe for WSL-first workflow
config.default_prog = { "pwsh.exe", "-NoLogo" }
-- config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu" }

-- ── Performance & Behaviour ───────────────────────────────────────────────
config.max_fps       = 120
config.animation_fps = 60
config.front_end     = "WebGpu"

config.scrollback_lines          = 100000
config.scroll_to_bottom_on_input = true

config.audible_bell = "Disabled"
config.visual_bell  = {
  fade_in_duration_ms  = 75,
  fade_out_duration_ms = 75,
  target               = "CursorColor",
}

config.check_for_updates = false

config.default_cursor_style  = "BlinkingBar"
config.cursor_blink_rate     = 500
config.cursor_blink_ease_in  = "Constant"
config.cursor_blink_ease_out = "Constant"

config.exit_behavior             = "CloseOnCleanExit"
config.window_close_confirmation = "NeverPrompt"
config.status_update_interval    = 1000

-- ── Hyperlink Rules ───────────────────────────────────────────────────────
local hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(hyperlink_rules, {
  regex  = [[\bgh#(\d+)\b]],
  format = "https://github.com/issues/$1",
})
config.hyperlink_rules = hyperlink_rules

-- ── Status Bar (right side) ───────────────────────────────────────────────
wezterm.on("update-status", function(window, pane)
  local workspace = window:active_workspace()

  local cwd = ""
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local raw = cwd_uri.file_path or tostring(cwd_uri)
    cwd = raw:gsub("^/[^/]+", "")
    if cwd == "" then cwd = raw end
    local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
    if home ~= "" then
      cwd = cwd:gsub("^" .. home:gsub("%-", "%%-"), "~")
    end
  end

  local bat_str = ""
  local ok, batteries = pcall(wezterm.battery_info)
  if ok and batteries and #batteries > 0 then
    local b   = batteries[1]
    local pct = math.floor(b.state_of_charge * 100)
    local icon
    if b.state == "Charging" then icon = "󱐋"
    elseif pct >= 80 then icon = "󰁹"
    elseif pct >= 60 then icon = "󰂀"
    elseif pct >= 40 then icon = "󰁾"
    elseif pct >= 20 then icon = "󰁼"
    else icon = "󰁺" end
    bat_str = icon .. " " .. pct .. "%"
  end

  local time_str = wezterm.strftime "%H:%M"

  local bg1 = "#2a2a2a"
  local bg2 = "#333333"
  local fg  = "#cccccc"
  local sep = "#555555"

  local cells = {}

  if workspace ~= "default" then
    table.insert(cells, { Background = { Color = bg2 } })
    table.insert(cells, { Foreground = { Color = fg  } })
    table.insert(cells, { Text = "  " .. workspace .. " " })
    table.insert(cells, { Foreground = { Color = sep } })
    table.insert(cells, { Text = "" })
  end

  if cwd ~= "" then
    table.insert(cells, { Background = { Color = bg1 } })
    table.insert(cells, { Foreground = { Color = fg  } })
    table.insert(cells, { Text = "  " .. cwd .. " " })
    table.insert(cells, { Foreground = { Color = sep } })
    table.insert(cells, { Text = "" })
  end

  if bat_str ~= "" then
    table.insert(cells, { Background = { Color = bg2 } })
    table.insert(cells, { Foreground = { Color = fg  } })
    table.insert(cells, { Text = " " .. bat_str .. " " })
    table.insert(cells, { Foreground = { Color = sep } })
    table.insert(cells, { Text = "" })
  end

  table.insert(cells, { Background = { Color = bg1 } })
  table.insert(cells, { Foreground = { Color = fg  } })
  table.insert(cells, { Text = " 󱑍 " .. time_str .. " " })

  window:set_right_status(wezterm.format(cells))
end)

-- ── Tab Titles ────────────────────────────────────────────────────────────
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _cfg, _hover, _max_width)
  local pane  = tab.active_pane
  local title = pane.title

  if tab.tab_title and #tab.tab_title > 0 then
    title = tab.tab_title
  end

  local process = pane.foreground_process_name or ""
  local prog    = process:match "([^\\/]+)$" or ""
  if prog ~= "" and prog ~= "pwsh.exe" and prog ~= "powershell.exe"
     and prog ~= "cmd.exe" and prog ~= "wsl.exe" then
    title = prog:gsub("%.exe$", "")
  end

  local zoom = pane.is_zoomed and " 󰊓" or ""
  local idx  = tostring(tab.tab_index + 1)

  return { { Text = " " .. idx .. ": " .. title .. zoom .. " " } }
end)

-- ── Leader Key ────────────────────────────────────────────────────────────
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 2000 }

-- ── Key Tables ────────────────────────────────────────────────────────────
config.key_tables = {
  resize_pane = {
    { key = "h",      action = act.AdjustPaneSize { "Left",  5 } },
    { key = "j",      action = act.AdjustPaneSize { "Down",  5 } },
    { key = "k",      action = act.AdjustPaneSize { "Up",    5 } },
    { key = "l",      action = act.AdjustPaneSize { "Right", 5 } },
    { key = "Escape", action = act.PopKeyTable },
    { key = "q",      action = act.PopKeyTable },
  },
}

-- ── Keybindings ───────────────────────────────────────────────────────────
-- Windows convention: CTRL|SHIFT replaces CMD
config.disable_default_key_bindings = false

config.keys = {
  { key = "Enter", mods = "SHIFT", action = act.SendString "\x1b\r" },

  -- Window / Tab management
  { key = "n", mods = "CTRL|SHIFT", action = act.SpawnWindow },
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab "CurrentPaneDomain" },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane { confirm = false } },
  { key = "W", mods = "CTRL|SHIFT|ALT", action = act.CloseCurrentTab { confirm = false } },

  -- Tab cycling
  { key = "[", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1)  },

  -- Direct tab access
  { key = "1", mods = "CTRL|SHIFT", action = act.ActivateTab(0) },
  { key = "2", mods = "CTRL|SHIFT", action = act.ActivateTab(1) },
  { key = "3", mods = "CTRL|SHIFT", action = act.ActivateTab(2) },
  { key = "4", mods = "CTRL|SHIFT", action = act.ActivateTab(3) },
  { key = "5", mods = "CTRL|SHIFT", action = act.ActivateTab(4) },
  { key = "6", mods = "CTRL|SHIFT", action = act.ActivateTab(5) },
  { key = "7", mods = "CTRL|SHIFT", action = act.ActivateTab(6) },
  { key = "8", mods = "CTRL|SHIFT", action = act.ActivateTab(7) },
  { key = "9", mods = "CTRL|SHIFT", action = act.ActivateTab(-1) },

  -- Pane splitting
  { key = "d", mods = "CTRL|SHIFT",     action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },
  { key = "d", mods = "CTRL|SHIFT|ALT", action = act.SplitVertical   { domain = "CurrentPaneDomain" } },

  -- Pane navigation
  { key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection "Left"  },
  { key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection "Down"  },
  { key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection "Up"    },
  { key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection "Right" },

  { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },
  { key = "Space", mods = "CTRL|SHIFT|ALT", action = act.RotatePanes "Clockwise" },

  -- Scrollback
  { key = "u", mods = "CTRL|SHIFT",     action = act.ScrollByPage(-0.5) },
  { key = "d", mods = "CTRL|SHIFT|ALT", action = act.ScrollByPage(0.5)  },
  { key = "UpArrow",   mods = "CTRL|SHIFT", action = act.ScrollToPrompt(-1) },
  { key = "DownArrow", mods = "CTRL|SHIFT", action = act.ScrollToPrompt(1)  },

  -- Copy / Paste
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo    "Clipboard" },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom "Clipboard" },

  -- Font size
  { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CTRL", action = act.ResetFontSize    },

  -- Misc
  { key = ",", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
  { key = "p", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
  { key = "f", mods = "CTRL|SHIFT", action = act.Search { CaseSensitiveString = "" } },

  { key = "s", mods = "CTRL|SHIFT|ALT", action = act.QuickSelect },
  { key = "Enter", mods = "CTRL|SHIFT|ALT", action = act.ActivateCopyMode },

  { key = "p", mods = "CTRL|SHIFT|ALT", action = act.PaneSelect { alphabet = "1234567890" } },

  -- Leader bindings
  {
    key    = "r",
    mods   = "LEADER",
    action = act.ActivateKeyTable {
      name = "resize_pane", one_shot = false, timeout_milliseconds = 2000,
    },
  },
  { key = "s", mods = "LEADER", action = act.ShowLauncherArgs { flags = "WORKSPACES" } },
  { key = "Space", mods = "LEADER|CTRL", action = act.SendKey { key = "Space", mods = "CTRL" } },
}

-- ── Mouse Bindings ────────────────────────────────────────────────────────
config.mouse_bindings = {
  {
    event  = { Up = { streak = 1, button = "Left" } },
    mods   = "NONE",
    action = act.CopyTo "ClipboardAndPrimarySelection",
  },
  {
    event  = { Down = { streak = 1, button = "Right" } },
    mods   = "NONE",
    action = act.PasteFrom "Clipboard",
  },
  {
    event  = { Up = { streak = 1, button = "Left" } },
    mods   = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
}

return config
