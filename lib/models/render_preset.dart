class RenderPreset {
  RenderPreset({
    required this.id,
    required this.userId,
    required this.mode,
    required this.name,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String mode;
  final String name;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RenderPreset.fromMap(Map<String, dynamic> map) {
    final dynamic rawPayload = map['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : <String, dynamic>{});
    return RenderPreset(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      mode: map['mode']?.toString() ?? '2d',
      name: map['name']?.toString() ?? 'Untitled',
      payload: payload,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
