import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../tower_defense_game.dart';
import '../utils/constants.dart';

/// HUD lives in the camera viewport (screen space).
/// All stats are read from the game every frame — no manual refresh needed.
class HudComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  HudComponent() : super(priority: 100);

  static const double hudHeight = 52.0;

  late TextComponent _goldText;
  late TextComponent _livesText;
  late TextComponent _scoreText;
  late TextComponent _waveText;
  late TextComponent _hintText;
  late TextComponent _toastText;
  late TextComponent _countdownText;

  double _toastTimer = 0.0;
  static const double _toastDuration = 2.0;

  @override
  Future<void> onLoad() async {
    size = game.size;

    // ── Background bar ────────────────────────────────────────────────────────
    add(RectangleComponent(
      size: Vector2(size.x, hudHeight),
      paint: Paint()..color = GameConstants.colorHudBg,
    ));

    // Cyan separator line under bar
    add(RectangleComponent(
      position: Vector2(0, hudHeight),
      size: Vector2(size.x, 1),
      paint: Paint()..color = const Color(0xFF00BCD4).withAlpha(80),
    ));

    // ── Stat labels ───────────────────────────────────────────────────────────
    _goldText = TextComponent(
      position: Vector2(10, 8),
      textRenderer: TextPaint(
        style: TextStyle(
          color: GameConstants.colorGold,
          fontSize: 15,
          shadows: const [Shadow(blurRadius: 4)],
        ),
      ),
    );

    _livesText = TextComponent(
      position: Vector2(size.x * 0.30, 8),
      textRenderer: TextPaint(
        style: TextStyle(
          color: GameConstants.colorLives,
          fontSize: 15,
          shadows: const [Shadow(blurRadius: 4)],
        ),
      ),
    );

    _scoreText = TextComponent(
      position: Vector2(size.x * 0.52, 8),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          shadows: [Shadow(blurRadius: 4)],
        ),
      ),
    );

    _waveText = TextComponent(
      position: Vector2(size.x * 0.74, 8),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF80DEEA),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4)],
        ),
      ),
    );

    _hintText = TextComponent(
      position: Vector2(10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );

    // ── Toast (centred, shown briefly) ────────────────────────────────────────
    _toastText = TextComponent(
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.45),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      priority: 10,
    );

    // ── Wave countdown ────────────────────────────────────────────────────────
    _countdownText = TextComponent(
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y - GameConstants.buildPanelHeight - 40),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFEB3B),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4)],
        ),
      ),
    );

    addAll([
      _goldText,
      _livesText,
      _scoreText,
      _waveText,
      _hintText,
      _toastText,
      _countdownText,
    ]);
  }

  // ─── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Stat bar — read live from game every frame.
    _goldText.text = 'Gold: ${game.gold}';
    _livesText.text = 'Lives: ${game.lives}';
    _scoreText.text = 'Score: ${game.score}';
    _waveText.text = game.isWaveActive
        ? 'Wave ${game.currentWave}'
        : 'Wave ${game.currentWave + 1}';
    _hintText.text =
        'Tap: ${game.selectedTowerType.displayName} (${game.selectedTowerType.cost}g)';

    // Toast fade-out.
    if (_toastTimer > 0) {
      _toastTimer -= dt;
      if (_toastTimer <= 0) _toastText.text = '';
    }

    // Countdown only between waves.
    if (!game.isWaveActive && !game.isGameOver && game.waveCountdown > 0) {
      _countdownText.text = 'Next wave in ${game.waveCountdown.ceil()} s';
    } else {
      _countdownText.text = '';
    }
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  void showMessage(String msg) {
    _toastText.text = msg;
    _toastTimer = _toastDuration;
  }
}
