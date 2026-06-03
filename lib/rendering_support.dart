import 'models/image_payload.dart';
import 'models/three_d_payload.dart';

DeepXMediaType mediaTypeFromPayload(Map<String, dynamic> payload) {
  if (payload['media'] is Map) {
    final media = Map<String, dynamic>.from(payload['media'] as Map);
    return mediaTypeFromString(media['type']?.toString());
  }
  return mediaTypeFromString(
    payload['media_type']?.toString() ??
        payload['mediaType']?.toString() ??
        payload['type']?.toString(),
  );
}

bool isThreeDPayload(Map<String, dynamic> payload) {
  return mediaTypeFromPayload(payload) != DeepXMediaType.image;
}

ThreeDAssetPayload? threeDAssetFromPayload(Map<String, dynamic> payload) {
  if (!isThreeDPayload(payload)) return null;
  final asset = ThreeDAssetPayload.fromMap(payload);
  return asset.assetUrl.trim().isEmpty ? null : asset;
}

Map<String, dynamic> simpleThreeDPayload({
  required DeepXMediaType mediaType,
  required String assetUrl,
  required String format,
  String assetPath = '',
  String contentType = 'application/octet-stream',
  int? byteSize,
  String sourceKind = 'manual',
  String? jobId,
  int? sourceImageCount,
  Map<String, dynamic> transform = const <String, dynamic>{},
  Map<String, dynamic> camera = const <String, dynamic>{},
  Map<String, dynamic> meta = const <String, dynamic>{},
}) {
  return ThreeDAssetPayload(
    mediaType: mediaType,
    assetUrl: assetUrl,
    assetPath: assetPath,
    format: format,
    contentType: contentType,
    byteSize: byteSize,
    sourceKind: sourceKind,
    jobId: jobId,
    sourceImageCount: sourceImageCount,
    transform: transform,
    camera: camera,
    meta: meta,
  ).toMap();
}

String missingThreeDAssetLabel(Map<String, dynamic> payload) {
  return switch (mediaTypeFromPayload(payload)) {
    DeepXMediaType.gaussianSplat => 'No 3DGS',
    DeepXMediaType.triangleMesh => 'No 3D mesh',
    DeepXMediaType.missing3d || DeepXMediaType.image => 'No 3D',
  };
}

Map<String, dynamic> simpleMissingThreeDPayload({
  DeepXMediaType preferredType = DeepXMediaType.missing3d,
  String reason = 'missing_3d_asset',
  String migratedFrom = '',
  String editor = 'missing_3d_payload',
}) {
  final DeepXMediaType mediaType = preferredType == DeepXMediaType.image
      ? DeepXMediaType.missing3d
      : preferredType;
  return ThreeDAssetPayload(
    mediaType: mediaType,
    assetUrl: '',
    assetPath: '',
    format: '',
    contentType: 'application/octet-stream',
    sourceKind: 'missing_3d',
    meta: <String, dynamic>{
      'editor': editor,
      'reason': reason,
      if (migratedFrom.trim().isNotEmpty) 'migratedFrom': migratedFrom.trim(),
      'preferredType': mediaType.databaseValue,
    },
  ).toMap();
}

Map<String, dynamic> normalizeRenderPayload(
  Map<String, dynamic> payload, {
  String editor = 'render_payload_normalizer',
  String sourceKind = 'upload',
}) {
  if (isThreeDPayload(payload)) {
    return <String, dynamic>{
      ...payload,
      'meta': <String, dynamic>{
        'editor': editor,
        if (payload['meta'] is Map)
          ...Map<String, dynamic>.from(payload['meta'] as Map),
      },
    };
  }
  return simpleMissingThreeDPayload(
    reason: 'image_payload_not_detail_content',
    migratedFrom: 'image',
    editor: editor,
  );
}

