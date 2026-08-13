# pr_app

Motor de GUI **multiplataforma** con **Flutter + Rust**, donde las **páginas se definen en Lua** y se pueden **descargar desde la web y re-renderizar sin recompilar la app**.

## Arquitectura

```
[Página Lua descargada/empaquetada]  <- define la GUI (widgets + handlers)
        ↓  lua_dardo_plus (VM Lua 5.3, 100% Dart, sin nativo)
[Dart / Flutter]  <- hub: renderiza widgets y conecta todo
        ↓  flutter_rust_bridge
[Rust]  <- motor: lógica pesada / tus librerías Rust
```

- **Lua = páginas.** Un script Lua devuelve una tabla `page` con `body` (lista de widgets) y `handlers` (funciones). Editando el `.lua` cambias la GUI completa **sin recompilar el binario**.
- **Flutter = render.** Un pequeño motor en Dart (`lib/engine/`) ejecuta el script y pinta los widgets.
- **Rust = motor lógico.** Las funciones Rust se exponen a Dart con `flutter_rust_bridge` y Lua las llama con `rust_greet`, `rust_sum`, `rust_fibonacci`, etc.

## Funciones expuestas a Lua (motor)

| Función Lua | Qué hace |
|---|---|
| `engine_get(id)` | Lee el valor actual de un widget |
| `engine_set(id, valor)` | Actualiza un widget y re-renderiza |
| `rust_greet(nombre)` | Llama a Rust |
| `rust_sum(a, b)` | Llama a Rust |
| `rust_fibonacci(n)` | Llama a Rust |

### Widgets soportados en una página

| type | campos |
|---|---|
| `heading` | `text` |
| `text` | `id`, `text` |
| `input` | `id`, `label`, `value` |
| `button` | `text`, `on_click` (nombre del handler) |
| `divider` | — |
| `spacer` | — |

## Estructura

```
pr_app/
├── lib/
│   ├── main.dart                  # shell de la app (barra URL + render)
│   ├── engine/
│   │   ├── page_engine.dart       # VM Lua + parseo + puente a Rust
│   │   └── widget_renderer.dart   # nodo Lua -> widget Flutter
│   └── src/rust/                  # GENERADO por flutter_rust_bridge (no se commitea)
├── rust/
│   └── src/api/simple.rs          # motor Rust (greet, sum, fibonacci)
├── rust_builder/                  # plugin que compila el crate (cargokit)
├── assets/pages/demo.lua          # página demo
├── android/                       # Kotlin (MainActivity + lo que quieras por plataforma)
└── .github/workflows/build.yml    # CI: Windows, Linux y Android
```

## Requisitos locales (solo para desarrollo)

- Flutter SDK estable
- Rust (rustup)
- Android build: JDK 17 + Android SDK/NDK

### Generar los bindings Rust <-> Dart

Los archivos `lib/src/rust/` y `rust/src/frb_generated.rs` se generan (no se commitean):

```bash
cargo install flutter_rust_bridge_codegen --version 2.12.0
flutter pub get
flutter_rust_bridge_codegen generate
```

Luego:

```bash
flutter run                 # Android / escritorio
flutter build apk --release # APK
```

## Descargar páginas desde la web

En la barra superior de la app pega la URL de un `.lua` (p. ej. alojado en un servidor estático o GitHub raw). La app lo descarga, lo ejecuta y re-renderiza la GUI. Sin tocar el binario.

Ejemplo de página:

```lua
page = {
  title = "Mi página",
  body = {
    { type = "text",   id = "out", text = "Listo" },
    { type = "button", text = "Calcular", on_click = "calc" },
  },
  handlers = {
    calc = function()
      engine_set("out", "Suma = " .. tostring(rust_sum(2, 3)))
    end,
  },
}
page.body_count = #page.body
```

## CI (GitHub Actions)

El workflow `.github/workflows/build.yml` compila automáticamente para:

- **Linux** (bundle portable)
- **Windows** (carpeta Release)
- **Android** (APK)

Los artefactos quedan disponibles en la pestaña Actions del repo. En CI se instala Rust, se genera el código con `flutter_rust_bridge_codegen`, se aceptan licencias de Android y se instala el NDK.

## Parte Android (Kotlin)

Solo Android usa Kotlin: `android/app/src/main/kotlin/com/example/pr_app/MainActivity.kt`. Puedes añadir ahí cualquier lógica específica de Android (platform channels, notificaciones, etc.) sin tocar las demás plataformas.

## Notas

- `lua_dardo_plus` es un VM de Lua 5.3 **100% Dart**: corre en Android, iOS, Windows, Linux, macOS y web sin código nativo (~sin peso extra).
- Los bindings se regeneran en CI, así que el repo queda limpio de archivos generados.