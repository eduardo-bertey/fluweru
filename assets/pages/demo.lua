-- Página demo: la GUI se define aquí, en Lua.
-- Widgets: heading | text | input | button | divider | spacer
-- Handlers: funciones Lua que usan el motor:
--   engine_get(id)             -> leer valor de un widget
--   engine_set(id, valor)      -> actualizar un widget (re-render)
--   rust_greet / rust_sum / rust_fibonacci -> llamar a Rust

page = {
  title = "Demo Lua + Rust",
  body = {
    { type = "heading", text = "Motor: Flutter + Rust, GUI en Lua" },
    { type = "text",   text = "Escribe tu nombre y presiona el botón. La llamada a Rust ocurre desde Lua." },
    { type = "input",  id = "name", label = "Nombre", value = "Ana" },
    { type = "button", text = "Saludar (Rust)", on_click = "saludar" },
    { type = "button", text = "Sumar 21 + 21 (Rust)", on_click = "sumar" },
    { type = "button", text = "Fibonacci(40) (Rust)", on_click = "fib" },
    { type = "divider" },
    { type = "text",   id = "greeting", text = "Saludo pendiente..." },
    { type = "text",   id = "result",   text = "Resultado: -" },
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

-- El motor lee body_count para saber cuántos nodos hay.
page.body_count = #page.body