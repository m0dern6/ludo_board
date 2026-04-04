import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPlayers = List.generate(5, (_) => AudioPlayer());
  int _nextSfx = 0;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  Future<void> init() async {
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void updateSettings(bool music, bool sfx) {
    _musicEnabled = music;
    _sfxEnabled = sfx;
    
    if (!_musicEnabled) {
      pauseBgm();
    } else {
      resumeBgm();
    }
  }

  void pauseBgm() {
    _bgmPlayer.pause();
  }

  void resumeBgm() {
    if (_musicEnabled) {
      _bgmPlayer.resume();
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
       print("Error stopping BGM: $e");
    }
  }

  Future<void> startBgm() async {
    if (!_musicEnabled) return;
    try {
      await _bgmPlayer.play(AssetSource('audio/bgm.mp3'));
    } catch (e) {
      print("Error starting BGM: $e");
    }
  }

  Future<void> playSfx(String path) async {
    if (!_sfxEnabled) return;
    try {
      final player = _sfxPlayers[_nextSfx];
      await player.stop(); // Stop before play to avoid overlapping issues on some platforms
      await player.play(AssetSource(path));
      _nextSfx = (_nextSfx + 1) % _sfxPlayers.length;
    } catch (e) {
      print("Error playing SFX: $e");
    }
  }

  // Pre-defined SFX methods
  void playDice() => playSfx('audio/dice_roll.mp3');
  void playMove() => playSfx('audio/move.mp3');
  void playCapture() => playSfx('audio/capture.mp3');
  void playVictory() => playSfx('audio/victory.mp3');
  void playClick() => playSfx('audio/click.mp3');

  Future<void> stopAllSfx() async {
    for (var p in _sfxPlayers) {
      try {
        await p.stop();
      } catch (e) {
        print("Error stopping SFX cleanup: $e");
      }
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    for (var p in _sfxPlayers) {
      p.dispose();
    }
  }
}
