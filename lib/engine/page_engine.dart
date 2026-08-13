import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lua_dardo_plus/lua.dart';
import 'package:pr_app/src/rust/api/simple.dart';

/// Página ya parseada: título + lista de nodos de UI.
class PageModel {
  final String title;
  final List<Map<String, Object?>> body;

  PageModel(this.title, this.body);
}

/// Motor de páginas: ejecuta scripts Lua (locales o descargados) que
/// describen la GUI. Lua puede:
///   - engine_get(id)    -> leer el valor actual de un widget
///   - engine_set(id, v) -> actualizar un widget (re-render)
///   - rust_greet/sum/fibonacci -> llamar a las librerías Rust del motor
class PageEngine {
  late LuaState _lua;
  final Map<String, String> _values = {};

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

  /// Ejecuta el script Lua y parsea la tabla global `page`.
  PageModel load(String code) {
    _values.clear();
    _lua = LuaState.newState();
    _lua.openLibs();
    _registerGlobals();
    _lua.loadString(code);
    _lua.call(0, 0);
    return _parsePage();
  }

  /// Invoca un handler (función Lua) definido en `page.handlers`.
  void invokeHandler(String name) {
    _lua.getGlobal('handlers');
    _lua.getField(-1, name);
    if (_lua.isFunction(-1)) {
      _lua.pCall(0, 0, 0);
      _lua.pop(1); // handlers
    } else {
      _lua.pop(2); // fn no-función + handlers
    }
  }

  // ---------------------------------------------------------------- globals

  void _registerGlobals() {
    _registerSync('engine_get', _luaEngineGet);
    _registerSync('engine_set', _luaEngineSet);
    _registerSync('rust_greet', _luaRustGreet);
    _registerSync('rust_sum', _luaRustSum);
    _registerSync('rust_fibonacci', _luaRustFibonacci);
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

  // ---------------------------------------------------------------- parsing

  PageModel _parsePage() {
    _lua.getGlobal('page');
    final title = _getFieldStr('title') ?? 'Página';
    final count = _getFieldInt('body_count') ?? 0;

    final body = <Map<String, Object?>>[];
    _lua.getField(-1, 'body');
    for (var i = 1; i <= count; i++) {
      _lua.getField(-1, '$i');
      body.add(<String, Object?>{
        'type': _getFieldStr('type') ?? 'text',
        'id': _getFieldStr('id'),
        'text': _getFieldStr('text'),
        'label': _getFieldStr('label'),
        'value': _getFieldStr('value'),
        'on_click': _getFieldStr('on_click'),
      });
      _lua.pop(1);
    }
    _lua.pop(1); // body
    _lua.pop(1); // page
    return PageModel(title, body);
  }

  String? _getFieldStr(String key) {
    _lua.getField(-1, key);
    String? result;
    if (_lua.isString(-1)) {
      result = _lua.toStr(-1);
    }
    _lua.pop(1);
    return result;
  }

  int? _getFieldInt(String key) {
    _lua.getField(-1, key);
    int? result;
    if (_lua.isInteger(-1)) {
      result = _lua.toInteger(-1);
    } else if (_lua.isNumber(-1)) {
      result = _lua.toNumber(-1).toInt();
    }
    _lua.pop(1);
    return result;
  }
}