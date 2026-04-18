import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextDirection, TextStyle, FontWeight, Shadow;
import 'package:flutter/material.dart' show Colors;

import '../tower_defense_game.dart';
import '../utils/constants.dart';

class HudComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  HudComponent() {
    priority = 100;
  }

  // ─── Toast ─────────────────────────────────────────────────────────────────
  String _message = '';
  double _messageTimer = 0.0;
  static const double _messageDuration = 2.0;

  // ─── Countdown ─────────────────────────────────────────────────────────────
  double _countdown = 0.0;

  // ─── Game-end overlay ──────────────────────────────────────────────────────
  bool _isGameEnd = false;
  bool _isVictory = false;
  int _finalScore = 0;

  final Paint _hudBgPaint = Paint()..color = GameConstants.colorHudBg;
  final Paint _panelPaint = Paint()..color = const Color(0xDD0D0D1A);

  late TextPainter _textPainter;

  static const double _hudHeight = 52.0;
  static const double _padding = 10.0;

  @override
  Future<void> onLoad() async {
    size = game.size;
    _textPainter = TextPainter(textDirection: TextDirection.ltr);
  }

  @override
  void update(double dt) {
    if (_messageTimer > 0) {
      _messageTimer -= dt;
      if (_messageTimer <= 0) _message = '';
    }
  }

  void showMessage(String msg) {
    _message = msg;
    _messageTimer = _messageDuration;
  }

  void updateCountdown(double seconds) {
    _countdown = seconds;
  }

  void showGameOver(int finalScore) {
    _isGameEnd = true;
    _isVictory = false;
    _finalScore = finalScore;
  }

  void showVictory(int finalScore) {
    _isGameEnd = true;
    _isVictory = true;
    _finalScore = finalScore;
  }

  void refresh() {}

  @override
  void render(Canvas canvas) {
    _renderHudBar(canvas);
    _renderToastMessage(canvas);

    if (!game.isWaveActive && !_isGameEnd) {
      _renderWaveCountdown(canvas);
    }

    if (_isGameEnd) {
      _renderGameEnd(canvas);
    }
  }

  void _renderHudBar(Canvas canvas) {
    final w = size.x;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, _hudHeight), _hudBgPaint);
    canvas.drawLine(
      Offset(0, _hudHeight),
      Offset(w, _hudHeight),
      Paint()
        ..color = const Color(0xFF00BCD4).withAlpha(80)
        ..strokeWidth = 1.0,
    );

    _drawText(canvas, '💰 ${game.gold}', Offset(_padding, 8), GameConstants.colorGold, fontSize: 15);
    _drawText(canvas, '❤️ ${game.lives}', Offset(w * 0.30, 8), GameConstants.colorLives, fontSize: 15);
    _drawText(canvas, '⭐ ${game.score}', Offset(w * 0.52, 8), Colors.white, fontSize: 15);

    final waveText = game.isWaveActive ? 'Wave ${game.currentWave}' : 'Wave ${game.currentWave + 1}';
    _drawText(canvas, waveText, Offset(w * 0.74, 8), const Color(0xFF80DEEA), fontSize: 15, bold: true);

    final cost = game.selectedTowerType.cost;
    _drawText(
      canvas,
      'Tap to build ${game.selectedTowerType.displayName} (${cost}g)',
      Offset(_padding, 30),
      Colors.white54,
      fontSize: 11,
    );
  }

  void _renderToastMessage(Canvas canvas) {
    if (_message.isEmpty) return;

    final alpha = (_messageTimer / _messageDuration).clamp(0.0, 1.0);
    final w = size.x;
    final y = size.y * 0.45;
    final textW = w * 0.75;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, y), width: textW, height: 36),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xDD000000).withAlpha((alpha * 0xDD).round()),
    );

    _drawText(
      canvas,
      _message,
      Offset((w - textW) / 2 + _padding, y - 10),
      Colors.white.withAlpha((alpha * 255).round()),
      fontSize: 14,
    );
  }

  void _renderWaveCountdown(Canvas canvas) {
    if (_countdown <= 0) return;
    final w = size.x;
    final secs = _countdown.ceil();
    _drawText(
      canvas,
      'Next wave in $secs s',
      Offset(w / 2 - 65, size.y - GameConstants.buildPanelHeight - 40),
      const Color(0xFFFFEB3B),
      fontSize: 16,
      bold: true,
    );
  }

  void _renderGameEnd(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xCC000000));

    final panelW = w * 0.8;
    final panelH = h * 0.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: panelW, height: panelH),
        const Radius.circular(16),
      ),
      _panelPaint,
    );

    final titleColor = _isVictory ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final title = _isVictory ? 'YOU WIN! 🎉' : 'GAME OVER';
    _drawText(canvas, title, Offset(w / 2 - 70, h / 2 - 70), titleColor, fontSize: 26, bold: true);
    _drawText(canvas, 'Score: $_finalScore', Offset(w / 2 - 50, h / 2 - 20), Colors.white, fontSize: 20);
    _drawText(canvas, 'Tap Play Again to restart', Offset(w / 2 - 100, h / 2 + 30), Colors.white54, fontSize: 13);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color, {
    double fontSize = 14,
    bool bold = false,
  }) {
    _textPainter
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          shadows: const [Shadow(blurRadius: 4, color: Color(0xFF000000))],
        ),
      )
      ..layout();
    _textPainter.paint(canvas, position);
  }
}
