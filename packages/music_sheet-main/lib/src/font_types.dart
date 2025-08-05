enum FontType {
  bravura(svgPath: bravuraSvgPath, metadataPath: bravuraMetadataPath),
  petaluma(svgPath: petalumaSvgPath, metadataPath: petalumaMetadataPath);

  const FontType({required this.svgPath, required this.metadataPath});

  static const bravuraSvgPath =
      'packages/music_sheet/assets/Bravura.svg';
  static const bravuraMetadataPath =
      'packages/music_sheet/assets/bravura_metadata.json';
  static const petalumaSvgPath =
      'packages/music_sheet/assets/Petaluma.svg';
  static const petalumaMetadataPath =
      'packages/music_sheet/assets/petaluma_metadata.json';

  final String svgPath;
  final String metadataPath;
}
