import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lua_dardo_plus/lua.dart';
import 'package:pr_app/src/rust/api/simple.dart';

import '../media/media_player.dart';
import '../widgets/gui_node.dart';
import 'page_model.dart';

/// Controlador Lua: lee la página desde Lua y controla los bucles (recorrido
/// de `page.body`) y las llamadas (handlers Lua y funciones Rust).
///
/// Lua puede llamar a:
///   - engine_get(id)               -> leer el valor actual de un widget
///   - engine_set(id, valor)        -> actualizar un widget (re-render)
///   - rust_greet / rust_sum / rust_fibonacci -> llamar a Rust
class LuaController {
  late LuaState _lua;
  final Map<String, String> _values = {};

  /// Reproductor compartido (media_kit) expuesto a Lua.
  MediaPlayer? mediaPlayer;

  /// Llamado por `navigate()` para cambiar de página.
  void Function(String page)? onNavigate;

  /// Llamado por engine_set para que la UI se re-renderice.
  void Function(String id, String value)? onUpdate;

  Map<String, String> get values => _values;

  void setInputValue(String id, String value) => _values[id] = value;

  void dispose() {
    _values.clear();
  }

  /// Carga una página desde un asset empaquetado.
  Future<PageModel> loadFromAsset(String path) async {
    final code = await rootBundle.loadString(path);
    return load(code);
  }

