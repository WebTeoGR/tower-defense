import 'dart:math';
import 'dart:typed_data';

/// All sounds used in the game.
enum SoundType {
  bgmMenu,
  bgmForest,
  bgmDesert,
  bgmVolcano,
  sfxCannonFire,
  sfxSniperFire,
  sfxMortarFire,
  sfxExplosion,
  sfxEnemyDie,
  sfxEnemyEscape,
  sfxTowerPlace,
  sfxWaveStart,
  sfxGameOver,
  sfxVictory,
  sfxButtonClick,
}

/// Generates PCM audio as WAV bytes entirely in code — no asset files required.
/// Every sound is synthesised from sine waves, square waves, and noise.
class SoundGenerator {
  static const int _sr = 22050; // sample rate Hz
  static final _rng = Random(0xBEEF);

  // ─── Public entry point ────────────────────────────────────────────────────

  static Uint8List generate(SoundType type) => _toWav(_build(type));

  // ─── Dispatch ──────────────────────────────────────────────────────────────

  static List<double> _build(SoundType type) => switch (type) {
        SoundType.sfxButtonClick => _tone(1200, 0.05, amp: 0.55, decay: 0.9),
        SoundType.sfxTowerPlace => _glide(320, 740, 0.18, amp: 0.65),
        SoundType.sfxCannonFire =>
          _mix([_noise(0.24, amp: 0.75, envDecay: 11), _tone(100, 0.24, amp: 0.38, decay: 0.88)]),
        SoundType.sfxSniperFire =>
          _mix([_tone(2100, 0.08, amp: 0.72, decay: 0.96), _noise(0.06, amp: 0.22, envDecay: 28)]),
        SoundType.sfxMortarFire =>
          _mix([_tone(62, 0.34, amp: 0.78, decay: 0.92), _noise(0.18, amp: 0.48, envDecay: 8)]),
        SoundType.sfxExplosion =>
          _mix([_noise(0.6, amp: 0.88, envDecay: 4.5), _tone(82, 0.5, amp: 0.48, decay: 0.92)]),
        SoundType.sfxEnemyDie => _glide(460, 65, 0.28, amp: 0.65),
        SoundType.sfxEnemyEscape => _seq([
            _tone(840, 0.09, amp: 0.65, decay: 0.5),
            _silence(0.04),
            _tone(840, 0.09, amp: 0.65, decay: 0.5),
            _silence(0.04),
          ]),
        SoundType.sfxWaveStart =>
          _arpeggio(const [261.63, 329.63, 392.00, 523.25], 0.13, amp: 0.65),
        SoundType.sfxGameOver =>
          _arpeggio(const [523.25, 392.00, 329.63, 261.63, 196.00], 0.22, amp: 0.65),
        SoundType.sfxVictory => _seq([
            _arpeggio(const [261.63, 329.63, 392.00, 523.25], 0.12, amp: 0.68),
            _tone(523.25, 0.4, amp: 0.62, decay: 0.82),
          ]),
        SoundType.bgmMenu => _bgm(_menuNotes, 70),
        SoundType.bgmForest => _bgm(_forestNotes, 100),
        SoundType.bgmDesert => _bgm(_desertNotes, 125),
        SoundType.bgmVolcano => _bgm(_volcanoNotes, 165),
      };

  // ─── BGM note tables ───────────────────────────────────────────────────────
  // Each list is 16 quarter-note frequencies.  0.0 = rest.

  static const _menuNotes = [
    220.00, 261.63, 329.63, 261.63, // A3 C4 E4 C4
    220.00, 196.00, 220.00, 246.94, // A3 G3 A3 B3
    246.94, 293.66, 369.99, 293.66, // B3 D4 F#4 D4
    246.94, 220.00, 196.00, 174.61, // B3 A3 G3 F3
  ];

  static const _forestNotes = [
    392.00, 493.88, 587.33, 493.88, // G4 B4 D5 B4
    392.00, 329.63, 261.63, 329.63, // G4 E4 C4 E4
    440.00, 523.25, 659.25, 523.25, // A4 C5 E5 C5
    392.00, 329.63, 293.66, 261.63, // G4 E4 D4 C4
  ];

  static const _desertNotes = [
    293.66, 349.23, 440.00, 349.23, // D4 F4 A4 F4
    293.66, 246.94, 220.00, 246.94, // D4 B3 A3 B3
    329.63, 392.00, 493.88, 392.00, // E4 G4 B4 G4
    329.63, 293.66, 246.94, 220.00, // E4 D4 B3 A3
  ];

  static const _volcanoNotes = [
    329.63, 392.00, 493.88, 392.00, // E4 G4 B4 G4
    329.63, 293.66, 329.63, 293.66, // E4 D4 E4 D4
    246.94, 293.66, 369.99, 293.66, // B3 D4 F#4 D4
    246.94, 220.00, 196.00, 220.00, // B3 A3 G3 A3
  ];

