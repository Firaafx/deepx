class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.actorUserId,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? actorUserId;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final dynamic rawData = map['data'];
    final Map<String, dynamic> parsedData = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{});
    return NotificationItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      actorUserId: map['actor_user_id']?.toString(),
      kind: map['kind']?.toString() ?? 'mention',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      data: parsedData,
      read: map['read'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
