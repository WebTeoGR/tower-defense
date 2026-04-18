import 'package:flutter/material.dart';

enum EnemyType {
  basic,
  fast,
  tank;

  double get healthMultiplier => switch (this) {
        EnemyType.basic => 1.0,
        EnemyType.fast => 0.5,
        EnemyType.tank => 3.0,
      };

  double get speedMultiplier => switch (this) {
        EnemyType.basic => 1.0,
        EnemyType.fast => 2.2,
        EnemyType.tank => 0.45,
      };

  double get sizeMultiplier => switch (this) {
        EnemyType.basic => 1.0,
        EnemyType.fast => 0.75,
        EnemyType.tank => 1.35,
      };

  int get killReward => switch (this) {
        EnemyType.basic => 15,
        EnemyType.fast => 10,
        EnemyType.tank => 40,
      };

  Color get bodyColor => switch (this) {
        EnemyType.basic => const Color(0xFFF44336),
        EnemyType.fast => const Color(0xFFFF9800),
        EnemyType.tank => const Color(0xFF7B1FA2),
      };

  Color get outlineColor => switch (this) {
        EnemyType.basic => const Color(0xFFB71C1C),
        EnemyType.fast => const Color(0xFFE65100),
        EnemyType.tank => const Color(0xFF4A148C),
      };
}
