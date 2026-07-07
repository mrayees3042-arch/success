import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium sound manager that generates short, subtle sine-wave sounds
/// programmatically and plays them via AudioPlayer with sonification attributes.
/// All sounds are designed to feel like mechanical clicks — not digital beeps.
class SoundManager {
  static const _prefsKey = 'sounds_enabled';
  static bool _enabled = true;
  static bool _initialized = false;

  // Pre-created players for zero-latency playback
  static final AudioPlayer _tapPlayer = AudioPlayer();
  static final AudioPlayer _counterPlayer = AudioPlayer();
  static final AudioPlayer _setCompletePlayer = AudioPlayer();
  static final AudioPlayer _exerciseCompletePlayer = AudioPlayer();
  static final AudioPlayer _workoutCompletePlayer = AudioPlayer();

  // Pre-generated WAV byte data
  static Uint8List? _tapClickWav;
  static Uint8List? _counterTickWav;
  static Uint8List? _setCompleteWav;
  static Uint8List? _exerciseCompleteWav;
  static Uint8List? _workoutCompleteWav;

  /// Initialize: load preference and pre-generate all sound data
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      _enabled = true;
    }

    // Configure AudioContext to prevent audio focus theft
    final context = AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.assistanceSonification,
        contentType: AndroidContentType.sonification,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: [AVAudioSessionOptions.mixWithOthers],
      ),
    );
    try {
      _tapPlayer.setAudioContext(context);
      _counterPlayer.setAudioContext(context);
      _setCompletePlayer.setAudioContext(context);
      _exerciseCompletePlayer.setAudioContext(context);
      _workoutCompletePlayer.setAudioContext(context);
    } catch (_) {}

    // Generate all WAV data
    _tapClickWav = _generateTapClick();
    _counterTickWav = _generateCounterTick();
    _setCompleteWav = _generateSetComplete();
    _exerciseCompleteWav = _generateExerciseComplete();
    _workoutCompleteWav = _generateWorkoutComplete();

    // Set low volume for all players (subtle sounds)
    _tapPlayer.setVolume(0.3);
    _counterPlayer.setVolume(0.35);
    _setCompletePlayer.setVolume(0.3);
    _exerciseCompletePlayer.setVolume(0.3);
    _workoutCompletePlayer.setVolume(0.3);

    _initialized = true;
  }

  static bool get isEnabled => _enabled;

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  // ── PLAY METHODS ──

  /// Very short click for button taps, nav switches, toggles
  static Future<void> playTapClick() async {
    if (!_enabled || _tapClickWav == null) return;
    try {
      await _tapPlayer.stop();
      await _tapPlayer.play(BytesSource(_tapClickWav!));
    } catch (_) {}
  }

  /// Sharper click for rep counter TAP button
  static Future<void> playCounterTick() async {
    if (!_enabled || _counterTickWav == null) return;
    try {
      await _counterPlayer.stop();
      await _counterPlayer.play(BytesSource(_counterTickWav!));
    } catch (_) {}
  }

  /// Two-note ascending for set completion
  static Future<void> playSetComplete() async {
    if (!_enabled || _setCompleteWav == null) return;
    try {
      await _setCompletePlayer.stop();
      await _setCompletePlayer.play(BytesSource(_setCompleteWav!));
    } catch (_) {}
  }

  /// Three-note ascending for exercise completion
  static Future<void> playExerciseComplete() async {
    if (!_enabled || _exerciseCompleteWav == null) return;
    try {
      await _exerciseCompletePlayer.stop();
      await _exerciseCompletePlayer.play(BytesSource(_exerciseCompleteWav!));
    } catch (_) {}
  }

  /// Four-note arpeggio for full workout completion
  static Future<void> playWorkoutComplete() async {
    if (!_enabled || _workoutCompleteWav == null) return;
    try {
      await _workoutCompletePlayer.stop();
      await _workoutCompletePlayer.play(BytesSource(_workoutCompleteWav!));
    } catch (_) {}
  }

  // ── WAV GENERATION ──

  /// Generate a WAV file from PCM 16-bit mono samples at 44100Hz
  static Uint8List _buildWav(List<double> samples) {
    const sampleRate = 44100;
    const bitsPerSample = 16;
    const numChannels = 1;
    final dataSize = samples.length * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // (space)
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(
      offset,
      sampleRate * numChannels * bitsPerSample ~/ 8,
      Endian.little,
    ); // byte rate
    offset += 4;
    buffer.setUint16(
      offset,
      numChannels * bitsPerSample ~/ 8,
      Endian.little,
    ); // block align
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Write PCM samples
    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      final intSample = (clamped * 32767).round();
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  /// Generate sine wave samples with exponential decay
  static List<double> _sineWithDecay({
    required double frequency,
    required double durationMs,
    double amplitude = 0.5,
    double decayRate = 10.0,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = <double>[];

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = amplitude * exp(-decayRate * t);
      final value = envelope * sin(2 * pi * frequency * t);
      samples.add(value);
    }
    return samples;
  }

  /// Generate silence samples
  static List<double> _silence(double durationMs) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    return List.filled(numSamples, 0.0);
  }

  /// 1. Tap click — 40ms at 1200Hz, fast decay (like premium keyboard)
  static Uint8List _generateTapClick() {
    final samples = _sineWithDecay(
      frequency: 1200,
      durationMs: 40,
      amplitude: 0.35,
      decayRate: 40.0,
    );
    return _buildWav(samples);
  }

  /// 2. Counter tick — 30ms at 1600Hz, very fast decay (mechanical counter)
  static Uint8List _generateCounterTick() {
    const sampleRate = 44100;
    final numSamples = (sampleRate * 30 / 1000).round();
    final samples = <double>[];
    final rng = Random(42); // Fixed seed for consistency

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = 0.4 * exp(-50.0 * t);
      final sine = sin(2 * pi * 1600 * t);
      final noise = (rng.nextDouble() * 2 - 1) * 0.1; // subtle noise layer
      samples.add(envelope * (sine * 0.85 + noise * 0.15));
    }
    return _buildWav(samples);
  }

  /// 3. Set complete — two ascending notes (800Hz → 1200Hz)
  static Uint8List _generateSetComplete() {
    final note1 = _sineWithDecay(
      frequency: 800,
      durationMs: 60,
      amplitude: 0.3,
      decayRate: 15.0,
    );
    final gap = _silence(40);
    final note2 = _sineWithDecay(
      frequency: 1200,
      durationMs: 60,
      amplitude: 0.35,
      decayRate: 15.0,
    );
    return _buildWav([...note1, ...gap, ...note2]);
  }

  /// 4. Exercise complete — three ascending notes (600 → 900 → 1200)
  static Uint8List _generateExerciseComplete() {
    final note1 = _sineWithDecay(
      frequency: 600,
      durationMs: 50,
      amplitude: 0.3,
      decayRate: 12.0,
    );
    final gap1 = _silence(30);
    final note2 = _sineWithDecay(
      frequency: 900,
      durationMs: 50,
      amplitude: 0.32,
      decayRate: 12.0,
    );
    final gap2 = _silence(30);
    final note3 = _sineWithDecay(
      frequency: 1200,
      durationMs: 50,
      amplitude: 0.35,
      decayRate: 12.0,
    );
    return _buildWav([...note1, ...gap1, ...note2, ...gap2, ...note3]);
  }

  /// 5. Workout complete — four-note arpeggio (500 → 700 → 900 → 1200)
  static Uint8List _generateWorkoutComplete() {
    final note1 = _sineWithDecay(
      frequency: 500,
      durationMs: 80,
      amplitude: 0.25,
      decayRate: 8.0,
    );
    final gap1 = _silence(50);
    final note2 = _sineWithDecay(
      frequency: 700,
      durationMs: 80,
      amplitude: 0.28,
      decayRate: 8.0,
    );
    final gap2 = _silence(50);
    final note3 = _sineWithDecay(
      frequency: 900,
      durationMs: 80,
      amplitude: 0.3,
      decayRate: 8.0,
    );
    final gap3 = _silence(50);
    final note4 = _sineWithDecay(
      frequency: 1200,
      durationMs: 80,
      amplitude: 0.35,
      decayRate: 8.0,
    );
    return _buildWav([
      ...note1,
      ...gap1,
      ...note2,
      ...gap2,
      ...note3,
      ...gap3,
      ...note4,
    ]);
  }
}
