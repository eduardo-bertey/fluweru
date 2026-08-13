-- Pagina demo: la GUI se define aqui, en Lua.
-- Widgets: heading | text | input | button | divider | spacer | rect | rect_image | video
-- Layout/estilo: align, width, height, padding, color, bg_color, radius,
--                border_color, border_width, font = { family, size, bold, italic, color }
-- Handlers: funciones Lua que usan el motor:
--   engine_get(id)             -> leer valor de un widget
--   engine_set(id, valor)      -> actualizar un widget (re-render)
--   navigate("pagina")         -> cambiar de pagina (demo | player)
--   rust_greet / rust_sum / rust_fibonacci -> llamar a Rust
--   player_config()            -> opciones con que se compilo libmpv (debe decir --enable-lgpl)
--   player_pick()              -> abrir selector de archivos y reproducir

page = {
  title = "Demo Lua + Rust",

  body = {
    { type = "rect", text = "Motor: Flutter + Rust, GUI en Lua",
      bg_color = "#1976d2", radius = 12, padding = 14, align = "center",
      font = { size = 18, bold = true, color = "white" } },

    { type = "spacer", space = 10 },

    { type = "rect_image",
      src = "https://picsum.photos/seed/pr_app/640/300",
      fit = "cover", height = 190 },

    { type = "spacer", space = 10 },

    { type = "text",
      text = "Escribe tu nombre y presiona un boton. La llamada a Rust ocurre desde Lua.",
      font = { size = 14 }, color = "#555555", padding = 4 },

    { type = "input", id = "name", label = "Nombre", value = "Ana" },

    { type = "spacer", space = 6 },

    { type = "text", text = "Acciones Rust:", align = "center",
      font = { size = 15, bold = true, color = "#1976d2" } },

    { type = "button", text = "Saludar (Rust)", on_click = "saludar" },
    { type = "button", text = "Sumar 21 + 21 (Rust)", on_click = "sumar" },
    { type = "button", text = "Fibonacci(40) (Rust)", on_click = "fib" },

    { type = "divider", height = 26 },

    { type = "text", id = "greeting", text = "Saludo pendiente...",
      font = { size = 16 } },
    { type = "text", id = "result", text = "Resultado: -",
      font = { size = 16 } },

    { type = "divider", height = 26 },

    { type = "text", text = "Paginas:", align = "center",
      font = { size = 15, bold = true, color = "#1976d2" } },

    { type = "button", text = "Ir al reproductor (pagina 2)", on_click = "ir_player" },
    { type = "button", text = "Comprobar LGPL de libmpv", on_click = "check_mpv" },
    { type = "text", id = "mpv_cfg", text = "mpv-configuration: -",
      font = { size = 13 } },
  },

  handlers = {
    saludar = function()
      local nombre = engine_get("name")
      local saludo = rust_greet(nombre)
      engine_set("greeting", "-> " .. saludo)
    end,
    sumar = function()
      local r = rust_sum(21, 21)
      engine_set("result", "21 + 21 = " .. tostring(r))
    end,
    fib = function()
      local r = rust_fibonacci(40)
      engine_set("result", "Fibonacci(40) = " .. tostring(r))
    end,
    ir_player = function()
      navigate("player")
    end,
    check_mpv = function()
      local cfg = player_config()
      engine_set("mpv_cfg", cfg)
    end,
  },
}

-- El motor lee body_count para saber cuantos nodos hay.
page.body_count = #page.body
