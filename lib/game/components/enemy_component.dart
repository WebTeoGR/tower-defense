import 'dart:ui';

import 'package:flame/components.dart';

import '../../audio/audio_service.dart';
import '../models/enemy_type.dart';
import '../tower_defense_game.dart';
import '../utils/constants.dart';

// ─── Sprite config per enemy type ─────────────────────────────────────────────

typedef _SpriteConfig = ({
  String folder,
  String prefix,
  String moveState, // 'walk' or 'run'
});

_SpriteConfig _configFor(EnemyType type) => switch (type) {
      EnemyType.basic => (
          folder: 'troll',
          prefix: '3_enemies_1_',
          moveState: 'walk',
        ),
      EnemyType.fast => (
          folder: 'fast',
          prefix: '1_enemies_1_',
          moveState: 'run',
        ),
      EnemyType.tank => (
          folder: 'tank',
          prefix: '10_enemies_1_',
          moveState: 'walk',
        ),
    };

// ─── Component ────────────────────────────────────────────────────────────────

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

  // ─── Death (non-sprite fallback, unused now but kept for safety) ────────────
  bool _isDead = false;

  // ─── Sprite animation ──────────────────────────────────────────────────────
  SpriteAnimationComponent? _spriteComp;
  SpriteAnimation? _moveAnim; // walk or run depending on type
  SpriteAnimation? _hurtAnim;
  SpriteAnimation? _dieAnim;
  bool _isHurting = false;

  // ─── Health bar paints ─────────────────────────────────────────────────────
  final Paint _hpBgPaint = Paint()..color = GameConstants.colorHealthBarBg;
  final Paint _hpFgPaint = Paint()..color = GameConstants.colorHealthBarFg;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    _currentHealth = _maxHealth;

    final ts = game.tileSize;
    // Sprite-based enemies fill 90% of a tile; size multiplier keeps
    // fast smaller and tank larger than basic.
    size = Vector2.all(ts * 0.90 * enemyType.sizeMultiplier);

    if (_path.isNotEmpty) {
      position = _path[0].clone() - size / 2;
    }

    priority = 10;

    await _loadSpriteAnimations();
  }

  Future<void> _loadSpriteAnimations() async {
    final cfg = _configFor(enemyType);

    _moveAnim = await _buildAnim(cfg, cfg.moveState, stepTime: 0.05, loop: true);
    _hurtAnim = await _buildAnim(cfg, 'hurt', stepTime: 0.04, loop: false);
    _dieAnim  = await _buildAnim(cfg, 'die',  stepTime: 0.05, loop: false);

    _spriteComp = SpriteAnimationComponent(
      animation: _moveAnim,
      size: size.clone(),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteComp!);
  }

  Future<SpriteAnimation> _buildAnim(
    _SpriteConfig cfg,
    String state, {
    required double stepTime,
    required bool loop,
  }) async {
    final paths = List.generate(
      20,
      (i) =>
          'enemies/${cfg.folder}/${cfg.prefix}${state}_${i.toString().padLeft(3, '0')}.png',
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
    if (_isDead) return; // sprite onComplete drives removal
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
      _updateSpriteFlip(dir.x);
      position += dir * step;
    }
  }

  /// Flip sprite so it always faces the direction of travel.
  void _updateSpriteFlip(double dirX) {
    final sc = _spriteComp;
    if (sc == null) return;
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
    _triggerHurt();
    return false;
  }

  void _triggerHurt() {
    if (_isHurting || _spriteComp == null) return;
    _isHurting = true;
    _spriteComp!.animation = _hurtAnim;
    _spriteComp!.animationTicker?.onComplete = () {
      _isHurting = false;
      if (!_isDead) _spriteComp!.animation = _moveAnim;
    };
  }

  void _die() {
    _isDead = true;
    AudioService.instance.playSfx(SoundType.sfxEnemyDie);
    game.enemyKilled(enemyType.killReward);

    if (_spriteComp != null) {
      _isHurting = false;
      _spriteComp!.animation = _dieAnim;
      _spriteComp!.animationTicker?.onComplete = removeFromParent;
    } else {
      removeFromParent();
    }
  }

  // ─── Rendering ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Sprite child handles all visuals. Only draw health bar while alive.
    if (!_isDead) _renderHealthBar(canvas, size.x, size.y);
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
}
