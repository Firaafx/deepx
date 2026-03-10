import 'app_user_profile.dart';

class PresetComment {
  PresetComment({
    required this.id,
    required this.presetId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String presetId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final AppUserProfile? author;
}
