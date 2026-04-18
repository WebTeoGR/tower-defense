import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../audio/audio_service.dart';
import '../models/enemy_type.dart';
import '../tower_defense_game.dart';
import '../utils/constants.dart';

class EnemyComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  EnemyComponent({
    required List<Vector2> path,
    required this.enemyType,
    double waveHealthMultiplier = 1.0,
    double waveSpeedMultiplier = 1.0,
  })  : _path = List.unmodifiable(path),
        _maxHealth = (GameConstants.enemyBaseHealth *
                enemyType.healthMultiplier *
                waveHealthMultiplier)
            .round(),
        _speed = GameConstants.enemyBaseSpeed *
            enemyType.speedMultiplier *
            waveSpeedMultiplier;

  final EnemyType enemyType;

  // ─── Path ──────────────────────────────────────────────────────────────────
  final List<Vector2> _path;
  int _waypointIndex = 0;

  // ─── Stats ─────────────────────────────────────────────────────────────────
  final int _maxHealth;
  late int _currentHealth;
  final double _speed;

  // ─── Animation ─────────────────────────────────────────────────────────────
  double _walkTimer = 0.0;
  double _walkAngle = 0.0;
  bool _isDead = false;
  double _deathTimer = 0.0;
  static const double _deathDuration = 0.4;

  // ─── Paints ────────────────────────────────────────────────────────────────
  late Paint _bodyPaint;
  late Paint _outlinePaint;
  final Paint _hpBgPaint = Paint()..color = GameConstants.colorHealthBarBg;
  final Paint _hpFgPaint = Paint()..color = GameConstants.colorHealthBarFg;
  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    _currentHealth = _maxHealth;

    _bodyPaint = Paint()..color = enemyType.bodyColor;
    _outlinePaint = Paint()
      ..color = enemyType.outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = enemyType == EnemyType.tank ? 3.0 : 2.0;

    final ts = game.tileSize;
    final s = enemyType.sizeMultiplier;
    size = Vector2(ts * 0.55 * s, ts * 0.55 * s);

    if (_path.isNotEmpty) {
      position = _path[0].clone() - size / 2;
    }

    priority = 10;
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (_isDead) {
      _deathTimer += dt;
      if (_deathTimer >= _deathDuration) removeFromParent();
      return;
    }

    _walkTimer += dt * (enemyType == EnemyType.fast ? 10.0 : 6.0);
    _moveAlongPath(dt);
  }

  void _moveAlongPath(double dt) {
    if (_waypointIndex >= _path.length) {
      _onReachedEnd();
      return;
    }

    final target = _path[_waypointIndex];
    final centre = position + size / 2;
    final toTarget = target - centre;
    final distance = toTarget.length;
    final step = _speed * dt;

    if (step >= distance) {
      position = target - size / 2;
      _waypointIndex++;
    } else {
      final dir = toTarget.normalized();
      _walkAngle = atan2(dir.y, dir.x);
      position += dir * step;
    }
  }

  void _onReachedEnd() {
    if (_isDead) return;
    _isDead = true;
    AudioService.instance.playSfx(SoundType.sfxEnemyEscape);
    game.enemyReachedEnd();
    removeFromParent();
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  Vector2 get centre => position + size / 2;
  double get pathProgress => _path.isEmpty ? 0 : _waypointIndex / _path.length;
  bool get isDead => _isDead;

  bool takeDamage(int damage) {
    if (_isDead) return false;
    _currentHealth -= damage;
    if (_currentHealth <= 0) {
      _currentHealth = 0;
      _die();
      return true;
    }
    return false;
  }

  void _die() {
    _isDead = true;
    AudioService.instance.playSfx(SoundType.sfxEnemyDie);
    game.enemyKilled(enemyType.killReward);
  }

  // ─── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_isDead) {
      _renderDeathAnimation(canvas);
      return;
    }

    final w = size.x;
    final h = size.y;
    final bob = sin(_walkTimer) * 2.0;

    switch (enemyType) {
      case EnemyType.tank:
        _renderTank(canvas, w, h, bob);
      case EnemyType.fast:
        _renderFast(canvas, w, h, bob);
      case EnemyType.basic:
        _renderBasic(canvas, w, h, bob);
    }

    _renderHealthBar(canvas, w, h);
  }

  void _renderBasic(Canvas canvas, double w, double h, double bob) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2 + bob, w - 4, h - 4),
      Radius.circular(w * 0.25),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);
    canvas.drawRRect(bodyRect, _outlinePaint);

    final eyeOffsetX = cos(_walkAngle) * 3;
    final eyeRadius = w * 0.1;
    final eyeY = h * 0.35 + bob;
    canvas.drawCircle(Offset(w * 0.35 + eyeOffsetX, eyeY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(w * 0.65 + eyeOffsetX, eyeY), eyeRadius, _eyePaint);
    canvas.drawCircle(Offset(w * 0.36 + eyeOffsetX, eyeY), eyeRadius * 0.5, _pupilPaint);
    canvas.drawCircle(Offset(w * 0.66 + eyeOffsetX, eyeY), eyeRadius * 0.5, _pupilPaint);
  }

  void _renderFast(Canvas canvas, double w, double h, double bob) {
    // Speed streaks behind
    final streakPaint = Paint()
      ..color = enemyType.bodyColor.withAlpha(50)
      ..style = PaintingStyle.fill;
    final cx = w / 2;
    final cy = h / 2 + bob;
    final backX = -cos(_walkAngle) * w * 0.6;
    final backY = -sin(_walkAngle) * h * 0.4;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + backX, cy + backY), width: w * 0.5, height: h * 0.3),
      streakPaint,
    );

    // Slim, pointed body
    final path = Path()
      ..moveTo(cx + cos(_walkAngle) * w * 0.45, cy + sin(_walkAngle) * h * 0.45)
      ..lineTo(cx - sin(_walkAngle) * w * 0.25, cy + cos(_walkAngle) * h * 0.25)
      ..lineTo(cx - cos(_walkAngle) * w * 0.35, cy - sin(_walkAngle) * h * 0.35)
      ..lineTo(cx + sin(_walkAngle) * w * 0.25, cy - cos(_walkAngle) * h * 0.25)
      ..close();
    canvas.drawPath(path, _bodyPaint);
    canvas.drawPath(path, _outlinePaint);
  }

  void _renderTank(Canvas canvas, double w, double h, double bob) {
    // Chunky square body with rounded corners
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 2 + bob, w - 2, h - 4),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);
    canvas.drawRRect(bodyRect, _outlinePaint);

    // Armour plates
    final platePaint = Paint()
      ..color = enemyType.outlineColor.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(3, h * 0.25 + bob, w - 6, h * 0.18), platePaint);
    canvas.drawRect(Rect.fromLTWH(3, h * 0.55 + bob, w - 6, h * 0.18), platePaint);

    // Angry eyes
    final eyeRadius = w * 0.12;
    final eyeY = h * 0.3 + bob;
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.3, eyeY), width: eyeRadius * 2, height: eyeRadius), _eyePaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.7, eyeY), width: eyeRadius * 2, height: eyeRadius), _eyePaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.3, eyeY), width: eyeRadius, height: eyeRadius * 0.8), _pupilPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.7, eyeY), width: eyeRadius, height: eyeRadius * 0.8), _pupilPaint);
  }

  void _renderHealthBar(Canvas canvas, double w, double h) {
    const barH = 4.0;
    const margin = 2.0;
    final barW = w - margin * 2;
    const barY = -barH - 2.0;

    canvas.drawRect(Rect.fromLTWH(margin, barY, barW, barH), _hpBgPaint);

    final ratio = _currentHealth / _maxHealth;
    _hpFgPaint.color =
        ratio > 0.5 ? GameConstants.colorHealthBarFg : GameConstants.colorHealthBarLow;
    canvas.drawRect(Rect.fromLTWH(margin, barY, barW * ratio, barH), _hpFgPaint);
  }

  void _renderDeathAnimation(Canvas canvas) {
    final progress = _deathTimer / _deathDuration;
    final scale = 1.0 + progress * 0.5;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale, scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    final fadePaint = Paint()
      ..color = enemyType.bodyColor.withAlpha((alpha * 255).round());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        Radius.circular(size.x * 0.25),
      ),
      fadePaint,
    );
    canvas.restore();
  }
}
