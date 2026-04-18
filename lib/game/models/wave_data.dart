import 'enemy_type.dart';

class WaveData {
  const WaveData({
    required this.waveNumber,
    required this.enemyCount,
    required this.healthMultiplier,
    required this.speedMultiplier,
    this.enemyTypes = const [EnemyType.basic],
  });

  final int waveNumber;
  final int enemyCount;
  final double healthMultiplier;
  final double speedMultiplier;

  /// Enemy types to cycle through when spawning this wave.
  final List<EnemyType> enemyTypes;
}
