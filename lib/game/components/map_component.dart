import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../models/stage_data.dart';
import '../models/tile_type.dart';
import '../utils/constants.dart';

class MapComponent extends PositionComponent with HasGameReference {
  MapComponent({required this.stage});

  final StageData stage;

  late double tileSize;
  late List<List<TileType>> _grid;
  late List<Vector2> worldPath;

  late MapTheme _theme;

  // Cached paints
  late Paint _grassPaint;
  late Paint _grassCheckerPaint;
  late Paint _pathPaint;
  late Paint _pathBorderPaint;
  late Paint _blockedPaint;
  late Paint _entryExitPaint;

  final Random _rng = Random(42);
  late List<List<double>> _grassDetail;

  @override
  Future<void> onLoad() async {
    _theme = stage.theme;
    tileSize = game.size.x / GameConstants.mapCols;

    size = Vector2(
      tileSize * GameConstants.mapCols,
      tileSize * GameConstants.mapRows,
    );

    _grassPaint = Paint()..color = _theme.grass;
    _grassCheckerPaint = Paint()
      ..color = _theme.grassDark.withAlpha(40);
    _pathPaint = Paint()..color = _theme.path;
    _pathBorderPaint = Paint()
      ..color = _theme.pathBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _blockedPaint = Paint()..color = _theme.blocked;
    _entryExitPaint = Paint()..color = const Color(0xFFFF6F00);

    _buildGrid();
    _buildWorldPath();
    _buildGrassDetail();
  }

  void _buildGrid() {
    _grid = List.generate(
      GameConstants.mapRows,
      (_) => List.filled(GameConstants.mapCols, TileType.grass),
    );

    for (final p in stage.path) {
      if (p.y >= 0 && p.y < GameConstants.mapRows && p.x >= 0 && p.x < GameConstants.mapCols) {
        _grid[p.y][p.x] = TileType.path;
      }
    }

    for (final b in stage.blockedTiles) {
      if (b.y >= 0 && b.y < GameConstants.mapRows && b.x >= 0 && b.x < GameConstants.mapCols) {
        if (_grid[b.y][b.x] != TileType.path) {
          _grid[b.y][b.x] = TileType.blocked;
        }
      }
    }
  }

  void _buildWorldPath() {
    worldPath = stage.path
        .where((p) =>
            p.y >= 0 && p.y < GameConstants.mapRows && p.x >= 0 && p.x < GameConstants.mapCols)
        .map((p) => Vector2((p.x + 0.5) * tileSize, (p.y + 0.5) * tileSize))
        .toList();
  }

  void _buildGrassDetail() {
    _grassDetail = List.generate(
      GameConstants.mapRows,
      (_) => List.generate(GameConstants.mapCols, (_) => _rng.nextDouble()),
    );
  }

  @override
  void render(Canvas canvas) {
    for (int row = 0; row < GameConstants.mapRows; row++) {
      for (int col = 0; col < GameConstants.mapCols; col++) {
        _renderTile(canvas, col, row);
      }
    }
    _drawEntryExit(canvas);
  }

  void _renderTile(Canvas canvas, int col, int row) {
    final rect = Rect.fromLTWH(col * tileSize, row * tileSize, tileSize, tileSize);

    switch (_grid[row][col]) {
      case TileType.grass:
        _drawGrassTile(canvas, rect, col, row);
      case TileType.path:
        _drawPathTile(canvas, rect);
      case TileType.blocked:
        _drawBlockedTile(canvas, rect);
      case TileType.tower:
        // Draw grass only — the tower sprite handles its own visual.
        _drawGrassTile(canvas, rect, col, row);
    }
  }

  void _drawGrassTile(Canvas canvas, Rect rect, int col, int row) {
    canvas.drawRect(rect, _grassPaint);
    if ((col + row) % 2 == 0) {
      canvas.drawRect(rect, _grassCheckerPaint);
    }
    final detail = _grassDetail[row][col];
    if (detail > 0.6) {
      final bladePaint = Paint()
        ..color = _theme.grassDark.withAlpha(80)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final cx = rect.left + detail * tileSize;
      final cy = rect.top + (1 - detail) * tileSize;
      canvas.drawLine(Offset(cx, cy), Offset(cx + 2, cy - 4), bladePaint);
    }
  }

  void _drawPathTile(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, _pathPaint);
    canvas.drawRect(rect.deflate(tileSize * 0.08), Paint()..color = _theme.path.withAlpha(180));
    canvas.drawRect(rect, _pathBorderPaint);
  }

  void _drawBlockedTile(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, _blockedPaint);

    final treePaint = Paint()..color = _theme.blocked.withAlpha(200);
    final trunkPaint = Paint()..color = const Color(0xFF5D4037);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final s = tileSize * 0.35;

    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.5), width: s * 0.3, height: s * 0.7),
      trunkPaint,
    );
    canvas.drawCircle(Offset(cx, cy - s * 0.1), s * 0.8, treePaint);
    canvas.drawCircle(
      Offset(cx, cy - s * 0.4),
      s * 0.6,
      Paint()..color = _theme.blocked.withAlpha(230),
    );
  }

  void _drawEntryExit(Canvas canvas) {
    if (worldPath.isEmpty) return;

    final labelPaint = Paint()..color = _entryExitPaint.color.withAlpha(180);
    final entry = worldPath.first;
    canvas.drawCircle(Offset(entry.x, entry.y), tileSize * 0.25, labelPaint);

    final exitP = worldPath.last;
    canvas.drawCircle(
      Offset(exitP.x, exitP.y),
      tileSize * 0.25,
      Paint()..color = const Color(0xFFE53935).withAlpha(200),
    );
  }

  bool isBuildable(int col, int row) {
    if (col < 0 || col >= GameConstants.mapCols) return false;
    if (row < 0 || row >= GameConstants.mapRows) return false;
    return _grid[row][col].isBuildable;
  }

  void setTileType(int col, int row, TileType type) {
    if (col < 0 || col >= GameConstants.mapCols) return;
    if (row < 0 || row >= GameConstants.mapRows) return;
    _grid[row][col] = type;
  }
}
