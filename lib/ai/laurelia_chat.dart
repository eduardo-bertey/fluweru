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

  String get status => _status ?? '';
  bool get loaded => _loaded;
  int get downloadedBytes => _downloadedBytes;

  String _ckpt() => fine ? ckptFine : ckpt;

  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
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
