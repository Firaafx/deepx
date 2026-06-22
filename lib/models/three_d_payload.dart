import 'dart:math' as math;

enum DeepXMediaType {
  image,
  gaussianSplat,
  triangleMesh,
  missing3d,
}

extension DeepXMediaTypeX on DeepXMediaType {
  String get databaseValue {
    return switch (this) {
      DeepXMediaType.image => 'image',
      DeepXMediaType.gaussianSplat => 'gaussian_splat',
      DeepXMediaType.triangleMesh => 'triangle_mesh',
      DeepXMediaType.missing3d => 'missing_3d',
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
    'missing_3d' ||
    'missing3d' ||
    'missing' ||
    'no_3d' =>
      DeepXMediaType.missing3d,
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
    this.viewer = const <String, dynamic>{},
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
  final Map<String, dynamic> viewer;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> normalizedTransform =
        transform.isEmpty ? _defaultTransform() : _deepCopyMap(transform);
    final Map<String, dynamic> normalizedCamera =
        camera.isEmpty ? _defaultCamera() : _deepCopyMap(camera);
    final Map<String, dynamic> normalizedViewer =
        _normalizedViewerState(viewer);
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
      'viewer': normalizedViewer,
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
    final Map<String, dynamic> viewer = payload['viewer'] is Map
        ? Map<String, dynamic>.from(payload['viewer'] as Map)
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
      viewer: _normalizedViewerState(viewer),
      meta: meta,
    );
  }
}

Map<String, dynamic> payloadWithThreeDCamera(
  Map<String, dynamic> payload, {
  required List<double> initialPosition,
  required List<double> initialTarget,
  Map<String, dynamic> rotationDegrees = const <String, dynamic>{},
  double fov = 45,
  double? distance,
}) {
  final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(payload);
  return asset.copyWith(
    camera: <String, dynamic>{
      ...asset.camera,
      'initialPosition': initialPosition,
      'initialTarget': initialTarget,
      'rotationDegrees': <String, dynamic>{
        'yaw': _safeDouble(rotationDegrees['yaw'], 0),
        'pitch': _safeDouble(rotationDegrees['pitch'], 0),
        'roll': _safeDouble(rotationDegrees['roll'], 0),
      },
      'fov': fov,
      'distance': distance ?? _distance(initialPosition, initialTarget),
    },
  ).toMap();
}

Map<String, dynamic> payloadWithThreeDTransform(
  Map<String, dynamic> payload, {
  required List<double> position,
  required double scale,
  required List<double> rotation,
}) {
  final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(payload);
  return asset.copyWith(
    transform: <String, dynamic>{
      'position': _vector3(position, const <double>[0, -0.09, -0.03]),
      'scale': _safeDouble(scale, 0.071).clamp(0.001, 100).toDouble(),
      'rotation': _vector3(rotation, const <double>[0, -0.628, 0]),
    },
  ).toMap();
}

Map<String, dynamic> payloadWithThreeDViewerState(
  Map<String, dynamic> payload, {
  bool? gridVisible,
  bool? dartsVisible,
  bool? objectVisible,
  String? selectedLayerId,
  List<Map<String, dynamic>>? imageLayers,
  double? trackingSmoothing,
  double? deadZoneX,
  double? deadZoneY,
  double? deadZoneZ,
}) {
  final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(payload);
  final Map<String, dynamic> current = _normalizedViewerState(asset.viewer);
  return asset.copyWith(
    viewer: <String, dynamic>{
      ...current,
      if (gridVisible != null) 'gridVisible': gridVisible,
      if (dartsVisible != null) 'dartsVisible': dartsVisible,
      if (objectVisible != null) 'objectVisible': objectVisible,
      if (selectedLayerId != null) 'selectedLayerId': selectedLayerId,
      if (imageLayers != null) 'imageLayers': imageLayers,
      if (trackingSmoothing != null) 'trackingSmoothing': trackingSmoothing,
      if (deadZoneX != null) 'deadZoneX': deadZoneX,
      if (deadZoneY != null) 'deadZoneY': deadZoneY,
      if (deadZoneZ != null) 'deadZoneZ': deadZoneZ,
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
    Map<String, dynamic>? viewer,
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
      viewer: viewer ?? this.viewer,
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
    'scale': 0.071,
    'position': <double>[0, -0.09, -0.03],
    'rotation': <double>[0, -0.628, 0],
  };
}

Map<String, dynamic> _defaultCamera() {
  return <String, dynamic>{
    'initialPosition': <double>[0, 0, 3],
    'initialTarget': <double>[0, 0, 0],
    'rotationDegrees': <String, double>{
      'yaw': 0,
      'pitch': 0,
      'roll': 0,
    },
    'fov': 45,
    'distance': 3,
  };
}

Map<String, dynamic> _defaultViewerState() {
  return <String, dynamic>{
    'gridVisible': true,
    'dartsVisible': false,
    'objectVisible': true,
    'selectedLayerId': '',
    'imageLayers': <Map<String, dynamic>>[],
    'trackingSmoothing': 0.3,
    'deadZoneX': 0.0,
    'deadZoneY': 0.0,
    'deadZoneZ': 0.0,
  };
}

Map<String, dynamic> _normalizedViewerState(Map<String, dynamic> value) {
  final Map<String, dynamic> fallback = _defaultViewerState();
  final List<Map<String, dynamic>> imageLayers = value['imageLayers'] is List
      ? (value['imageLayers'] as List)
          .whereType<Map>()
          .map((layer) => _deepCopyMap(Map<String, dynamic>.from(layer)))
          .toList()
      : <Map<String, dynamic>>[];
  return <String, dynamic>{
    'gridVisible': _safeBool(value['gridVisible'], fallback['gridVisible']!),
    'dartsVisible': _safeBool(value['dartsVisible'], fallback['dartsVisible']!),
    'objectVisible':
        _safeBool(value['objectVisible'], fallback['objectVisible']!),
    'selectedLayerId': _string(value['selectedLayerId']),
    'imageLayers': imageLayers,
    'trackingSmoothing':
        _safeDouble(value['trackingSmoothing'], 0.3).clamp(0, 1).toDouble(),
    'deadZoneX': _safeDouble(value['deadZoneX'], 0).clamp(0, 0.2).toDouble(),
    'deadZoneY': _safeDouble(value['deadZoneY'], 0).clamp(0, 0.2).toDouble(),
    'deadZoneZ': _safeDouble(value['deadZoneZ'], 0).clamp(0, 0.4).toDouble(),
  };
}

double _safeDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _safeBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  final String text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

List<double> _vector3(dynamic value, List<double> fallback) {
  if (value is! List || value.length < 3) return List<double>.from(fallback);
  return <double>[
    _safeDouble(value[0], fallback[0]),
    _safeDouble(value[1], fallback[1]),
    _safeDouble(value[2], fallback[2]),
  ];
}

double _distance(List<double> a, List<double> b) {
  if (a.length < 3 || b.length < 3) return 3;
  final double dx = a[0] - b[0];
  final double dy = a[1] - b[1];
  final double dz = a[2] - b[2];
  final double value = (dx * dx + dy * dy + dz * dz);
  if (value <= 0) return 3;
  return double.parse(math.sqrt(value).toStringAsFixed(5));
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
