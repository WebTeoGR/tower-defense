import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../audio/audio_service.dart';
import '../components/enemy_component.dart';
import '../tower_defense_game.dart';
import '../utils/constants.dart';

class ProjectileComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  ProjectileComponent({
    required Vector2 startPosition,
    required EnemyComponent target,
    required int damage,
    double speed = 250.0,
    double splashRadius = 0.0,
    Color? color,
    SpriteAnimation? spriteAnimation,
  })  : _target = target,
        _damage = damage,
        _speed = speed,
        _splashRadius = splashRadius,
        _color = color ?? GameConstants.colorProjectile,
        _spriteAnimation = spriteAnimation {
    position = startPosition.clone();
    // Sprite projectiles are rendered larger than the plain circle.
    final visualSize = spriteAnimation != null
        ? GameConstants.projectileRadius * 6
        : GameConstants.projectileRadius * 2;
    size = Vector2.all(visualSize);
    priority = 20;
  }

  final EnemyComponent _target;
  final int _damage;
  final double _speed;
  final double _splashRadius;
  final Color _color;
  final SpriteAnimation? _spriteAnimation;

  // Explosion animation state (bomb only)
  bool _isExploding = false;
  double _explosionTimer = 0.0;
  static const double _explosionDuration = 0.35;

  late final Paint _corePaint = Paint()..color = _color;
  late final Paint _glowPaint = Paint()
    ..color = _color.withAlpha(80)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  Future<void> onLoad() async {
    if (_spriteAnimation != null) {
      add(SpriteAnimationComponent(
        animation: _spriteAnimation,
        size: size.clone(),
        anchor: Anchor.center,
        position: size / 2,
      ));
    }
  }

  @override
  void update(double dt) {
    if (_isExploding) {
      _explosionTimer += dt;
      if (_explosionTimer >= _explosionDuration) removeFromParent();
      return;
    }

    if (_target.isDead || !_target.isMounted) {
      removeFromParent();
      return;
    }

    final targetCentre = _target.centre;
    final myCentre = position + size / 2;
    final toTarget = targetCentre - myCentre;
    final distance = toTarget.length;
    final step = _speed * dt;

    if (step >= distance) {
      _onImpact();
    } else {
      position += toTarget.normalized() * step;
    }
  }

  void _onImpact() {
    if (_splashRadius > 0) {
      final impactPos = _target.centre;
      for (final enemy in game.activeEnemies.toList()) {
        if (!enemy.isDead && (enemy.centre - impactPos).length <= _splashRadius) {
          enemy.takeDamage(_damage);
        }
      }
      AudioService.instance.playSfx(SoundType.sfxExplosion);
      _isExploding = true;
      size = Vector2.all(_splashRadius * 2);
      position = impactPos - size / 2;
    } else {
      _target.takeDamage(_damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isExploding) {
      _renderExplosion(canvas);
      return;
    }

    // Sprite child handles rendering for cannon projectiles.
    if (_spriteAnimation != null) return;

    final r = GameConstants.projectileRadius;
    canvas.drawCircle(Offset(r, r), r * 1.8, _glowPaint);
    canvas.drawCircle(Offset(r, r), r, _corePaint);
  }

  void _renderExplosion(Canvas canvas) {
    final progress = _explosionTimer / _explosionDuration;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final radius = _splashRadius * progress;
    final cx = size.x / 2;
    final cy = size.y / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = Colors.orange.withAlpha((alpha * 120).round())
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = Colors.yellow.withAlpha((alpha * 200).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
