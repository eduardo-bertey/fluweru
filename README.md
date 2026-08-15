# pr_app

App **multiplataforma** (Android / Windows / Linux / iOS / macOS / web) hecha con **Flutter + Rust + Lua**, con **IA de chat local (Candle)** en el dispositivo y una **GUI controlada por Lua**: muy dinámica y totalmente programable, capaz de re-renderizarse en caliente y de reproducir **audio y video**.

## Qué es

- **GUI programable en Lua.** Cada pantalla es un script Lua (`assets/pages/*.lua`) que define widgets y comportamiento. Cambias el `.lua` y la interfaz cambia por completo **sin recompilar la app**. Las páginas se pueden bajar desde una URL y renderizarse al instante.
- **IA local en Rust (Candle).** Chat LLM embebido que corre **en el dispositivo** (sin servidor): la app descarga el modelo desde HuggingFace por HTTP (por streaming, con progreso), Rust lo lee del disco y lo carga en RAM, y genera texto directamente en el teléfono. Dos modelos: `base` y `fine`.
- **Multimedia integrada.** Reproducción de audio y video desde Lua (media_kit): abrir archivo, play/pausa, seek, status.

## Arquitectura

```
[Página Lua]  <- define la GUI (widgets + handlers) + control multimedia + IA
      ↓  lua_dardo_plus (VM Lua 5.3, 100% Dart, sin nativo)
[Dart / Flutter]  <- hub: renderiza widgets, gestiona media y conecta todo
      ↓  flutter_rust_bridge
[Rust]  <- IA (Candle: tokenizer + LLM) y lógica pesada
```

- **Lua = páginas + comportamiento.** Un script define `page.body` (lista de widgets) y `page.handlers` (funciones). También puede llamar a `engine_set` para re-renderizar un widget en vivo, al reproductor multimedia y a la IA.
- **Flutter = render.** Un motor en Dart (`lib/gui/`, `lib/widgets/`) ejecuta el script y pinta los widgets.
- **Rust = IA y motor lógico.** Con `flutter_rust_bridge`, Rust expone funciones a Dart y Lua las llama: `laurelia_generate`, `laurelia_load_model`, `rust_greet`, `rust_sum`, `rust_fibonacci`, etc.

## Funciones expuestas a Lua

### Motor de GUI

| Función Lua | Qué hace |
|---|---|
| `engine_get(id)` | Lee el valor actual de un widget |
| `engine_set(id, valor)` | Actualiza un widget y re-renderiza |
| `navigate("página")` | Cambia de página |
| `gui_*` (`gui_button`, `gui_text`, `gui_input`, `gui_rect`, ...) | Construye la GUI llamando funciones (estilo Godot) |
| `handler("nombre", fn)` | Registra un manejador de evento para los `on_click` |

### IA Laurelia (chat local en Rust/Candle)

| Función Lua | Qué hace |
|---|---|
| `laurelia_set_model("base"\|"fine")` | Selecciona el modelo |
| `laurelia_download()` | Descarga por streaming lo que falte (progreso en vivo) |
| `laurelia_download_and_load()` | Descarga y carga en Rust en una sola acción |
| `laurelia_load()` | Carga el modelo del disco a RAM |
| `laurelia_unload()` | Libera el modelo de RAM |
| `laurelia_delete_model("base"\|"fine")` | Borra el modelo del disco |
| `laurelia_generate(prompt, max_tokens)` | Genera texto; el resultado va a `laurelia_out` |
| `laurelia_count_tokens(texto)` | Cuenta tokens (necesita tokenizer) |
| `laurelia_is_loaded()` / `laurelia_status()` / `laurelia_info()` | Estado: cargado, progreso, ruta, MB, completo |
| `laurelia_vocab()` | Tamaño del vocabulario |

### Multimedia

| Función Lua | Qué hace |
|---|---|
| `player_pick()` | Abre selector de archivo |
| `player_open(url)` | Abre una URL o ruta |
| `player_play()` / `player_pause()` / `player_toggle()` / `player_stop()` | Control del reproductor |
| `player_status()` | Estado actual (playing/paused/... ) |

