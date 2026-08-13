import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproductor de audio/video basado en media_kit (libmpv + FFmpeg, LGPL).
///
/// Expone operaciones asincrónicas y un caché de estado (strings) para que
/// Lua (síncrono) pueda leer el estado sin bloquearse. Los resultados se
/// empujan a la UI vía [onPush] (id + valor) para que los widgets con `id`
/// se re-rendericen automáticamente.
class MediaPlayer {
  late final Player _player;
  late final VideoController _videoController;

  String _status = 'Sin archivo';
  String _config = '';
  String _current = '';

  /// Empuja un (id, valor) a la GUI cuando algo cambia (config, status...).
  void Function(String id, String value)? onPush;

  /// Notifica a la UI que hubo un cambio de estado.
  void Function()? onChanged;

  VideoController get videoController => _videoController;
  String get status => _status;
  String get current => _current;
  String get config => _config;

  MediaPlayer() {
    _player = Player();
    _videoController = VideoController(_player);
    _subscribe();
    _refreshConfig();
  }

  /// Suscribe streams de libmpv para mantener [_status] al día.
  void _subscribe() {
    _player.stream.error.listen((e) {
      _status = 'Error: $e';
      _push('player_status', _status);
    });
    _player.stream.playing.listen((playing) {
      if (playing) _status = 'Reproduciendo: ${_current}';
      _push('player_status', _status);
    });
    _player.stream.playlist.listen((playlist) {
      if (playlist.medias.isNotEmpty) {
        _current = playlist.medias.first.uri;
        _status = 'Cargado: $_current';
      }
      _push('player_status', _status);
    });
    _player.stream.completed.listen((done) {
      if (done) _status = 'Terminado: $_current';
      _push('player_status', _status);
    });
  }

  /// Pide a libmpv con qué opciones se compiló (debe mostrar --enable-lgpl).
  Future<void> _refreshConfig() async {
    try {
      _config = await _player.getProperty('mpv-configuration');
    } catch (e) {
      _config = 'Error al leer config: $e';
    }
    _push('mpv_cfg', _config);
  }

  /// Recarga mpv-configuration (para el botón de verificación).
  Future<void> checkConfiguration() => _refreshConfig();

  /// Abre el selector de archivos de Android y reproduce el archivo elegido.
  Future<void> pickAndPlay() async {
    try {
      _status = 'Abriendo selector...';
      _push('player_status', _status);
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        _status = 'Selección cancelada';
        _push('player_status', _status);
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _status = 'Archivo sin ruta accesible';
        _push('player_status', _status);
        return;
      }
      await openPath(path);
    } catch (e) {
      _status = 'Error al abrir: $e';
      _push('player_status', _status);
    }
  }

  /// Reproduce un archivo por ruta (p. ej. /storage/emulated/0/...).
  Future<void> openPath(String path) async {
    try {
      await _player.open(Media(path));
      _current = path;
      _status = 'Reproduciendo: $path';
    } catch (e) {
      _status = 'Error al reproducir: $e';
    }
    _push('player_status', _status);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> playOrPause() => _player.playOrPause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  void _push(String id, String value) {
    onPush?.call(id, value);
    onChanged?.call();
  }

  void dispose() {
    _player.dispose();
  }
}
