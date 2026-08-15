import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pr_app/src/rust/api/laurelia.dart';

/// Chat LLM Laurelia: descarga el modelo desde HuggingFace por HTTP
/// (mismo flujo que `laurelia_example.gd` de Godot) y delega la inferencia
/// en Rust (Candle) vía flutter_rust_bridge.
///
///   const ckpt = 'checkpoint.pt'; // o 'fine-checkpoint.pt'
///   final chat = LaureliaChat();
///   await chat.download();   // descarga lo que falte
///   await chat.load();       // carga tokenizer + checkpoint
///   final out = await chat.generate('Hola!', maxNewTokens: 100);
class LaureliaChat {
  static const baseUrl = 'https://huggingface.co/ScortexIA/laurelia/resolve/laurelia-llm/';
  static const ckpt = 'checkpoint.pt';
  static const ckptFine = 'fine-checkpoint.pt';
  static const tok = 'tokenizer.json';
  static const dirName = 'hf_models/laurelia';

  /// Qué checkpoint se usa: base o fine.
  bool fine = false;

  bool _loaded = false;
  int _downloadedBytes = 0;
  String? _status;
  String? _dirPath;

  String get status => _status ?? '';
  bool get loaded => _loaded;
  int get downloadedBytes => _downloadedBytes;
  String? get dirPath => _dirPath;

  String _ckpt() => fine ? ckptFine : ckpt;

  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dirPath = dir.path;
    return dir;
  }

  Future<String> _path(String name) async =>
      '${(await _dir()).path}/$name';

  /// Qué archivos faltan (para descargar). Vacío si ya están todos.
  Future<List<String>> _missing() async {
    final missing = <String>[];
    for (final f in [_ckpt(), tok]) {
      if (!await File(await _path(f)).exists()) missing.add(f);
    }
    return missing;
  }

  bool _progress(String msg) {
    _status = msg;
    onProgress?.call(msg);
    return true;
  }

  /// Descarga por HTTP los archivos que falten (checkpoint + tokenizer).
  /// Reusa el estado guardado si ya están en disco.
  Future<bool> download() async {
    _progress('Descargando…');
    var missing = await _missing();
    while (missing.isNotEmpty) {
      final name = missing.first;
      _progress('Descargando $name…');
      final res = await http.get(Uri.parse(baseUrl + name));
      if (res.statusCode != 200) {
        _progress('Error HTTP ${res.statusCode} al descargar $name');
        return false;
      }
      _downloadedBytes += res.bodyBytes.length;
      await File(await _path(name)).writeAsBytes(res.bodyBytes);
      missing = await _missing();
    }
    _progress('Modelo descargado. Tocá Cargar.');
    return true;
  }

  /// Estado real en disco: tamaño de cada archivo y si falta alguno.
  Future<Map<String, Object?>> diskInfo() async {
    final dir = await _dir();
    final files = [_ckpt(), tok];
    final info = <String, Object?>{
      'dir': dir.path,
      'files': <Map<String, Object?>>[],
      'total_bytes': 0,
      'complete': false,
    };
    var total = 0;
    final fileInfos = <Map<String, Object?>>[];
    for (final f in files) {
      final file = File('${dir.path}/$f');
      final size = file.existsSync() ? file.lengthSync() : -1;
      if (size > 0) total += size;
      fileInfos.add({'name': f, 'size': size});
    }
    info['files'] = fileInfos;
    info['total_bytes'] = total;
    info['complete'] = fileInfos.every((f) => (f['size'] as int) > 0);
    return info;
  }

  String _fmt(int bytes) {
    if (bytes < 0) return 'no';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Texto de estado detallado para mostrar en la GUI de Lua.
  Future<String> detailedStatus() async {
    final info = await diskInfo();
    final files = info['files'] as List;
    final parts = <String>[];
    parts.add('Dir: ${info['dir']}');
    for (final f in files.cast<Map<String, Object?>>()) {
      parts.add('${f['name']}: ${_fmt((f['size'] as int))}');
    }
    final complete = info['complete'] as bool;
    parts.add('Total: ${_fmt(info['total_bytes'] as int)}');
    parts.add('Descarga: ${complete ? 'completa' : 'INCOMPLETA'}');
    parts.add('Rust: ${_loaded ? 'modelo cargado' : 'no cargado'}');
    return parts.join('\n');
  }

  /// Carga tokenizer + checkpoint en Rust.
  Future<bool> load() async {
    if ((await _missing()).isNotEmpty) {
      _progress('Primero descargá el modelo.');
      return false;
    }
    _progress('Cargando modelo…');
    final ok = await laureliaLoadModel(
      ckptPath: await _path(_ckpt()),
      tokenizerPath: await _path(tok),
    );
    _loaded = ok;
    _progress(ok ? 'Modelo cargado. Tocá Generar.' : 'Error al cargar. Mirá la consola.');
    return ok;
  }

  /// Cuenta los tokens que representaría un texto (necesita tokenizer).
  Future<int> countTokens(String text) async {
    if (!_loaded && (await _missing()).isNotEmpty) return -1;
    if (!_loaded) await laureliaLoadTokenizer(tokenizerPath: await _path(tok));
    return await laureliaCountTokens(text: text);
  }

  /// Genera texto. Los parámetros tienen defaults iguales al ejemplo Godot.
  Future<String> generate(
    String prompt, {
    int maxNewTokens = 50,
    double temperature = 0.7,
    int topK = 40,
    double topP = 0.9,
    double repetitionPenalty = 1.2,
  }) async {
    return laureliaGenerate(
      prompt: prompt,
      maxNewTokens: maxNewTokens,
      temperature: temperature,
      topK: topK,
      topP: topP,
      repetitionPenalty: repetitionPenalty,
    );
  }

  Future<bool> isLoaded() async => _loaded && await laureliaIsLoaded();

  Future<String> modelInfo() async => laureliaModelInfo();

  Future<int> vocabSize() async => laureliaVocabSize();

  Future<void> unload() async {
    await laureliaUnloadModel();
    _loaded = false;
    _progress('Modelo liberado.');
  }

  /// Callback de progreso (para actualizar la UI desde Lua).
  void Function(String msg)? onProgress;

  /// Serializa los datos de estado para mostrarlos en Lua.
  String stateJson() {
    return jsonEncode({
      'loaded': _loaded,
      'downloaded_bytes': _downloadedBytes,
      'status': _status,
    });
  }
}
