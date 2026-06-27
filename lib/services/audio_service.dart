import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static Future<void> _play(String assetPath) async {
    try {
      final player = AudioPlayer();
      await player.setVolume(0.25); // Subtle, low volume
      await player.play(AssetSource(assetPath));
      // Dispose the player once the sound is finished to avoid memory leaks
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (_) {}
  }

  static Future<void> playLaunch() async {
    await _play('sounds/chime.mp3');
  }

  static Future<void> playHabitComplete() async {
    await _play('sounds/pop.mp3');
  }

  static Future<void> playAllHabitsDone() async {
    await _play('sounds/melody.mp3');
  }

  static Future<void> playWorkoutSetComplete() async {
    await _play('sounds/beep.mp3');
  }

  static Future<void> playRestTimerEnd() async {
    await _play('sounds/chime.mp3');
  }

  static Future<void> playIncomeLogged() async {
    await _play('sounds/coin.mp3');
  }
}
