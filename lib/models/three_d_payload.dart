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
  final Map<String, dynamic> meta;

  Map<String, dynamic> toMap() {
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
      'transform': <String, dynamic>{
        'scale': 1,
        'position': <double>[0, 0, 0],
        'rotation': <double>[0, 0, 0],
      },
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
      meta: meta,
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
