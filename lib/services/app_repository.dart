import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';
import '../models/chat_models.dart';
import '../models/collection_models.dart';
import '../models/feed_post.dart';
import '../models/preset_comment.dart';
import '../models/profile_stats.dart';
import '../models/render_preset.dart';

class AppRepository {
  AppRepository._();

  static final AppRepository instance = AppRepository._();

  static const String assetsBucket = 'deepx-assets';
  static const String avatarsBucket = 'deepx-avatars';

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

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
        'tracker_enabled': true,
        'tracker_ui_visible': false,
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
    final row = await _client
        .from('profiles')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUserProfile.fromMap(row);
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

  Future<ProfileStats> fetchProfileStats(String userId) async {
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
  }

  Future<Map<String, dynamic>?> fetchModeState(String mode) async {
    final user = currentUser;
    if (user == null) return null;

    final row = await _client
        .from('mode_states')
        .select('state')
        .eq('user_id', user.id)
        .eq('mode', mode)
        .maybeSingle();

    if (row == null) return null;
    final dynamic state = row['state'];
    if (state is Map<String, dynamic>) {
      return state;
    }
    if (state is Map) {
      return Map<String, dynamic>.from(state);
    }
    return null;
  }

  Future<void> upsertModeState({
    required String mode,
    required Map<String, dynamic> state,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('mode_states').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'mode': mode,
        'state': state,
      },
      onConflict: 'user_id,mode',
    );
  }

  Future<List<RenderPreset>> fetchUserPresets({String? mode}) async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];

    dynamic query = _client
        .from('presets')
        .select('*')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    if (mode != null) {
      query = query.eq('mode', mode);
    }

    final List<dynamic> rows = await query;
    return rows
        .map((dynamic e) =>
            RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RenderPreset>> fetchUserPosts(String userId) async {
    final List<dynamic> rows = await _client
        .from('presets')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return rows
        .map((dynamic e) =>
            RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RenderPreset>> fetchFeedPresets({int limit = 200}) async {
    final List<dynamic> rows = await _client
        .from('presets')
        .select('*')
        .order('updated_at', ascending: false)
        .limit(limit);

    return rows
        .map((dynamic e) =>
            RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FeedPost>> fetchFeedPosts({int limit = 200}) async {
    final List<RenderPreset> presets = await fetchFeedPresets(limit: limit);
    return _hydrateFeedPosts(presets);
  }

  Future<FeedPost?> fetchFeedPostById(String presetId) async {
    final row = await _client
        .from('presets')
        .select('*')
        .eq('id', presetId)
        .maybeSingle();
    if (row == null) return null;
    final RenderPreset preset = RenderPreset.fromMap(row);
    final List<FeedPost> posts =
        await _hydrateFeedPosts(<RenderPreset>[preset]);
    if (posts.isEmpty) return null;
    return posts.first;
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
    final Set<String> followingUserIds = <String>{};

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
      return FeedPost(
        preset: preset,
        author: profileById[preset.userId],
        likesCount: _toInt(stats['likes_count']),
        dislikesCount: _toInt(stats['dislikes_count']),
        commentsCount: _toInt(stats['comments_count']),
        savesCount: _toInt(stats['saves_count']),
        myReaction: myReactionByPreset[preset.id] ?? 0,
        isSaved: savedPresetIds.contains(preset.id),
        isFollowingAuthor: followingUserIds.contains(preset.userId),
      );
    }).toList();
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

  Future<void> savePreset({
    required String mode,
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('presets').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'mode': mode,
        'name': name,
        'payload': payload,
      },
      onConflict: 'user_id,mode,name',
    );
  }

  Future<Map<String, dynamic>?> fetchUserPresetByName({
    required String mode,
    required String name,
  }) async {
    final user = currentUser;
    if (user == null) return null;

    final row = await _client
        .from('presets')
        .select('payload')
        .eq('user_id', user.id)
        .eq('mode', mode)
        .eq('name', name)
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
    final row = await _client
        .from('presets')
        .select('*')
        .eq('id', presetId)
        .maybeSingle();
    if (row == null) return null;
    return RenderPreset.fromMap(row);
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
    return map;
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
  }

  Future<List<PresetComment>> fetchPresetComments(
    String presetId, {
    int limit = 200,
  }) async {
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
  }

  Future<void> recordPresetView(String presetId) async {
    await _client.rpc(
      'record_preset_view',
      params: <String, dynamic>{'p_preset_id': presetId},
    );
  }

  Future<List<RenderPreset>> fetchSavedPresetsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];

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
  }

  Future<List<RenderPreset>> fetchHistoryPresetsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <RenderPreset>[];

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
  }

  Future<String> createOrGetDirectChat(String otherUserId) async {
    final dynamic value = await _client.rpc(
      'create_or_get_direct_chat',
      params: <String, dynamic>{'other_user_id': otherUserId},
    );
    return value?.toString() ?? '';
  }

  Future<String> createGroupChat({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      final chatId = await createGroupChatRpc(name: name, memberIds: memberIds);
      if (chatId.isNotEmpty) return chatId;
    } catch (_) {}

    final user = currentUser;
    if (user == null) return '';

    final Map<String, dynamic> chatRow = await _client
        .from('chats')
        .insert(
          <String, dynamic>{
            'created_by': user.id,
            'name': name.trim(),
            'is_group': true,
          },
        )
        .select('*')
        .single();

    final String chatId = chatRow['id'].toString();
    final Set<String> uniqueMembers = <String>{...memberIds, user.id};
    final List<Map<String, dynamic>> rows = uniqueMembers
        .map(
          (String id) => <String, dynamic>{
            'chat_id': chatId,
            'user_id': id,
            'role': id == user.id ? 'owner' : 'member',
          },
        )
        .toList();
    await _client.from('chat_members').upsert(rows);

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
    final List<dynamic> rows = await _client
        .from('collections')
        .select('*')
        .eq('published', true)
        .order('updated_at', ascending: false)
        .limit(limit);
    return _hydrateCollectionSummaries(rows);
  }

  Future<List<CollectionSummary>> fetchCollectionsForCurrentUser() async {
    final user = currentUser;
    if (user == null) return const <CollectionSummary>[];

    final List<dynamic> rows = await _client
        .from('collections')
        .select('*')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    return _hydrateCollectionSummaries(rows);
  }

  Future<CollectionDetail?> fetchCollectionById(String collectionId) async {
    final row = await _client
        .from('collections')
        .select('*')
        .eq('id', collectionId)
        .maybeSingle();
    if (row == null) return null;

    final List<dynamic> itemRows = await _client
        .from('collection_items')
        .select('*')
        .eq('collection_id', collectionId)
        .order('position', ascending: true);

    final profile = await fetchProfileById(row['user_id'].toString());
    final items = itemRows
        .map((dynamic e) =>
            CollectionItemSnapshot.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return CollectionDetail(
      summary: CollectionSummary(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        name: row['name']?.toString() ?? 'Untitled collection',
        description: row['description']?.toString() ?? '',
        published: row['published'] == true,
        itemsCount: items.length,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        firstItem: items.isEmpty ? null : items.first,
        author: profile,
      ),
      items: items,
    );
  }

  Future<String> saveCollectionWithItems({
    String? collectionId,
    required String name,
    String description = '',
    required bool publish,
    required List<CollectionDraftItem> items,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (items.isEmpty) throw Exception('Collection needs at least one preset.');

    String id = collectionId ?? '';

    if (id.isEmpty) {
      final inserted = await _client
          .from('collections')
          .insert(
            <String, dynamic>{
              'user_id': user.id,
              'name': name.trim().isEmpty ? 'Untitled collection' : name.trim(),
              'description': description,
              'published': publish,
            },
          )
          .select('*')
          .single();
      id = inserted['id'].toString();
    } else {
      await _client.from('collections').update(
        <String, dynamic>{
          'name': name.trim().isEmpty ? 'Untitled collection' : name.trim(),
          'description': description,
          'published': publish,
        },
      ).eq('id', id).eq('user_id', user.id);

      await _client.from('collection_items').delete().eq('collection_id', id);
    }

    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < items.length; i++) {
      rows.add(
        <String, dynamic>{
          'collection_id': id,
          'position': i,
          'mode': items[i].mode,
          'preset_name': items[i].name,
          'preset_snapshot': items[i].snapshot,
        },
      );
    }
    await _client.from('collection_items').insert(rows);
    return id;
  }

  Future<void> deleteCollection(String collectionId) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('collections')
        .delete()
        .eq('id', collectionId)
        .eq('user_id', user.id);
  }

  Future<List<CollectionSummary>> _hydrateCollectionSummaries(
    List<dynamic> rows,
  ) async {
    if (rows.isEmpty) return const <CollectionSummary>[];

    final collectionIds = rows
        .map((dynamic e) => (e as Map)['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toList();
    final userIds = rows
        .map((dynamic e) => (e as Map)['user_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final profileById = await _fetchProfilesByIds(userIds);

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
      return CollectionSummary(
        id: id,
        userId: map['user_id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Untitled collection',
        description: map['description']?.toString() ?? '',
        published: map['published'] == true,
        itemsCount: items.length,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        firstItem: items.isEmpty ? null : items.first,
        author: profileById[map['user_id']?.toString() ?? ''],
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

  Future<Map<String, bool>> fetchTrackerPreferencesForCurrentUser() async {
    final user = currentUser;
    if (user == null) {
      return <String, bool>{
        'trackerEnabled': true,
        'trackerUiVisible': false,
      };
    }

    final row = await _client
        .from('user_settings')
        .select('tracker_enabled,tracker_ui_visible')
        .eq('user_id', user.id)
        .maybeSingle();

    return <String, bool>{
      'trackerEnabled': row?['tracker_enabled'] != false,
      'trackerUiVisible': row?['tracker_ui_visible'] == true,
    };
  }

  Future<void> updateTrackerPreferencesForCurrentUser({
    bool? trackerEnabled,
    bool? trackerUiVisible,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final values = <String, dynamic>{'user_id': user.id};
    if (trackerEnabled != null) {
      values['tracker_enabled'] = trackerEnabled;
    }
    if (trackerUiVisible != null) {
      values['tracker_ui_visible'] = trackerUiVisible;
    }

    await _client.from('user_settings').upsert(
          values,
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
              contentType:
                  contentType.isEmpty ? 'application/octet-stream' : contentType,
            ),
          );
      return _client.storage.from(bucket).getPublicUrl(path);
    } on StorageException catch (e) {
      final String message = e.message.toLowerCase();
      if (message.contains('bucket') && message.contains('not found')) {
        throw Exception(
          'Upload failed: storage bucket "$bucket" is missing.',
        );
      }
      if (message.contains('row-level security') || message.contains('policy')) {
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _sanitizeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (cleaned.isEmpty) return 'file';
    return cleaned;
  }
}
