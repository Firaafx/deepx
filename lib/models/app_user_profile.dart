class AppUserProfile {
  AppUserProfile({
    required this.userId,
    required this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    required this.bio,
    this.gender,
    this.birthDate,
    required this.onboardingCompleted,
  });

  final String userId;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String bio;
  final String? gender;
  final DateTime? birthDate;
  final bool onboardingCompleted;

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
      gender: map['gender']?.toString(),
      birthDate: map['birth_date'] == null
          ? null
          : DateTime.tryParse(map['birth_date'].toString()),
      onboardingCompleted: map['onboarding_completed'] == true,
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
      'gender': gender,
      'birth_date': birthDate?.toIso8601String(),
      'onboarding_completed': onboardingCompleted,
    };
  }
}
