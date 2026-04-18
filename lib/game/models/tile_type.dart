/// Describes what kind of tile occupies a grid cell.
enum TileType {
  /// Buildable grass — player can place towers here
  grass,

  /// Enemy path — enemies walk along these tiles, towers cannot be placed
  path,

  /// Decorative non-buildable tile (trees, rocks, etc.)
  blocked,

  /// Grass tile that already has a tower on it
  tower,
}

extension TileTypeX on TileType {
  bool get isBuildable => this == TileType.grass;
  bool get isPath => this == TileType.path;
}
