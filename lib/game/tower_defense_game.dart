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

  // ─── Reactive state ─────────────────────────────────────────────────────────
  int gold = 0;
  int lives = 0;
  int score = 0;
  int currentWave = 0;

  bool isGameOver = false;
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

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Color backgroundColor() => currentStage.theme.background;

  @override
  Future<void> onLoad() async {
    gold = currentStage.startingGold;
    lives = currentStage.startingLives;

    _mapComponent = MapComponent(stage: currentStage);
    await add(_mapComponent);

    _hudComponent = HudComponent();
    await add(_hudComponent);

    _startWaveCountdown();

    overlays.add('buildPanel');
    overlays.add('pauseButton');

    // Start stage background music
    final bgm = switch (currentStage.id) {
      'forest'  => SoundType.bgmForest,
      'desert'  => SoundType.bgmDesert,
      'volcano' => SoundType.bgmVolcano,
      _         => SoundType.bgmMenu,
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

    // Ignore taps in the build panel area at the bottom
    if (tapPos.y > size.y - GameConstants.buildPanelHeight) return;

    final tileSize = _mapComponent.tileSize;
    final col = (tapPos.x / tileSize).floor();
    final row = (tapPos.y / tileSize).floor();

    if (col < 0 || col >= GameConstants.mapCols || row < 0 || row >= GameConstants.mapRows) return;

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
    add(TowerComponent(
      gridCol: col,
      gridRow: row,
      tileSize: _mapComponent.tileSize,
      towerType: type,
    ));
  }

  // ─── Economy ────────────────────────────────────────────────────────────────

  void spendGold(int amount) {
    gold = max(0, gold - amount);
    _hudComponent.refresh();
  }

  void earnGold(int amount) {
    gold += amount;
    _hudComponent.refresh();
  }

  void addScore(int points) {
    score += points;
    _hudComponent.refresh();
  }

  // ─── Enemy callbacks ────────────────────────────────────────────────────────

  void enemyReachedEnd() {
    lives--;
    _hudComponent.refresh();
    _enemiesAliveThisWave--;

    if (lives <= 0) {
      _triggerGameOver();
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
    _hudComponent.refresh();
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
      if (_waveTimer <= 0) {
        _launchNextWave();
      }
      _hudComponent.updateCountdown(_waveTimer);
    }
  }

  void _launchNextWave() {
    if (currentWave >= currentStage.waves.length) {
      isGameOver = true;
      _hudComponent.showVictory(score);
      _endGameOverlays();
      AudioService.instance.stopBgm();
      AudioService.instance.playSfx(SoundType.sfxVictory);
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
    _hudComponent.refresh();
  }

  void _spawnEnemy() {
    if (_currentWaveData == null) return;
    final types = _currentWaveData!.enemyTypes;
    final enemyType = types[_enemiesSpawnedThisWave % types.length];

    add(EnemyComponent(
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

  void _triggerGameOver() {
    isGameOver = true;
    _hudComponent.showGameOver(score);
    _endGameOverlays();
    AudioService.instance.stopBgm();
    AudioService.instance.playSfx(SoundType.sfxGameOver);
  }

  void _endGameOverlays() {
    overlays.remove('buildPanel');
    overlays.remove('pauseButton');
    overlays.add('restartButton');
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

  // ─── Accessors ──────────────────────────────────────────────────────────────

  Iterable<EnemyComponent> get activeEnemies => children.whereType<EnemyComponent>();
  double get tileSize => _mapComponent.tileSize;
}