### Widgets soportados en una página

| type | campos |
|---|---|
| `heading` | `text` |
| `text` | `id`, `text`, `multiline` (texto largo), `font`, `color`, `align` |
| `input` | `id`, `label`, `value` |
| `button` | `text`, `on_click` (nombre del handler) |
| `rect` | `text`, `bg_color`, `radius`, `padding`, `align`, `font` |
| `rect_image` / `image` | `src` (URL), `fit` |
| `video` | — (reproduce con el reproductor compartido) |
| `divider` | `height` |
| `spacer` | `space` |

## Estructura

```
pr_app/
├── lib/
│   ├── main.dart                    # shell de la app (barra URL + render)
│   ├── ai/laurelia_chat.dart        # IA: descarga por streaming + carga + generar
│   ├── gui/engine_shell.dart        # shell Flutter (media + laurelia + páginas)
│   ├── lua/lua_controller.dart      # VM Lua + parseo + puente a Rust/media/IA
│   ├── media/media_player.dart      # reproductor audio/video (media_kit)
│   ├── widgets/                     # nodo Lua -> widget Flutter
│   └── src/rust/                    # GENERADO por flutter_rust_bridge (no se commitea)
├── rust/
│   ├── src/api/simple.rs            # motor Rust (greet, sum, fibonacci)
│   └── src/api/laurelia.rs          # IA Candle: carga modelo + generar texto
├── rust_builder/                    # plugin que compila el crate (cargokit)
├── assets/pages/
│   ├── demo.lua                     # página demo (Rust)
│   ├── player.lua                   # página multimedia (audio/video)
│   └── laurelia.lua                 # página chat IA (base/fine, descargar/eliminar)
├── android/                         # Kotlin (MainActivity + lo que quieras por plataforma)
└── .github/workflows/build.yml      # CI: Windows, Linux y Android
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
page.title = "Mi página"

gui_button({ text = "Calcular", on_click = "calc" })
gui_text({ id = "out", text = "Listo" })

handler("calc", function()
  engine_set("out", "Suma = " .. tostring(rust_sum(2, 3)))
end)
```

## Chat IA en el dispositivo (Laurelia)

1. **Descargar** el modelo (base o fine, ~650 MB) por HTTP con progreso en vivo → se guarda en disco (`hf_models/laurelia/<modelo>/`).
2. **Cargar en Rust**: Rust lee el checkpoint del disco y lo pone en RAM.
3. **Generar**: el texto se genera localmente y aparece en `laurelia_out` (multilinea, scrolleable).
4. **Eliminar** un modelo borra solo su carpeta; **Liberar** libera la RAM.

## CI (GitHub Actions)

El workflow `.github/workflows/build.yml` compila automáticamente para:

- **Linux** (bundle portable)
- **Windows** (carpeta Release)
- **Android** (APK)

Los artefactos quedan disponibles en la pestaña Actions del repo. En CI se instala Rust, se genera el código con `flutter_rust_bridge_codegen`, se aceptan licencias de Android y se instala el NDK. El APK de Android incluye `libc++_shared.so` para que las dependencias C++ de Candle (tokenizer) funcionen en el dispositivo.

## Parte Android (Kotlin)

Solo Android usa Kotlin: `android/app/src/main/kotlin/com/example/pr_app/MainActivity.kt`. Puedes añadir ahí cualquier lógica específica de Android (platform channels, notificaciones, etc.) sin tocar las demás plataformas.

## Notas

- `lua_dardo_plus` es un VM de Lua 5.3 **100% Dart**: corre en Android, iOS, Windows, Linux, macOS y web sin código nativo (~sin peso extra).
- La IA usa **Candle** (Rust) para tokenizar y generar: todo local, sin conexión tras descargar el modelo.
- Los bindings se regeneran en CI, así que el repo queda limpio de archivos generados.
