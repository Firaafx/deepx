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
    return RenderPreset(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      mode: map['mode'] as String,
      name: map['name'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
