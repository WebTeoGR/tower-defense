import 'package:audioplayers/audioplayers.dart';

import 'sound_generator.dart';

export 'sound_generator.dart' show SoundType;

/// Singleton that manages all BGM and SFX playback.
/// Call [init] once at startup to pre-generate all audio bytes.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // ─── Pre-generated WAV bytes for every sound ───────────────────────────────
  final Map<SoundType, BytesSource> _cache = {};

  // ─── BGM player (single, looping) ─────────────────────────────────────────
  AudioPlayer? _bgmPlayer;
  SoundType? _currentBgm;

  // ─── SFX player pool (round-robin to allow overlapping sounds) ────────────
  static const _poolSize = 10;
  late final List<AudioPlayer> _pool;
  int _poolIdx = 0;

  // ─── Settings ──────────────────────────────────────────────────────────────
  bool isMuted = false;
  double bgmVolume = 0.35;
  double sfxVolume = 0.72;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Generate all audio bytes once (pure Dart maths — fast)
    for (final type in SoundType.values) {
      _cache[type] = BytesSource(SoundGenerator.generate(type));
    }

    // Pre-create the SFX pool so first-play has no latency
    _pool = List.generate(_poolSize, (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
  }

  void dispose() {
    _bgmPlayer?.dispose();
    for (final p in _pool) {
      p.dispose();
    }
  }

  // ─── BGM ───────────────────────────────────────────────────────────────────

  Future<void> playBgm(SoundType type) async {
    if (_currentBgm == type) return; // already playing this track
    _currentBgm = type;

    await _bgmPlayer?.stop();
    _bgmPlayer?.dispose();
    _bgmPlayer = AudioPlayer();

    await _bgmPlayer!.setVolume(isMuted ? 0 : bgmVolume);
    await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer!.play(_cache[type]!);
  }

  Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer?.stop();
  }

  Future<void> pauseBgm() async => _bgmPlayer?.pause();
  Future<void> resumeBgm() async {
    if (!isMuted) await _bgmPlayer?.resume();
  }

  // ─── SFX ───────────────────────────────────────────────────────────────────

  Future<void> playSfx(SoundType type) async {
    if (isMuted) return;
    final player = _pool[_poolIdx % _poolSize];
    _poolIdx++;
    await player.stop();
    await player.setVolume(sfxVolume);
    await player.play(_cache[type]!);
  }

  // ─── Mute toggle ───────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _bgmPlayer?.setVolume(isMuted ? 0 : bgmVolume);
  }
}