  // ─── BGM synthesis ─────────────────────────────────────────────────────────

  static List<double> _bgm(List<double> notes, int bpm) {
    final noteDur = 60.0 / bpm; // seconds per quarter note
    final totalSamples = (noteDur * notes.length * _sr).round();
    final out = List.filled(totalSamples, 0.0);

    for (int ni = 0; ni < notes.length; ni++) {
      final freq = notes[ni];
      final start = (ni * noteDur * _sr).round();
      final end = ((ni + 1) * noteDur * _sr).round().clamp(0, totalSamples);
      final len = end - start;
      final rel = (len * 0.25).round(); // 25% release

      for (int i = 0; i < len; i++) {
        final t = (start + i) / _sr;
        // Softened square wave (odd harmonics only — classic chiptune)
        final sq = sin(2 * pi * freq * t) >= 0 ? 1.0 : -1.0;
        // Add a quieter octave below for warmth
        final lower = sin(2 * pi * (freq / 2) * t);
        final env = i < len - rel ? 1.0 : (len - i) / rel;
        out[start + i] = (sq * 0.55 + lower * 0.25) * env;
      }
    }

    _normalise(out, 0.72);
    return out;
  }

  // ─── Primitive generators ──────────────────────────────────────────────────

  /// Sine-wave tone with a simple attack + exponential-ish decay envelope.
  /// [decay] is the fraction of [duration] used for the release.
  static List<double> _tone(
    double freq,
    double duration, {
    double amp = 1.0,
    double decay = 0.7,
    double attack = 0.01,
  }) {
    final n = (duration * _sr).round();
    final attackN = (attack * _sr).round();
    final releaseN = (decay * n).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      double env;
      if (i < attackN) {
        env = i / attackN;
      } else if (i >= n - releaseN) {
        env = (n - i) / releaseN;
      } else {
        env = 1.0;
      }
      return sin(2 * pi * freq * t) * env * amp;
    });
  }

  /// Frequency-glide (portamento) from [startFreq] to [endFreq].
  static List<double> _glide(
    double startFreq,
    double endFreq,
    double duration, {
    double amp = 1.0,
  }) {
    final n = (duration * _sr).round();
    double phase = 0;
    return List.generate(n, (i) {
      final progress = i / n;
      final env = 1.0 - progress * 0.95;
      final freq = startFreq + (endFreq - startFreq) * progress;
      final sample = sin(phase) * env * amp;
      phase += 2 * pi * freq / _sr;
      if (phase > 2 * pi) phase -= 2 * pi;
      return sample;
    });
  }

  /// White noise with exponential volume decay.
  static List<double> _noise(
    double duration, {
    double amp = 1.0,
    double envDecay = 10.0,
  }) {
    final n = (duration * _sr).round();
    return List.generate(n, (i) {
      final t = i / _sr;
      final env = exp(-envDecay * t);
      return (_rng.nextDouble() * 2 - 1) * env * amp;
    });
  }

  /// Silent gap.
  static List<double> _silence(double duration) =>
      List.filled((duration * _sr).round(), 0.0);

  /// Sequence of tones (musical notes), each with a tiny gap.
  static List<double> _arpeggio(
    List<double> freqs,
    double noteDuration, {
    double amp = 1.0,
    double gapFrac = 0.15,
  }) {
    final gap = noteDuration * gapFrac;
    final noteLen = noteDuration - gap;
    return _seq(freqs.map((f) => [..._tone(f, noteLen, amp: amp, decay: 0.6), ..._silence(gap)]).toList());
  }

  /// Concatenate a list of sample arrays.
  static List<double> _seq(List<List<double>> parts) {
    final out = <double>[];
    for (final p in parts) {
      out.addAll(p);
    }
    return out;
  }

  /// Mix (sum) multiple same-length or different-length sample arrays.
  static List<double> _mix(List<List<double>> sources) {
    final len = sources.fold(0, (m, s) => s.length > m ? s.length : m);
    final out = List.filled(len, 0.0);
    for (final src in sources) {
      for (int i = 0; i < src.length; i++) {
        out[i] += src[i];
      }
    }
    _normalise(out, 0.92);
    return out;
  }

  static void _normalise(List<double> s, double target) {
    double peak = s.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);
    if (peak < 0.001) return;
    final scale = target / peak;
    for (int i = 0; i < s.length; i++) {
      s[i] *= scale;
    }
  }

  // ─── WAV encoder ───────────────────────────────────────────────────────────

  static Uint8List _toWav(List<double> samples) {
    final data = ByteData(44 + samples.length * 2);

    void str(int off, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _sr, Endian.little);
    data.setUint32(28, _sr * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }

    return data.buffer.asUint8List();
  }
}
