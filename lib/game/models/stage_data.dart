import 'dart:math';

import 'package:flutter/material.dart';

import 'enemy_type.dart';
import 'wave_data.dart';

class MapTheme {
  const MapTheme({
    required this.grass,
    required this.grassDark,
    required this.path,
    required this.pathBorder,
    required this.background,
    required this.blocked,
  });

  final Color grass;
  final Color grassDark;
  final Color path;
  final Color pathBorder;
  final Color background;
  final Color blocked;
}

class StageData {
  const StageData({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.description,
    required this.themeColor,
    required this.theme,
    required this.path,
    required this.blockedTiles,
    required this.waves,
    this.startingGold = 150,
    this.startingLives = 20,
  });

  final String id;
  final String name;
  final String difficulty;
  final String description;
  final Color themeColor;
  final MapTheme theme;
  final List<Point<int>> path;
  final List<Point<int>> blockedTiles;
  final List<WaveData> waves;
  final int startingGold;
  final int startingLives;

  static const List<StageData> stages = [
    // ── Stage 1: Forest (Easy) ────────────────────────────────────────────────
    StageData(
      id: 'forest',
      name: 'Forest',
      difficulty: 'Easy',
      description: 'A peaceful woodland path.\nPerfect for beginners.',
      themeColor: Color(0xFF4CAF50),
      theme: MapTheme(
        grass: Color(0xFF4CAF50),
        grassDark: Color(0xFF388E3C),
        path: Color(0xFFD7B97A),
        pathBorder: Color(0xFFA1784A),
        background: Color(0xFF1A1A2E),
        blocked: Color(0xFF2E7D32),
      ),
      path: [
        Point(0, 3), Point(1, 3), Point(2, 3),
        Point(2, 4), Point(2, 5), Point(2, 6), Point(2, 7),
        Point(3, 7), Point(4, 7), Point(5, 7), Point(6, 7),
        Point(6, 6), Point(6, 5), Point(6, 4), Point(6, 3), Point(6, 2),
        Point(7, 2), Point(8, 2),
      ],
      blockedTiles: [
        Point(0, 0), Point(1, 0), Point(0, 1),
        Point(7, 0), Point(8, 0), Point(8, 1),
        Point(0, 13), Point(1, 13), Point(0, 12),
        Point(7, 13), Point(8, 13), Point(8, 12),
        Point(4, 10), Point(5, 10),
      ],
      waves: [
        WaveData(waveNumber: 1, enemyCount: 5, healthMultiplier: 1.0, speedMultiplier: 1.0, enemyTypes: [EnemyType.basic]),
        WaveData(waveNumber: 2, enemyCount: 8, healthMultiplier: 1.2, speedMultiplier: 1.0, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 3, enemyCount: 10, healthMultiplier: 1.4, speedMultiplier: 1.1, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 4, enemyCount: 8, healthMultiplier: 1.5, speedMultiplier: 1.0, enemyTypes: [EnemyType.basic, EnemyType.tank]),
        WaveData(waveNumber: 5, enemyCount: 12, healthMultiplier: 1.8, speedMultiplier: 1.2, enemyTypes: [EnemyType.basic, EnemyType.fast, EnemyType.tank]),
      ],
      startingGold: 150,
      startingLives: 20,
    ),

    // ── Stage 2: Desert (Medium) ───────────────────────────────────────────────
    StageData(
      id: 'desert',
      name: 'Desert',
      difficulty: 'Medium',
      description: 'Scorching sands and\ntreacherous dunes.',
      themeColor: Color(0xFFFF9800),
      theme: MapTheme(
        grass: Color(0xFFD4A843),
        grassDark: Color(0xFFC09030),
        path: Color(0xFFBF9060),
        pathBorder: Color(0xFF8B6A40),
        background: Color(0xFF1A1205),
        blocked: Color(0xFF8B6914),
      ),
      path: [
        Point(0, 2), Point(1, 2), Point(2, 2), Point(3, 2), Point(4, 2),
        Point(4, 3), Point(4, 4), Point(4, 5), Point(4, 6),
        Point(5, 6), Point(6, 6), Point(7, 6), Point(8, 6),
        Point(8, 7), Point(8, 8), Point(8, 9), Point(8, 10),
        Point(7, 10), Point(6, 10), Point(5, 10), Point(4, 10), Point(3, 10), Point(2, 10),
        Point(2, 11), Point(2, 12), Point(2, 13),
      ],
      blockedTiles: [
        Point(0, 0), Point(1, 0),
        Point(7, 0), Point(8, 0),
        Point(0, 5), Point(0, 6),
        Point(6, 3), Point(7, 3),
        Point(5, 12), Point(6, 12),
      ],
      waves: [
        WaveData(waveNumber: 1, enemyCount: 7, healthMultiplier: 1.2, speedMultiplier: 1.1, enemyTypes: [EnemyType.basic]),
        WaveData(waveNumber: 2, enemyCount: 9, healthMultiplier: 1.3, speedMultiplier: 1.2, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 3, enemyCount: 6, healthMultiplier: 2.0, speedMultiplier: 1.0, enemyTypes: [EnemyType.tank]),
        WaveData(waveNumber: 4, enemyCount: 12, healthMultiplier: 1.5, speedMultiplier: 1.3, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 5, enemyCount: 8, healthMultiplier: 2.5, speedMultiplier: 1.1, enemyTypes: [EnemyType.basic, EnemyType.tank]),
        WaveData(waveNumber: 6, enemyCount: 14, healthMultiplier: 1.8, speedMultiplier: 1.4, enemyTypes: [EnemyType.fast, EnemyType.tank]),
        WaveData(waveNumber: 7, enemyCount: 15, healthMultiplier: 2.5, speedMultiplier: 1.5, enemyTypes: [EnemyType.basic, EnemyType.fast, EnemyType.tank]),
      ],
      startingGold: 120,
      startingLives: 15,
    ),

    // ── Stage 3: Volcano (Hard) ────────────────────────────────────────────────
    StageData(
      id: 'volcano',
      name: 'Volcano',
      difficulty: 'Hard',
      description: 'Lava flows and\nrelentless hordes await.',
      themeColor: Color(0xFFF44336),
      theme: MapTheme(
        grass: Color(0xFF4A1010),
        grassDark: Color(0xFF3A0A0A),
        path: Color(0xFF8B4513),
        pathBorder: Color(0xFF6B2800),
        background: Color(0xFF0D0000),
        blocked: Color(0xFF7B1FA2),
      ),
      // S-shaped path: top row → right side → middle row → left vertical → mid row → right side → bottom row
      path: [
        Point(0, 1), Point(1, 1), Point(2, 1), Point(3, 1), Point(4, 1), Point(5, 1), Point(6, 1), Point(7, 1), Point(8, 1),
        Point(8, 2), Point(8, 3), Point(8, 4),
        Point(7, 4), Point(6, 4), Point(5, 4), Point(4, 4), Point(3, 4), Point(2, 4),
        Point(2, 5), Point(2, 6), Point(2, 7), Point(2, 8),
        Point(3, 8), Point(4, 8), Point(5, 8), Point(6, 8), Point(7, 8), Point(8, 8),
        Point(8, 9), Point(8, 10), Point(8, 11), Point(8, 12),
        Point(7, 12), Point(6, 12), Point(5, 12), Point(4, 12), Point(3, 12), Point(2, 12), Point(1, 12), Point(0, 12),
      ],
      blockedTiles: [
        Point(0, 3), Point(1, 3),
        Point(4, 3), Point(5, 3),
        Point(0, 6), Point(1, 6),
        Point(4, 6), Point(5, 6),
        Point(0, 10), Point(1, 10),
        Point(4, 10), Point(5, 10),
      ],
      waves: [
        WaveData(waveNumber: 1, enemyCount: 10, healthMultiplier: 1.5, speedMultiplier: 1.3, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 2, enemyCount: 8, healthMultiplier: 3.0, speedMultiplier: 1.0, enemyTypes: [EnemyType.tank]),
        WaveData(waveNumber: 3, enemyCount: 15, healthMultiplier: 1.5, speedMultiplier: 1.5, enemyTypes: [EnemyType.fast]),
        WaveData(waveNumber: 4, enemyCount: 10, healthMultiplier: 3.5, speedMultiplier: 1.2, enemyTypes: [EnemyType.tank, EnemyType.basic]),
        WaveData(waveNumber: 5, enemyCount: 20, healthMultiplier: 1.8, speedMultiplier: 1.6, enemyTypes: [EnemyType.fast, EnemyType.basic]),
        WaveData(waveNumber: 6, enemyCount: 12, healthMultiplier: 4.0, speedMultiplier: 1.3, enemyTypes: [EnemyType.tank]),
        WaveData(waveNumber: 7, enemyCount: 18, healthMultiplier: 2.0, speedMultiplier: 1.7, enemyTypes: [EnemyType.basic, EnemyType.fast]),
        WaveData(waveNumber: 8, enemyCount: 10, healthMultiplier: 5.0, speedMultiplier: 1.4, enemyTypes: [EnemyType.tank, EnemyType.fast]),
        WaveData(waveNumber: 9, enemyCount: 25, healthMultiplier: 2.5, speedMultiplier: 1.8, enemyTypes: [EnemyType.fast, EnemyType.basic, EnemyType.tank]),
        WaveData(waveNumber: 10, enemyCount: 30, healthMultiplier: 3.0, speedMultiplier: 2.0, enemyTypes: [EnemyType.basic, EnemyType.fast, EnemyType.tank]),
      ],
      startingGold: 100,
      startingLives: 10,
    ),
  ];
}
