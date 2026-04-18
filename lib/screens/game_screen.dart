import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../game/models/stage_data.dart';
import '../game/models/tower_type.dart';
import '../game/tower_defense_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.stage});

  final StageData stage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late TowerDefenseGame _game;

  @override
  void initState() {
    super.initState();
    _game = TowerDefenseGame(currentStage: widget.stage);
  }

  void _restartGame() {
    setState(() {
      _game = TowerDefenseGame(currentStage: widget.stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget<TowerDefenseGame>(
        key: ValueKey(_game),
        game: _game,
        errorBuilder: (context, ex) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Failed to load game',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text(ex.toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _restartGame, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        overlayBuilderMap: {
          'buildPanel': (context, game) => BuildPanelOverlay(game: game),
          'pauseButton': (context, game) => _PauseButton(game: game),
          'pauseMenu': (context, game) => PauseMenuOverlay(
                game: game,
                onRestart: () {
                  game.overlays.remove('pauseMenu');
                  _restartGame();
                },
                onMainMenu: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
          'restartButton': (context, game) => _RestartOverlay(
                onRestart: _restartGame,
                onMainMenu: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
        },
      ),
    );
  }
}

// ── Build panel ────────────────────────────────────────────────────────────────

class BuildPanelOverlay extends StatefulWidget {
  const BuildPanelOverlay({super.key, required this.game});

  final TowerDefenseGame game;

  @override
  State<BuildPanelOverlay> createState() => _BuildPanelOverlayState();
}

class _BuildPanelOverlayState extends State<BuildPanelOverlay> {
  TowerType _selected = TowerType.basic;
  bool _muted = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          height: 90,
          decoration: const BoxDecoration(
            color: Color(0xEE0D0D1A),
            border: Border(top: BorderSide(color: Color(0x4400BCD4))),
          ),
          child: Row(
            children: [
              ...TowerType.values.map((t) => _TowerButton(
                    type: t,
                    selected: _selected == t,
                    canAfford: widget.game.gold >= t.cost,
                    onTap: () {
                      AudioService.instance.playSfx(SoundType.sfxButtonClick);
                      setState(() => _selected = t);
                      widget.game.selectedTowerType = t;
                    },
                  )),
              // Mute toggle
              GestureDetector(
                onTap: () async {
                  await AudioService.instance.toggleMute();
                  setState(() => _muted = AudioService.instance.isMuted);
                },
                child: Container(
                  width: 44,
                  height: double.infinity,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TowerButton extends StatelessWidget {
  const _TowerButton({
    required this.type,
    required this.selected,
    required this.canAfford,
    required this.onTap,
  });

  final TowerType type;
  final bool selected;
  final bool canAfford;
  final VoidCallback onTap;

  static const _icons = {
    TowerType.basic: Icons.adjust,
    TowerType.sniper: Icons.gps_fixed,
    TowerType.bomb: Icons.radio_button_checked,
  };

  @override
  Widget build(BuildContext context) {
    final color = canAfford ? type.uiColor : Colors.grey;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(55) : Colors.transparent,
            border: Border.all(
              color: selected ? color : color.withAlpha(70),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icons[type]!, color: color, size: 22),
              const SizedBox(height: 2),
              Text(type.displayName,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              Text('${type.cost}g',
                  style: TextStyle(color: color.withAlpha(170), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pause button ───────────────────────────────────────────────────────────────

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});

  final TowerDefenseGame game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, right: 8),
        child: GestureDetector(
          onTap: () {
            AudioService.instance.playSfx(SoundType.sfxButtonClick);
            game.pauseGame();
            game.overlays.add('pauseMenu');
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xAA000000),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.pause, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Pause menu ─────────────────────────────────────────────────────────────────

class PauseMenuOverlay extends StatelessWidget {
  const PauseMenuOverlay({
    super.key,
    required this.game,
    required this.onRestart,
    required this.onMainMenu,
  });

  final TowerDefenseGame game;
  final VoidCallback onRestart;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          width: 270,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            border: Border.all(color: const Color(0xFF00BCD4).withAlpha(70)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              _PauseMenuButton(
                label: 'RESUME',
                icon: Icons.play_arrow,
                color: const Color(0xFF00BCD4),
                onPressed: () {
                  AudioService.instance.playSfx(SoundType.sfxButtonClick);
                  game.overlays.remove('pauseMenu');
                  game.resumeGame();
                },
              ),
              const SizedBox(height: 12),
              _PauseMenuButton(
                label: 'RESTART',
                icon: Icons.refresh,
                color: const Color(0xFFFF9800),
                onPressed: () {
                  AudioService.instance.playSfx(SoundType.sfxButtonClick);
                  onRestart();
                },
              ),
              const SizedBox(height: 12),
              _PauseMenuButton(
                label: 'MAIN MENU',
                icon: Icons.home,
                color: const Color(0xFF546E7A),
                onPressed: () {
                  AudioService.instance.playSfx(SoundType.sfxButtonClick);
                  onMainMenu();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseMenuButton extends StatelessWidget {
  const _PauseMenuButton({
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
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(25),
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        onPressed: onPressed,
      ),
    );
  }
}

// ── Game-over / victory restart overlay ────────────────────────────────────────

class _RestartOverlay extends StatelessWidget {
  const _RestartOverlay({required this.onRestart, required this.onMainMenu});

  final VoidCallback onRestart;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Play Again', style: TextStyle(fontSize: 18)),
              onPressed: () {
                AudioService.instance.playSfx(SoundType.sfxButtonClick);
                onRestart();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                AudioService.instance.playSfx(SoundType.sfxButtonClick);
                onMainMenu();
              },
              child: const Text('Main Menu', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
