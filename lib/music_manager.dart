import 'package:audioplayers/audioplayers.dart';

class MusicManager {
  // Singleton instance
  static final MusicManager _instance = MusicManager._internal();
  static MusicManager get instance => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = true;

  MusicManager._internal() {
    // Set the release mode to loop so the music replays automatically
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Remove the default 'assets/' prefix because our file is in 'lib/music/'
    AudioCache.instance.prefix = '';
  }

  bool get isPlaying => _isPlaying;

  // Initialize and start playing music
  Future<void> init() async {
    // We start playing immediately when the app starts
    await playMusic();
  }

  Future<void> playMusic() async {
    try {
      await _audioPlayer.play(
        AssetSource('lib/music/Ceylin-H-Bici-Bici-Sarkisi.mp3'),
      );
      _isPlaying = true;
    } catch (e) {
      print("Error playing music: $e");
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
    } catch (e) {
      print("Error pausing music: $e");
    }
  }

  Future<void> toggleMusic() async {
    if (_isPlaying) {
      await pauseMusic();
    } else {
      await playMusic();
    }
  }
}