ImagePayloadData imagePayloadFromMap(Map<String, dynamic> payload) {
  if (payload['schemaVersion'] == ImagePayloadData.schemaVersion &&
      payload['image'] is Map) {
    final Map<String, dynamic> image =
        Map<String, dynamic>.from(payload['image'] as Map);
    final Map<String, dynamic> source = payload['source'] is Map
        ? Map<String, dynamic>.from(payload['source'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> meta = payload['meta'] is Map
        ? Map<String, dynamic>.from(payload['meta'] as Map)
        : const <String, dynamic>{};
    return ImagePayloadData(
      imageUrl: _stringValue(
        image['url'] ?? image['imageUrl'] ?? image['image_url'],
      ),
      offsetX: _safeDouble(image['offsetX'], 0),
      offsetY: _safeDouble(image['offsetY'], 0),
      scale: _safeDouble(image['scale'], 1).clamp(0.2, 8.0).toDouble(),
      rotationDegrees: _safeDouble(image['rotationDegrees'], 0),
      flipX: image['flipX'] == true,
      flipY: image['flipY'] == true,
      sourceKind: _stringValue(source['kind']).isEmpty
          ? 'upload'
          : _stringValue(source['kind']),
      linkedItemPosition: _safeInt(source['linkedItemPosition'], 0),
      meta: meta,
    );
  }

  final String url = _extractLegacyImageUrl(payload);
  final Map<String, dynamic> meta = payload['meta'] is Map
      ? Map<String, dynamic>.from(payload['meta'] as Map)
      : const <String, dynamic>{};
  return ImagePayloadData(
    imageUrl: url,
    sourceKind: _stringValue(meta['sourceKind']).isEmpty
        ? 'upload'
        : _stringValue(meta['sourceKind']),
    linkedItemPosition: _safeInt(meta['linkedItemPosition'], 0),
    meta: <String, dynamic>{
      ...meta,
      if (!meta.containsKey('upgradedFromLegacy')) 'upgradedFromLegacy': true,
    },
  );
}

Map<String, dynamic> simpleImagePayload({
  required String imageUrl,
  String editor = 'image_studio',
  double offsetX = 0,
  double offsetY = 0,
  double scale = 1,
  double rotationDegrees = 0,
  bool flipX = false,
  bool flipY = false,
  String sourceKind = 'upload',
  int linkedItemPosition = 0,
  Map<String, dynamic> meta = const <String, dynamic>{},
}) {
  return ImagePayloadData(
    imageUrl: imageUrl.trim(),
    offsetX: offsetX,
    offsetY: offsetY,
    scale: scale,
    rotationDegrees: rotationDegrees,
    flipX: flipX,
    flipY: flipY,
    sourceKind: sourceKind,
    linkedItemPosition: linkedItemPosition,
    meta: <String, dynamic>{'editor': editor, ...meta},
  ).toMap();
}

Map<String, dynamic> normalizeImagePayload(
  Map<String, dynamic> payload, {
  String editor = 'image_normalizer',
  String sourceKind = 'upload',
}) {
  final ImagePayloadData adapted = imagePayloadFromMap(payload);
  return adapted.copyWith(
    imageUrl: adapted.imageUrl.trim(),
    sourceKind: adapted.sourceKind.isEmpty ? sourceKind : adapted.sourceKind,
    meta: <String, dynamic>{'editor': editor, ...adapted.meta},
  ).toMap();
}

Map<String, dynamic> payloadWithImageUrl(
  Map<String, dynamic> payload,
  String imageUrl, {
  String? sourceKind,
  int? linkedItemPosition,
  String editor = 'image_sync',
}) {
  final ImagePayloadData adapted = imagePayloadFromMap(payload);
  return adapted.copyWith(
    imageUrl: imageUrl.trim(),
    sourceKind: sourceKind ?? adapted.sourceKind,
    linkedItemPosition: linkedItemPosition ?? adapted.linkedItemPosition,
    meta: <String, dynamic>{'editor': editor, ...adapted.meta},
  ).toMap();
}

Map<String, dynamic> payloadWithTransform(
  Map<String, dynamic> payload, {
  double? offsetX,
  double? offsetY,
  double? scale,
  double? rotationDegrees,
  bool? flipX,
  bool? flipY,
  String editor = 'image_transform',
}) {
  final ImagePayloadData adapted = imagePayloadFromMap(payload);
  return adapted.copyWith(
    offsetX: offsetX,
    offsetY: offsetY,
    scale: scale,
    rotationDegrees: rotationDegrees,
    flipX: flipX,
    flipY: flipY,
    meta: <String, dynamic>{'editor': editor, ...adapted.meta},
  ).toMap();
}

String? imageUrlFromPayload(Map<String, dynamic> payload) {
  final String value = imagePayloadFromMap(payload).imageUrl.trim();
  return value.isEmpty ? null : value;
}

double imageScaleFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).scale;
}

double imageOffsetXFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).offsetX;
}

double imageOffsetYFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).offsetY;
}

double imageRotationFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).rotationDegrees;
}

bool imageFlipXFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).flipX;
}

bool imageFlipYFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).flipY;
}

String sourceKindFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).sourceKind;
}

int linkedItemPositionFromPayload(Map<String, dynamic> payload) {
  return imagePayloadFromMap(payload).linkedItemPosition;
}

String? ambientImageUrlFromPayload(Map<String, dynamic> payload) {
  return imageUrlFromPayload(payload);
}

Map<String, dynamic>? ambientBackgroundPayloadFromPayload(
  Map<String, dynamic> payload,
) {
  final ImagePayloadData adapted = imagePayloadFromMap(payload);
  if (adapted.imageUrl.trim().isEmpty) return null;
  return adapted.copyWith(
    meta: <String, dynamic>{'editor': 'ambient_background', ...adapted.meta},
  ).toMap();
}

String _extractLegacyImageUrl(Map<String, dynamic> payload) {
  final Map<String, dynamic> scene = payload['scene'] is Map
      ? Map<String, dynamic>.from(payload['scene'] as Map)
      : payload;

  final String direct = _stringValue(
    scene['imageUrl'] ??
        scene['image_url'] ??
        scene['assetUrl'] ??
        scene['asset_url'] ??
        payload['imageUrl'] ??
        payload['image_url'] ??
        payload['assetUrl'] ??
        payload['asset_url'],
  );
  if (direct.isNotEmpty) return direct;

  final String layered = _firstImageUrlFromScene(scene);
  if (layered.isNotEmpty) return layered;

  return _firstLikelyImageUrl(payload);
}

String _firstImageUrlFromScene(Map<String, dynamic> scene) {
  final List<Map<String, dynamic>> layers = <Map<String, dynamic>>[];
  for (final MapEntry<String, dynamic> entry in scene.entries) {
    if (entry.key == 'turning_point') continue;
    final dynamic raw = entry.value;
    if (raw is! Map) continue;
    final Map<String, dynamic> layer = Map<String, dynamic>.from(raw);
    if (_stringValue(layer['isVisible']).toLowerCase() == 'false') continue;
    final String url = _stringValue(layer['url'] ?? layer['imageUrl']);
    if (url.isEmpty) continue;
    layers.add(<String, dynamic>{
      'url': url,
      'order': _safeDouble(layer['order'], 0),
      'isRect': layer['isRect'] == true,
    });
  }
  layers.sort((a, b) {
    final bool aRect = a['isRect'] == true;
    final bool bRect = b['isRect'] == true;
    if (aRect != bRect) return aRect ? 1 : -1;
    return (a['order'] as double).compareTo(b['order'] as double);
  });
  return layers.isEmpty ? '' : layers.first['url'] as String;
}

String _firstLikelyImageUrl(dynamic value) {
  if (value is String) {
    final String trimmed = value.trim();
    return _looksLikeImageUrl(trimmed) ? trimmed : '';
  }
  if (value is List) {
    for (final dynamic item in value) {
      final String found = _firstLikelyImageUrl(item);
      if (found.isNotEmpty) return found;
    }
    return '';
  }
  if (value is Map) {
    const List<String> preferredKeys = <String>[
      'imageUrl',
      'image_url',
      'url',
      'assetUrl',
      'thumbnailUrl',
      'thumbnail_url',
    ];
    for (final String key in preferredKeys) {
      if (!value.containsKey(key)) continue;
      final String found = _firstLikelyImageUrl(value[key]);
      if (found.isNotEmpty) return found;
    }
    for (final dynamic item in value.values) {
      final String found = _firstLikelyImageUrl(item);
      if (found.isNotEmpty) return found;
    }
  }
  return '';
}

bool _looksLikeImageUrl(String value) {
  if (value.isEmpty) return false;
  final String lower = value.toLowerCase();
  if (lower.startsWith('data:image/')) return true;
  if (!(lower.startsWith('http://') || lower.startsWith('https://'))) {
    return false;
  }
  return lower.contains('/storage/v1/object/') ||
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.avif') ||
      lower.contains('.png?') ||
      lower.contains('.jpg?') ||
      lower.contains('.jpeg?') ||
      lower.contains('.webp?') ||
      lower.contains('.gif?') ||
      lower.contains('.avif?');
}

String _stringValue(dynamic value) {
  return value?.toString().trim() ?? '';
}

double _safeDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _safeInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
