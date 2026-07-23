import '../../../../core/audio/ambient_music_service.dart';

class GameMusicService {
  GameMusicService({AmbientMusicService? ambientMusicService})
    : _ambientMusicService =
          ambientMusicService ?? AmbientMusicService.instance;

  final AmbientMusicService _ambientMusicService;

  Future<void> initialize({required bool playWhenReady}) async {
    if (playWhenReady) {
      await _ambientMusicService.ensurePlaying();
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _ambientMusicService.setEnabled(enabled);

  // Ambient music is application-scoped and must survive screen disposal.
  Future<void> dispose() async {}
}
