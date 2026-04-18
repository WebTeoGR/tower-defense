import 'package:flutter/material.dart';

enum TowerType {
  basic,
  sniper,
  bomb;

  String get displayName => switch (this) {
        TowerType.basic => 'Cannon',
        TowerType.sniper => 'Sniper',
        TowerType.bomb => 'Mortar',
      };

  String get description => switch (this) {
        TowerType.basic => 'Balanced',
        TowerType.sniper => 'Long range',
        TowerType.bomb => 'Area splash',
      };

  int get cost => switch (this) {
        TowerType.basic => 50,
        TowerType.sniper => 75,
        TowerType.bomb => 100,
      };

  double get range => switch (this) {
        TowerType.basic => 120.0,
        TowerType.sniper => 220.0,
        TowerType.bomb => 100.0,
      };

  double get fireRate => switch (this) {
        TowerType.basic => 1.2,
        TowerType.sniper => 0.5,
        TowerType.bomb => 0.7,
      };

  int get damage => switch (this) {
        TowerType.basic => 20,
        TowerType.sniper => 55,
        TowerType.bomb => 35,
      };

  double get splashRadius => switch (this) {
        TowerType.basic => 0.0,
        TowerType.sniper => 0.0,
        TowerType.bomb => 50.0,
      };

  double get projectileSpeed => switch (this) {
        TowerType.basic => 250.0,
        TowerType.sniper => 400.0,
        TowerType.bomb => 180.0,
      };

  Color get primaryColor => switch (this) {
        TowerType.basic => const Color(0xFF607D8B),
        TowerType.sniper => const Color(0xFF1565C0),
        TowerType.bomb => const Color(0xFF6D4C41),
      };

  Color get secondaryColor => switch (this) {
        TowerType.basic => const Color(0xFF455A64),
        TowerType.sniper => const Color(0xFF0D47A1),
        TowerType.bomb => const Color(0xFF4E342E),
      };

  Color get gunColor => switch (this) {
        TowerType.basic => const Color(0xFF263238),
        TowerType.sniper => const Color(0xFF1A237E),
        TowerType.bomb => const Color(0xFF3E2723),
      };

  Color get uiColor => switch (this) {
        TowerType.basic => const Color(0xFF78909C),
        TowerType.sniper => const Color(0xFF1976D2),
        TowerType.bomb => const Color(0xFF8D6E63),
      };
}
