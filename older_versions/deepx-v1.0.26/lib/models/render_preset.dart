class RenderPreset {
  RenderPreset({
    required this.id,
    required this.userId,
    required this.mode,
    required this.name,
    required this.title,
    required this.description,
    required this.tags,
    required this.mentionUserIds,
    required this.visibility,
    required this.thumbnailPayload,
    required this.thumbnailMode,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String mode;
  final String name;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> mentionUserIds;
  final String visibility;
  final Map<String, dynamic> thumbnailPayload;
  final String? thumbnailMode;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublic => visibility != 'private';

  factory RenderPreset.fromMap(Map<String, dynamic> map) {
    final dynamic rawPayload = map['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{});
    final dynamic rawThumbPayload = map['thumbnail_payload'];
    final Map<String, dynamic> thumbPayload = rawThumbPayload is Map<String, dynamic>
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
      userId: map['user_id']?.toString() ?? '',
      mode: map['mode']?.toString() ?? '2d',
      name: map['name']?.toString() ?? 'Untitled',
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title']!.toString().trim()
          : (map['name']?.toString() ?? 'Untitled'),
      description: map['description']?.toString() ?? '',
      tags: tags,
      mentionUserIds: mentions,
      visibility: normalizedVisibility,
      thumbnailPayload: thumbPayload,
      thumbnailMode: map['thumbnail_mode']?.toString(),
      payload: payload,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
}
