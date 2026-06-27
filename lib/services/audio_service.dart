import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // Pre-initialize static player instances for instant playback without creation lag
  static final AudioPlayer _launchPlayer = AudioPlayer();
  static final AudioPlayer _habitPlayer = AudioPlayer();
  static final AudioPlayer _melodyPlayer = AudioPlayer();
  static final AudioPlayer _workoutPlayer = AudioPlayer();
  static final AudioPlayer _incomePlayer = AudioPlayer();

  static void init() {
    try {
      // Warm up volumes beforehand
      _launchPlayer.setVolume(0.25);
      _habitPlayer.setVolume(0.25);
      _melodyPlayer.setVolume(0.25);
      _workoutPlayer.setVolume(0.25);
      _incomePlayer.setVolume(0.25);
    } catch (_) {}
  }

  static Future<void> playLaunch() async {
    try {
      await _launchPlayer.stop();
      await _launchPlayer.play(AssetSource('sounds/chime.mp3'));
    } catch (_) {}
  }

  static Future<void> playHabitComplete() async {
    try {
      await _habitPlayer.stop();
      await _habitPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (_) {}
  }

  static Future<void> playAllHabitsDone() async {
    try {
      await _melodyPlayer.stop();
      await _melodyPlayer.play(AssetSource('sounds/melody.mp3'));
    } catch (_) {}
  }

  static Future<void> playWorkoutSetComplete() async {
    try {
      await _workoutPlayer.stop();
      await _workoutPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {}
  }

  static Future<void> playRestTimerEnd() async {
    try {
      await _launchPlayer.stop();
      await _launchPlayer.play(AssetSource('sounds/chime.mp3'));
    } catch (_) {}
  }

  static Future<void> playIncomeLogged() async {
    try {
      await _incomePlayer.stop();
      await _incomePlayer.play(AssetSource('sounds/coin.mp3'));
    } catch (_) {}
  }
}
