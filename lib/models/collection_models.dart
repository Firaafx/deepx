import 'app_user_profile.dart';

class CollectionItemSnapshot {
  CollectionItemSnapshot({
    required this.id,
    required this.mode,
    required this.name,
    required this.position,
    required this.snapshot,
  });

  final String id;
  final String mode;
  final String name;
  final int position;
  final Map<String, dynamic> snapshot;

  factory CollectionItemSnapshot.fromMap(Map<String, dynamic> map) {
    return CollectionItemSnapshot(
      id: map['id']?.toString() ?? '',
      mode: map['mode']?.toString() ?? '2d',
      name: map['preset_name']?.toString() ?? 'Untitled preset',
      position: _toInt(map['position']),
      snapshot: map['preset_snapshot'] is Map
          ? Map<String, dynamic>.from(map['preset_snapshot'] as Map)
          : <String, dynamic>{},
    );
  }
}

class CollectionSummary {
  CollectionSummary({
    required this.id,
    required this.shareId,
    required this.userId,
    required this.name,
    required this.description,
    required this.tags,
    required this.mentionUserIds,
    required this.published,
    required this.thumbnailPayload,
    required this.thumbnailMode,
    required this.itemsCount,
    required this.createdAt,
    required this.updatedAt,
    required this.firstItem,
    required this.author,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.commentsCount = 0,
    this.savesCount = 0,
    this.viewsCount = 0,
    this.myReaction = 0,
    this.isSavedByCurrentUser = false,
    this.isWatchLater = false,
  });

  final String id;
  final String shareId;
  final String userId;
  final String name;
  final String description;
  final List<String> tags;
  final List<String> mentionUserIds;
  final bool published;
  final Map<String, dynamic> thumbnailPayload;
  final String? thumbnailMode;
  final int itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CollectionItemSnapshot? firstItem;
  final AppUserProfile? author;
  final int likesCount;
  final int dislikesCount;
  final int commentsCount;
  final int savesCount;
  final int viewsCount;
  final int myReaction;
  final bool isSavedByCurrentUser;
  final bool isWatchLater;
}

class CollectionDetail {
  CollectionDetail({
    required this.summary,
    required this.items,
  });

  final CollectionSummary summary;
  final List<CollectionItemSnapshot> items;
}

class CollectionDraftItem {
  CollectionDraftItem({
    required this.mode,
    required this.name,
    required this.snapshot,
  });

  final String mode;
  final String name;
  final Map<String, dynamic> snapshot;

  CollectionDraftItem copyWith({
    String? mode,
    String? name,
    Map<String, dynamic>? snapshot,
  }) {
    return CollectionDraftItem(
      mode: mode ?? this.mode,
      name: name ?? this.name,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
