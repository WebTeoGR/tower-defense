import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_service.dart';
import 'stage_select_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    AudioService.instance.playBgm(SoundType.bgmMenu);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF050510), Color(0xFF1A1A2E)],
              ),
            ),
          ),
          const _StarField(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00BCD4).withAlpha(80), width: 2),
                  ),
                  child: const Icon(Icons.shield, color: Color(0xFF00BCD4), size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TOWER\nDEFENSE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF00BCD4),
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    height: 1.1,
                    shadows: [Shadow(color: Color(0xFF00BCD4), blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 64),
                _MenuButton(
                  label: 'PLAY',
                  icon: Icons.play_arrow,
                  color: const Color(0xFF00BCD4),
                  onPressed: () {
                    AudioService.instance.playSfx(SoundType.sfxButtonClick);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StageSelectScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  label: 'EXIT',
                  icon: Icons.exit_to_app,
                  color: const Color(0xFF546E7A),
                  onPressed: () {
                    AudioService.instance.playSfx(SoundType.sfxButtonClick);
                    SystemNavigator.pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarPainter(), size: Size.infinite);
}

class _StarPainter extends CustomPainter {
  final _rng = Random(77);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(60);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        _rng.nextDouble() * 1.5 + 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(25),
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
