-- Pagina 2: Reproductor de audio/video (media_kit / libmpv + FFmpeg).
-- Abre archivos de Android con el selector nativo y los reproduce.
-- Globals de reproductor disponibles:
--   player_config()   -> opciones con que se compilo libmpv (debe decir --enable-lgpl)
--   player_pick()     -> abrir selector de archivos y reproducir
--   player_open(ruta) -> reproducir una ruta directa
--   player_play() / player_pause() / player_toggle() / player_stop()
--   player_status()   -> estado actual (texto)

page = {
  title = "Reproductor (pagina 2)",

  body = {
    { type = "rect", text = "Reproductor media_kit (libmpv)",
      bg_color = "#1976d2", radius = 12, padding = 14, align = "center",
      font = { size = 18, bold = true, color = "white" } },

    { type = "spacer", space = 10 },

    { type = "video", height = 220, align = "center" },

    { type = "spacer", space = 10 },

    { type = "button", text = "Abrir archivo de Android", on_click = "abrir" },
    { type = "button", text = "Reproducir / Pausar", on_click = "toggle" },
    { type = "button", text = "Detener", on_click = "detener" },
    { type = "button", text = "Comprobar LGPL de libmpv", on_click = "check_mpv" },

    { type = "divider", height = 24 },

    { type = "text", id = "player_status", text = "Estado: sin archivo",
      font = { size = 14 } },
    { type = "text", id = "mpv_cfg", text = "mpv-configuration: -",
      font = { size = 13 } },

    { type = "divider", height = 24 },

    { type = "button", text = "< Volver a la pagina 1 (Rust)", on_click = "volver" },
  },

  handlers = {
    abrir = function()
      player_pick()
    end,
    toggle = function()
      player_toggle()
    end,
    detener = function()
      player_stop()
    end,
    check_mpv = function()
      local cfg = player_config()
      engine_set("mpv_cfg", cfg)
    end,
    volver = function()
      navigate("demo")
    end,
  },
}

page.body_count = #page.body
