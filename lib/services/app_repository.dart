import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';
import '../models/app_user_profile.dart';
import '../models/chat_models.dart';
import '../models/collection_models.dart';
import '../models/feed_post.dart';
import '../models/notification_item.dart';
import '../models/preset_comment.dart';
import '../models/profile_stats.dart';
import '../models/render_preset.dart';
import '../models/three_d_payload.dart';
import '../models/watch_later_item.dart';
import '../rendering_support.dart';
import 'cache_service.dart';

class UploadedAsset {
  const UploadedAsset({
    required this.publicUrl,
    required this.path,
    required this.bucket,
  });

  final String publicUrl;
  final String path;
  final String bucket;
}

class AppRepository {
  AppRepository._();

  static final AppRepository instance = AppRepository._();

  static const String assetsBucket = 'deepx-assets';
  static const String avatarsBucket = 'deepx-avatars';
  static const String sourceImagesBucket = 'deepx-3d-sources';
  static const String threeDAssetsBucket = 'deepx-3d-assets';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}\-'
    r'[0-9a-fA-F]{4}\-'
    r'[0-9a-fA-F]{4}\-'
    r'[0-9a-fA-F]{4}\-'
    r'[0-9a-fA-F]{12}$',
  );

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  String? get currentAccessToken => _client.auth.currentSession?.accessToken;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: '${Uri.base.origin}/',
    );
  }

  Future<AuthResponse> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
    await ensureCurrentProfile();
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response =
        await _client.auth.signInWithPassword(email: email, password: password);
    await ensureCurrentProfile();
    return response;
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<AppUserProfile?> ensureCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    Map<String, dynamic>? row = await _client
        .from('profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) {
      await _client.from('profiles').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'email': user.email ?? '',
          'bio': '',
          'onboarding_completed': false,
        },
        onConflict: 'user_id',
      );
      row = await _client
          .from('profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();
    }

    await _client.from('user_settings').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'theme_mode': 'dark',
      },
      onConflict: 'user_id',
      ignoreDuplicates: true,
      defaultToNull: false,
    );

    if (row == null) return null;
    return AppUserProfile.fromMap(row);
  }

  Future<AppUserProfile?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return fetchProfileById(user.id);
  }

  Future<AppUserProfile?> fetchProfileById(String userId) async {
    final String trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    final String cacheKey = 'profile.byId.$trimmed';
    return CacheService.instance.getOrFetch<AppUserProfile?>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        final row = await _client
            .from('profiles')
            .select('*')
            .eq('user_id', trimmed)
            .maybeSingle();
        if (row == null) return null;
        return AppUserProfile.fromMap(row);
      },
      encode: (value) => value?.toMap(),
      decode: (data) => _decodeProfileNullable(data),
    );
  }

  Future<AppUserProfile?> fetchProfileByUsername(String username) async {
    final String normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final String cacheKey = 'profile.byUsername.$normalized';
    return CacheService.instance.getOrFetch<AppUserProfile?>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        final row = await _client
            .from('profiles')
            .select('*')
            .eq('username', normalized)
            .maybeSingle();
        if (row == null) return null;
        return AppUserProfile.fromMap(row);
      },
      encode: (value) => value?.toMap(),
      decode: (data) => _decodeProfileNullable(data),
    );
  }

  Future<List<RenderPreset>> fetchPublicPostsForUser(
    String userId, {
    int limit = 80,
  }) async {
    final String trimmed = userId.trim();
    if (trimmed.isEmpty) return const <RenderPreset>[];
    final String cacheKey = 'profile.publicPosts.$trimmed.$limit';
    return CacheService.instance.getOrFetch<List<RenderPreset>>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        final rows = await _client
            .from('presets')
            .select('*')
            .eq('user_id', trimmed)
            .neq('visibility', 'private')
            .order('created_at', ascending: false)
            .limit(limit);
        final List<RenderPreset> presets = (rows as List)
            .map((raw) =>
                RenderPreset.fromMap(Map<String, dynamic>.from(raw as Map)))
            .toList();
        return _applyViewerEntitlementsToPresets(presets);
      },
      encode: (value) => value.map(_encodePreset).toList(),
      decode: (data) => _decodePresetList(data),
    );
  }

  Future<List<CollectionSummary>> fetchPublicCollectionsForUser(
    String userId, {
    int limit = 40,
  }) async {
    final String trimmed = userId.trim();
    if (trimmed.isEmpty) return const <CollectionSummary>[];
    final String viewer = currentUser?.id ?? 'guest';
    final String cacheKey = 'profile.publicCollections.$trimmed.$limit.$viewer';
    return CacheService.instance.getOrFetch<List<CollectionSummary>>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        final rows = await _client
            .from('collections')
            .select('*')
            .eq('user_id', trimmed)
            .eq('published', true)
            .order('created_at', ascending: false)
            .limit(limit);
        return _hydrateCollectionSummaries(rows);
      },
      encode: (value) => value.map(_encodeCollectionSummary).toList(),
      decode: (data) => _decodeCollectionSummaryList(data),
    );
  }

  Future<bool> isUsernameAvailable(String rawUsername) async {
    final user = currentUser;
    if (user == null) return false;

    final username = rawUsername.trim().toLowerCase();
    if (username.length < 3) return false;

    final row = await _client
        .from('profiles')
        .select('user_id')
        .eq('username', username)
        .maybeSingle();

    if (row == null) return true;
    return row['user_id']?.toString() == user.id;
  }

  Future<void> completeOnboarding({
    required String username,
    required String gender,
    required DateTime birthDate,
    String? fullName,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('profiles').update(
      <String, dynamic>{
        'email': user.email ?? '',
        'username': username.trim().toLowerCase(),
        'full_name': fullName?.trim().isEmpty == true ? null : fullName?.trim(),
        'gender': gender,
        'birth_date': birthDate.toIso8601String().split('T').first,
        'onboarding_completed': true,
      },
    ).eq('user_id', user.id);
  }

  Future<void> updateCurrentProfile({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? gender,
    DateTime? birthDate,
    bool? onboardingCompleted,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final Map<String, dynamic> values = <String, dynamic>{
      'email': user.email ?? '',
    };

    if (username != null) {
      values['username'] = username.trim().isEmpty ? null : username.trim();
    }
    if (fullName != null) {
      values['full_name'] = fullName.trim().isEmpty ? null : fullName.trim();
    }
    if (bio != null) {
      values['bio'] = bio.trim();
    }
    if (avatarUrl != null) {
      values['avatar_url'] = avatarUrl;
    }
    if (gender != null) {
      values['gender'] = gender;
    }
    if (birthDate != null) {
      values['birth_date'] = birthDate.toIso8601String().split('T').first;
    }
    if (onboardingCompleted != null) {
      values['onboarding_completed'] = onboardingCompleted;
    }

    await _client.from('profiles').update(values).eq('user_id', user.id);
  }

  Future<void> setProfileVerification({
    required String userId,
    required bool isVerified,
  }) async {
    final String trimmed = userId.trim();
    if (trimmed.isEmpty) return;
    await _client.from('profiles').update(
        <String, dynamic>{'is_verified': isVerified}).eq('user_id', trimmed);
    await CacheService.instance.markDomainDirty(CacheDomain.profile);
  }

  Future<List<AppUserProfile>> searchProfiles(
    String query, {
    int limit = 20,
  }) async {
    final user = currentUser;
    if (user == null) return const <AppUserProfile>[];

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('*')
          .neq('user_id', user.id)
          .limit(limit);
      return rows
          .map((dynamic e) =>
              AppUserProfile.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final String escaped = trimmed.replaceAll(',', '');
    final String pattern = '%$escaped%';
    final Map<String, AppUserProfile> merged = <String, AppUserProfile>{};

    Future<void> collectMatches(String column) async {
      if (merged.length >= limit) return;
      final int remaining = limit - merged.length;
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('*')
          .neq('user_id', user.id)
          .ilike(column, pattern)
          .limit(remaining);
      for (final dynamic row in rows) {
        final profile =
            AppUserProfile.fromMap(Map<String, dynamic>.from(row as Map));
        merged.putIfAbsent(profile.userId, () => profile);
        if (merged.length >= limit) return;
      }
    }

    await collectMatches('username');
    await collectMatches('full_name');
    await collectMatches('email');
    return merged.values.toList();
  }

  Future<List<AppUserProfile>> searchMentionTargets(
    String query, {
    int limit = 12,
  }) {
    return searchProfiles(query, limit: limit);
  }

  Future<void> createMentionNotifications({
    required List<String> mentionedUserIds,
    required String presetId,
    required String presetTitle,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final List<String> targets = _normalizeUuidList(mentionedUserIds)
        .where((String id) => id != user.id)
        .toSet()
        .toList();
    if (targets.isEmpty) return;

    final List<Map<String, dynamic>> rows = targets
        .map(
          (id) => <String, dynamic>{
            'user_id': id,
            'actor_user_id': user.id,
            'kind': 'mention',
            'title': 'You were mentioned',
            'body': presetTitle,
            'data': <String, dynamic>{
              'preset_id': presetId,
              'preset_title': presetTitle,
            },
          },
        )
        .toList();
    await _client.from('notifications').insert(rows);
  }

  Future<List<NotificationItem>> fetchNotifications({
    int limit = 100,
    bool unreadOnly = false,
  }) async {
    final user = currentUser;
    if (user == null) return const <NotificationItem>[];
    dynamic query = _client
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    if (unreadOnly) {
      query = query.eq('read', false);
    }
    final List<dynamic> rows = await query;
    return rows
        .map((dynamic e) =>
            NotificationItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markNotificationRead(
    String notificationId, {
    bool read = true,
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'read': read})
        .eq('id', notificationId)
        .eq('user_id', user.id);
  }

  Future<void> markNotificationsSeen() async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'read': true})
        .eq('user_id', user.id)
        .eq('read', false);
  }

  Future<ProfileStats> fetchProfileStats(String userId) async {
    final String cacheKey = 'profile.stats.$userId';
    return CacheService.instance.getOrFetch<ProfileStats>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        final row = await _client
            .from('profile_stats')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) {
          return const ProfileStats(
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
          );
        }
        return ProfileStats.fromMap(row);
      },
      encode: (value) => _encodeProfileStats(value),
      decode: (data) => _decodeProfileStats(data),
    );
  }

  Future<bool> isFollowing(String targetUserId) async {
    final user = currentUser;
    if (user == null || user.id == targetUserId) return false;

    final row = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', user.id)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> setFollow({
    required String targetUserId,
    required bool follow,
  }) async {
    final user = currentUser;
    if (user == null || user.id == targetUserId) return;

    if (follow) {
      await _client.from('follows').upsert(
        <String, dynamic>{
          'follower_id': user.id,
          'following_id': targetUserId,
        },
      );
    } else {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetUserId);
    }
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.feed, CacheDomain.profile},
    );
  }

  Future<List<RenderPreset>> fetchUserPresets() async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];

    dynamic query = _client
        .from('presets')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final List<dynamic> rows = await query;
    final List<RenderPreset> presets = rows
        .map((dynamic e) =>
            RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _applyViewerEntitlementsToPresets(presets);
  }

  Future<List<RenderPreset>> fetchUserPosts(String userId) async {
    final String trimmed = userId.trim();
    if (trimmed.isEmpty) return const <RenderPreset>[];
    final String cacheKey =
        'profile.userPosts.$trimmed.${currentUser?.id == trimmed}';
    return CacheService.instance.getOrFetch<List<RenderPreset>>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async {
        dynamic query = _client
            .from('presets')
            .select('*')
            .eq('user_id', trimmed)
            .order('created_at', ascending: false);

        if (currentUser?.id != trimmed) {
          query = query.eq('visibility', 'public');
        }

        final List<dynamic> rows = await query;

        final List<RenderPreset> presets = rows
            .map((dynamic e) =>
                RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        return _applyViewerEntitlementsToPresets(presets);
      },
      encode: (value) => value.map(_encodePreset).toList(),
      decode: (data) => _decodePresetList(data),
    );
  }

  Future<List<RenderPreset>> fetchFeedPresets({int limit = 200}) async {
    final user = currentUser;
    final List<RenderPreset> merged = <RenderPreset>[];
    final Set<String> seen = <String>{};

    final List<dynamic> publicRows = await _client
        .from('presets')
        .select('*')
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .limit(limit);
    for (final dynamic raw in publicRows) {
      final RenderPreset preset =
          RenderPreset.fromMap(Map<String, dynamic>.from(raw as Map));
      if (seen.add(preset.id)) {
        merged.add(preset);
      }
    }

    if (user != null) {
      final List<dynamic> mineRows = await _client
          .from('presets')
          .select('*')
          .eq('user_id', user.id)
          .eq('visibility', 'private')
          .order('created_at', ascending: false)
          .limit(limit);
      for (final dynamic raw in mineRows) {
        final RenderPreset preset =
            RenderPreset.fromMap(Map<String, dynamic>.from(raw as Map));
        if (seen.add(preset.id)) {
          merged.add(preset);
        }
      }
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final List<RenderPreset> limited =
        merged.length > limit ? merged.sublist(0, limit) : merged;
    return _applyViewerEntitlementsToPresets(limited);
  }

  Future<List<FeedPost>> fetchFeedPosts({int limit = 200}) async {
    final String viewer = currentUser?.id ?? 'guest';
    final String cacheKey = 'feed.posts.$limit.$viewer';
    return CacheService.instance.getOrFetch<List<FeedPost>>(
      key: cacheKey,
      domains: const {CacheDomain.feed},
      fetch: () async {
        final List<RenderPreset> presets = await fetchFeedPresets(limit: limit);
        return _hydrateFeedPosts(presets);
      },
      encode: (value) => value.map(_encodeFeedPost).toList(),
      decode: (data) => _decodeFeedPostList(data),
    );
  }

  Future<List<FeedPost>> fetchGuestFeedPosts({int limit = 200}) async {
    final String cacheKey = 'feed.guest.$limit';
    return CacheService.instance.getOrFetch<List<FeedPost>>(
      key: cacheKey,
      domains: const {CacheDomain.feed},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('presets')
            .select('*')
            .eq('visibility', 'public')
            .order('created_at', ascending: false)
            .limit(limit);
        final List<RenderPreset> presets = rows
            .map((dynamic e) =>
                RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        return _hydrateFeedPosts(
            await _applyViewerEntitlementsToPresets(presets));
      },
      encode: (value) => value.map(_encodeFeedPost).toList(),
      decode: (data) => _decodeFeedPostList(data),
    );
  }

  Future<FeedPost?> fetchFeedPostById(String presetId) async {
    return fetchFeedPostByRouteId(presetId);
  }

  Future<FeedPost?> fetchFeedPostByRouteId(String idOrShareId) async {
    final String routeId = idOrShareId.trim();
    if (routeId.isEmpty) return null;
    final String viewer = currentUser?.id ?? 'guest';
    final String cacheKey = 'feed.post.$routeId.$viewer';
    return CacheService.instance.getOrFetch<FeedPost?>(
      key: cacheKey,
      domains: const {CacheDomain.feed},
      fetch: () async {
        Map<String, dynamic>? row = await _client
            .from('presets')
            .select('*')
            .eq('share_id', routeId)
            .maybeSingle();
        if (row == null && _looksLikeUuid(routeId)) {
          row = await _client
              .from('presets')
              .select('*')
              .eq('id', routeId)
              .maybeSingle();
        }
        if (row == null) return null;

        final RenderPreset preset = RenderPreset.fromMap(row);
        final bool canView =
            preset.isPublic || preset.userId == currentUser?.id;
        if (!canView) return null;
        final List<FeedPost> posts =
            await _hydrateFeedPosts(<RenderPreset>[preset]);
        if (posts.isEmpty) return null;
        return posts.first;
      },
      encode: (value) => value == null ? null : _encodeFeedPost(value),
      decode: (data) => _decodeFeedPostNullable(data),
    );
  }

  Future<List<FeedPost>> _hydrateFeedPosts(List<RenderPreset> presets) async {
    if (presets.isEmpty) return const <FeedPost>[];

    final user = currentUser;
    final Set<String> userIds =
        presets.map((RenderPreset e) => e.userId).toSet();
    final Set<String> presetIds = presets.map((RenderPreset e) => e.id).toSet();

    final Map<String, AppUserProfile> profileById =
        await _fetchProfilesByIds(userIds);
    final Map<String, Map<String, dynamic>> statsByPresetId =
        await _fetchPresetStatsByIds(presetIds);

    final Map<String, int> myReactionByPreset = <String, int>{};
    final Set<String> savedPresetIds = <String>{};
    final Set<String> watchLaterPresetIds = <String>{};
    final Set<String> followingUserIds = <String>{};
    final Map<String, bool> viewerHasPaidByPreset =
        await _fetchViewerEntitlements(
      targetType: 'post',
      targetIds: presetIds,
    );

    if (user != null) {
      final List<dynamic> myReactions = await _client
          .from('preset_reactions')
          .select('preset_id,reaction')
          .eq('user_id', user.id)
          .inFilter('preset_id', presetIds.toList());
      for (final dynamic row in myReactions) {
        final map = Map<String, dynamic>.from(row as Map);
        myReactionByPreset[map['preset_id'].toString()] =
            _toInt(map['reaction']);
      }

      final List<dynamic> mySaves = await _client
          .from('saved_presets')
          .select('preset_id')
          .eq('user_id', user.id)
          .inFilter('preset_id', presetIds.toList());
      for (final dynamic row in mySaves) {
        final map = Map<String, dynamic>.from(row as Map);
        savedPresetIds.add(map['preset_id'].toString());
      }

      final List<dynamic> watchLaterRows = await _client
          .from('watch_later_items')
          .select('target_id')
          .eq('user_id', user.id)
          .eq('target_type', 'post')
          .inFilter('target_id', presetIds.toList());
      for (final dynamic row in watchLaterRows) {
        final map = Map<String, dynamic>.from(row as Map);
        watchLaterPresetIds.add(map['target_id']?.toString() ?? '');
      }

      final List<dynamic> followingRows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id)
          .inFilter('following_id', userIds.toList());
      for (final dynamic row in followingRows) {
        final map = Map<String, dynamic>.from(row as Map);
        followingUserIds.add(map['following_id'].toString());
      }
    }

    return presets.map((RenderPreset preset) {
      final stats = statsByPresetId[preset.id] ?? const <String, dynamic>{};
      final bool viewerHasPaid = (user != null && user.id == preset.userId) ||
          (viewerHasPaidByPreset[preset.id] ?? false);
      return FeedPost(
        preset: _copyPresetWithViewerAccess(
          preset,
          viewerHasPaid: viewerHasPaid,
        ),
        author: profileById[preset.userId],
        likesCount: _toInt(stats['likes_count']),
        dislikesCount: _toInt(stats['dislikes_count']),
        commentsCount: _toInt(stats['comments_count']),
        savesCount: _toInt(stats['saves_count']),
        viewsCount: _toInt(stats['views_count']),
        myReaction: myReactionByPreset[preset.id] ?? 0,
        isSaved: savedPresetIds.contains(preset.id),
        isFollowingAuthor: followingUserIds.contains(preset.userId),
        isWatchLater: watchLaterPresetIds.contains(preset.id),
      );
    }).toList();
  }

  Future<Map<String, bool>> _fetchViewerEntitlements({
    required String targetType,
    required Set<String> targetIds,
  }) async {
    final user = currentUser;
    if (user == null || targetIds.isEmpty) return const <String, bool>{};
    final List<dynamic> rows = await _client
        .from('viewer_content_entitlements')
        .select('target_id,has_paid')
        .eq('user_id', user.id)
        .eq('target_type',
            targetType.toLowerCase() == 'collection' ? 'collection' : 'post')
        .inFilter('target_id', targetIds.toList());
    final Map<String, bool> out = <String, bool>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
      final String id = map['target_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      out[id] = map['has_paid'] == true;
    }
    return out;
  }

  Future<List<RenderPreset>> _applyViewerEntitlementsToPresets(
    List<RenderPreset> presets,
  ) async {
    if (presets.isEmpty) return presets;
    final Map<String, bool> paidByPreset = await _fetchViewerEntitlements(
      targetType: 'post',
      targetIds: presets.map((preset) => preset.id).toSet(),
    );
    final String? viewerId = currentUser?.id;
    return presets.map((preset) {
      final bool viewerHasPaid =
          (viewerId != null && viewerId == preset.userId) ||
              (paidByPreset[preset.id] ?? false);
      return _copyPresetWithViewerAccess(
        preset,
        viewerHasPaid: viewerHasPaid,
      );
    }).toList();
  }

  RenderPreset _copyPresetWithViewerAccess(
    RenderPreset preset, {
    required bool viewerHasPaid,
  }) {
    return RenderPreset(
      id: preset.id,
      shareId: preset.shareId,
      userId: preset.userId,
      name: preset.name,
      title: preset.title,
      description: preset.description,
      tags: preset.tags,
      mentionUserIds: preset.mentionUserIds,
      visibility: preset.visibility,
      mediaType: preset.mediaType,
      thumbnailPayload: preset.thumbnailPayload,
      payload: preset.payload,
      createdAt: preset.createdAt,
      updatedAt: preset.updatedAt,
      isPaid: preset.isPaid,
      priceCents: preset.priceCents,
      accentColorHex: preset.accentColorHex,
      viewerHasPaid: viewerHasPaid,
    );
  }

  Future<Map<String, AppUserProfile>> _fetchProfilesByIds(
      Set<String> ids) async {
    if (ids.isEmpty) return <String, AppUserProfile>{};
    final List<dynamic> rows = await _client
        .from('profiles')
        .select('*')
        .inFilter('user_id', ids.toList());
    final Map<String, AppUserProfile> map = <String, AppUserProfile>{};
    for (final dynamic row in rows) {
      final profile =
          AppUserProfile.fromMap(Map<String, dynamic>.from(row as Map));
      map[profile.userId] = profile;
    }
    return map;
  }

  Future<Map<String, AppUserProfile>> fetchProfilesByIds(
    Iterable<String> ids,
  ) async {
    final List<String> list = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (list.isEmpty) return <String, AppUserProfile>{};
    final String cacheKey = 'profile.byIds.${list.join(',')}';
    return CacheService.instance.getOrFetch<Map<String, AppUserProfile>>(
      key: cacheKey,
      domains: const {CacheDomain.profile},
      fetch: () async => _fetchProfilesByIds(list.toSet()),
      encode: (value) =>
          value.map((key, profile) => MapEntry(key, profile.toMap())),
      decode: (data) => _decodeProfileMap(data),
    );
  }

  Future<Map<String, Map<String, dynamic>>> fetchPresetStatsByIds(
    Iterable<String> ids,
  ) async {
    final List<String> list = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (list.isEmpty) return <String, Map<String, dynamic>>{};
    final String cacheKey = 'feed.presetStats.${list.join(',')}';
    return CacheService.instance.getOrFetch<Map<String, Map<String, dynamic>>>(
      key: cacheKey,
      domains: const {CacheDomain.feed},
      fetch: () async => _fetchPresetStatsByIds(list.toSet()),
      encode: (value) => value,
      decode: (data) => _decodeStatsMap(data),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchPresetStatsByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return <String, Map<String, dynamic>>{};
    final List<dynamic> rows = await _client
        .from('preset_stats')
        .select('*')
        .inFilter('preset_id', ids.toList());
    final Map<String, Map<String, dynamic>> map =
        <String, Map<String, dynamic>>{};
    for (final dynamic row in rows) {
      final item = Map<String, dynamic>.from(row as Map);
      map[item['preset_id'].toString()] = item;
    }
    return map;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchCollectionStatsByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return <String, Map<String, dynamic>>{};
    final List<dynamic> rows = await _client
        .from('collection_stats')
        .select('*')
        .inFilter('collection_id', ids.toList());
    final Map<String, Map<String, dynamic>> map =
        <String, Map<String, dynamic>>{};
    for (final dynamic row in rows) {
      final item = Map<String, dynamic>.from(row as Map);
      map[item['collection_id']?.toString() ?? ''] = item;
    }
    return map;
  }

  Future<void> savePreset({
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final Map<String, dynamic> imagePayload = normalizeRenderPayload(
      payload,
      editor: 'repository_save',
    );

    final existing = await _client
        .from('presets')
        .select('id')
        .eq('user_id', user.id)
        .eq('name', cleanName)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final values = <String, dynamic>{
      'user_id': user.id,
      'name': cleanName,
      'title': cleanName,
      'description': '',
      'tags': const <String>[],
      'mention_user_ids': const <String>[],
      'visibility': 'private',
      'media_type': mediaTypeFromPayload(imagePayload).databaseValue,
      'payload': imagePayload,
      'thumbnail_payload': imagePayload,
      'is_paid': false,
      'price_cents': null,
      'accent_color_hex': null,
    };

    if (existing == null) {
      await _client.from('presets').insert(values);
      return;
    }

    await _client.from('presets').update(values).eq('id', existing['id']);
  }

  Future<String> publishPresetPost({
    required String name,
    required Map<String, dynamic> payload,
    required String title,
    required String description,
    required List<String> tags,
    required List<String> mentionUserIds,
    String visibility = 'public',
    Map<String, dynamic>? thumbnailPayload,
    bool isPaid = false,
    int? priceCents,
    String? accentColorHex,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    final Map<String, dynamic> imagePayload = normalizeRenderPayload(
      payload,
      editor: 'repository_publish',
    );
    final Map<String, dynamic> imageThumbnailPayload = normalizeImagePayload(
      thumbnailPayload ?? payload,
      editor: 'repository_thumbnail',
    );

    final Map<String, dynamic> row = await _client
        .from('presets')
        .insert(
          <String, dynamic>{
            'user_id': user.id,
            'name': name.trim().isEmpty ? 'Untitled' : name.trim(),
            'title': title.trim().isEmpty ? 'Untitled' : title.trim(),
            'description': description.trim(),
            'tags': _normalizeTags(tags),
            'mention_user_ids': _normalizeUuidList(mentionUserIds),
            'visibility': visibility == 'private' ? 'private' : 'public',
            'media_type': mediaTypeFromPayload(imagePayload).databaseValue,
            'payload': imagePayload,
            'thumbnail_payload': imageThumbnailPayload,
            'is_paid': isPaid,
            'price_cents': isPaid ? _sanitizePriceCents(priceCents) : null,
            'accent_color_hex': _normalizeHexOrNull(accentColorHex),
          },
        )
        .select('*')
        .single();
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.feed, CacheDomain.profile},
    );
    return row['id']?.toString() ?? '';
  }

  Future<void> updatePresetDetail({
    required String presetId,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? mentionUserIds,
    Map<String, dynamic>? payload,
    String? visibility,
    bool? isPaid,
    int? priceCents,
    String? accentColorHex,
  }) {
    final Map<String, dynamic>? effectivePayload = payload == null
        ? null
        : normalizeRenderPayload(
            payload,
            editor: 'repository_update',
          );
    return updatePresetPost(
      presetId: presetId,
      title: title,
      description: description,
      tags: tags,
      mentionUserIds: mentionUserIds,
      payload: effectivePayload,
      visibility: visibility,
      isPaid: isPaid,
      priceCents: priceCents,
      accentColorHex: accentColorHex,
    );
  }

  Future<void> updatePresetCard({
    required String presetId,
    required Map<String, dynamic> thumbnailPayload,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? mentionUserIds,
    String? visibility,
    bool? isPaid,
    int? priceCents,
    String? accentColorHex,
  }) {
    final Map<String, dynamic> imageThumbnailPayload = normalizeImagePayload(
      thumbnailPayload,
      editor: 'repository_thumbnail_update',
    );
    return updatePresetPost(
      presetId: presetId,
      title: title,
      description: description,
      tags: tags,
      mentionUserIds: mentionUserIds,
      thumbnailPayload: imageThumbnailPayload,
      visibility: visibility,
      isPaid: isPaid,
      priceCents: priceCents,
      accentColorHex: accentColorHex,
    );
  }

  Future<void> updatePresetPost({
    required String presetId,
    String? title,
    String? description,
    List<String>? tags,
    List<String>? mentionUserIds,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? thumbnailPayload,
    String? visibility,
    bool? isPaid,
    int? priceCents,
    String? accentColorHex,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');

    final Map<String, dynamic> values = <String, dynamic>{};
    if (title != null) {
      values['title'] = title.trim().isEmpty ? 'Untitled' : title.trim();
    }
    if (description != null) {
      values['description'] = description.trim();
    }
    if (tags != null) {
      values['tags'] = _normalizeTags(tags);
    }
    if (mentionUserIds != null) {
      values['mention_user_ids'] = _normalizeUuidList(mentionUserIds);
    }
    if (payload != null) {
      final Map<String, dynamic> normalizedPayload = normalizeRenderPayload(
        payload,
        editor: 'repository_update',
      );
      values['payload'] = normalizedPayload;
      values['media_type'] =
          mediaTypeFromPayload(normalizedPayload).databaseValue;
    }
    if (thumbnailPayload != null) {
      values['thumbnail_payload'] = normalizeImagePayload(
        thumbnailPayload,
        editor: 'repository_thumbnail_update',
      );
    }
    if (visibility != null) {
      values['visibility'] = visibility == 'private' ? 'private' : 'public';
    }
    if (isPaid != null) {
      values['is_paid'] = isPaid;
      values['price_cents'] = isPaid ? _sanitizePriceCents(priceCents) : null;
    } else if (priceCents != null) {
      values['price_cents'] = _sanitizePriceCents(priceCents);
    }
    if (accentColorHex != null) {
      values['accent_color_hex'] = _normalizeHexOrNull(accentColorHex);
    }
    if (values.isEmpty) return;

    await _client
        .from('presets')
        .update(values)
        .eq('id', presetId)
        .eq('user_id', user.id);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.feed, CacheDomain.profile},
    );
  }

  Future<void> deletePresetPost(String presetId) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    await _client
        .from('presets')
        .delete()
        .eq('id', presetId)
        .eq('user_id', user.id);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.feed, CacheDomain.profile},
    );
  }

  Future<void> setPresetVisibility({
    required String presetId,
    required bool isPublic,
  }) {
    return updatePresetPost(
      presetId: presetId,
      visibility: isPublic ? 'public' : 'private',
    );
  }

  Future<Map<String, dynamic>?> fetchUserPresetByName({
    required String name,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    final row = await _client
        .from('presets')
        .select('payload')
        .eq('user_id', user.id)
        .eq('name', name)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    final dynamic payload = row['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  Future<RenderPreset?> fetchPresetById(String presetId) async {
    return fetchPresetByRouteId(presetId);
  }

  Future<RenderPreset?> fetchPresetByRouteId(String idOrShareId) async {
    final String routeId = idOrShareId.trim();
    if (routeId.isEmpty) return null;

    final row = await _client
        .from('presets')
        .select('*')
        .eq('share_id', routeId)
        .maybeSingle();
    if (row != null) {
      final RenderPreset preset = RenderPreset.fromMap(row);
      final List<RenderPreset> resolved =
          await _applyViewerEntitlementsToPresets(<RenderPreset>[preset]);
      return resolved.isEmpty ? preset : resolved.first;
    }
    if (!_looksLikeUuid(routeId)) return null;

    final uuidRow = await _client
        .from('presets')
        .select('*')
        .eq('id', routeId)
        .maybeSingle();
    if (uuidRow == null) return null;
    final RenderPreset preset = RenderPreset.fromMap(uuidRow);
    final List<RenderPreset> resolved =
        await _applyViewerEntitlementsToPresets(<RenderPreset>[preset]);
    return resolved.isEmpty ? preset : resolved.first;
  }

  Future<Map<String, RenderPreset>> fetchPresetsByIds(List<String> ids) async {
    if (ids.isEmpty) return <String, RenderPreset>{};
    final List<dynamic> rows =
        await _client.from('presets').select('*').inFilter('id', ids);
    final Map<String, RenderPreset> map = <String, RenderPreset>{};
    for (final dynamic row in rows) {
      final preset =
          RenderPreset.fromMap(Map<String, dynamic>.from(row as Map));
      map[preset.id] = preset;
    }
    final List<RenderPreset> resolved =
        await _applyViewerEntitlementsToPresets(map.values.toList());
    final Map<String, RenderPreset> withEntitlements = <String, RenderPreset>{};
    for (final RenderPreset preset in resolved) {
      withEntitlements[preset.id] = preset;
    }
    return withEntitlements;
  }

  Future<void> setReaction({
    required String presetId,
    required int reaction,
  }) async {
    final user = currentUser;
    if (user == null) return;

    if (reaction != 1 && reaction != -1) {
      await _client
          .from('preset_reactions')
          .delete()
          .eq('preset_id', presetId)
          .eq('user_id', user.id);
      await CacheService.instance.markDomainDirty(CacheDomain.feed);
      return;
    }

    await _client.from('preset_reactions').upsert(
      <String, dynamic>{
        'preset_id': presetId,
        'user_id': user.id,
        'reaction': reaction,
      },
      onConflict: 'preset_id,user_id',
    );
    await CacheService.instance.markDomainDirty(CacheDomain.feed);
  }

  Future<void> toggleSavePreset(String presetId, {required bool save}) async {
    final user = currentUser;
    if (user == null) return;

    if (save) {
      await _client.from('saved_presets').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'preset_id': presetId,
        },
      );
    } else {
      await _client
          .from('saved_presets')
          .delete()
          .eq('user_id', user.id)
          .eq('preset_id', presetId);
    }
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.feed, CacheDomain.profile, CacheDomain.saved},
    );
  }

  Future<void> toggleWatchLaterItem({
    required String targetType,
    required String targetId,
    required bool watchLater,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final String normalizedType =
        targetType.toLowerCase() == 'collection' ? 'collection' : 'post';
    if (watchLater) {
      await _client.from('watch_later_items').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'target_type': normalizedType,
          'target_id': targetId,
        },
        onConflict: 'user_id,target_type,target_id',
      );
    } else {
      await _client
          .from('watch_later_items')
          .delete()
          .eq('user_id', user.id)
          .eq('target_type', normalizedType)
          .eq('target_id', targetId);
    }
    await CacheService.instance.markDomainsDirty(
      const {
        CacheDomain.feed,
        CacheDomain.collections,
        CacheDomain.profile,
        CacheDomain.saved,
      },
    );
  }

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final String normalizedType =
        targetType.toLowerCase() == 'collection' ? 'collection' : 'post';
    final String cleanReason = reason.trim();
    if (cleanReason.isEmpty) return;
    await _client.from('content_reports').insert(
      <String, dynamic>{
        'reporter_user_id': user.id,
        'target_type': normalizedType,
        'target_id': targetId,
        'reason': cleanReason,
        'details': details?.trim().isEmpty == true ? null : details?.trim(),
      },
    );
  }

  Future<void> setRecommendationExclusion({
    required String exclusionType,
    required String targetId,
    required bool excluded,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final String normalizedType;
    switch (exclusionType.toLowerCase()) {
      case 'post':
      case 'collection':
      case 'user':
        normalizedType = exclusionType.toLowerCase();
        break;
      default:
        normalizedType = 'post';
    }
    if (excluded) {
      await _client.from('recommendation_exclusions').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'exclusion_type': normalizedType,
          'target_id': targetId,
        },
        onConflict: 'user_id,exclusion_type,target_id',
      );
    } else {
      await _client
          .from('recommendation_exclusions')
          .delete()
          .eq('user_id', user.id)
          .eq('exclusion_type', normalizedType)
          .eq('target_id', targetId);
    }
  }

  Future<void> setViewerContentEntitlement({
    required String userId,
    required String targetType,
    required String targetId,
    required bool hasPaid,
  }) async {
    final String normalizedType =
        targetType.toLowerCase() == 'collection' ? 'collection' : 'post';
    if (hasPaid) {
      await _client.from('viewer_content_entitlements').upsert(
        <String, dynamic>{
          'user_id': userId,
          'target_type': normalizedType,
          'target_id': targetId,
          'has_paid': true,
        },
        onConflict: 'user_id,target_type,target_id',
      );
    } else {
      await _client.from('viewer_content_entitlements').upsert(
        <String, dynamic>{
          'user_id': userId,
          'target_type': normalizedType,
          'target_id': targetId,
          'has_paid': false,
        },
        onConflict: 'user_id,target_type,target_id',
      );
    }
    await CacheService.instance.markDomainsDirty(
      const {
        CacheDomain.feed,
        CacheDomain.collections,
        CacheDomain.profile,
        CacheDomain.saved,
      },
    );
  }

  Future<List<WatchLaterItem>> fetchWatchLaterForCurrentUser({
    int limit = 240,
  }) async {
    final user = currentUser;
    if (user == null) return const <WatchLaterItem>[];
    final String cacheKey = 'saved.watchLater.${user.id}.$limit';
    return CacheService.instance.getOrFetch<List<WatchLaterItem>>(
      key: cacheKey,
      domains: const {CacheDomain.profile, CacheDomain.saved},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('watch_later_items')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(limit);
        if (rows.isEmpty) return const <WatchLaterItem>[];

        final List<String> postIds = <String>[];
        final List<String> collectionIds = <String>[];
        for (final dynamic raw in rows) {
          final map = Map<String, dynamic>.from(raw as Map);
          final String id = map['target_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          if ((map['target_type']?.toString() ?? '') == 'collection') {
            collectionIds.add(id);
          } else {
            postIds.add(id);
          }
        }

        final Map<String, RenderPreset> postsById = postIds.isEmpty
            ? <String, RenderPreset>{}
            : await fetchPresetsByIds(postIds);
        final Map<String, CollectionSummary> collectionsById =
            <String, CollectionSummary>{};
        if (collectionIds.isNotEmpty) {
          final List<dynamic> collectionRows = await _client
              .from('collections')
              .select('*')
              .inFilter('id', collectionIds);
          final hydrated = await _hydrateCollectionSummaries(collectionRows);
          for (final summary in hydrated) {
            collectionsById[summary.id] = summary;
          }
        }

        final List<WatchLaterItem> items = <WatchLaterItem>[];
        for (final dynamic raw in rows) {
          final map = Map<String, dynamic>.from(raw as Map);
          final String id = map['id']?.toString() ?? '';
          final String type = map['target_type']?.toString() ?? 'post';
          final String targetId = map['target_id']?.toString() ?? '';
          final DateTime createdAt =
              DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          if (targetId.isEmpty) continue;
          if (type == 'collection') {
            final summary = collectionsById[targetId];
            if (summary == null) continue;
            items.add(
              WatchLaterItem.collection(
                id: id,
                createdAt: createdAt,
                collection: summary,
              ),
            );
          } else {
            final post = postsById[targetId];
            if (post == null) continue;
            items.add(
              WatchLaterItem.post(
                id: id,
                createdAt: createdAt,
                post: post,
              ),
            );
          }
        }
        return items;
      },
      encode: (value) => value.map(_encodeWatchLaterItem).toList(),
      decode: (data) => _decodeWatchLaterList(data),
    );
  }

  Future<List<PresetComment>> fetchPresetComments(
    String presetId, {
    int limit = 200,
  }) async {
    final String cacheKey = 'comments.preset.$presetId.$limit';
    return CacheService.instance.getOrFetch<List<PresetComment>>(
      key: cacheKey,
      domains: const {CacheDomain.comments},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('preset_comments')
            .select('*')
            .eq('preset_id', presetId)
            .order('created_at', ascending: true)
            .limit(limit);

        final Set<String> userIds = rows
            .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toSet();
        final Map<String, AppUserProfile> profiles =
            await _fetchProfilesByIds(userIds);

        return rows.map((dynamic e) {
          final map = Map<String, dynamic>.from(e as Map);
          final userId = map['user_id']?.toString() ?? '';
          return PresetComment(
            id: map['id']?.toString() ?? '',
            presetId: map['preset_id']?.toString() ?? '',
            userId: userId,
            content: map['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            author: profiles[userId],
          );
        }).toList();
      },
      encode: (value) => value.map(_encodePresetComment).toList(),
      decode: (data) => _decodePresetCommentList(data),
    );
  }

  Future<void> addPresetComment({
    required String presetId,
    required String content,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final text = content.trim();
    if (text.isEmpty) return;

    await _client.from('preset_comments').insert(
      <String, dynamic>{
        'preset_id': presetId,
        'user_id': user.id,
        'content': text,
      },
    );
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.comments, CacheDomain.feed},
    );
  }

  Future<void> recordPresetView(String presetId) async {
    await _client.rpc(
      'record_preset_view',
      params: <String, dynamic>{'p_preset_id': presetId},
    );
    await CacheService.instance.markDomainDirty(CacheDomain.feed);
  }

  Future<List<RenderPreset>> fetchSavedPresetsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];
    final String cacheKey = 'saved.presets.${user.id}';
    return CacheService.instance.getOrFetch<List<RenderPreset>>(
      key: cacheKey,
      domains: const {CacheDomain.profile, CacheDomain.saved},
      fetch: () async {
        final List<dynamic> saveRows = await _client
            .from('saved_presets')
            .select('preset_id,created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        final List<String> presetIds = saveRows
            .map((dynamic e) => (e as Map)['preset_id']?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toList();
        if (presetIds.isEmpty) return const <RenderPreset>[];

        final Map<String, RenderPreset> presetById =
            await fetchPresetsByIds(presetIds);
        final List<RenderPreset> ordered = <RenderPreset>[];
        for (final String id in presetIds) {
          final preset = presetById[id];
          if (preset != null) ordered.add(preset);
        }
        return ordered;
      },
      encode: (value) => value.map(_encodePreset).toList(),
      decode: (data) => _decodePresetList(data),
    );
  }

  Future<List<CollectionSummary>> fetchSavedCollectionsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <CollectionSummary>[];
    final String cacheKey = 'saved.collections.${user.id}';
    return CacheService.instance.getOrFetch<List<CollectionSummary>>(
      key: cacheKey,
      domains: const {CacheDomain.profile, CacheDomain.saved},
      fetch: () async {
        final List<dynamic> saveRows = await _client
            .from('saved_collections')
            .select('collection_id,created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        final List<String> collectionIds = saveRows
            .map((dynamic e) => (e as Map)['collection_id']?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toList();
        if (collectionIds.isEmpty) return const <CollectionSummary>[];
        final List<dynamic> rows = await _client
            .from('collections')
            .select('*')
            .inFilter('id', collectionIds);
        final List<CollectionSummary> hydrated =
            await _hydrateCollectionSummaries(rows);
        final Map<String, CollectionSummary> byId = <String, CollectionSummary>{
          for (final summary in hydrated) summary.id: summary,
        };
        final List<CollectionSummary> ordered = <CollectionSummary>[];
        for (final id in collectionIds) {
          final summary = byId[id];
          if (summary != null) ordered.add(summary);
        }
        return ordered;
      },
      encode: (value) => value.map(_encodeCollectionSummary).toList(),
      decode: (data) => _decodeCollectionSummaryList(data),
    );
  }

  Future<List<Map<String, dynamic>>> fetchSavedGrid({
    String filter = 'all',
    int limit = 300,
  }) async {
    final user = currentUser;
    if (user == null) return const <Map<String, dynamic>>[];

    final String normalized = filter.trim().toLowerCase();
    final bool wantsPosts = normalized == 'all' || normalized == 'saved_posts';
    final bool wantsCollections =
        normalized == 'all' || normalized == 'saved_collections';
    final bool wantsWatchLater =
        normalized == 'all' || normalized == 'watch_later';

    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];

    if (wantsPosts) {
      final List<dynamic> rows = await _client
          .from('saved_presets')
          .select('preset_id,created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      final List<String> ids = rows
          .map((dynamic row) => (row as Map)['preset_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        final presets = await fetchPresetsByIds(ids);
        for (final dynamic row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final String id = map['preset_id']?.toString() ?? '';
          final preset = presets[id];
          if (preset == null) continue;
          entries.add(
            <String, dynamic>{
              'kind': 'saved_post',
              'createdAt':
                  DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0),
              'preset': preset,
            },
          );
        }
      }
    }

    if (wantsCollections) {
      final List<dynamic> rows = await _client
          .from('saved_collections')
          .select('collection_id,created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      final List<String> ids = rows
          .map((dynamic row) => (row as Map)['collection_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) {
        final List<dynamic> summariesRaw =
            await _client.from('collections').select('*').inFilter('id', ids);
        final summaries = await _hydrateCollectionSummaries(summariesRaw);
        final Map<String, CollectionSummary> byId = <String, CollectionSummary>{
          for (final summary in summaries) summary.id: summary,
        };
        for (final dynamic row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final String id = map['collection_id']?.toString() ?? '';
          final summary = byId[id];
          if (summary == null) continue;
          entries.add(
            <String, dynamic>{
              'kind': 'saved_collection',
              'createdAt':
                  DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0),
              'collection': summary,
            },
          );
        }
      }
    }

    if (wantsWatchLater) {
      final List<WatchLaterItem> watchLater =
          await fetchWatchLaterForCurrentUser(
        limit: limit,
      );
      for (final item in watchLater) {
        entries.add(
          <String, dynamic>{
            'kind': item.type == WatchLaterTargetType.collection
                ? 'watch_later_collection'
                : 'watch_later_post',
            'createdAt': item.createdAt,
            if (item.post != null) 'preset': item.post,
            if (item.collection != null) 'collection': item.collection,
          },
        );
      }
    }

    entries.sort((a, b) {
      final DateTime aTime = a['createdAt'] is DateTime
          ? a['createdAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime = b['createdAt'] is DateTime
          ? b['createdAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    if (entries.length > limit) {
      return entries.sublist(0, limit);
    }
    return entries;
  }

  Future<List<RenderPreset>> fetchHistoryPresetsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];
    final String cacheKey = 'profile.history.${user.id}';
    return CacheService.instance.getOrFetch<List<RenderPreset>>(
      key: cacheKey,
      domains: const {CacheDomain.profile, CacheDomain.saved},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('view_history')
            .select('preset_id,last_viewed_at')
            .eq('user_id', user.id)
            .order('last_viewed_at', ascending: false)
            .limit(200);

        final List<String> presetIds = rows
            .map((dynamic e) => (e as Map)['preset_id']?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toList();
        if (presetIds.isEmpty) return const <RenderPreset>[];

        final Map<String, RenderPreset> presetById =
            await fetchPresetsByIds(presetIds);
        final List<RenderPreset> ordered = <RenderPreset>[];
        for (final String id in presetIds) {
          final preset = presetById[id];
          if (preset != null) ordered.add(preset);
        }
        return ordered;
      },
      encode: (value) => value.map(_encodePreset).toList(),
      decode: (data) => _decodePresetList(data),
    );
  }

  Future<List<RenderPreset>> fetchRecentViewedPresetsForSharing() async {
    final List<RenderPreset> history =
        await fetchHistoryPresetsForCurrentUser();
    if (history.isNotEmpty) return history;
    return fetchFeedPresets(limit: 40);
  }

  Future<List<ChatSummary>> fetchChatsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <ChatSummary>[];

    final List<dynamic> mineRows = await _client
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', user.id);
    final List<String> chatIds = mineRows
        .map((dynamic e) => (e as Map)['chat_id']?.toString() ?? '')
        .where((String e) => e.isNotEmpty)
        .toList();

    if (chatIds.isEmpty) return const <ChatSummary>[];

    final List<dynamic> chatRows = await _client
        .from('chats')
        .select('*')
        .inFilter('id', chatIds)
        .order('updated_at', ascending: false);

    final List<dynamic> memberRows = await _client
        .from('chat_members')
        .select('*')
        .inFilter('chat_id', chatIds);

    final Set<String> memberIds = memberRows
        .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
        .where((String e) => e.isNotEmpty)
        .toSet();
    final Map<String, AppUserProfile> profileById =
        await _fetchProfilesByIds(memberIds);

    final Map<String, Map<String, dynamic>?> lastRowByChat =
        <String, Map<String, dynamic>?>{};
    final List<Future<void>> pending = <Future<void>>[];
    for (final String chatId in chatIds) {
      pending.add(() async {
        final row = await _client
            .from('chat_messages')
            .select('*')
            .eq('chat_id', chatId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        lastRowByChat[chatId] = row;
      }());
    }
    await Future.wait(pending);

    return chatRows.map((dynamic e) {
      final map = Map<String, dynamic>.from(e as Map);
      final chatId = map['id']?.toString() ?? '';
      final bool isGroup = map['is_group'] == true;
      final List<AppUserProfile> members = memberRows
          .where((dynamic row) => (row as Map)['chat_id']?.toString() == chatId)
          .map((dynamic row) => (row as Map)['user_id']?.toString() ?? '')
          .map((String id) => profileById[id])
          .whereType<AppUserProfile>()
          .toList();

      final Map<String, dynamic>? last = lastRowByChat[chatId];
      final String? lastMessage =
          (last == null) ? null : last['body']?.toString().trim();
      final DateTime? lastAt = (last == null)
          ? null
          : DateTime.tryParse(last['created_at']?.toString() ?? '');

      return ChatSummary(
        id: chatId,
        isGroup: isGroup,
        name: map['name']?.toString(),
        members: members,
        lastMessage: (lastMessage == null || lastMessage.isEmpty)
            ? (last?['shared_preset_id'] != null ? 'Shared a preset' : null)
            : lastMessage,
        lastMessageAt: lastAt,
      );
    }).toList();
  }

  Future<List<AppUserProfile>> fetchChatMembers(String chatId) async {
    final List<dynamic> rows = await _client
        .from('chat_members')
        .select('user_id')
        .eq('chat_id', chatId);
    final Set<String> userIds = rows
        .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
        .where((String e) => e.isNotEmpty)
        .toSet();
    final Map<String, AppUserProfile> profiles =
        await _fetchProfilesByIds(userIds);
    return userIds
        .map((String id) => profiles[id])
        .whereType<AppUserProfile>()
        .toList();
  }

  Stream<List<ChatMessageItem>> streamMessagesForChat(String chatId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: <String>['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((List<Map<String, dynamic>> rows) => rows
            .map((Map<String, dynamic> row) => ChatMessageItem.fromMap(row))
            .toList());
  }

  Future<void> sendChatMessage({
    required String chatId,
    required String body,
    String? sharedPresetId,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final String trimmed = body.trim();
    if (trimmed.isEmpty && sharedPresetId == null) return;

    await _client.from('chat_messages').insert(
      <String, dynamic>{
        'chat_id': chatId,
        'sender_id': user.id,
        'body': trimmed,
        'shared_preset_id': sharedPresetId,
      },
    );

    await _client.from('chats').update(<String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', chatId);

    try {
      final List<dynamic> memberRows = await _client
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId);
      final Set<String> targets = memberRows
          .map((dynamic row) => (row as Map)['user_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty && id != user.id)
          .toSet();
      if (targets.isNotEmpty) {
        final senderProfile = await ensureCurrentProfile();
        final String senderName =
            senderProfile?.displayName ?? user.email ?? 'User';
        final String preview =
            trimmed.isNotEmpty ? trimmed : 'Shared a preset with you';
        final rows = targets
            .map(
              (target) => <String, dynamic>{
                'user_id': target,
                'actor_user_id': user.id,
                'kind': 'system',
                'title': 'New message from $senderName',
                'body': preview,
                'data': <String, dynamic>{
                  'type': 'chat_message',
                  'chat_id': chatId,
                  'sender_id': user.id,
                  'preview': preview,
                  if (sharedPresetId != null)
                    'shared_preset_id': sharedPresetId,
                },
              },
            )
            .toList();
        await _client.from('notifications').insert(rows);
      }
    } catch (_) {
      // Never block chat delivery because notification fanout failed.
    }
  }

  Future<String> createOrGetDirectChat(String otherUserId) async {
    final dynamic value = await _client.rpc(
      'create_or_get_direct_chat',
      params: <String, dynamic>{'other_user_id': otherUserId},
    );
    return value?.toString() ?? '';
  }

  Future<void> shareCollectionToUser({
    required String recipientUserId,
    required CollectionSummary summary,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    if (recipientUserId.trim().isEmpty) return;
    final String chatId = await createOrGetDirectChat(recipientUserId);
    if (chatId.isEmpty) {
      throw Exception('Unable to create direct chat.');
    }
    final String routeId =
        summary.shareId.trim().isNotEmpty ? summary.shareId.trim() : summary.id;
    String prefix = '';
    if (Uri.base.host.toLowerCase().endsWith('github.io')) {
      final List<String> segments =
          Uri.base.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        prefix = '/${segments.first}';
      }
    }
    final String link =
        '${Uri.base.origin}$prefix/collection/${Uri.encodeComponent(routeId)}';
    await sendChatMessage(
      chatId: chatId,
      body: 'Shared a collection: ${summary.name}\n$link',
    );
  }

  Future<String> createGroupChat({
    required String name,
    required List<String> memberIds,
  }) async {
    final chatId = await createGroupChatRpc(name: name, memberIds: memberIds);
    if (chatId.isEmpty) {
      throw Exception(
        'Group chat creation RPC returned an empty id. Check migration state.',
      );
    }
    return chatId;
  }

  Future<String> createGroupChatRpc({
    required String name,
    required List<String> memberIds,
  }) async {
    final user = currentUser;
    if (user == null) return '';
    final dynamic value = await _client.rpc(
      'create_group_chat',
      params: <String, dynamic>{
        'group_name': name.trim(),
        'member_ids': memberIds,
      },
    );
    return value?.toString() ?? '';
  }

  Future<List<CollectionSummary>> fetchPublishedCollections({
    int limit = 120,
  }) async {
    final String viewer = currentUser?.id ?? 'guest';
    final String cacheKey = 'collections.published.$limit.$viewer';
    return CacheService.instance.getOrFetch<List<CollectionSummary>>(
      key: cacheKey,
      domains: const {CacheDomain.collections},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('collections')
            .select('*')
            .eq('published', true)
            .order('created_at', ascending: false)
            .limit(limit);
        return _hydrateCollectionSummaries(rows);
      },
      encode: (value) => value.map(_encodeCollectionSummary).toList(),
      decode: (data) => _decodeCollectionSummaryList(data),
    );
  }

  Future<List<CollectionSummary>> fetchCollectionsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <CollectionSummary>[];
    final String cacheKey = 'collections.mine.${user.id}';
    return CacheService.instance.getOrFetch<List<CollectionSummary>>(
      key: cacheKey,
      domains: const {CacheDomain.collections, CacheDomain.profile},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('collections')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        return _hydrateCollectionSummaries(rows);
      },
      encode: (value) => value.map(_encodeCollectionSummary).toList(),
      decode: (data) => _decodeCollectionSummaryList(data),
    );
  }

  Future<CollectionDetail?> fetchCollectionById(String collectionId) async {
    return fetchCollectionByRouteId(collectionId);
  }

  Future<CollectionDetail?> fetchCollectionByRouteId(
    String idOrShareId,
  ) async {
    final String routeId = idOrShareId.trim();
    if (routeId.isEmpty) return null;
    final String viewer = currentUser?.id ?? 'guest';
    final String cacheKey = 'collections.detail.$routeId.$viewer';
    return CacheService.instance.getOrFetch<CollectionDetail?>(
      key: cacheKey,
      domains: const {CacheDomain.collections},
      fetch: () async {
        Map<String, dynamic>? row = await _client
            .from('collections')
            .select('*')
            .eq('share_id', routeId)
            .maybeSingle();
        if (row == null && _looksLikeUuid(routeId)) {
          row = await _client
              .from('collections')
              .select('*')
              .eq('id', routeId)
              .maybeSingle();
        }
        if (row == null) return null;

        final String collectionId = row['id']?.toString() ?? '';
        if (collectionId.isEmpty) return null;

        final List<dynamic> itemRows = await _client
            .from('collection_items')
            .select('*')
            .eq('collection_id', collectionId)
            .order('position', ascending: true);

        final profile = await fetchProfileById(row['user_id'].toString());
        final statsByCollection =
            await _fetchCollectionStatsByIds(<String>{collectionId});
        final stats =
            statsByCollection[collectionId] ?? const <String, dynamic>{};
        bool isSavedByCurrentUser = false;
        bool isWatchLater = false;
        int myReaction = 0;
        bool viewerHasPaid = false;
        final user = currentUser;
        if (user != null) {
          final savedRow = await _client
              .from('saved_collections')
              .select('collection_id')
              .eq('user_id', user.id)
              .eq('collection_id', collectionId)
              .maybeSingle();
          isSavedByCurrentUser = savedRow != null;

          final watchRow = await _client
              .from('watch_later_items')
              .select('target_id')
              .eq('user_id', user.id)
              .eq('target_type', 'collection')
              .eq('target_id', collectionId)
              .maybeSingle();
          isWatchLater = watchRow != null;

          final reactionRow = await _client
              .from('collection_reactions')
              .select('reaction')
              .eq('user_id', user.id)
              .eq('collection_id', collectionId)
              .maybeSingle();
          myReaction = _toInt(reactionRow?['reaction']);

          final entitlementRow = await _client
              .from('viewer_content_entitlements')
              .select('has_paid')
              .eq('user_id', user.id)
              .eq('target_type', 'collection')
              .eq('target_id', collectionId)
              .maybeSingle();
          viewerHasPaid = user.id == row['user_id']?.toString() ||
              entitlementRow?['has_paid'] == true;
        }
        final items = itemRows
            .map((dynamic e) => CollectionItemSnapshot.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList();

        return CollectionDetail(
          summary: CollectionSummary(
            id: collectionId,
            shareId: row['share_id']?.toString() ?? '',
            userId: row['user_id'].toString(),
            name: row['name']?.toString() ?? 'Untitled collection',
            description: row['description']?.toString() ?? '',
            tags: _stringListFrom(row['tags']),
            mentionUserIds: _stringListFrom(row['mention_user_ids']),
            published: row['published'] == true,
            thumbnailPayload: _mapFrom(row['thumbnail_payload']),
            itemsCount: items.length,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            firstItem: items.isEmpty ? null : items.first,
            author: profile,
            likesCount: _toInt(stats['likes_count']),
            dislikesCount: _toInt(stats['dislikes_count']),
            commentsCount: _toInt(stats['comments_count']),
            savesCount: _toInt(stats['saves_count']),
            viewsCount: _toInt(stats['views_count']),
            myReaction: myReaction,
            isSavedByCurrentUser: isSavedByCurrentUser,
            isWatchLater: isWatchLater,
            isPaid: row['is_paid'] == true,
            priceCents: _toNullableInt(row['price_cents']),
            accentColorHex:
                _normalizeHexOrNull(row['accent_color_hex']?.toString()),
            viewerHasPaid: viewerHasPaid,
          ),
          items: items,
        );
      },
      encode: (value) => value == null ? null : _encodeCollectionDetail(value),
      decode: (data) => _decodeCollectionDetailNullable(data),
    );
  }

  Future<String> saveCollectionWithItems({
    String? collectionId,
    required String name,
    String description = '',
    List<String> tags = const <String>[],
    List<String> mentionUserIds = const <String>[],
    Map<String, dynamic>? thumbnailPayload,
    required bool publish,
    required List<CollectionDraftItem> items,
    bool isPaid = false,
    int? priceCents,
    String? accentColorHex,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (items.isEmpty) throw Exception('Collection needs at least one preset.');
    final List<CollectionDraftItem> imageItems = items
        .map(
          (item) => item.copyWith(
            snapshot: normalizeImagePayload(
              item.snapshot,
              editor: 'repository_collection_item',
            ),
          ),
        )
        .toList();
    final Map<String, dynamic> imageThumbnailPayload = normalizeImagePayload(
      thumbnailPayload ?? imageItems.first.snapshot,
      editor: 'repository_collection_thumbnail',
    );

    String id = collectionId ?? '';

    if (id.isEmpty) {
      final inserted = await _client
          .from('collections')
          .insert(
            <String, dynamic>{
              'user_id': user.id,
              'name': name.trim().isEmpty ? 'Untitled collection' : name.trim(),
              'description': description,
              'tags': _normalizeTags(tags),
              'mention_user_ids': _normalizeUuidList(mentionUserIds),
              'thumbnail_payload': imageThumbnailPayload,
              'published': publish,
              'is_paid': isPaid,
              'price_cents': isPaid ? _sanitizePriceCents(priceCents) : null,
              'accent_color_hex': _normalizeHexOrNull(accentColorHex),
            },
          )
          .select('*')
          .single();
      id = inserted['id'].toString();
    } else {
      final Map<String, dynamic> values = <String, dynamic>{
        'name': name.trim().isEmpty ? 'Untitled collection' : name.trim(),
        'description': description,
        'tags': _normalizeTags(tags),
        'mention_user_ids': _normalizeUuidList(mentionUserIds),
        'published': publish,
        'is_paid': isPaid,
        'price_cents': isPaid ? _sanitizePriceCents(priceCents) : null,
      };
      values['thumbnail_payload'] = imageThumbnailPayload;
      if (accentColorHex != null) {
        values['accent_color_hex'] = _normalizeHexOrNull(accentColorHex);
      }
      await _client
          .from('collections')
          .update(values)
          .eq('id', id)
          .eq('user_id', user.id);

      await _client.from('collection_items').delete().eq('collection_id', id);
    }

    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < imageItems.length; i++) {
      rows.add(
        <String, dynamic>{
          'collection_id': id,
          'position': i,
          'preset_name': imageItems[i].name,
          'preset_snapshot': imageItems[i].snapshot,
        },
      );
    }
    await _client.from('collection_items').insert(rows);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.collections, CacheDomain.profile},
    );
    return id;
  }

  Future<void> updateCollectionItemsDetail({
    required String collectionId,
    required String name,
    String description = '',
    List<String> tags = const <String>[],
    List<String> mentionUserIds = const <String>[],
    required bool publish,
    required List<CollectionDraftItem> items,
    bool isPaid = false,
    int? priceCents,
    String? accentColorHex,
  }) async {
    await saveCollectionWithItems(
      collectionId: collectionId,
      name: name,
      description: description,
      tags: tags,
      mentionUserIds: mentionUserIds,
      publish: publish,
      items: items,
      isPaid: isPaid,
      priceCents: priceCents,
      accentColorHex: accentColorHex,
    );
  }

  Future<void> updateCollectionCard({
    required String collectionId,
    required String name,
    String description = '',
    List<String> tags = const <String>[],
    List<String> mentionUserIds = const <String>[],
    required bool publish,
    required List<CollectionDraftItem> items,
    required Map<String, dynamic> thumbnailPayload,
    bool isPaid = false,
    int? priceCents,
    String? accentColorHex,
  }) async {
    await saveCollectionWithItems(
      collectionId: collectionId,
      name: name,
      description: description,
      tags: tags,
      mentionUserIds: mentionUserIds,
      publish: publish,
      items: items,
      thumbnailPayload: thumbnailPayload,
      isPaid: isPaid,
      priceCents: priceCents,
      accentColorHex: accentColorHex,
    );
  }

  Future<void> updateCollectionMeta({
    required String collectionId,
    String? name,
    String? description,
    List<String>? tags,
    List<String>? mentionUserIds,
    bool? published,
    bool? isPaid,
    int? priceCents,
    String? accentColorHex,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    final Map<String, dynamic> values = <String, dynamic>{};
    if (name != null) {
      final String clean = name.trim();
      values['name'] = clean.isEmpty ? 'Untitled collection' : clean;
    }
    if (description != null) {
      values['description'] = description.trim();
    }
    if (tags != null) {
      values['tags'] = _normalizeTags(tags);
    }
    if (mentionUserIds != null) {
      values['mention_user_ids'] = _normalizeUuidList(mentionUserIds);
    }
    if (published != null) {
      values['published'] = published;
    }
    if (isPaid != null) {
      values['is_paid'] = isPaid;
      values['price_cents'] = isPaid ? _sanitizePriceCents(priceCents) : null;
    } else if (priceCents != null) {
      values['price_cents'] = _sanitizePriceCents(priceCents);
    }
    if (accentColorHex != null) {
      values['accent_color_hex'] = _normalizeHexOrNull(accentColorHex);
    }
    if (values.isEmpty) return;
    await _client
        .from('collections')
        .update(values)
        .eq('id', collectionId)
        .eq('user_id', user.id);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.collections, CacheDomain.profile},
    );
  }

  Future<void> deleteCollection(String collectionId) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('collections')
        .delete()
        .eq('id', collectionId)
        .eq('user_id', user.id);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.collections, CacheDomain.profile},
    );
  }

  Future<void> setCollectionPublished({
    required String collectionId,
    required bool published,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    await _client
        .from('collections')
        .update(<String, dynamic>{'published': published})
        .eq('id', collectionId)
        .eq('user_id', user.id);
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.collections, CacheDomain.profile},
    );
  }

  Future<void> setCollectionReaction({
    required String collectionId,
    required int reaction,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (reaction != 1 && reaction != -1) {
      await _client
          .from('collection_reactions')
          .delete()
          .eq('collection_id', collectionId)
          .eq('user_id', user.id);
      await CacheService.instance.markDomainDirty(CacheDomain.collections);
      return;
    }
    await _client.from('collection_reactions').upsert(
      <String, dynamic>{
        'collection_id': collectionId,
        'user_id': user.id,
        'reaction': reaction,
      },
      onConflict: 'collection_id,user_id',
    );
    await CacheService.instance.markDomainDirty(CacheDomain.collections);
  }

  Future<void> toggleSaveCollection(
    String collectionId, {
    required bool save,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (save) {
      await _client.from('saved_collections').upsert(
        <String, dynamic>{
          'collection_id': collectionId,
          'user_id': user.id,
        },
        onConflict: 'collection_id,user_id',
      );
    } else {
      await _client
          .from('saved_collections')
          .delete()
          .eq('collection_id', collectionId)
          .eq('user_id', user.id);
    }
    await CacheService.instance.markDomainsDirty(
      const {
        CacheDomain.collections,
        CacheDomain.profile,
        CacheDomain.saved,
      },
    );
  }

  Future<void> recordCollectionView(String collectionId) async {
    await _client.rpc(
      'record_collection_view',
      params: <String, dynamic>{'p_collection_id': collectionId},
    );
    await CacheService.instance.markDomainDirty(CacheDomain.collections);
  }

  Future<List<PresetComment>> fetchCollectionComments(
    String collectionId, {
    int limit = 200,
  }) async {
    final String cacheKey = 'comments.collection.$collectionId.$limit';
    return CacheService.instance.getOrFetch<List<PresetComment>>(
      key: cacheKey,
      domains: const {CacheDomain.comments},
      fetch: () async {
        final List<dynamic> rows = await _client
            .from('collection_comments')
            .select('*')
            .eq('collection_id', collectionId)
            .order('created_at', ascending: true)
            .limit(limit);

        final Set<String> userIds = rows
            .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toSet();
        final Map<String, AppUserProfile> profiles =
            await _fetchProfilesByIds(userIds);

        return rows.map((dynamic e) {
          final map = Map<String, dynamic>.from(e as Map);
          final userId = map['user_id']?.toString() ?? '';
          return PresetComment(
            id: map['id']?.toString() ?? '',
            presetId: map['collection_id']?.toString() ?? '',
            userId: userId,
            content: map['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            author: profiles[userId],
          );
        }).toList();
      },
      encode: (value) => value.map(_encodePresetComment).toList(),
      decode: (data) => _decodePresetCommentList(data),
    );
  }

  Future<void> addCollectionComment({
    required String collectionId,
    required String content,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final String text = content.trim();
    if (text.isEmpty) return;
    await _client.from('collection_comments').insert(
      <String, dynamic>{
        'collection_id': collectionId,
        'user_id': user.id,
        'content': text,
      },
    );
    await CacheService.instance.markDomainsDirty(
      const {CacheDomain.comments, CacheDomain.collections},
    );
  }

  Future<List<CollectionSummary>> _hydrateCollectionSummaries(
    List<dynamic> rows,
  ) async {
    if (rows.isEmpty) return const <CollectionSummary>[];

    final user = currentUser;
    final collectionIds = rows
        .map((dynamic e) => (e as Map)['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toList();
    final userIds = rows
        .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final profileById = await _fetchProfilesByIds(userIds);
    final Map<String, Map<String, dynamic>> statsByCollectionId =
        await _fetchCollectionStatsByIds(collectionIds.toSet());

    final Set<String> savedCollectionIds = <String>{};
    final Set<String> watchLaterCollectionIds = <String>{};
    final Map<String, int> myReactionsByCollection = <String, int>{};
    final Map<String, bool> viewerHasPaidByCollection =
        await _fetchViewerEntitlements(
      targetType: 'collection',
      targetIds: collectionIds.toSet(),
    );
    if (user != null) {
      final List<dynamic> saveRows = await _client
          .from('saved_collections')
          .select('collection_id')
          .eq('user_id', user.id)
          .inFilter('collection_id', collectionIds);
      for (final dynamic row in saveRows) {
        savedCollectionIds.add((row as Map)['collection_id']?.toString() ?? '');
      }

      final List<dynamic> watchRows = await _client
          .from('watch_later_items')
          .select('target_id')
          .eq('user_id', user.id)
          .eq('target_type', 'collection')
          .inFilter('target_id', collectionIds);
      for (final dynamic row in watchRows) {
        watchLaterCollectionIds
            .add((row as Map)['target_id']?.toString() ?? '');
      }

      final List<dynamic> reactionRows = await _client
          .from('collection_reactions')
          .select('collection_id,reaction')
          .eq('user_id', user.id)
          .inFilter('collection_id', collectionIds);
      for (final dynamic row in reactionRows) {
        final map = Map<String, dynamic>.from(row as Map);
        myReactionsByCollection[map['collection_id']?.toString() ?? ''] =
            _toInt(map['reaction']);
      }
    }

    final List<dynamic> itemRows = await _client
        .from('collection_items')
        .select('*')
        .inFilter('collection_id', collectionIds)
        .order('position', ascending: true);

    final Map<String, List<CollectionItemSnapshot>> itemsByCollection =
        <String, List<CollectionItemSnapshot>>{};
    for (final dynamic raw in itemRows) {
      final map = Map<String, dynamic>.from(raw as Map);
      final String collectionId = map['collection_id']?.toString() ?? '';
      if (collectionId.isEmpty) continue;
      itemsByCollection
          .putIfAbsent(collectionId, () => <CollectionItemSnapshot>[])
          .add(CollectionItemSnapshot.fromMap(map));
    }

    return rows.map((dynamic raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id']?.toString() ?? '';
      final items = itemsByCollection[id] ?? const <CollectionItemSnapshot>[];
      final stats = statsByCollectionId[id] ?? const <String, dynamic>{};
      final bool viewerHasPaid =
          (user != null && user.id == map['user_id']?.toString()) ||
              (viewerHasPaidByCollection[id] ?? false);
      return CollectionSummary(
        id: id,
        shareId: map['share_id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Untitled collection',
        description: map['description']?.toString() ?? '',
        tags: _stringListFrom(map['tags']),
        mentionUserIds: _stringListFrom(map['mention_user_ids']),
        published: map['published'] == true,
        thumbnailPayload: _mapFrom(map['thumbnail_payload']),
        itemsCount: items.length,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        firstItem: items.isEmpty ? null : items.first,
        author: profileById[map['user_id']?.toString() ?? ''],
        likesCount: _toInt(stats['likes_count']),
        dislikesCount: _toInt(stats['dislikes_count']),
        commentsCount: _toInt(stats['comments_count']),
        savesCount: _toInt(stats['saves_count']),
        viewsCount: _toInt(stats['views_count']),
        myReaction: myReactionsByCollection[id] ?? 0,
        isSavedByCurrentUser: savedCollectionIds.contains(id),
        isWatchLater: watchLaterCollectionIds.contains(id),
        isPaid: map['is_paid'] == true,
        priceCents: _toNullableInt(map['price_cents']),
        accentColorHex: _normalizeHexOrNull(
          map['accent_color_hex']?.toString(),
        ),
        viewerHasPaid: viewerHasPaid,
      );
    }).toList();
  }

  Future<String> fetchThemeModeForCurrentUser() async {
    final user = currentUser;
    if (user == null) return 'dark';

    final row = await _client
        .from('user_settings')
        .select('theme_mode')
        .eq('user_id', user.id)
        .maybeSingle();
    final value = row?['theme_mode']?.toString().toLowerCase();
    if (value == 'light' || value == 'dark' || value == 'system') {
      return value!;
    }
    return 'dark';
  }

  Future<void> updateThemeModeForCurrentUser(String mode) async {
    final user = currentUser;
    if (user == null) return;

    final normalized = mode.toLowerCase();
    if (normalized != 'light' &&
        normalized != 'dark' &&
        normalized != 'system') {
      return;
    }

    await _client.from('user_settings').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'theme_mode': normalized,
      },
      onConflict: 'user_id',
      defaultToNull: false,
    );
  }

  Future<String> uploadAssetBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
    String bucket = assetsBucket,
  }) async {
    final UploadedAsset asset = await uploadAssetBytesWithPath(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: folder,
      bucket: bucket,
    );
    return asset.publicUrl;
  }

  Future<UploadedAsset> uploadAssetBytesWithPath({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
    String bucket = assetsBucket,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Upload failed: not authenticated.');
    }
    if (bytes.isEmpty) {
      throw Exception('Upload failed: selected file is empty.');
    }

    final String safeName = _sanitizeFileName(fileName);
    final String path =
        '${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType.isEmpty
                  ? 'application/octet-stream'
                  : contentType,
            ),
          );
      return UploadedAsset(
        publicUrl: _client.storage.from(bucket).getPublicUrl(path),
        path: path,
        bucket: bucket,
      );
    } on StorageException catch (e) {
      final String message = e.message.toLowerCase();
      if (message.contains('bucket') && message.contains('not found')) {
        throw Exception(
          'Upload failed: storage bucket "$bucket" is missing.',
        );
      }
      if (message.contains('row-level security') ||
          message.contains('policy')) {
        throw Exception(
          'Upload failed: storage policy blocked this file. Verify RLS for bucket "$bucket".',
        );
      }
      throw Exception('Upload failed in storage: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception(
          'Upload failed by database policy (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<String> uploadProfileAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    return uploadAssetBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'avatars',
      bucket: avatarsBucket,
    );
  }

  Future<String> createSplatGenerationJob({
    required String title,
    required String description,
    required List<String> tags,
    required List<String> mentionUserIds,
    required String visibility,
    required List<String> sourceImagePaths,
    required Map<String, dynamic> thumbnailPayload,
    bool isPaid = false,
    int? priceCents,
    String? accentColorHex,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated.');
    if (sourceImagePaths.length < 3) {
      throw Exception('InstantSplat needs at least 3 source images.');
    }
    final Map<String, dynamic> row = await _client
        .from('splat_generation_jobs')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'status': 'queued',
          'progress': 0,
          'stage': 'Queued',
          'source_bucket': sourceImagesBucket,
          'source_image_paths': sourceImagePaths,
          'thumbnail_payload': normalizeImagePayload(
            thumbnailPayload,
            editor: 'splat_job_thumbnail',
          ),
          'post_title': title.trim().isEmpty ? 'Untitled' : title.trim(),
          'post_description': description.trim(),
          'post_tags': _normalizeTags(tags),
          'post_mention_user_ids': _normalizeUuidList(mentionUserIds),
          'post_visibility': visibility == 'private' ? 'private' : 'public',
          'is_paid': isPaid,
          'price_cents': isPaid ? _sanitizePriceCents(priceCents) : null,
          'accent_color_hex': _normalizeHexOrNull(accentColorHex),
        })
        .select('id')
        .single();
    return row['id']?.toString() ?? '';
  }

  Future<Map<String, dynamic>?> fetchSplatGenerationJob(String jobId) async {
    if (jobId.trim().isEmpty) return null;
    final row = await _client
        .from('splat_generation_jobs')
        .select('*')
        .eq('id', jobId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> startInstantSplatWorker(String jobId) async {
    if (!SupabaseConfig.hasInstantSplatWorker) {
      throw Exception('INSTANTSPLAT_WORKER_URL is not configured.');
    }
    final String? token = currentAccessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated.');
    }
    final Uri endpoint = Uri.parse(SupabaseConfig.instantSplatWorkerUrl);
    final response = await http.post(
      endpoint,
      headers: <String, String>{
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, dynamic>{
        'job_id': jobId,
        'supabase_url': SupabaseConfig.url,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'InstantSplat worker rejected the job (${response.statusCode}).',
      );
    }
  }

  Map<String, dynamic> _encodePreset(RenderPreset preset) {
    return <String, dynamic>{
      'id': preset.id,
      'share_id': preset.shareId,
      'user_id': preset.userId,
      'name': preset.name,
      'title': preset.title,
      'description': preset.description,
      'tags': preset.tags,
      'mention_user_ids': preset.mentionUserIds,
      'visibility': preset.visibility,
      'media_type': preset.mediaType,
      'thumbnail_payload': preset.thumbnailPayload,
      'payload': preset.payload,
      'is_paid': preset.isPaid,
      'price_cents': preset.priceCents,
      'accent_color_hex': preset.accentColorHex,
      'viewer_has_paid': preset.viewerHasPaid,
      'created_at': preset.createdAt.toIso8601String(),
      'updated_at': preset.updatedAt.toIso8601String(),
    };
  }

  RenderPreset _decodePreset(Object? raw) {
    final map = _mapFrom(raw);
    return RenderPreset.fromMap(map);
  }

  List<RenderPreset> _decodePresetList(Object? raw) {
    if (raw is! List) return const <RenderPreset>[];
    return raw
        .map(_decodePreset)
        .where((preset) => preset.id.isNotEmpty)
        .toList();
  }

  AppUserProfile? _decodeProfileNullable(Object? raw) {
    final map = _mapFrom(raw);
    if (map.isEmpty) return null;
    return AppUserProfile.fromMap(map);
  }

  Map<String, AppUserProfile> _decodeProfileMap(Object? raw) {
    if (raw is! Map) return <String, AppUserProfile>{};
    final Map<String, AppUserProfile> output = <String, AppUserProfile>{};
    raw.forEach((key, value) {
      final profile = _decodeProfileNullable(value);
      if (profile != null) {
        output[key.toString()] = profile;
      }
    });
    return output;
  }

  Map<String, dynamic> _encodeFeedPost(FeedPost post) {
    return <String, dynamic>{
      'preset': _encodePreset(post.preset),
      'author': post.author?.toMap(),
      'likesCount': post.likesCount,
      'dislikesCount': post.dislikesCount,
      'commentsCount': post.commentsCount,
      'savesCount': post.savesCount,
      'viewsCount': post.viewsCount,
      'myReaction': post.myReaction,
      'isSaved': post.isSaved,
      'isFollowingAuthor': post.isFollowingAuthor,
      'isWatchLater': post.isWatchLater,
    };
  }

  FeedPost _decodeFeedPost(Object? raw) {
    final map = _mapFrom(raw);
    final preset = _decodePreset(map['preset']);
    return FeedPost(
      preset: preset,
      author: _decodeProfileNullable(map['author']),
      likesCount: _toInt(map['likesCount']),
      dislikesCount: _toInt(map['dislikesCount']),
      commentsCount: _toInt(map['commentsCount']),
      savesCount: _toInt(map['savesCount']),
      viewsCount: _toInt(map['viewsCount']),
      myReaction: _toInt(map['myReaction']),
      isSaved: map['isSaved'] == true,
      isFollowingAuthor: map['isFollowingAuthor'] == true,
      isWatchLater: map['isWatchLater'] == true,
    );
  }

  FeedPost? _decodeFeedPostNullable(Object? raw) {
    if (raw == null) return null;
    final map = _mapFrom(raw);
    if (map.isEmpty) return null;
    final preset = _decodePreset(map['preset']);
    if (preset.id.isEmpty) return null;
    return _decodeFeedPost(map);
  }

  List<FeedPost> _decodeFeedPostList(Object? raw) {
    if (raw is! List) return const <FeedPost>[];
    return raw
        .map(_decodeFeedPost)
        .where((post) => post.preset.id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _encodeCollectionItem(CollectionItemSnapshot item) {
    return <String, dynamic>{
      'id': item.id,
      'preset_name': item.name,
      'position': item.position,
      'preset_snapshot': item.snapshot,
    };
  }

  CollectionItemSnapshot _decodeCollectionItem(Object? raw) {
    return CollectionItemSnapshot.fromMap(_mapFrom(raw));
  }

  Map<String, dynamic> _encodeCollectionSummary(CollectionSummary summary) {
    return <String, dynamic>{
      'id': summary.id,
      'share_id': summary.shareId,
      'user_id': summary.userId,
      'name': summary.name,
      'description': summary.description,
      'tags': summary.tags,
      'mention_user_ids': summary.mentionUserIds,
      'published': summary.published,
      'thumbnail_payload': summary.thumbnailPayload,
      'items_count': summary.itemsCount,
      'created_at': summary.createdAt.toIso8601String(),
      'updated_at': summary.updatedAt.toIso8601String(),
      'first_item': summary.firstItem == null
          ? null
          : _encodeCollectionItem(summary.firstItem!),
      'author': summary.author?.toMap(),
      'likes_count': summary.likesCount,
      'dislikes_count': summary.dislikesCount,
      'comments_count': summary.commentsCount,
      'saves_count': summary.savesCount,
      'views_count': summary.viewsCount,
      'my_reaction': summary.myReaction,
      'is_saved': summary.isSavedByCurrentUser,
      'is_watch_later': summary.isWatchLater,
      'is_paid': summary.isPaid,
      'price_cents': summary.priceCents,
      'accent_color_hex': summary.accentColorHex,
      'viewer_has_paid': summary.viewerHasPaid,
    };
  }

  CollectionSummary _decodeCollectionSummary(Object? raw) {
    final map = _mapFrom(raw);
    final firstRaw = map['first_item'];
    final CollectionItemSnapshot? firstItem =
        firstRaw == null ? null : _decodeCollectionItem(firstRaw);
    return CollectionSummary(
      id: map['id']?.toString() ?? '',
      shareId: map['share_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled collection',
      description: map['description']?.toString() ?? '',
      tags: _stringListFrom(map['tags']),
      mentionUserIds: _stringListFrom(map['mention_user_ids']),
      published: map['published'] == true,
      thumbnailPayload: _mapFrom(map['thumbnail_payload']),
      itemsCount: _toInt(map['items_count']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      firstItem: firstItem,
      author: _decodeProfileNullable(map['author']),
      likesCount: _toInt(map['likes_count']),
      dislikesCount: _toInt(map['dislikes_count']),
      commentsCount: _toInt(map['comments_count']),
      savesCount: _toInt(map['saves_count']),
      viewsCount: _toInt(map['views_count']),
      myReaction: _toInt(map['my_reaction']),
      isSavedByCurrentUser: map['is_saved'] == true,
      isWatchLater: map['is_watch_later'] == true,
      isPaid: map['is_paid'] == true,
      priceCents: _toNullableInt(map['price_cents']),
      accentColorHex: _normalizeHexOrNull(map['accent_color_hex']?.toString()),
      viewerHasPaid: map['viewer_has_paid'] == true,
    );
  }

  List<CollectionSummary> _decodeCollectionSummaryList(Object? raw) {
    if (raw is! List) return const <CollectionSummary>[];
    return raw
        .map(_decodeCollectionSummary)
        .where((summary) => summary.id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _encodeCollectionDetail(CollectionDetail detail) {
    return <String, dynamic>{
      'summary': _encodeCollectionSummary(detail.summary),
      'items': detail.items.map(_encodeCollectionItem).toList(),
    };
  }

  CollectionDetail _decodeCollectionDetail(Object? raw) {
    final map = _mapFrom(raw);
    final summary = _decodeCollectionSummary(map['summary']);
    final Object? itemsRaw = map['items'];
    final List<CollectionItemSnapshot> items = itemsRaw is List
        ? itemsRaw.map(_decodeCollectionItem).toList()
        : const <CollectionItemSnapshot>[];
    return CollectionDetail(summary: summary, items: items);
  }

  CollectionDetail? _decodeCollectionDetailNullable(Object? raw) {
    if (raw == null) return null;
    final map = _mapFrom(raw);
    if (map.isEmpty) return null;
    final detail = _decodeCollectionDetail(map);
    if (detail.summary.id.isEmpty) return null;
    return detail;
  }

  Map<String, dynamic> _encodeProfileStats(ProfileStats stats) {
    return <String, dynamic>{
      'followers_count': stats.followersCount,
      'following_count': stats.followingCount,
      'posts_count': stats.postsCount,
    };
  }

  ProfileStats _decodeProfileStats(Object? raw) {
    final map = _mapFrom(raw);
    if (map.isEmpty) {
      return const ProfileStats(
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
      );
    }
    return ProfileStats.fromMap(map);
  }

  Map<String, dynamic> _encodePresetComment(PresetComment comment) {
    return <String, dynamic>{
      'id': comment.id,
      'preset_id': comment.presetId,
      'user_id': comment.userId,
      'content': comment.content,
      'created_at': comment.createdAt.toIso8601String(),
      'author': comment.author?.toMap(),
    };
  }

  List<PresetComment> _decodePresetCommentList(Object? raw) {
    if (raw is! List) return const <PresetComment>[];
    return raw
        .map((entry) {
          final map = _mapFrom(entry);
          final userId = map['user_id']?.toString() ?? '';
          return PresetComment(
            id: map['id']?.toString() ?? '',
            presetId: map['preset_id']?.toString() ?? '',
            userId: userId,
            content: map['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            author: _decodeProfileNullable(map['author']),
          );
        })
        .where((comment) => comment.id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _encodeWatchLaterItem(WatchLaterItem item) {
    return <String, dynamic>{
      'id': item.id,
      'type': item.type.name,
      'created_at': item.createdAt.toIso8601String(),
      'post': item.post == null ? null : _encodePreset(item.post!),
      'collection': item.collection == null
          ? null
          : _encodeCollectionSummary(item.collection!),
    };
  }

  List<WatchLaterItem> _decodeWatchLaterList(Object? raw) {
    if (raw is! List) return const <WatchLaterItem>[];
    final List<WatchLaterItem> items = <WatchLaterItem>[];
    for (final entry in raw) {
      final map = _mapFrom(entry);
      final String id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final String type = map['type']?.toString() ?? 'post';
      final DateTime createdAt =
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      if (type == 'collection') {
        final summary = _decodeCollectionSummary(map['collection']);
        if (summary.id.isEmpty) continue;
        items.add(
          WatchLaterItem.collection(
            id: id,
            createdAt: createdAt,
            collection: summary,
          ),
        );
      } else {
        final preset = _decodePreset(map['post']);
        if (preset.id.isEmpty) continue;
        items.add(
          WatchLaterItem.post(
            id: id,
            createdAt: createdAt,
            post: preset,
          ),
        );
      }
    }
    return items;
  }

  Map<String, Map<String, dynamic>> _decodeStatsMap(Object? raw) {
    if (raw is! Map) return <String, Map<String, dynamic>>{};
    final Map<String, Map<String, dynamic>> output =
        <String, Map<String, dynamic>>{};
    raw.forEach((key, value) {
      final map = _mapFrom(value);
      if (map.isNotEmpty) {
        output[key.toString()] = map;
      }
    });
    return output;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int _sanitizePriceCents(int? value) {
    final int parsed = value ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  String? _normalizeHexOrNull(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final String normalized = raw.startsWith('#') ? raw : '#$raw';
    final RegExp hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!hexPattern.hasMatch(normalized)) return null;
    return normalized.toUpperCase();
  }

  List<String> _normalizeTags(List<String> raw) {
    return raw
        .map((String e) => e.trim().toLowerCase())
        .where((String e) => e.isNotEmpty)
        .map((String e) => e.startsWith('#') ? e : '#$e')
        .toSet()
        .toList();
  }

  List<String> _normalizeUuidList(List<String> raw) {
    final Set<String> ids = <String>{};
    for (final String item in raw) {
      final String value = item.trim();
      if (value.isEmpty) continue;
      ids.add(value);
    }
    return ids.toList();
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<String> _stringListFrom(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  bool _looksLikeUuid(String value) {
    return _uuidPattern.hasMatch(value);
  }

  String _sanitizeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (cleaned.isEmpty) return 'file';
    return cleaned;
  }
}
