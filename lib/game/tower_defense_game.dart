import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import 'components/enemy_component.dart';
import 'components/hud_component.dart';
import 'components/map_component.dart';
import 'components/tower_component.dart';
import 'models/stage_data.dart';
import 'models/tile_type.dart';
import 'models/tower_type.dart';
import 'models/wave_data.dart';
import 'utils/constants.dart';

class TowerDefenseGame extends FlameGame with TapCallbacks {
  TowerDefenseGame({required this.currentStage});

  final StageData currentStage;

  // ─── State ──────────────────────────────────────────────────────────────────
  int gold = 0;
  int lives = 0;
  int score = 0;
  int currentWave = 0;
  bool isGameOver = false;
  bool isVictory = false;
  bool isWaveActive = false;

  TowerType selectedTowerType = TowerType.basic;

  // ─── Internal refs ──────────────────────────────────────────────────────────
  late MapComponent _mapComponent;
  late HudComponent _hudComponent;

  // Wave bookkeeping
  double _waveTimer = 0.0;
  double _spawnTimer = 0.0;
  int _enemiesLeftToSpawn = 0;
  int _enemiesAliveThisWave = 0;
  int _enemiesSpawnedThisWave = 0;
  WaveData? _currentWaveData;

  double _incomeAccumulator = 0.0;

  /// Exposed so HudComponent can read it every frame.
  double get waveCountdown => _waveTimer;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Color backgroundColor() => currentStage.theme.background;

  @override
  Future<void> onLoad() async {
    gold = currentStage.startingGold;
    lives = currentStage.startingLives;

    // Game entities live in the Flame-managed World.
    _mapComponent = MapComponent(stage: currentStage);
    await world.add(_mapComponent);

    // HUD lives in the camera viewport (screen space, unaffected by camera).
    _hudComponent = HudComponent();
    await camera.viewport.add(_hudComponent);

    _startWaveCountdown();

    overlays.add('buildPanel');
    overlays.add('pauseButton');

    final bgm = switch (currentStage.id) {
      'forest' => SoundType.bgmForest,
      'desert' => SoundType.bgmDesert,
      'volcano' => SoundType.bgmVolcano,
      _ => SoundType.bgmMenu,
    };
    AudioService.instance.playBgm(bgm);
  }

