class ImagePayloadData {
  const ImagePayloadData({
    required this.imageUrl,
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.rotationDegrees = 0,
    this.flipX = false,
    this.flipY = false,
    this.sourceKind = 'upload',
    this.linkedItemPosition = 0,
    this.meta = const <String, dynamic>{},
  });

  static const int schemaVersion = 3;

  final String imageUrl;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotationDegrees;
  final bool flipX;
  final bool flipY;
  final String sourceKind;
  final int linkedItemPosition;
  final Map<String, dynamic> meta;

  ImagePayloadData copyWith({
    String? imageUrl,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotationDegrees,
    bool? flipX,
    bool? flipY,
    String? sourceKind,
    int? linkedItemPosition,
    Map<String, dynamic>? meta,
  }) {
    return ImagePayloadData(
      imageUrl: imageUrl ?? this.imageUrl,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      sourceKind: sourceKind ?? this.sourceKind,
      linkedItemPosition: linkedItemPosition ?? this.linkedItemPosition,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'image': <String, dynamic>{
        'url': imageUrl.trim(),
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
        'rotationDegrees': rotationDegrees,
        'flipX': flipX,
        'flipY': flipY,
      },
      'source': <String, dynamic>{
        'kind': sourceKind,
        'linkedItemPosition': linkedItemPosition,
      },
      'meta': meta,
    };
  }
}
