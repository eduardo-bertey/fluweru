-- Pagina demo: la GUI se define aqui, en Lua.
-- Widgets: heading | text | input | button | divider | spacer | rect | rect_image
-- Layout/estilo: align, width, height, padding, color, bg_color, radius,
--                border_color, border_width, font = { family, size, bold, italic, color }
-- Handlers: funciones Lua que usan el motor:
--   engine_get(id)             -> leer valor de un widget
--   engine_set(id, valor)      -> actualizar un widget (re-render)
--   rust_greet / rust_sum / rust_fibonacci -> llamar a Rust

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
  },
}

-- El motor lee body_count para saber cuantos nodos hay.
page.body_count = #page.body
