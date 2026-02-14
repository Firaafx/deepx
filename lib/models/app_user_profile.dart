class AppUserProfile {
  AppUserProfile({
    required this.userId,
    required this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    required this.bio,
  });

  final String userId;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String bio;

  String get displayName {
    final String full = (fullName ?? '').trim();
    if (full.isNotEmpty) return full;
    final String handle = (username ?? '').trim();
    if (handle.isNotEmpty) return '@$handle';
    if (email.isNotEmpty) return email;
    return userId;
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      userId: map['user_id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString(),
      fullName: map['full_name']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }
}
