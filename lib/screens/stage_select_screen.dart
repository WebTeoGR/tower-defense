import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../game/models/stage_data.dart';
import 'game_screen.dart';

class StageSelectScreen extends StatelessWidget {
  const StageSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('SELECT STAGE', style: TextStyle(letterSpacing: 2, fontSize: 16)),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: StageData.stages.length,
        separatorBuilder: (context, i) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _StageCard(stage: StageData.stages[i]),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final StageData stage;

  Color get _difficultyColor => switch (stage.difficulty) {
        'Easy' => const Color(0xFF4CAF50),
        'Medium' => const Color(0xFFFF9800),
        _ => const Color(0xFFF44336),
      };

  IconData get _stageIcon => switch (stage.id) {
        'forest' => Icons.forest,
        'desert' => Icons.wb_sunny,
        _ => Icons.local_fire_department,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        border: Border.all(color: stage.themeColor.withAlpha(70)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon swatch
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: stage.themeColor.withAlpha(30),
              border: Border.all(color: stage.themeColor.withAlpha(150)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_stageIcon, color: stage.themeColor, size: 30),
          ),
          const SizedBox(width: 14),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stage.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _difficultyColor.withAlpha(30),
                        border: Border.all(color: _difficultyColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stage.difficulty,
                        style: TextStyle(
                          color: _difficultyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stage.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Chip(Icons.waves, '${stage.waves.length} waves'),
                    _Chip(Icons.favorite, '${stage.startingLives} lives'),
                    _Chip(Icons.monetization_on, '${stage.startingGold}g start'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Play button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: stage.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              AudioService.instance.playSfx(SoundType.sfxButtonClick);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GameScreen(stage: stage)),
              );
            },
            child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 11),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