  // ─── Game loop ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    _handlePassiveIncome(dt);
    _handleWaveProgression(dt);
  }

  // ─── Input ──────────────────────────────────────────────────────────────────

  @override
  void onTapUp(TapUpEvent event) {
    if (isGameOver) return;

    final tapPos = event.localPosition;

    // Block taps in the HUD bar at the top and the build panel at the bottom.
    if (tapPos.y < HudComponent.hudHeight) return;
    if (tapPos.y > size.y - GameConstants.buildPanelHeight) return;

    final tileSize = _mapComponent.tileSize;
    final col = (tapPos.x / tileSize).floor();
    final row = (tapPos.y / tileSize).floor();

    if (col < 0 || col >= GameConstants.mapCols) return;
    if (row < 0 || row >= GameConstants.mapRows) return;

    _tryPlaceTower(col, row);
  }

  // ─── Tower placement ────────────────────────────────────────────────────────

  void _tryPlaceTower(int col, int row) {
    final type = selectedTowerType;

    if (!_mapComponent.isBuildable(col, row)) {
      _hudComponent.showMessage('Cannot build here!');
      return;
    }
    if (gold < type.cost) {
      _hudComponent.showMessage('Need ${type.cost}g for ${type.displayName}!');
      return;
    }

    spendGold(type.cost);
    _mapComponent.setTileType(col, row, TileType.tower);
    AudioService.instance.playSfx(SoundType.sfxTowerPlace);

    world.add(TowerComponent(
      gridCol: col,
      gridRow: row,
      tileSize: _mapComponent.tileSize,
      towerType: type,
    ));
  }

  // ─── Economy ────────────────────────────────────────────────────────────────

  void spendGold(int amount) => gold = max(0, gold - amount);
  void earnGold(int amount) => gold += amount;
  void addScore(int points) => score += points;

  // ─── Enemy callbacks ────────────────────────────────────────────────────────

  void enemyReachedEnd() {
    lives--;
    _enemiesAliveThisWave--;

    if (lives <= 0) {
      _endGame(victory: false);
    } else {
      _checkWaveComplete();
    }
  }

  void enemyKilled(int reward) {
    earnGold(reward);
    addScore(reward * 10);
    _enemiesAliveThisWave--;
    _checkWaveComplete();
  }

  // ─── Wave management ────────────────────────────────────────────────────────

  void _startWaveCountdown() {
    _waveTimer = GameConstants.timeBetweenWaves;
    isWaveActive = false;
  }

  void _handlePassiveIncome(double dt) {
    _incomeAccumulator += GameConstants.passiveIncomePerSecond * dt;
    if (_incomeAccumulator >= 1.0) {
      final earned = _incomeAccumulator.floor();
      _incomeAccumulator -= earned;
      earnGold(earned);
    }
  }

  void _handleWaveProgression(double dt) {
    if (isWaveActive) {
      if (_enemiesLeftToSpawn > 0) {
        _spawnTimer -= dt;
        if (_spawnTimer <= 0) {
          _spawnEnemy();
          _spawnTimer = GameConstants.spawnInterval;
        }
      }
    } else {
      _waveTimer -= dt;
      if (_waveTimer <= 0) _launchNextWave();
    }
  }

  void _launchNextWave() {
    if (currentWave >= currentStage.waves.length) {
      _endGame(victory: true);
      return;
    }

    _currentWaveData = currentStage.waves[currentWave];
    currentWave++;
    isWaveActive = true;
    AudioService.instance.playSfx(SoundType.sfxWaveStart);
    _enemiesLeftToSpawn = _currentWaveData!.enemyCount;
    _enemiesAliveThisWave = _currentWaveData!.enemyCount;
    _enemiesSpawnedThisWave = 0;
    _spawnTimer = 0;
  }

  void _spawnEnemy() {
    if (_currentWaveData == null) return;
    final types = _currentWaveData!.enemyTypes;
    final enemyType = types[_enemiesSpawnedThisWave % types.length];

    world.add(EnemyComponent(
      path: _mapComponent.worldPath,
      enemyType: enemyType,
      waveHealthMultiplier: _currentWaveData!.healthMultiplier,
      waveSpeedMultiplier: _currentWaveData!.speedMultiplier,
    ));

    _enemiesLeftToSpawn--;
    _enemiesSpawnedThisWave++;
  }

  void _checkWaveComplete() {
    if (_enemiesAliveThisWave <= 0 && _enemiesLeftToSpawn <= 0) {
      isWaveActive = false;
      _hudComponent.showMessage('Wave $currentWave complete!');
      _startWaveCountdown();
    }
  }

  // ─── Game end ───────────────────────────────────────────────────────────────

  void _endGame({required bool victory}) {
    isGameOver = true;
    isVictory = victory;
    // Pause the engine so entities freeze while the overlay is visible.
    pauseEngine();
    overlays.remove('buildPanel');
    overlays.remove('pauseButton');
    overlays.add('restartButton');
    AudioService.instance.stopBgm();
    AudioService.instance.playSfx(
      victory ? SoundType.sfxVictory : SoundType.sfxGameOver,
    );
  }

  // ─── Pause ──────────────────────────────────────────────────────────────────

  void pauseGame() {
    pauseEngine();
    AudioService.instance.pauseBgm();
  }

  void resumeGame() {
    resumeEngine();
    AudioService.instance.resumeBgm();
  }

  // ─── Accessors for components ────────────────────────────────────────────────

  /// All living enemy components currently in the world.
  Iterable<EnemyComponent> get activeEnemies =>
      world.children.whereType<EnemyComponent>();

  double get tileSize => _mapComponent.tileSize;
}