  /// Carga una página Lua desde una URL (script descargado de la web).
  Future<PageModel> loadFromUrl(String url) async {
    url = _normalizeUrl(url);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} al cargar $url');
    }
    final body = utf8.decode(res.bodyBytes);
    if (body.trimLeft().startsWith('<')) {
      throw Exception(
        'La URL devolvió HTML, no código Lua. '
        'Usa la URL "raw" del archivo, p. ej. '
        'https://raw.githubusercontent.com/eduardo-bertey/fluweru/main/assets/pages/demo.lua',
      );
    }
    return load(body);
  }

  /// Convierte URLs de GitHub (blob o raw) a raw.githubusercontent.com.
  String _normalizeUrl(String url) {
    final match = RegExp(
      r'^https?://github\.com/([^/]+/[^/]+)/(blob|raw)/(.+)$',
    ).firstMatch(url);
    if (match == null) return url;
    return 'https://raw.githubusercontent.com/${match.group(1)}/${match.group(3)}';
  }

  /// Ejecuta el script Lua, recorre `page.body` (bucle) y devuelve el modelo.
  PageModel load(String code) {
    _values.clear();
    _lua = LuaState.newState();
    _lua.openLibs();
    _registerGlobals();
    final status = _lua.loadString(code);
    if (status != ThreadStatus.luaOk) {
      throw Exception('El script Lua no compiló (status: $status)');
    }
    _lua.call(0, 0);
    return _parsePage();
  }

  /// Invoca un handler (función Lua) definido en `page.handlers`.
  void invokeHandler(String name) {
    _lua.getGlobal('page');
    _lua.getField(-1, 'handlers');
    if (!_lua.isTable(-1)) {
      _lua.pop(2); // handlers no definido + page
      return;
    }
    _lua.getField(-1, name);
    if (_lua.isFunction(-1)) {
      _lua.pCall(0, 0, 0);
      _lua.pop(2); // fn + handlers + page
    } else {
      _lua.pop(3); // fn no-función + handlers + page
    }
  }

  // ---------------------------------------------------------------- globals

  void _registerGlobals() {
    _registerSync('engine_get', _luaEngineGet);
    _registerSync('engine_set', _luaEngineSet);
    _registerSync('navigate', _luaNavigate);
    _registerSync('rust_greet', _luaRustGreet);
    _registerSync('rust_sum', _luaRustSum);
    _registerSync('rust_fibonacci', _luaRustFibonacci);
    if (mediaPlayer != null) {
      _registerSync('player_pick', _luaPlayerPick);
      _registerSync('player_open', _luaPlayerOpen);
      _registerSync('player_play', _luaPlayerPlay);
      _registerSync('player_pause', _luaPlayerPause);
      _registerSync('player_toggle', _luaPlayerToggle);
      _registerSync('player_stop', _luaPlayerStop);
      _registerSync('player_status', _luaPlayerStatus);
    }
  }

  void _registerSync(String name, int Function(LuaState) fn) {
    _lua.pushDartFunction(fn);
    _lua.setGlobal(name);
  }

  int _luaEngineGet(LuaState ls) {
    final id = ls.checkString(1) ?? '';
    ls.pop(1);
    ls.pushString(_values[id] ?? '');
    return 1;
  }

  int _luaEngineSet(LuaState ls) {
    final id = ls.checkString(1) ?? '';
    final value = ls.checkString(2) ?? '';
    ls.pop(2);
    _values[id] = value;
    onUpdate?.call(id, value);
    return 0;
  }

  int _luaRustGreet(LuaState ls) {
    final name = ls.checkString(1) ?? '';
    ls.pop(1);
    ls.pushString(greet(name: name));
    return 1;
  }

  int _luaRustSum(LuaState ls) {
    final a = ls.checkInteger(1) ?? 0;
    final b = ls.checkInteger(2) ?? 0;
    ls.pop(2);
    ls.pushInteger(sum(a: a, b: b));
    return 1;
  }

  int _luaRustFibonacci(LuaState ls) {
    final n = ls.checkInteger(1) ?? 0;
    ls.pop(1);
    ls.pushInteger(fibonacci(n: n));
    return 1;
  }

  // ----------------------------------------------------------- navegación

  /// `navigate("player")` cambia de página (llama a onNavigate).
  int _luaNavigate(LuaState ls) {
    final page = ls.checkString(1) ?? '';
    ls.pop(1);
    if (page.isNotEmpty) onNavigate?.call(page);
    return 0;
  }

  // -------------------------------------------------------------- player

  /// Abre el selector de archivos de Android y reproduce lo elegido.
  int _luaPlayerPick(LuaState ls) {
    ls.pop(0);
    mediaPlayer!.pickAndPlay();
    return 0;
  }

  /// Reproduce una ruta, p. ej. player_open("/storage/emulated/0/Music/x.mp3").
  int _luaPlayerOpen(LuaState ls) {
    final path = ls.checkString(1) ?? '';
    ls.pop(1);
    if (path.isNotEmpty) mediaPlayer!.openPath(path);
    return 0;
  }

  int _luaPlayerPlay(LuaState ls) {
    ls.pop(0);
    mediaPlayer!.play();
    return 0;
  }

  int _luaPlayerPause(LuaState ls) {
    ls.pop(0);
    mediaPlayer!.pause();
    return 0;
  }

  int _luaPlayerToggle(LuaState ls) {
    ls.pop(0);
    mediaPlayer!.playOrPause();
    return 0;
  }

  int _luaPlayerStop(LuaState ls) {
    ls.pop(0);
    mediaPlayer!.stop();
    return 0;
  }

  /// Devuelve el estado actual del reproductor.
  int _luaPlayerStatus(LuaState ls) {
    ls.pop(0);
    ls.pushString(mediaPlayer!.status);
    return 1;
  }

  // ---------------------------------------------------------------- parsing

  /// Lee la tabla global `page` y recorre `page.body` (bucle sobre
  /// `body_count`) convirtiendo cada nodo en un [GuiNode].
  PageModel _parsePage() {
    _lua.getGlobal('page');
    if (!_lua.isTable(-1)) {
      final got = _lua.isNil(-1) ? 'nil' : _lua.typeName2(-1);
      _lua.pop(1);
      throw Exception('El script no definió la tabla global "page" ($got)');
    }
    final title = _field(-1, 'title') as String? ?? 'Página';
    final count = (_field(-1, 'body_count') as num?)?.toInt() ?? 0;

    _lua.getField(-1, 'body');
    final body = <GuiNode>[];
    for (var i = 1; i <= count; i++) {
      _lua.getI(-1, i);
      body.add(GuiNode.fromMap(_readNodeMap()));
      _lua.pop(1);
    }
    _lua.pop(1); // body
    _lua.pop(1); // page
    return PageModel(title: title, body: body);
  }

  /// Lee los campos de un nodo (la tabla en el tope de la pila) a un mapa.
  Map<String, Object?> _readNodeMap() {
    final m = <String, Object?>{};
    for (final k in [
      'type', 'id', 'text', 'label', 'value', 'on_click', 'align',
      'color', 'bg_color', 'border_color', 'src', 'fit',
    ]) {
      final v = _field(-1, k);
      if (v != null) m[k] = v;
    }
    for (final k in ['width', 'height', 'padding', 'radius', 'border_width', 'space']) {
      final v = _field(-1, k);
      if (v != null) m[k] = v;
    }
    for (final k in ['bold', 'italic']) {
      final v = _field(-1, k);
      if (v != null) m[k] = v;
    }
    final font = _fieldTable(-1, 'font');
    if (font != null) m['font'] = font;
    return m;
  }

  /// Lee un campo escalar (string/número/booleano) de la tabla en `idx`.
  Object? _field(int idx, String key) {
    _lua.getField(idx, key);
    Object? v;
    if (_lua.isString(-1)) {
      v = _lua.toStr(-1);
    } else if (_lua.isInteger(-1)) {
      v = _lua.toInteger(-1);
    } else if (_lua.isNumber(-1)) {
      v = _lua.toNumber(-1);
    } else if (_lua.isBoolean(-1)) {
      v = _lua.toBoolean(-1);
    }
    _lua.pop(1);
    return v;
  }

  /// Lee un campo que es una sub-tabla (p. ej. `font`) y devuelve su mapa.
  Map<String, Object?>? _fieldTable(int idx, String key) {
    _lua.getField(idx, key);
    if (!_lua.isTable(-1)) {
      _lua.pop(1);
      return null;
    }
    final m = <String, Object?>{};
    for (final k in ['family', 'size', 'bold', 'italic', 'color']) {
      final v = _field(-1, k);
      if (v != null) m[k] = v;
    }
    _lua.pop(1);
    return m;
  }
}
