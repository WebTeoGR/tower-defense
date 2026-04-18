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

  // ─── Non-sprite animation (fast / tank) ────────────────────────────────────
  double _walkTimer = 0.0;
  double _walkAngle = 0.0;
  bool _isDead = false;
  double _deathTimer = 0.0;
  static const double _deathDuration = 0.4;

  // ─── Troll sprite state ────────────────────────────────────────────────────
  SpriteAnimationComponent? _spriteComp;
  SpriteAnimation? _walkAnim;
  SpriteAnimation? _hurtAnim;
  SpriteAnimation? _dieAnim;
  bool _isHurting = false;

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

    if (enemyType == EnemyType.basic) {
      await _loadTrollAnimations();
    }
  }

  Future<void> _loadTrollAnimations() async {
    _walkAnim = await _buildAnim('walk', 20, stepTime: 0.05, loop: true);
    _hurtAnim = await _buildAnim('hurt', 20, stepTime: 0.04, loop: false);
    _dieAnim  = await _buildAnim('die',  20, stepTime: 0.05, loop: false);

    _spriteComp = SpriteAnimationComponent(
      animation: _walkAnim,
      size: size.clone(),
      // Center anchor so horizontal flip works without position offset.
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteComp!);
  }

  Future<SpriteAnimation> _buildAnim(
    String state,
    int frames, {
    required double stepTime,
    required bool loop,
  }) async {
    final paths = List.generate(
      frames,
      (i) => 'enemies/troll/3_enemies_1_${state}_${i.toString().padLeft(3, '0')}.png',
    );
    final images = await game.images.loadAll(paths);
    return SpriteAnimation.spriteList(
      images.map((img) => Sprite(img)).toList(),
      stepTime: stepTime,
      loop: loop,
    );
  }

  // ─── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (_isDead) {
      // Troll die animation drives removal via onComplete.
      // Other types use the canvas death timer.
      if (enemyType != EnemyType.basic) {
        _deathTimer += dt;
        if (_deathTimer >= _deathDuration) removeFromParent();
      }
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
      _updateSpriteFlip(dir.x);
      position += dir * step;
    }
  }

  /// Flip the troll sprite so it always faces the direction of travel.
  void _updateSpriteFlip(double dirX) {
    final sc = _spriteComp;
    if (sc == null) return;
    // scale.x = -1 mirrors around the center anchor (no position offset needed).
    sc.scale.x = dirX < 0 ? -1.0 : 1.0;
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
    if (enemyType == EnemyType.basic) _triggerHurt();
    return false;
  }

  void _triggerHurt() {
    // Don't interrupt an already-playing hurt animation.
    if (_isHurting || _spriteComp == null) return;
    _isHurting = true;
    _spriteComp!.animation = _hurtAnim;
    _spriteComp!.animationTicker?.onComplete = () {
      _isHurting = false;
      if (!_isDead) _spriteComp!.animation = _walkAnim;
    };
  }

  void _die() {
    _isDead = true;
    AudioService.instance.playSfx(SoundType.sfxEnemyDie);
    game.enemyKilled(enemyType.killReward);

    if (enemyType == EnemyType.basic && _spriteComp != null) {
      // Play die animation; remove after last frame.
      _isHurting = false;
      _spriteComp!.animation = _dieAnim;
      _spriteComp!.animationTicker?.onComplete = removeFromParent;
    }
    // Non-basic types: update() runs _deathDuration timer then removes.
  }

  // ─── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (enemyType == EnemyType.basic) {
      // SpriteAnimationComponent child handles all drawing.
      // Only draw the health bar here (while alive).
      if (!_isDead) _renderHealthBar(canvas, size.x, size.y);
      return;
    }

    if (_isDead) {
      _renderDeathAnimation(canvas);
      return;
    }

    final w = size.x;
    final h = size.y;
    final bob = sin(_walkTimer) * 2.0;

    switch (enemyType) {
      case EnemyType.fast:
        _renderFast(canvas, w, h, bob);
      case EnemyType.tank:
        _renderTank(canvas, w, h, bob);
      case EnemyType.basic:
        break; // handled above
    }

    _renderHealthBar(canvas, w, h);
  }

  void _renderFast(Canvas canvas, double w, double h, double bob) {
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
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 2 + bob, w - 2, h - 4),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);
    canvas.drawRRect(bodyRect, _outlinePaint);

    final platePaint = Paint()
      ..color = enemyType.outlineColor.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(3, h * 0.25 + bob, w - 6, h * 0.18), platePaint);
    canvas.drawRect(Rect.fromLTWH(3, h * 0.55 + bob, w - 6, h * 0.18), platePaint);

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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        Radius.circular(size.x * 0.25),
      ),
      Paint()..color = enemyType.bodyColor.withAlpha((alpha * 255).round()),
    );
    canvas.restore();
  }
}
