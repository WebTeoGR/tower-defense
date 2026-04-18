import 'package:flutter/material.dart';

class GameConstants {
  GameConstants._();

  // ─── Grid / Map ────────────────────────────────────────────────────────────
  static const int mapCols = 9;
  static const int mapRows = 14;

  // ─── Enemy base stats (scaled per EnemyType and wave multipliers) ──────────
  static const double enemyBaseHealth = 100.0;
  static const double enemyBaseSpeed = 60.0;

  // ─── Projectile ────────────────────────────────────────────────────────────
  static const double projectileRadius = 5.0;

  // ─── Wave timing ───────────────────────────────────────────────────────────
  static const double spawnInterval = 1.5;
  static const double timeBetweenWaves = 5.0;
  static const double passiveIncomePerSecond = 3.0;

  // ─── UI layout ─────────────────────────────────────────────────────────────
  static const double buildPanelHeight = 90.0;

  // ─── Palette ───────────────────────────────────────────────────────────────
  static const Color colorProjectile = Color(0xFFFFEB3B);
  static const Color colorHealthBarBg = Color(0xFF212121);
  static const Color colorHealthBarFg = Color(0xFF4CAF50);
  static const Color colorHealthBarLow = Color(0xFFF44336);
  static const Color colorHudBg = Color(0xDD1A1A2E);
  static const Color colorGold = Color(0xFFFFD700);
  static const Color colorLives = Color(0xFFFF5252);
}
