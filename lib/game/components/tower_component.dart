import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../audio/audio_service.dart';
import '../components/enemy_component.dart';
import '../components/projectile_component.dart';
import '../models/tower_type.dart';
import '../tower_defense_game.dart';

class TowerComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  TowerComponent({
    required int gridCol,
    required int gridRow,
    required double tileSize,
    required this.towerType,
  }) {
    // Cannon gets a larger footprint than the canvas-drawn towers.
    final scale = towerType == TowerType.basic ? 1.1 : 0.8;
    size = Vector2.all(tileSize * scale);
    position = Vector2(
      (gridCol * tileSize) + (tileSize - size.x) / 2,
      (gridRow * tileSize) + (tileSize - size.y) / 2,
    );
    priority = 15;
  }

  final TowerType towerType;

  // ─── Targeting ─────────────────────────────────────────────────────────────
  double _fireCooldown = 0.0;
  EnemyComponent? _currentTarget;

  // ─── Canvas-tower animation (sniper / bomb only) ────────────────────────────
  double _gunAngle = -pi / 2;
  double _idleTimer = 0.0;
  double _muzzleFlashTimer = 0.0;
  static const double _muzzleFlashDuration = 0.12;
  bool get _isFiring => _muzzleFlashTimer > 0;

  // ─── Range indicator (all types) ───────────────────────────────────────────
  bool _showRange = false;
  double _showRangeTimer = 0.0;
  static const double _showRangeDuration = 2.0;

  // ─── Cannon sprites (basic only) ───────────────────────────────────────────
  SpriteAnimationComponent? _spriteComp;
  SpriteAnimation? _idleAnim;
  SpriteAnimation? _attackAnim;
  SpriteAnimation? _projectileAnim; // fire frames — used by projectiles, not the tower

  // ─── Paints ────────────────────────────────────────────────────────────────
  late Paint _basePaint;
  late Paint _topPaint;
  late Paint _rangePaint;
  late Paint _rangeOutlinePaint;
  final Paint _muzzlePaint = Paint()..color = const Color(0xFFFFFFFF);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    _rangePaint = Paint()..color = towerType.primaryColor.withAlpha(30);
    _rangeOutlinePaint = Paint()
      ..color = towerType.primaryColor.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _showRange = true;
    _showRangeTimer = _showRangeDuration;

    if (towerType == TowerType.basic) {
      await _loadCannonSprites();
    } else {
      _basePaint = Paint()..color = towerType.primaryColor;
      _topPaint = Paint()..color = towerType.secondaryColor;
    }
  }

  Future<void> _loadCannonSprites() async {
    _idleAnim    = await _buildAnim('idle',   5, stepTime: 0.12, loop: true);
    _attackAnim  = await _buildAnim('attack', 7, stepTime: 0.08, loop: true);
    // fire frames are for the projectile — loop so it spins while in flight
    _projectileAnim = await _buildAnim('fire', 5, stepTime: 0.08, loop: true);

    _spriteComp = SpriteAnimationComponent(
      animation: _idleAnim,
      size: size.clone(),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteComp!);
  }

  Future<SpriteAnimation> _buildAnim(
    String state,
    int frameCount, {
    required double stepTime,
    required bool loop,
  }) async {
    final paths = List.generate(
      frameCount,
      (i) => 'towers/cannon/$state${i + 1}.png',
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
    if (_showRange && _showRangeTimer > 0) {
      _showRangeTimer -= dt;
      if (_showRangeTimer <= 0) _showRange = false;
    }

    if (_fireCooldown > 0) _fireCooldown -= dt;

    if (towerType != TowerType.basic) {
      _idleTimer += dt;
      if (_muzzleFlashTimer > 0) {
        _muzzleFlashTimer = (_muzzleFlashTimer - dt).clamp(0, _muzzleFlashDuration);
      }
    }

    final prevTarget = _currentTarget;
    _acquireTarget();

    // Sync cannon between idle ↔ attack when target is acquired or lost
    if (towerType == TowerType.basic && prevTarget != _currentTarget) {
      _syncCannonState();
    }

    if (_currentTarget != null) {
      if (towerType != TowerType.basic) _aimAtTarget(_currentTarget!);
      if (_fireCooldown <= 0) {
        _fireAt(_currentTarget!);
        _fireCooldown = 1.0 / towerType.fireRate;
      }
    }
  }

  void _acquireTarget() {
    if (_currentTarget != null &&
        (_currentTarget!.isDead ||
            !_currentTarget!.isMounted ||
            _distanceTo(_currentTarget!) > towerType.range)) {
      _currentTarget = null;
    }

    if (_currentTarget != null) return;

    EnemyComponent? best;
    double bestProgress = -1;
    for (final enemy in game.activeEnemies) {
      if (enemy.isDead) continue;
      if (_distanceTo(enemy) <= towerType.range) {
        if (enemy.pathProgress > bestProgress) {
          bestProgress = enemy.pathProgress;
          best = enemy;
        }
      }
    }
    _currentTarget = best;
  }

  double _distanceTo(EnemyComponent enemy) => (centre - enemy.centre).length;
  Vector2 get centre => position + size / 2;

  void _aimAtTarget(EnemyComponent target) {
    final diff = target.centre - centre;
    final targetAngle = atan2(diff.y, diff.x);
    _gunAngle = _lerpAngle(_gunAngle, targetAngle, 0.15);
  }

  double _lerpAngle(double a, double b, double t) {
    double diff = b - a;
    while (diff > pi) { diff -= 2 * pi; }
    while (diff < -pi) { diff += 2 * pi; }
    return a + diff * t;
  }

  void _syncCannonState() {
    final sc = _spriteComp;
    if (sc == null) return;
    sc.animation = _currentTarget != null ? _attackAnim : _idleAnim;
  }

  void _fireAt(EnemyComponent target) {
    if (target.isDead || !target.isMounted) return;

    final muzzleOffset = towerType == TowerType.basic
        ? Vector2.zero()
        : Vector2(cos(_gunAngle), sin(_gunAngle)) * (size.x * 0.5);

    game.world.add(ProjectileComponent(
      startPosition: centre + muzzleOffset,
      target: target,
      damage: towerType.damage,
      speed: towerType.projectileSpeed,
      splashRadius: towerType.splashRadius,
      color: towerType == TowerType.bomb ? const Color(0xFFFF6F00) : null,
      // Cannon projectile uses the fire sprite frames
      spriteAnimation: towerType == TowerType.basic ? _projectileAnim : null,
    ));

    if (towerType != TowerType.basic) _muzzleFlashTimer = _muzzleFlashDuration;

    AudioService.instance.playSfx(switch (towerType) {
      TowerType.basic  => SoundType.sfxCannonFire,
      TowerType.sniper => SoundType.sfxSniperFire,
      TowerType.bomb   => SoundType.sfxMortarFire,
    });
  }

  // ─── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    if (_showRange) {
      canvas.drawCircle(Offset(cx, cy), towerType.range, _rangePaint);
      canvas.drawCircle(Offset(cx, cy), towerType.range, _rangeOutlinePaint);
    }

    // Cannon: sprite child handles all visuals
    if (towerType == TowerType.basic) return;

    // ── Sniper / Bomb: canvas rendering ────────────────────────────────────
    final w = size.x;
    final h = size.y;
    final idleBob = sin(_idleTimer * 1.5) * 0.8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + idleBob), width: w * 0.85, height: h * 0.75),
        Radius.circular(towerType == TowerType.sniper ? 2 : 4),
      ),
      _basePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 2, cy - 2 + idleBob), width: w * 0.6, height: h * 0.5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF90A4AE).withAlpha(50),
    );

    canvas.save();
    canvas.translate(cx, cy + idleBob);
    canvas.rotate(_gunAngle + pi / 2);

    canvas.drawCircle(Offset.zero, w * 0.28, _topPaint);

    final barrelPaint = Paint()
      ..color = towerType.gunColor
      ..strokeCap = StrokeCap.round;

    switch (towerType) {
      case TowerType.sniper:
        barrelPaint.strokeWidth = w * 0.08;
        canvas.drawLine(Offset(0, -w * 0.05), Offset(0, -w * 0.62), barrelPaint);
      case TowerType.bomb:
        barrelPaint.strokeWidth = w * 0.18;
        canvas.drawLine(Offset(0, -w * 0.05), Offset(0, -w * 0.32), barrelPaint);
        canvas.drawCircle(
          Offset(0, -w * 0.32),
          w * 0.12,
          Paint()..color = towerType.gunColor,
        );
      case TowerType.basic:
        break;
    }

    if (_isFiring) {
      final flashAlpha = _muzzleFlashTimer / _muzzleFlashDuration;
      final flashPos = towerType == TowerType.sniper
          ? Offset(0, -w * 0.62)
          : Offset(0, -w * 0.32);
      _muzzlePaint.color = Colors.orange.withAlpha((flashAlpha * 220).round());
      canvas.drawCircle(flashPos, w * 0.14, _muzzlePaint);
      canvas.drawCircle(
        flashPos,
        w * 0.22,
        Paint()..color = Colors.yellow.withAlpha((flashAlpha * 80).round()),
      );
    }

    canvas.restore();

    _drawBattlements(canvas, cx, cy + idleBob, w, h);
  }

  void _drawBattlements(Canvas canvas, double cx, double cy, double w, double h) {
    final battSize = w * 0.14;
    final offset = w * 0.36;
    for (final p in [
      Offset(cx - offset, cy - h * 0.28),
      Offset(cx + offset - battSize, cy - h * 0.28),
      Offset(cx - offset, cy + h * 0.14),
      Offset(cx + offset - battSize, cy + h * 0.14),
    ]) {
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, battSize, battSize * 1.2), _basePaint);
    }
  }
}
