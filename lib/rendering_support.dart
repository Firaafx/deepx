import 'models/preset_payload_v2.dart';

const String kImageRenderMode = '2d';
const List<String> kSupportedRenderModes = <String>[kImageRenderMode];

String renderModeForIndex(int _) => kImageRenderMode;

int renderModeIndex(String? _) => 0;

Map<String, dynamic> simpleImagePayload({
  required String imageUrl,
  String editor = 'image_studio',
  Map<String, dynamic> meta = const <String, dynamic>{},
}) {
  final String normalizedUrl = imageUrl.trim();
  return PresetPayloadV2(
    mode: kImageRenderMode,
    scene: <String, dynamic>{
      'imageUrl': normalizedUrl,
    },
    controls: const <String, dynamic>{},
    meta: <String, dynamic>{
      'editor': editor,
      ...meta,
    },
  ).toMap();
}

Map<String, dynamic> normalizeImagePayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
  String editor = 'image_normalizer',
}) {
  final String url =
      imageUrlFromPayload(payload, fallbackMode: fallbackMode) ?? '';
  return simpleImagePayload(
    imageUrl: url,
    editor: editor,
    meta: <String, dynamic>{
      'sourceMode': fallbackMode,
    },
  );
}

String? imageUrlFromPayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
}) {
  try {
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: fallbackMode,
    );
    final String canonical =
        _stringValue(adapted.scene['imageUrl'] ?? adapted.scene['image_url']);
    if (canonical.isNotEmpty) return canonical;

    final String assetUrl = _stringValue(adapted.scene['assetUrl']);
    if (assetUrl.isNotEmpty) return assetUrl;

    final String sceneUrl = _firstImageUrlFromScene(adapted.scene);
    if (sceneUrl.isNotEmpty) return sceneUrl;

    final String recursive = _firstLikelyImageUrl(payload);
    return recursive.isEmpty ? null : recursive;
  } catch (_) {
    final String recursive = _firstLikelyImageUrl(payload);
    return recursive.isEmpty ? null : recursive;
  }
}

String? ambientImageUrlFromPayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
}) {
  return imageUrlFromPayload(payload, fallbackMode: fallbackMode);
}

Map<String, dynamic>? ambientBackgroundPayloadFromPayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
}) {
  final String? url = imageUrlFromPayload(payload, fallbackMode: fallbackMode);
  if (url == null || url.trim().isEmpty) return null;
  return simpleImagePayload(
    imageUrl: url,
    editor: 'ambient_background',
    meta: <String, dynamic>{'sourceMode': fallbackMode},
  );
}

String _firstImageUrlFromScene(Map<String, dynamic> scene) {
  final List<Map<String, dynamic>> layers = <Map<String, dynamic>>[];
  for (final MapEntry<String, dynamic> entry in scene.entries) {
    if (entry.key == 'turning_point') continue;
    final dynamic raw = entry.value;
    if (raw is! Map) continue;
    final Map<String, dynamic> layer = Map<String, dynamic>.from(raw);
    if (layer['isVisible'] == false) continue;
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
