class RenderPreset {
  RenderPreset({
    required this.id,
    required this.shareId,
    required this.userId,
    required this.name,
    required this.title,
    required this.description,
    required this.tags,
    required this.mentionUserIds,
    required this.visibility,
    required this.mediaType,
    required this.thumbnailPayload,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.isPaid = false,
    this.priceCents,
    this.accentColorHex,
    this.viewerHasPaid = false,
  });

  final String id;
  final String shareId;
  final String userId;
  final String name;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> mentionUserIds;
  final String visibility;
  final String mediaType;
  final Map<String, dynamic> thumbnailPayload;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPaid;
  final int? priceCents;
  final String? accentColorHex;
  final bool viewerHasPaid;

  bool get isPublic => visibility != 'private';

  factory RenderPreset.fromMap(Map<String, dynamic> map) {
    final dynamic rawPayload = map['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{});
    final dynamic rawThumbPayload = map['thumbnail_payload'];
    final Map<String, dynamic> thumbPayload =
        rawThumbPayload is Map<String, dynamic>
            ? rawThumbPayload
            : (rawThumbPayload is Map
                ? Map<String, dynamic>.from(rawThumbPayload)
                : <String, dynamic>{});
    final List<String> tags = _toStringList(map['tags']);
    final List<String> mentions = _toStringList(map['mention_user_ids']);
    final String normalizedVisibility =
        map['visibility']?.toString().toLowerCase() == 'private'
            ? 'private'
            : 'public';
    return RenderPreset(
      id: map['id']?.toString() ?? '',
      shareId: map['share_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled',
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title']!.toString().trim()
          : (map['name']?.toString() ?? 'Untitled'),
      description: map['description']?.toString() ?? '',
      tags: tags,
      mentionUserIds: mentions,
      visibility: normalizedVisibility,
      mediaType: _normalizeMediaType(map['media_type'], payload),
      thumbnailPayload: thumbPayload,
      payload: payload,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isPaid: map['is_paid'] == true,
      priceCents: _toNullableInt(map['price_cents']),
      accentColorHex: _normalizeHex(map['accent_color_hex']),
      viewerHasPaid: map['viewer_has_paid'] == true,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _normalizeHex(dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final String normalized = raw.startsWith('#') ? raw : '#$raw';
    final RegExp hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!hexPattern.hasMatch(normalized)) return null;
    return normalized.toUpperCase();
  }

  static String _normalizeMediaType(
    dynamic value,
    Map<String, dynamic> payload,
  ) {
    final String raw = value?.toString().trim().toLowerCase() ?? '';
    final String normalizedRaw = _mediaTypeAlias(raw);
    if (normalizedRaw != 'image') return normalizedRaw;
    final dynamic media = payload['media'];
    if (media is Map) {
      final String type = media['type']?.toString().trim().toLowerCase() ?? '';
      final String normalizedType = _mediaTypeAlias(type);
      if (normalizedType != 'image') return normalizedType;
    }
    return 'image';
  }

  static String _mediaTypeAlias(String raw) {
    return switch (raw) {
      'gaussian_splat' ||
      'splat' ||
      'ksplat' ||
      'ply' ||
      '3dgs' =>
        'gaussian_splat',
      'triangle_mesh' ||
      'mesh' ||
      'model' ||
      'glb' ||
      'gltf' =>
        'triangle_mesh',
      'missing_3d' || 'missing3d' || 'missing' || 'no_3d' => 'missing_3d',
      _ => 'image',
    };
  }
}
