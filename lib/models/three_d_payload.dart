enum DeepXMediaType {
  image,
  gaussianSplat,
  triangleMesh,
}

extension DeepXMediaTypeX on DeepXMediaType {
  String get databaseValue {
    return switch (this) {
      DeepXMediaType.image => 'image',
      DeepXMediaType.gaussianSplat => 'gaussian_splat',
      DeepXMediaType.triangleMesh => 'triangle_mesh',
    };
  }
}

DeepXMediaType mediaTypeFromString(String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'gaussian_splat' ||
    'splat' ||
    'ksplat' ||
    'ply' ||
    '3dgs' =>
      DeepXMediaType.gaussianSplat,
    'triangle_mesh' ||
    'mesh' ||
    'model' ||
    'glb' ||
    'gltf' =>
      DeepXMediaType.triangleMesh,
    _ => DeepXMediaType.image,
  };
}

class ThreeDAssetPayload {
  const ThreeDAssetPayload({
    required this.mediaType,
    required this.assetUrl,
    required this.format,
    this.assetPath = '',
    this.contentType = 'application/octet-stream',
    this.byteSize,
    this.sourceKind = 'manual',
    this.jobId,
    this.sourceImageCount,
    this.transform = const <String, dynamic>{},
    this.camera = const <String, dynamic>{},
    this.meta = const <String, dynamic>{},
  });

  static const int schemaVersion = 1;

  final DeepXMediaType mediaType;
  final String assetUrl;
  final String assetPath;
  final String format;
  final String contentType;
  final int? byteSize;
  final String sourceKind;
  final String? jobId;
  final int? sourceImageCount;
  final Map<String, dynamic> transform;
  final Map<String, dynamic> camera;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> normalizedTransform =
        transform.isEmpty ? _defaultTransform() : _deepCopyMap(transform);
    final Map<String, dynamic> normalizedCamera =
        camera.isEmpty ? _defaultCamera() : _deepCopyMap(camera);
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'media': <String, dynamic>{
        'type': mediaType.databaseValue,
        'url': assetUrl.trim(),
        'path': assetPath.trim(),
        'format': format.trim().toLowerCase(),
        'contentType': contentType.trim().isEmpty
            ? 'application/octet-stream'
            : contentType.trim(),
        if (byteSize != null) 'bytes': byteSize,
      },
      'transform': normalizedTransform,
      'camera': normalizedCamera,
      'source': <String, dynamic>{
        'kind': sourceKind.trim().isEmpty ? 'manual' : sourceKind.trim(),
        if (jobId != null && jobId!.trim().isNotEmpty) 'jobId': jobId,
        if (sourceImageCount != null) 'sourceImageCount': sourceImageCount,
      },
      'meta': meta,
    };
  }

  factory ThreeDAssetPayload.fromMap(Map<String, dynamic> payload) {
    final Map<String, dynamic> media = payload['media'] is Map
        ? Map<String, dynamic>.from(payload['media'] as Map)
        : payload;
    final Map<String, dynamic> source = payload['source'] is Map
        ? Map<String, dynamic>.from(payload['source'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> transform = payload['transform'] is Map
        ? Map<String, dynamic>.from(payload['transform'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> camera = payload['camera'] is Map
        ? Map<String, dynamic>.from(payload['camera'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> meta = payload['meta'] is Map
        ? Map<String, dynamic>.from(payload['meta'] as Map)
        : const <String, dynamic>{};
    return ThreeDAssetPayload(
      mediaType: mediaTypeFromString(media['type']?.toString()),
      assetUrl: _string(media['url'] ?? media['assetUrl']),
      assetPath: _string(media['path'] ?? media['assetPath']),
      format: _string(media['format']).toLowerCase(),
      contentType: _string(media['contentType']).isEmpty
          ? 'application/octet-stream'
          : _string(media['contentType']),
      byteSize: _nullableInt(media['bytes'] ?? media['byteSize']),
      sourceKind:
          _string(source['kind']).isEmpty ? 'manual' : _string(source['kind']),
      jobId: _string(source['jobId']).isEmpty ? null : _string(source['jobId']),
      sourceImageCount: _nullableInt(source['sourceImageCount']),
      transform: transform,
      camera: camera,
      meta: meta,
    );
  }
}

Map<String, dynamic> payloadWithThreeDCamera(
  Map<String, dynamic> payload, {
  required List<double> initialPosition,
  required List<double> initialTarget,
  double fov = 45,
}) {
  final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(payload);
  return asset.copyWith(
    camera: <String, dynamic>{
      ...asset.camera,
      'initialPosition': initialPosition,
      'initialTarget': initialTarget,
      'fov': fov,
    },
  ).toMap();
}

extension ThreeDAssetPayloadCopy on ThreeDAssetPayload {
  ThreeDAssetPayload copyWith({
    DeepXMediaType? mediaType,
    String? assetUrl,
    String? assetPath,
    String? format,
    String? contentType,
    int? byteSize,
    String? sourceKind,
    String? jobId,
    int? sourceImageCount,
    Map<String, dynamic>? transform,
    Map<String, dynamic>? camera,
    Map<String, dynamic>? meta,
  }) {
    return ThreeDAssetPayload(
      mediaType: mediaType ?? this.mediaType,
      assetUrl: assetUrl ?? this.assetUrl,
      assetPath: assetPath ?? this.assetPath,
      format: format ?? this.format,
      contentType: contentType ?? this.contentType,
      byteSize: byteSize ?? this.byteSize,
      sourceKind: sourceKind ?? this.sourceKind,
      jobId: jobId ?? this.jobId,
      sourceImageCount: sourceImageCount ?? this.sourceImageCount,
      transform: transform ?? this.transform,
      camera: camera ?? this.camera,
      meta: meta ?? this.meta,
    );
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Map<String, dynamic> _defaultTransform() {
  return <String, dynamic>{
    'scale': 1,
    'position': <double>[0, 0, 0],
    'rotation': <double>[0, 0, 0],
  };
}

Map<String, dynamic> _defaultCamera() {
  return <String, dynamic>{
    'initialPosition': <double>[0, 0, 3],
    'initialTarget': <double>[0, 0, 0],
    'fov': 45,
  };
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    if (value is Map) {
      return MapEntry(key, _deepCopyMap(Map<String, dynamic>.from(value)));
    }
    if (value is List) {
      return MapEntry(key, List<dynamic>.from(value));
    }
    return MapEntry(key, value);
  });
}
