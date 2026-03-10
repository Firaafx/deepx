class ProfileStats {
  const ProfileStats({
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
  });

  final int followersCount;
  final int followingCount;
  final int postsCount;

  factory ProfileStats.fromMap(Map<String, dynamic> map) {
    return ProfileStats(
      followersCount: _asInt(map['followers_count']),
      followingCount: _asInt(map['following_count']),
      postsCount: _asInt(map['posts_count']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
