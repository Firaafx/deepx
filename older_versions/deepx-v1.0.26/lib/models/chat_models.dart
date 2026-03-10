import 'app_user_profile.dart';

class ChatSummary {
  ChatSummary({
    required this.id,
    required this.isGroup,
    required this.name,
    required this.members,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  final String id;
  final bool isGroup;
  final String? name;
  final List<AppUserProfile> members;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  String titleFor(String currentUserId) {
    final String named = (name ?? '').trim();
    if (isGroup && named.isNotEmpty) return named;
    final AppUserProfile? other = members.cast<AppUserProfile?>().firstWhere(
          (AppUserProfile? p) => p != null && p.userId != currentUserId,
          orElse: () => null,
        );
    if (other == null) return named.isNotEmpty ? named : 'Direct chat';
    return other.displayName;
  }
}

class ChatMessageItem {
  ChatMessageItem({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.body,
    required this.sharedPresetId,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String body;
  final String? sharedPresetId;
  final DateTime createdAt;

  factory ChatMessageItem.fromMap(Map<String, dynamic> map) {
    return ChatMessageItem(
      id: map['id']?.toString() ?? '',
      chatId: map['chat_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      sharedPresetId: map['shared_preset_id']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
