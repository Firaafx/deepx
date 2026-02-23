import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipable_stack/swipable_stack.dart';
import 'package:url_launcher/url_launcher.dart';

import 'engine3d.dart';
import 'layer_mode.dart';
import 'models/app_user_profile.dart';
import 'models/chat_models.dart';
import 'models/collection_models.dart';
import 'models/feed_post.dart';
import 'models/notification_item.dart';
import 'models/preset_payload_v2.dart';
import 'models/preset_comment.dart';
import 'models/profile_stats.dart';
import 'models/render_preset.dart';
import 'models/tracker_runtime_config.dart';
import 'models/watch_later_item.dart';
import 'services/app_repository.dart';
import 'services/tracking_service.dart';
import 'services/web_file_upload.dart';
import 'widgets/preset_viewer.dart';
import 'widgets/window_effect_2d_preview.dart';

enum _ShellTab {
  home,
  collection,
  post,
  chat,
  profile,
  settings,
}

enum _ComposerKind {
  single,
  collection,
}

enum _ComposerEditTarget {
  detail,
  card,
}

String _routeIdFromShareOrUuid({
  required String shareId,
  required String uuid,
}) {
  final String trimmedShareId = shareId.trim();
  if (trimmedShareId.isNotEmpty) return trimmedShareId;
  return uuid.trim();
}

String buildPostRoutePathForPreset(RenderPreset preset) {
  final String routeId = _routeIdFromShareOrUuid(
    shareId: preset.shareId,
    uuid: preset.id,
  );
  return '/post/${Uri.encodeComponent(routeId)}';
}

String buildCollectionRoutePathForSummary(CollectionSummary summary) {
  final String routeId = _routeIdFromShareOrUuid(
    shareId: summary.shareId,
    uuid: summary.id,
  );
  return '/collection/${Uri.encodeComponent(routeId)}';
}

String _githubPagesBasePrefix() {
  final Uri base = Uri.base;
  if (!base.host.toLowerCase().endsWith('github.io')) return '';
  final List<String> segments =
      base.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.isEmpty) return '';
  return '/${segments.first}';
}

String _publicShareUrl(String routePath) {
  final String prefix = _githubPagesBasePrefix();
  return '${Uri.base.origin}$prefix$routePath';
}

String buildPostShareUrl(RenderPreset preset) {
  return _publicShareUrl(buildPostRoutePathForPreset(preset));
}

String buildCollectionShareUrl(CollectionSummary summary) {
  return _publicShareUrl(buildCollectionRoutePathForSummary(summary));
}

void _openPublicProfileRoute(
  BuildContext context,
  AppUserProfile? profile,
) {
  final String? username = profile?.username?.trim();
  if (username == null || username.isEmpty) return;
  Navigator.pushNamed(
    context,
    '/@${Uri.encodeComponent(username)}',
  );
}

class _TopEdgeLoadingPane extends StatefulWidget {
  const _TopEdgeLoadingPane({
    this.label,
    this.backgroundColor,
    this.minHeight = 3,
  });

  final String? label;
  final Color? backgroundColor;
  final double minHeight;

  @override
  State<_TopEdgeLoadingPane> createState() => _TopEdgeLoadingPaneState();
}

class _TopEdgeLoadingPaneState extends State<_TopEdgeLoadingPane> {
  OverlayEntry? _loadingOverlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOverlay());
  }

  @override
  void didUpdateWidget(covariant _TopEdgeLoadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadingOverlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
    super.dispose();
  }

  void _ensureOverlay() {
    if (!mounted || _loadingOverlayEntry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _loadingOverlayEntry = OverlayEntry(
      builder: (context) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: LinearProgressIndicator(
                  minHeight: widget.minHeight,
                  backgroundColor: Colors.transparent,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_loadingOverlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color:
          widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: widget.label != null && widget.label!.trim().isNotEmpty
          ? Center(
              child: Text(
                widget.label!,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class StandalonePostRoutePage extends StatefulWidget {
  const StandalonePostRoutePage({
    super.key,
    required this.idOrShareId,
  });

  final String idOrShareId;

  @override
  State<StandalonePostRoutePage> createState() =>
      _StandalonePostRoutePageState();
}

class _StandalonePostRoutePageState extends State<StandalonePostRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  FeedPost? _post;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String routeId = widget.idOrShareId.trim();
    if (routeId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Post link is invalid.';
      });
      return;
    }
    try {
      final post = await _repository.fetchFeedPostByRouteId(routeId);
      if (!mounted) return;
      if (post == null) {
        setState(() {
          _loading = false;
          _error = 'Post not found.';
        });
        return;
      }
      setState(() {
        _post = post;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _TopEdgeLoadingPane(label: 'Loading post...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3, value: 1),
            ),
            Center(
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return _PresetDetailPage(initialPost: _post!);
  }
}

class StandaloneCollectionRoutePage extends StatefulWidget {
  const StandaloneCollectionRoutePage({
    super.key,
    required this.idOrShareId,
  });

  final String idOrShareId;

  @override
  State<StandaloneCollectionRoutePage> createState() =>
      _StandaloneCollectionRoutePageState();
}

class _StandaloneCollectionRoutePageState
    extends State<StandaloneCollectionRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  CollectionDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String routeId = widget.idOrShareId.trim();
    if (routeId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Collection link is invalid.';
      });
      return;
    }
    try {
      final detail = await _repository.fetchCollectionByRouteId(routeId);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = 'Collection not found.';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load collection: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _TopEdgeLoadingPane(label: 'Loading collection...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3, value: 1),
            ),
            Center(
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return _CollectionDetailPage(
      collectionId: _detail!.summary.id,
      initialSummary: _detail!.summary,
    );
  }
}

enum _PublicProfileFilter { all, posts, collections }

class StandalonePublicProfileRoutePage extends StatefulWidget {
  const StandalonePublicProfileRoutePage({
    super.key,
    required this.username,
  });

  final String username;

  @override
  State<StandalonePublicProfileRoutePage> createState() =>
      _StandalonePublicProfileRoutePageState();
}

class _StandalonePublicProfileRoutePageState
    extends State<StandalonePublicProfileRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  AppUserProfile? _profile;
  ProfileStats? _stats;
  List<RenderPreset> _posts = const <RenderPreset>[];
  List<CollectionSummary> _collections = const <CollectionSummary>[];
  _PublicProfileFilter _filter = _PublicProfileFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String username = widget.username.trim().toLowerCase();
    if (username.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Profile username is missing.';
      });
      return;
    }
    try {
      final profile = await _repository.fetchProfileByUsername(username);
      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Profile not found.';
        });
        return;
      }
      final results = await Future.wait<dynamic>([
        _repository.fetchProfileStats(profile.userId),
        _repository.fetchPublicPostsForUser(profile.userId, limit: 90),
        _repository.fetchPublicCollectionsForUser(profile.userId, limit: 60),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = results[0] as ProfileStats;
        _posts = results[1] as List<RenderPreset>;
        _collections = results[2] as List<CollectionSummary>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
        body: _TopEdgeLoadingPane(label: 'Loading profile...'),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(
            _error ?? 'Profile unavailable.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final profile = _profile!;
    final stats = _stats ??
        const ProfileStats(
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
        );
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    if (_filter == _PublicProfileFilter.all ||
        _filter == _PublicProfileFilter.posts) {
      for (final post in _posts) {
        entries.add(<String, dynamic>{
          'kind': 'post',
          'title': post.title.isNotEmpty ? post.title : post.name,
          'meta':
              '${post.mode.toUpperCase()} · ${_friendlyTime(post.createdAt)}',
          'mode': post.thumbnailMode ?? post.mode,
          'payload': post.thumbnailPayload.isNotEmpty
              ? post.thumbnailPayload
              : post.payload,
          'tapPath': buildPostRoutePathForPreset(post),
        });
      }
    }
    if (_filter == _PublicProfileFilter.all ||
        _filter == _PublicProfileFilter.collections) {
      for (final collection in _collections) {
        entries.add(<String, dynamic>{
          'kind': 'collection',
          'title': collection.name.isNotEmpty ? collection.name : 'Collection',
          'meta':
              '${collection.itemsCount} items · ${_friendlyTime(collection.createdAt)}',
          'mode':
              collection.thumbnailMode ?? collection.firstItem?.mode ?? '2d',
          'payload': collection.thumbnailPayload.isNotEmpty
              ? collection.thumbnailPayload
              : (collection.firstItem?.snapshot ?? const <String, dynamic>{}),
          'tapPath': buildCollectionRoutePathForSummary(collection),
        });
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: Colors.white,
                          ),
                          const Spacer(),
                          Text(
                            '/@${profile.username ?? profile.displayName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundImage: (profile.avatarUrl != null &&
                                    profile.avatarUrl!.isNotEmpty)
                                ? NetworkImage(profile.avatarUrl!)
                                : null,
                            child: (profile.avatarUrl == null ||
                                    profile.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.bio.trim().isNotEmpty
                                      ? profile.bio.trim()
                                      : 'DeepX creator channel',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _profileStatTile(
                            label: 'Posts',
                            value: stats.postsCount,
                          ),
                          const SizedBox(width: 14),
                          _profileStatTile(
                            label: 'Followers',
                            value: stats.followersCount,
                          ),
                          const SizedBox(width: 14),
                          _profileStatTile(
                            label: 'Following',
                            value: stats.followingCount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.all,
                        label: const Text('All'),
                        onSelected: (_) =>
                            setState(() => _filter = _PublicProfileFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.posts,
                        label: const Text('Posts'),
                        onSelected: (_) => setState(
                            () => _filter = _PublicProfileFilter.posts),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.collections,
                        label: const Text('Collections'),
                        onSelected: (_) => setState(
                          () => _filter = _PublicProfileFilter.collections,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No public content yet.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = entries[index];
                      final String title = entry['title']?.toString() ?? '';
                      final String meta = entry['meta']?.toString() ?? '';
                      final String path = entry['tapPath']?.toString() ?? '/';
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pushNamed(context, path),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _GridPresetPreview(
                                    mode: entry['mode']?.toString() ?? '2d',
                                    payload: (entry['payload'] as Map?)
                                            ?.cast<String, dynamic>() ??
                                        const <String, dynamic>{},
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: entries.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileStatTile({required String label, required int value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.tab,
    required this.icon,
    required this.label,
  });

  final _ShellTab tab;
  final IconData icon;
  final String label;
}

class ShowFeedPage extends StatefulWidget {
  const ShowFeedPage({
    super.key,
    this.themeMode = 'dark',
    this.onThemeModeChanged,
    this.initialTab = 'home',
  });

  final String themeMode;
  final ValueChanged<String>? onThemeModeChanged;
  final String initialTab;

  @override
  State<ShowFeedPage> createState() => _ShowFeedPageState();
}

class _ShowFeedPageState extends State<ShowFeedPage> {
  static const double _headerHeight = 84;
  static const double _headerTopOffset = 0;
  static const double _feedTopPadding = _headerHeight + _headerTopOffset;
  static const double _tabContentTopPadding = 48;

  static const List<_NavItem> _primaryNav = <_NavItem>[
    _NavItem(tab: _ShellTab.home, icon: Icons.home_outlined, label: 'Home'),
    _NavItem(
      tab: _ShellTab.collection,
      icon: Icons.collections_bookmark_outlined,
      label: 'Collection',
    ),
    _NavItem(tab: _ShellTab.post, icon: Icons.add_box_outlined, label: 'Post'),
    _NavItem(
        tab: _ShellTab.chat, icon: Icons.chat_bubble_outline, label: 'Chat'),
    _NavItem(
      tab: _ShellTab.profile,
      icon: Icons.account_circle_outlined,
      label: 'Profile',
    ),
  ];

  final AppRepository _repository = AppRepository.instance;
  final GlobalKey<_HomeFeedTabState> _homeKey = GlobalKey<_HomeFeedTabState>();
  final GlobalKey<_CollectionTabState> _collectionKey =
      GlobalKey<_CollectionTabState>();
  final GlobalKey<_ChatTabState> _chatKey = GlobalKey<_ChatTabState>();
  final GlobalKey<_ProfileTabState> _profileKey = GlobalKey<_ProfileTabState>();
  final GlobalKey _navRegionKey = GlobalKey();

  _ShellTab _activeTab = _ShellTab.home;
  bool _navExpanded = false;
  bool _realNavHover = false;
  bool _trackerNavHover = false;
  Timer? _trackerNavDebounce;
  VoidCallback? _trackerNavListener;
  AppUserProfile? _currentProfile;
  List<NotificationItem> _headerNotifications = const <NotificationItem>[];
  Map<String, AppUserProfile> _notificationActors =
      const <String, AppUserProfile>{};

  bool get _isGuest => _repository.currentUser == null;

  _ShellTab _tabFromSegment(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'home':
        return _ShellTab.home;
      case 'collection':
        return _ShellTab.collection;
      case 'post':
        return _ShellTab.post;
      case 'chat':
        return _ShellTab.chat;
      case 'profile':
        return _ShellTab.profile;
      case 'settings':
        return _ShellTab.settings;
      default:
        return _ShellTab.home;
    }
  }

  String _segmentForTab(_ShellTab tab) {
    switch (tab) {
      case _ShellTab.home:
        return 'home';
      case _ShellTab.collection:
        return 'collection';
      case _ShellTab.post:
        return 'post';
      case _ShellTab.chat:
        return 'chat';
      case _ShellTab.profile:
        return 'profile';
      case _ShellTab.settings:
        return 'settings';
    }
  }

  String _pathForTab(_ShellTab tab) => '/feed/${_segmentForTab(tab)}';

  @override
  void initState() {
    super.initState();
    _activeTab = _tabFromSegment(widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackingService.instance.remapHeadBaselineToCurrentFrame();
    });
    _loadProfile();
    _loadHeaderNotifications();
    _trackerNavListener = _syncTrackerCursorHover;
    TrackingService.instance.frameNotifier.addListener(_trackerNavListener!);
  }

  @override
  void dispose() {
    debugPrint('Disposing ShowFeedPage(tab=${_activeTab.name})');
    _trackerNavDebounce?.cancel();
    final listener = _trackerNavListener;
    if (listener != null) {
      TrackingService.instance.frameNotifier.removeListener(listener);
    }
    super.dispose();
  }

  Future<void> _reloadActiveTab() async {
    switch (_activeTab) {
      case _ShellTab.home:
        await _homeKey.currentState?._loadFeed();
        break;
      case _ShellTab.collection:
        await _collectionKey.currentState?._loadCollections();
        break;
      case _ShellTab.post:
        break;
      case _ShellTab.chat:
        await _chatKey.currentState?._bootstrap();
        break;
      case _ShellTab.profile:
        await _profileKey.currentState?._load();
        break;
      case _ShellTab.settings:
        await _loadProfile();
        break;
    }
  }

  Future<void> _loadProfile() async {
    if (_repository.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _currentProfile = null;
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
      return;
    }
    final profile = await _repository.ensureCurrentProfile();
    if (!mounted) return;
    setState(() => _currentProfile = profile);
    unawaited(_loadHeaderNotifications());
  }

  Future<void> _loadHeaderNotifications() async {
    if (_repository.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
      return;
    }
    try {
      final notifications = await _repository.fetchNotifications(limit: 80);
      final Set<String> actorIds = notifications
          .map((n) => n.actorUserId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final actors = await _repository.fetchProfilesByIds(actorIds);
      if (!mounted) return;
      setState(() {
        _headerNotifications = notifications;
        _notificationActors = actors;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
    }
  }

  Future<void> _markNotificationReadLocal(NotificationItem item) async {
    if (item.read) return;
    await _repository.markNotificationRead(item.id, read: true);
    if (!mounted) return;
    setState(() {
      _headerNotifications = _headerNotifications
          .map((n) => n.id == item.id
              ? NotificationItem(
                  id: n.id,
                  userId: n.userId,
                  actorUserId: n.actorUserId,
                  kind: n.kind,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  read: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
  }

  Future<void> _openNotificationTarget(NotificationItem item) async {
    final String type = (item.data['type']?.toString() ?? '').toLowerCase();
    if (type == 'chat_message') {
      await _switchTab(_ShellTab.chat);
      return;
    }

    final String targetId = item.data['preset_id']?.toString() ?? '';
    if (targetId.isEmpty) return;
    final post = await _repository.fetchFeedPostByRouteId(targetId);
    if (!mounted) return;
    if (post != null) {
      await Navigator.pushNamed(
        context,
        buildPostRoutePathForPreset(post.preset),
      );
      return;
    }
    final collection = await _repository.fetchCollectionByRouteId(targetId);
    if (!mounted || collection == null) return;
    await Navigator.pushNamed(
      context,
      buildCollectionRoutePathForSummary(collection.summary),
    );
  }

  Future<void> _openHeaderNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        if (_headerNotifications.isEmpty) {
          return SizedBox(
            height: 260,
            child: Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }
        return SizedBox(
          height: 460,
          child: ListView.separated(
            itemCount: _headerNotifications.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
            itemBuilder: (context, index) {
              final item = _headerNotifications[index];
              final actor = item.actorUserId == null
                  ? null
                  : _notificationActors[item.actorUserId!];
              final bool isMessage =
                  (item.data['type']?.toString() ?? '') == 'chat_message';
              final String title = isMessage
                  ? (item.title.isNotEmpty
                      ? item.title
                      : 'New message from ${actor?.displayName ?? 'User'}')
                  : (item.kind == 'mention'
                      ? '${actor?.displayName ?? 'Someone'} mentioned you'
                      : item.title);
              final String body = item.body.isNotEmpty
                  ? item.body
                  : (item.data['preset_title']?.toString() ?? '');
              final String meta =
                  '${_friendlyTime(item.createdAt)} · ${_formatDateTime(item.createdAt)}';
              final String subtitleText = body.isEmpty ? meta : '$body\n$meta';
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      actor?.avatarUrl != null && actor!.avatarUrl!.isNotEmpty
                          ? NetworkImage(actor.avatarUrl!)
                          : null,
                  child: actor?.avatarUrl == null || actor!.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                subtitle: Text(subtitleText, maxLines: 3),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _markNotificationReadLocal(item);
                  if (!mounted) return;
                  navigator.pop();
                  await _openNotificationTarget(item);
                  if (!mounted) return;
                  await _loadHeaderNotifications();
                },
              );
            },
          ),
        );
      },
    );
    await _repository.markNotificationsSeen();
    if (!mounted) return;
    await _loadHeaderNotifications();
  }

  void _syncTrackerCursorHover() {
    if (!mounted) return;
    final tracking = TrackingService.instance;
    if (!tracking.trackerEnabled || !tracking.dartCursorEnabled) {
      _setTrackerNavHover(false);
      return;
    }
    if (!tracking.hasFreshFrame) {
      _trackerNavDebounce?.cancel();
      _setTrackerNavHover(false);
      return;
    }
    final RenderBox? box =
        _navRegionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      _setTrackerNavHover(false);
      return;
    }
    final frame = tracking.frameNotifier.value;
    if (frame.cursorX <= 0 && frame.cursorY <= 0) {
      _setTrackerNavHover(false);
      return;
    }
    final Offset local =
        box.globalToLocal(Offset(frame.cursorX, frame.cursorY));
    final bool insideStrict = local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
    if (insideStrict) {
      _trackerNavDebounce?.cancel();
      _setTrackerNavHover(true);
      return;
    }
    _trackerNavDebounce?.cancel();
    _setTrackerNavHover(false);
  }

  void _setTrackerNavHover(bool value) {
    if (_trackerNavHover == value) return;
    _trackerNavHover = value;
    _syncNavExpanded();
  }

  void _setRealNavHover(bool value) {
    if (_realNavHover == value) return;
    _realNavHover = value;
    _syncNavExpanded();
  }

  void _syncNavExpanded() {
    final tracking = TrackingService.instance;
    final bool trackerHoverActive = tracking.trackerEnabled &&
        tracking.dartCursorEnabled &&
        _trackerNavHover;
    final bool next = _realNavHover || trackerHoverActive;
    if (_navExpanded == next) return;
    if (!mounted) return;
    setState(() => _navExpanded = next);
  }

  bool _tabNeedsAuth(_ShellTab tab) {
    return tab != _ShellTab.home && tab != _ShellTab.collection;
  }

  Future<bool> _promptSignIn() async {
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return true;
  }

  Future<void> _toggleBrowserFullscreen() async {
    if (!kIsWeb) return;
    try {
      if (html.document.fullscreenElement != null) {
        html.document.exitFullscreen();
        return;
      }
      final html.Element? root = html.document.documentElement;
      if (root == null) return;
      root.requestFullscreen();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fullscreen is not available in this browser/device.'),
        ),
      );
    }
  }

  Future<void> _switchTab(_ShellTab tab) async {
    if (_isGuest && _tabNeedsAuth(tab)) {
      await _promptSignIn();
      return;
    }
    if (!mounted) return;
    final String targetPath = _pathForTab(tab);
    final String? currentPath = ModalRoute.of(context)?.settings.name;
    if (currentPath == targetPath) {
      if (_activeTab != tab) {
        setState(() => _activeTab = tab);
      }
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: targetPath),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => ShowFeedPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          initialTab: _segmentForTab(tab),
        ),
      ),
    );
  }

  void _onScrollableDirection(bool showHeader) {
    // Home and Collection keep a pinned header in v1.0.021.
  }

  String get _title {
    switch (_activeTab) {
      case _ShellTab.home:
        return 'DeepX';
      case _ShellTab.collection:
        return 'Collection';
      case _ShellTab.post:
        return 'Post Studio';
      case _ShellTab.chat:
        return 'Chat';
      case _ShellTab.profile:
        return 'Profile';
      case _ShellTab.settings:
        return 'Settings';
    }
  }

  double _topInsetForTab(_ShellTab tab) {
    switch (tab) {
      case _ShellTab.home:
      case _ShellTab.collection:
        return _feedTopPadding;
      case _ShellTab.post:
      case _ShellTab.chat:
      case _ShellTab.profile:
      case _ShellTab.settings:
        return _tabContentTopPadding;
    }
  }

  Widget _buildActiveTab() {
    final topInset = _topInsetForTab(_activeTab);
    switch (_activeTab) {
      case _ShellTab.home:
        return _HomeFeedTab(
          key: _homeKey,
          topInset: topInset,
          onScrollDirection: _onScrollableDirection,
        );
      case _ShellTab.collection:
        return _CollectionTab(
          key: _collectionKey,
          topInset: topInset,
          onScrollDirection: _onScrollableDirection,
        );
      case _ShellTab.post:
        return _PostStudioTab(topInset: topInset);
      case _ShellTab.chat:
        return _ChatTab(key: _chatKey, topInset: topInset);
      case _ShellTab.profile:
        return _ProfileTab(
          key: _profileKey,
          onProfileChanged: _loadProfile,
          topInset: topInset,
        );
      case _ShellTab.settings:
        return _SettingsTab(
          currentThemeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color headerTitleColor = isDark ? Colors.white : cs.onSurface;
    final bool swapHomeTitle = _activeTab == _ShellTab.home && _navExpanded;
    final String headerTitle = _activeTab == _ShellTab.home
        ? (swapHomeTitle ? 'Home' : 'DeepX')
        : _title;
    final int unreadNotifications =
        _headerNotifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          MouseRegion(
            key: _navRegionKey,
            onEnter: (_) => _setRealNavHover(true),
            onExit: (_) => _setRealNavHover(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: _navExpanded ? 224 : 78,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border(
                  right: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _switchTab(_ShellTab.home),
                        child: Row(
                          children: [
                            Icon(Icons.blur_on, color: headerTitleColor),
                            const SizedBox(width: 10),
                            if (_navExpanded)
                              Text(
                                'DeepX',
                                style: GoogleFonts.orbitron(
                                  color: headerTitleColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    for (final _NavItem item in _primaryNav)
                      _NavButton(
                        expanded: _navExpanded,
                        active: _activeTab == item.tab,
                        colorScheme: cs,
                        icon: item.icon,
                        label: item.label,
                        onTap: () => _switchTab(item.tab),
                      ),
                    const Spacer(),
                    _NavButton(
                      expanded: _navExpanded,
                      active: _activeTab == _ShellTab.settings,
                      colorScheme: cs,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => _switchTab(_ShellTab.settings),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: KeyedSubtree(
                      key: ValueKey<String>('active-tab-${_activeTab.name}'),
                      child: _buildActiveTab(),
                    ),
                  ),
                  Positioned(
                    top: _headerTopOffset,
                    left: 0,
                    right: 0,
                    child: ClipRect(
                      child: SizedBox(
                        height: _headerHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                      stops: const [0, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 10, 10),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: Text(
                                      headerTitle,
                                      key: ValueKey<String>(headerTitle),
                                      style: (_activeTab == _ShellTab.home
                                                  ? GoogleFonts.orbitron(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    )
                                                  : null)
                                              ?.copyWith(
                                            color: headerTitleColor,
                                            fontSize: 28,
                                          ) ??
                                          TextStyle(
                                            color: headerTitleColor,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_currentProfile != null)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () =>
                                          _switchTab(_ShellTab.profile),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundImage:
                                                  (_currentProfile!.avatarUrl !=
                                                              null &&
                                                          _currentProfile!
                                                              .avatarUrl!
                                                              .isNotEmpty)
                                                      ? NetworkImage(
                                                          _currentProfile!
                                                              .avatarUrl!)
                                                      : null,
                                              backgroundColor:
                                                  cs.surfaceContainerHighest,
                                              child: (_currentProfile!
                                                              .avatarUrl ==
                                                          null ||
                                                      _currentProfile!
                                                          .avatarUrl!.isEmpty)
                                                  ? Icon(Icons.person,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      size: 15)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _currentProfile!.displayName,
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    FilledButton.tonal(
                                      onPressed: () => _promptSignIn(),
                                      child: const Text('Sign In'),
                                    ),
                                  if (_currentProfile != null)
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          tooltip: 'Notifications',
                                          onPressed: _openHeaderNotifications,
                                          icon: Icon(
                                            Icons.notifications_outlined,
                                            color: headerTitleColor,
                                          ),
                                        ),
                                        if (unreadNotifications > 0)
                                          Positioned(
                                            right: 2,
                                            top: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                unreadNotifications > 99
                                                    ? '99+'
                                                    : '$unreadNotifications',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  IconButton(
                                    tooltip: 'Browser Fullscreen',
                                    onPressed: _toggleBrowserFullscreen,
                                    icon: Icon(
                                      Icons.fullscreen,
                                      color: headerTitleColor,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Recenter Parallax',
                                    onPressed: () {
                                      TrackingService.instance
                                          .remapHeadBaselineToCurrentFrame();
                                    },
                                    icon: Icon(Icons.gps_fixed,
                                        color: headerTitleColor),
                                  ),
                                  IconButton(
                                    tooltip: 'Reload',
                                    onPressed: _reloadActiveTab,
                                    icon: Icon(Icons.refresh,
                                        color: headerTitleColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.expanded,
    required this.active,
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final bool active;
  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        widget.active ? Colors.black : widget.colorScheme.onSurface;
    Color bg = Colors.transparent;
    if (widget.active) {
      bg = Colors.white;
    } else if (_hovered) {
      bg = widget.colorScheme.onSurface.withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: fg, size: 24),
                if (widget.expanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab({
    super.key,
    required this.topInset,
    required this.onScrollDirection,
  });

  final double topInset;
  final ValueChanged<bool> onScrollDirection;

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab> {
  final AppRepository _repository = AppRepository.instance;
  static const List<String> _homeFeedChips = <String>[
    'All',
    'FYP',
    'Trending',
    'Most Used Hashtags',
    'Most Liked',
    'Most Viewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  final List<FeedPost> _posts = <FeedPost>[];
  String _selectedHomeChip = _homeFeedChips.first;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await _repository.fetchFeedPosts(limit: 120);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openPost(FeedPost post) async {
    await _repository.recordPresetView(post.preset.id);
    if (!mounted) return;
    await Navigator.pushNamed(
        context, buildPostRoutePathForPreset(post.preset));
    await _loadFeed();
  }

  Future<void> _openPostEditor(FeedPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostCardComposerPage.single(
          name: post.preset.name,
          mode: post.preset.mode,
          payload: post.preset.payload,
          existingPreset: post.preset,
          editTarget: _ComposerEditTarget.card,
          startBlankCard: true,
        ),
      ),
    );
    await _loadFeed();
  }

  Future<void> _toggleVisibility(FeedPost post) async {
    try {
      await _repository.setPresetVisibility(
        presetId: post.preset.id,
        isPublic: !post.preset.isPublic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.preset.isPublic
                ? 'Post set to private.'
                : 'Post set to public.',
          ),
        ),
      );
      await _loadFeed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visibility: $e')),
      );
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deletePresetPost(post.preset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      await _loadFeed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_repository.currentUser != null) return true;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  Future<void> _toggleWatchLater(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    final bool watchLater = !post.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'post',
      targetId: post.preset.id,
      watchLater: watchLater,
    );
    if (!mounted) return;
    setState(() {
      final int index = _posts.indexWhere((p) => p.preset.id == post.preset.id);
      if (index < 0) return;
      final FeedPost current = _posts[index];
      _posts[index] = FeedPost(
        preset: current.preset,
        author: current.author,
        likesCount: current.likesCount,
        dislikesCount: current.dislikesCount,
        commentsCount: current.commentsCount,
        savesCount: current.savesCount,
        myReaction: current.myReaction,
        isSaved: current.isSaved,
        isFollowingAuthor: current.isFollowingAuthor,
        viewsCount: current.viewsCount,
        isWatchLater: watchLater,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          watchLater ? 'Added to Watch Later.' : 'Removed from Watch Later.',
        ),
      ),
    );
  }

  Future<void> _copyPostLink(RenderPreset preset) async {
    await Clipboard.setData(ClipboardData(text: buildPostShareUrl(preset)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied.')),
    );
  }

  Future<void> _openPostShareUrl(
    String url, {
    required RenderPreset preset,
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyPostLink(preset);
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openPostShareSheet(FeedPost post) async {
    final String link = buildPostShareUrl(post.preset);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(post.preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://t.me/share/url?url=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://wa.me/?text=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.instagram.com/',
                  preset: post.preset,
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.snapchat.com/',
                  preset: post.preset,
                  copyLinkFirst: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportPost(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    const List<String> reasons = <String>[
      'Spam',
      'Harassment',
      'Violence',
      'Adult content',
      'Misinformation',
    ];
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _repository.submitReport(
      targetType: 'post',
      targetId: post.preset.id,
      reason: reason.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  }

  Future<void> _notInterestedInPost(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'post',
      targetId: post.preset.id,
      excluded: true,
    );
    if (!mounted) return;
    setState(() => _posts.removeWhere((p) => p.preset.id == post.preset.id));
  }

  Future<void> _dontRecommendUser(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'user',
      targetId: post.preset.userId,
      excluded: true,
    );
    if (!mounted) return;
    setState(
        () => _posts.removeWhere((p) => p.preset.userId == post.preset.userId));
  }

  List<FeedPost> _postsForSelectedChip() {
    final List<FeedPost> items = List<FeedPost>.from(_posts);
    switch (_selectedHomeChip) {
      case 'Most Viewed':
        items.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'Most Liked':
        items.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'Trending':
        items.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        break;
      case 'Most Used Hashtags':
        items.sort((a, b) => b.preset.tags.length.compareTo(a.preset.tags.length));
        break;
      case 'Viral':
        items.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        break;
      case 'FYP':
      case 'All':
      default:
        break;
    }
    return items;
  }

  Widget _buildHomeChipRail(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, widget.topInset + 6, 14, 8),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _homeFeedChips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final String chip = _homeFeedChips[index];
            final bool selected = chip == _selectedHomeChip;
            return ChoiceChip(
              selected: selected,
              label: Text(chip),
              onSelected: (_) => setState(() => _selectedHomeChip = chip),
              selectedColor: cs.primary.withValues(alpha: 0.18),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<FeedPost> visiblePosts = _postsForSelectedChip();
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading feed...');
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: cs.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadFeed,
          icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
          label: Text(
            'Feed is empty. Refresh',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildHomeChipRail(cs),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                widget.onScrollDirection(false);
              } else if (notification.direction == ScrollDirection.forward ||
                  notification.metrics.pixels <= 1) {
                widget.onScrollDirection(true);
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                int crossAxisCount = 1;
                if (width >= 1500) {
                  crossAxisCount = 4;
                } else if (width >= 1150) {
                  crossAxisCount = 3;
                } else if (width >= 760) {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: visiblePosts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.18,
                  ),
                  itemBuilder: (context, index) {
                    final post = visiblePosts[index];
                    final bool mine =
                        _repository.currentUser?.id == post.preset.userId;
                    return _FeedTile(
                      post: post,
                      onTap: () => _openPost(post),
                      onOpenAuthorProfile: () =>
                          _openPublicProfileRoute(context, post.author),
                      isMine: mine,
                      onEdit: mine ? () => _openPostEditor(post) : null,
                      onToggleVisibility:
                          mine ? () => _toggleVisibility(post) : null,
                      onDelete: mine ? () => _deletePost(post) : null,
                      onWatchLater: () => _toggleWatchLater(post),
                      onShare: () => _openPostShareSheet(post),
                      onReport: () => _reportPost(post),
                      onNotInterested: () => _notInterestedInPost(post),
                      onDontRecommend: () => _dontRecommendUser(post),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionTab extends StatefulWidget {
  const _CollectionTab({
    super.key,
    required this.topInset,
    required this.onScrollDirection,
  });

  final double topInset;
  final ValueChanged<bool> onScrollDirection;

  @override
  State<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<_CollectionTab> {
  final AppRepository _repository = AppRepository.instance;
  static const List<String> _collectionChips = <String>[
    'All',
    'FYP',
    'Trending',
    'Most Used Hashtags',
    'Most Liked',
    'Most Viewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  final List<CollectionSummary> _collections = <CollectionSummary>[];
  String _selectedCollectionChip = _collectionChips.first;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, CollectionSummary> merged =
          <String, CollectionSummary>{};
      final published = await _repository.fetchPublishedCollections(limit: 120);
      for (final c in published) {
        merged[c.id] = c;
      }
      if (_repository.currentUser != null) {
        final mine = await _repository.fetchCollectionsForCurrentUser();
        for (final c in mine) {
          merged[c.id] = c;
        }
      }
      final collections = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _collections
          ..clear()
          ..addAll(collections);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openCollection(CollectionSummary summary) async {
    await Navigator.pushNamed(
      context,
      buildCollectionRoutePathForSummary(summary),
    );
    await _loadCollections();
  }

  Future<void> _toggleCollectionVisibility(CollectionSummary summary) async {
    try {
      await _repository.setCollectionPublished(
        collectionId: summary.id,
        published: !summary.published,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.published
                ? 'Collection set to private.'
                : 'Collection set to public.',
          ),
        ),
      );
      await _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update collection: $e')),
      );
    }
  }

  Future<void> _deleteCollection(CollectionSummary summary) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete collection?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deleteCollection(summary.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted.')),
      );
      await _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _updateCollection(CollectionSummary summary) async {
    final detail = await _repository.fetchCollectionById(summary.id);
    if (!mounted || detail == null) return;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostCardComposerPage.collection(
          collectionId: summary.id,
          collectionName: summary.name,
          collectionDescription: summary.description,
          tags: summary.tags,
          mentionUserIds: summary.mentionUserIds,
          published: summary.published,
          initialCardPayload: summary.thumbnailPayload,
          initialCardMode: summary.thumbnailMode,
          editTarget: _ComposerEditTarget.card,
          startBlankCard: true,
          items: detail.items
              .map(
                (item) => CollectionDraftItem(
                  mode: item.mode,
                  name: item.name,
                  snapshot: item.snapshot,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (updated == true) {
      await _loadCollections();
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_repository.currentUser != null) return true;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  Future<void> _toggleCollectionWatchLater(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    final bool watchLater = !summary.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'collection',
      targetId: summary.id,
      watchLater: watchLater,
    );
    if (!mounted) return;
    setState(() {
      final int index = _collections.indexWhere((c) => c.id == summary.id);
      if (index < 0) return;
      final CollectionSummary current = _collections[index];
      _collections[index] = CollectionSummary(
        id: current.id,
        shareId: current.shareId,
        userId: current.userId,
        name: current.name,
        description: current.description,
        tags: current.tags,
        mentionUserIds: current.mentionUserIds,
        published: current.published,
        thumbnailPayload: current.thumbnailPayload,
        thumbnailMode: current.thumbnailMode,
        itemsCount: current.itemsCount,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
        firstItem: current.firstItem,
        author: current.author,
        likesCount: current.likesCount,
        dislikesCount: current.dislikesCount,
        commentsCount: current.commentsCount,
        savesCount: current.savesCount,
        viewsCount: current.viewsCount,
        myReaction: current.myReaction,
        isSavedByCurrentUser: current.isSavedByCurrentUser,
        isWatchLater: watchLater,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          watchLater ? 'Added to Watch Later.' : 'Removed from Watch Later.',
        ),
      ),
    );
  }

  Future<void> _copyCollectionLink(CollectionSummary summary) async {
    await Clipboard.setData(
        ClipboardData(text: buildCollectionShareUrl(summary)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection link copied.')),
    );
  }

  Future<void> _openCollectionShareUrl(
    String url, {
    required CollectionSummary summary,
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyCollectionLink(summary);
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openCollectionShareSheet(CollectionSummary summary) async {
    final String link = buildCollectionShareUrl(summary);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyCollectionLink(summary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://t.me/share/url?url=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://wa.me/?text=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.instagram.com/',
                  summary: summary,
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.snapchat.com/',
                  summary: summary,
                  copyLinkFirst: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportCollection(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    const List<String> reasons = <String>[
      'Spam',
      'Harassment',
      'Violence',
      'Adult content',
      'Misinformation',
    ];
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _repository.submitReport(
      targetType: 'collection',
      targetId: summary.id,
      reason: reason.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  }

  Future<void> _notInterestedInCollection(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'collection',
      targetId: summary.id,
      excluded: true,
    );
    if (!mounted) return;
    setState(() => _collections.removeWhere((c) => c.id == summary.id));
  }

  Future<void> _dontRecommendCollectionUser(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'user',
      targetId: summary.userId,
      excluded: true,
    );
    if (!mounted) return;
    setState(
      () => _collections.removeWhere((c) => c.userId == summary.userId),
    );
  }

  List<CollectionSummary> _collectionsForSelectedChip() {
    final List<CollectionSummary> items =
        List<CollectionSummary>.from(_collections);
    switch (_selectedCollectionChip) {
      case 'Most Viewed':
        items.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'Most Liked':
        items.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'Trending':
        items.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        break;
      case 'Most Used Hashtags':
        items.sort((a, b) => b.tags.length.compareTo(a.tags.length));
        break;
      case 'Viral':
        items.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        break;
      case 'FYP':
      case 'All':
      default:
        break;
    }
    return items;
  }

  Widget _buildCollectionChipRail(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, widget.topInset + 6, 14, 8),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _collectionChips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final String chip = _collectionChips[index];
            final bool selected = chip == _selectedCollectionChip;
            return ChoiceChip(
              selected: selected,
              label: Text(chip),
              onSelected: (_) => setState(() => _selectedCollectionChip = chip),
              selectedColor: cs.primary.withValues(alpha: 0.18),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<CollectionSummary> visibleCollections =
        _collectionsForSelectedChip();
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading collections...');
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: cs.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_collections.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadCollections,
          icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
          label: Text(
            'No collections yet. Refresh',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildCollectionChipRail(cs),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                widget.onScrollDirection(false);
              } else if (notification.direction == ScrollDirection.forward ||
                  notification.metrics.pixels <= 1) {
                widget.onScrollDirection(true);
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 1;
                if (width >= 1500) {
                  crossAxisCount = 4;
                } else if (width >= 1150) {
                  crossAxisCount = 3;
                } else if (width >= 760) {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: visibleCollections.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.18,
                  ),
                  itemBuilder: (context, index) {
                    final summary = visibleCollections[index];
                    final bool mine =
                        _repository.currentUser?.id == summary.userId;
                    return _CollectionFeedTile(
                      summary: summary,
                      onTap: () => _openCollection(summary),
                      onOpenAuthorProfile: () =>
                          _openPublicProfileRoute(context, summary.author),
                      isMine: mine,
                      onToggleVisibility:
                          mine ? () => _toggleCollectionVisibility(summary) : null,
                      onDelete: mine ? () => _deleteCollection(summary) : null,
                      onUpdate: mine ? () => _updateCollection(summary) : null,
                      onWatchLater: () => _toggleCollectionWatchLater(summary),
                      onShare: () => _openCollectionShareSheet(summary),
                      onReport: () => _reportCollection(summary),
                      onNotInterested: () => _notInterestedInCollection(summary),
                      onDontRecommend: () => _dontRecommendCollectionUser(summary),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionFeedTile extends StatelessWidget {
  const _CollectionFeedTile({
    required this.summary,
    required this.onTap,
    required this.onOpenAuthorProfile,
    required this.isMine,
    required this.onWatchLater,
    required this.onShare,
    required this.onReport,
    required this.onNotInterested,
    required this.onDontRecommend,
    this.onUpdate,
    this.onDelete,
    this.onToggleVisibility,
  });

  final CollectionSummary summary;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthorProfile;
  final bool isMine;
  final VoidCallback onWatchLater;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onNotInterested;
  final VoidCallback onDontRecommend;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final BorderRadius cardRadius = BorderRadius.circular(16);
    final item = summary.firstItem;
    final String previewMode = summary.thumbnailMode ?? item?.mode ?? '2d';
    final Map<String, dynamic> previewPayload =
        summary.thumbnailPayload.isNotEmpty
            ? summary.thumbnailPayload
            : (item?.snapshot ?? const <String, dynamic>{});
    final preview = previewPayload.isEmpty
        ? Container(
            color: cs.surfaceContainerLow,
            child: Center(
              child: Icon(
                Icons.collections_bookmark_outlined,
                color: cs.onSurfaceVariant,
                size: 34,
              ),
            ),
          )
        : _GridPresetPreview(
            mode: previewMode,
            payload: previewPayload,
            borderRadius: cardRadius,
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  IgnorePointer(child: preview),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      tooltip: 'Collection actions',
                      color: cs.surfaceContainerHighest,
                      onSelected: (value) {
                        if (value == 'watch_later') onWatchLater();
                        if (value == 'share') onShare();
                        if (value == 'report') onReport();
                        if (value == 'not_interested') onNotInterested();
                        if (value == 'dont_recommend') onDontRecommend();
                        if (value == 'update') onUpdate?.call();
                        if (value == 'visibility') onToggleVisibility?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'watch_later',
                            child: Text(
                              summary.isWatchLater
                                  ? 'Remove from Watch Later'
                                  : 'Watch Later',
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'share',
                            child: Text('Share'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Report'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'not_interested',
                            child: Text('Not interested'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'dont_recommend',
                            child: Text('Don\'t recommend channel'),
                          ),
                        ];
                        if (isMine) {
                          items.addAll(
                            <PopupMenuEntry<String>>[
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'update',
                                child: Text('Update'),
                              ),
                              PopupMenuItem<String>(
                                value: 'visibility',
                                child: Text(
                                  summary.published
                                      ? 'Make Private'
                                      : 'Make Public',
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          );
                        }
                        return items;
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary.name.isNotEmpty ? summary.name : 'Untitled collection',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            InkWell(
              onTap: onOpenAuthorProfile,
              child: Text(
                summary.author?.displayName ?? 'Unknown creator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_friendlyCount(summary.viewsCount)} views · ${_friendlyTime(summary.createdAt)} · ${summary.itemsCount} items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.post,
    required this.onTap,
    required this.onOpenAuthorProfile,
    required this.isMine,
    required this.onWatchLater,
    required this.onShare,
    required this.onReport,
    required this.onNotInterested,
    required this.onDontRecommend,
    this.onEdit,
    this.onDelete,
    this.onToggleVisibility,
  });

  final FeedPost post;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthorProfile;
  final bool isMine;
  final VoidCallback onWatchLater;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onNotInterested;
  final VoidCallback onDontRecommend;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final BorderRadius cardRadius = BorderRadius.circular(16);
    final String previewMode = post.preset.thumbnailMode ?? post.preset.mode;
    final Map<String, dynamic> previewPayload =
        post.preset.thumbnailPayload.isNotEmpty
            ? post.preset.thumbnailPayload
            : post.preset.payload;
    final Widget preview = _GridPresetPreview(
      mode: previewMode,
      payload: previewPayload,
      borderRadius: cardRadius,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  IgnorePointer(child: preview),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      tooltip: 'Post actions',
                      color: cs.surfaceContainerHighest,
                      onSelected: (value) {
                        if (value == 'watch_later') onWatchLater();
                        if (value == 'share') onShare();
                        if (value == 'report') onReport();
                        if (value == 'not_interested') onNotInterested();
                        if (value == 'dont_recommend') onDontRecommend();
                        if (value == 'edit') onEdit?.call();
                        if (value == 'visibility') onToggleVisibility?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'watch_later',
                            child: Text(
                              post.isWatchLater
                                  ? 'Remove from Watch Later'
                                  : 'Watch Later',
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'share',
                            child: Text('Share'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Report'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'not_interested',
                            child: Text('Not interested'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'dont_recommend',
                            child: Text('Don\'t recommend channel'),
                          ),
                        ];
                        if (isMine) {
                          items.addAll(
                            <PopupMenuEntry<String>>[
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Update'),
                              ),
                              PopupMenuItem<String>(
                                value: 'visibility',
                                child: Text(
                                  post.preset.isPublic
                                      ? 'Make Private'
                                      : 'Make Public',
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          );
                        }
                        return items;
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.preset.title.isNotEmpty
                  ? post.preset.title
                  : post.preset.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            InkWell(
              onTap: onOpenAuthorProfile,
              child: Text(
                post.author?.displayName ?? 'Unknown creator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_friendlyCount(post.viewsCount)} views · ${_friendlyTime(post.preset.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPresetPreview extends StatelessWidget {
  const _GridPresetPreview({
    required this.mode,
    required this.payload,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.pointerPassthrough = true,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final BorderRadius borderRadius;
  final bool pointerPassthrough;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: mode,
    );

    if (adapted.scene.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(color: cs.surfaceContainerLow),
          child: Center(
            child: Icon(
              adapted.mode == '3d'
                  ? Icons.view_in_ar_outlined
                  : Icons.layers_outlined,
              color: cs.onSurfaceVariant,
              size: 28,
            ),
          ),
        ),
      );
    }

    if (adapted.mode == '2d') {
      return WindowEffect2DPreview(
        mode: adapted.mode,
        payload: adapted.toMap(),
        borderRadius: borderRadius,
      );
    }

    return _build3DPreview(adapted);
  }

  Widget _build3DPreview(PresetPayloadV2 adapted) {
    final bool hasWindowAssignments = _has3DWindowAssignments(adapted.scene);
    if (!hasWindowAssignments) {
      return PresetViewer(
        mode: adapted.mode,
        payload: adapted.toMap(),
        cleanView: true,
        embedded: true,
        disableAudio: true,
        useGlobalTracking: true,
        pointerPassthrough: pointerPassthrough,
      );
    }

    final Map<String, dynamic> insidePayload = adapted.toMap()
      ..['scene'] = _filtered3dScene(adapted.scene, 'inside');
    final Map<String, dynamic> outsidePayload = adapted.toMap()
      ..['scene'] = _filtered3dScene(adapted.scene, 'outside');
    final bool hasOutside = _sceneHasModelsOrLights(outsidePayload['scene']);

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(
          borderRadius: borderRadius,
          child: PresetViewer(
            mode: adapted.mode,
            payload: insidePayload,
            cleanView: true,
            embedded: true,
            disableAudio: true,
            useGlobalTracking: true,
            pointerPassthrough: pointerPassthrough,
          ),
        ),
        if (hasOutside)
          Positioned(
            left: -50,
            right: -50,
            top: -50,
            bottom: -50,
            child: IgnorePointer(
              child: PresetViewer(
                mode: adapted.mode,
                payload: outsidePayload,
                cleanView: true,
                embedded: true,
                disableAudio: true,
                useGlobalTracking: true,
                pointerPassthrough: pointerPassthrough,
              ),
            ),
          ),
      ],
    );
  }

  bool _has3DWindowAssignments(Map<String, dynamic> scene) {
    final models = scene['models'];
    if (models is List) {
      for (final model in models) {
        if (model is Map && model['windowLayer'] != null) {
          return true;
        }
      }
    }
    final lights = scene['lights'];
    if (lights is List) {
      for (final light in lights) {
        if (light is Map && light['windowLayer'] != null) {
          return true;
        }
      }
    }
    final audios = scene['audios'];
    if (audios is List) {
      for (final audio in audios) {
        if (audio is Map && audio['windowLayer'] != null) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> _filtered3dScene(
    Map<String, dynamic> scene,
    String layer,
  ) {
    final Map<String, dynamic> next = Map<String, dynamic>.from(scene);
    final List<Map<String, dynamic>> models = <Map<String, dynamic>>[];
    final dynamic modelsRaw = scene['models'];
    if (modelsRaw is List) {
      for (final item in modelsRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final String windowLayer =
            (map['windowLayer']?.toString().toLowerCase() ?? 'inside');
        if (windowLayer == layer) {
          models.add(map);
        }
      }
    }

    final List<Map<String, dynamic>> lights = <Map<String, dynamic>>[];
    final dynamic lightsRaw = scene['lights'];
    if (lightsRaw is List) {
      for (final item in lightsRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final String windowLayer =
            (map['windowLayer']?.toString().toLowerCase() ?? 'inside');
        if (windowLayer == layer) {
          lights.add(map);
        }
      }
    }

    final List<Map<String, dynamic>> audios = <Map<String, dynamic>>[];
    final dynamic audiosRaw = scene['audios'];
    if (audiosRaw is List) {
      for (final item in audiosRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final String windowLayer =
            (map['windowLayer']?.toString().toLowerCase() ?? 'inside');
        if (windowLayer == layer) {
          audios.add(map);
        }
      }
    }

    next['models'] = models;
    next['lights'] = lights;
    next['audios'] = audios;
    final dynamic orderRaw = scene['renderOrder'];
    if (orderRaw is List) {
      final available = <String>{
        ...models.map((e) => 'model:${e['id']}'),
        ...lights.map((e) => 'light:${e['id']}'),
        ...audios.map((e) => 'audio:${e['id']}'),
      };
      next['renderOrder'] = orderRaw
          .map((e) => e.toString())
          .where((token) => available.contains(token))
          .toList();
    }
    return next;
  }

  bool _sceneHasModelsOrLights(dynamic rawScene) {
    if (rawScene is! Map) return false;
    final scene = Map<String, dynamic>.from(rawScene);
    final models = scene['models'];
    if (models is List && models.isNotEmpty) return true;
    final lights = scene['lights'];
    if (lights is List && lights.isNotEmpty) return true;
    final audios = scene['audios'];
    if (audios is List && audios.isNotEmpty) return true;
    return false;
  }
}

class _PresetDetailPage extends StatefulWidget {
  const _PresetDetailPage({required this.initialPost});

  final FeedPost initialPost;

  @override
  State<_PresetDetailPage> createState() => _PresetDetailPageState();
}

class _PresetDetailPageState extends State<_PresetDetailPage> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _immersiveFocusNode =
      FocusNode(debugLabel: 'detail-immersive-focus');
  static const List<String> _suggestionFilters = <String>[
    'All',
    'FromUser',
    'Related',
    'FYP',
    'Trending',
    'MostUsedHashtags',
    'MostLiked',
    'MostViewed',
    'Viral',
  ];

  late FeedPost _post;
  bool _loadingComments = true;
  bool _sendingComment = false;
  bool _commentsOpen = false;
  bool _immersive = false;
  bool _loadingSuggestions = false;
  bool _descriptionExpanded = false;
  bool? _cursorBeforeImmersive;
  List<PresetComment> _comments = const <PresetComment>[];
  List<FeedPost> _suggestedPosts = const <FeedPost>[];
  String _suggestionFilter = _suggestionFilters.first;

  bool get _mine =>
      _repository.currentUser != null &&
      _repository.currentUser!.id == _post.preset.userId;

  Future<bool> _requireAuthAction() async {
    if (_repository.currentUser != null) return true;
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  @override
  void initState() {
    super.initState();
    TrackingService.instance.remapHeadBaselineToCurrentFrame();
    _post = widget.initialPost;
    _loadComments();
    _loadSuggestions();
  }

  @override
  void dispose() {
    if (_cursorBeforeImmersive != null) {
      TrackingService.instance.setDartCursorEnabled(_cursorBeforeImmersive!);
      _cursorBeforeImmersive = null;
    }
    _immersiveFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleImmersive() {
    final TrackingService tracking = TrackingService.instance;
    if (!_immersive) {
      _cursorBeforeImmersive = tracking.dartCursorEnabled;
      tracking.setDartCursorEnabled(false);
      setState(() => _immersive = true);
      return;
    }
    setState(() => _immersive = false);
    if (_cursorBeforeImmersive != null) {
      tracking.setDartCursorEnabled(_cursorBeforeImmersive!);
      _cursorBeforeImmersive = null;
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final comments = await _repository.fetchPresetComments(_post.preset.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loadingComments = false;
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: comments.length,
        savesCount: _post.savesCount,
        myReaction: _post.myReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _toggleReaction(int value) async {
    if (!await _requireAuthAction()) return;
    final int newReaction = _post.myReaction == value ? 0 : value;
    await _repository.setReaction(
        presetId: _post.preset.id, reaction: newReaction);
    if (!mounted) return;

    int likes = _post.likesCount;
    int dislikes = _post.dislikesCount;
    if (_post.myReaction == 1) likes = (likes - 1).clamp(0, 999999999);
    if (_post.myReaction == -1) dislikes = (dislikes - 1).clamp(0, 999999999);
    if (newReaction == 1) likes += 1;
    if (newReaction == -1) dislikes += 1;

    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: likes,
        dislikesCount: dislikes,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: newReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _toggleSave() async {
    if (!await _requireAuthAction()) return;
    final bool shouldSave = !_post.isSaved;
    await _repository.toggleSavePreset(_post.preset.id, save: shouldSave);
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: shouldSave
            ? _post.savesCount + 1
            : (_post.savesCount - 1).clamp(0, 999999999),
        myReaction: _post.myReaction,
        isSaved: shouldSave,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _toggleWatchLater() async {
    if (!await _requireAuthAction()) return;
    final bool shouldWatchLater = !_post.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'post',
      targetId: _post.preset.id,
      watchLater: shouldWatchLater,
    );
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: _post.myReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: shouldWatchLater,
      );
    });
  }

  Future<void> _toggleFollow() async {
    if (!await _requireAuthAction()) return;
    final bool follow = !_post.isFollowingAuthor;
    await _repository.setFollow(
      targetUserId: _post.preset.userId,
      follow: follow,
    );
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: _post.myReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: follow,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _shareToUser() async {
    if (!await _requireAuthAction()) return;
    if (!mounted) return;
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Share Preset to User'),
    );
    if (profile == null) return;

    try {
      final chatId = await _repository.createOrGetDirectChat(profile.userId);
      await _repository.sendChatMessage(
        chatId: chatId,
        body: 'Shared a preset',
        sharedPresetId: _post.preset.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _copyPostLinkToClipboard() async {
    final String link = buildPostShareUrl(_post.preset);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied to clipboard.')),
    );
  }

  Future<void> _openShareUrl(
    String url, {
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyPostLinkToClipboard();
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openShareSheet() async {
    final String link = buildPostShareUrl(_post.preset);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Share to user'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                subtitle:
                    Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  _copyPostLinkToClipboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Telegram'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl('https://t.me/share/url?url=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Facebook'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl('https://wa.me/?text=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('X (Twitter)'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                      'https://twitter.com/intent/tweet?url=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Instagram'),
                subtitle: const Text('Copies link first'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.instagram.com/',
                    copyLinkFirst: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_front_outlined),
                title: const Text('Snapchat'),
                subtitle: const Text('Copies link first'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.snapchat.com/',
                    copyLinkFirst: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reddit'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                      'https://www.reddit.com/submit?url=$encodedLink');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendComment() async {
    if (!await _requireAuthAction()) return;
    final String text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    await _repository.addPresetComment(
        presetId: _post.preset.id, content: text);
    if (!mounted) return;
    _commentController.clear();
    setState(() => _sendingComment = false);
    await _loadComments();
  }

  Future<void> _editOwnPost() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostCardComposerPage.single(
          name: _post.preset.name,
          mode: _post.preset.mode,
          payload: _post.preset.payload,
          existingPreset: _post.preset,
          editTarget: _ComposerEditTarget.detail,
          startBlankCard: false,
        ),
      ),
    );
    if (updated == true) {
      final refreshed = await _repository.fetchFeedPostById(_post.preset.id);
      if (!mounted || refreshed == null) return;
      setState(() => _post = refreshed);
    }
  }

  Future<void> _toggleOwnVisibility() async {
    try {
      await _repository.setPresetVisibility(
        presetId: _post.preset.id,
        isPublic: !_post.preset.isPublic,
      );
      final refreshed = await _repository.fetchFeedPostById(_post.preset.id);
      if (!mounted) return;
      if (refreshed != null) {
        setState(() => _post = refreshed);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _post.preset.isPublic
                ? 'Post set to private.'
                : 'Post set to public.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visibility: $e')),
      );
    }
  }

  Future<void> _deleteOwnPost() async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deletePresetPost(_post.preset.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  String _displayFilterName(String filter) {
    if (filter == 'FromUser') {
      final username = _post.author?.username?.trim();
      if (username != null && username.isNotEmpty) {
        return 'From @$username';
      }
      return 'From creator';
    }
    switch (filter) {
      case 'MostUsedHashtags':
        return 'Most Used Hashtags';
      case 'MostLiked':
        return 'Most Liked';
      case 'MostViewed':
        return 'Most Viewed';
      default:
        return filter;
    }
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final posts = await _repository.fetchFeedPosts(limit: 120);
      if (!mounted) return;
      setState(() {
        _suggestedPosts = posts;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  List<FeedPost> _filteredSuggestions() {
    final List<FeedPost> candidates = _suggestedPosts
        .where((item) => item.preset.id != _post.preset.id)
        .toList();
    final String currentUserId = _post.preset.userId;
    final Set<String> currentTags = _post.preset.tags.map((e) => e.toLowerCase()).toSet();
    switch (_suggestionFilter) {
      case 'FromUser':
        return candidates.where((item) => item.preset.userId == currentUserId).toList();
      case 'Related':
        return candidates.where((item) {
          final tags = item.preset.tags.map((e) => e.toLowerCase()).toSet();
          return tags.intersection(currentTags).isNotEmpty;
        }).toList();
      case 'Trending':
        candidates.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'MostUsedHashtags':
        candidates.sort((a, b) => b.preset.tags.length.compareTo(a.preset.tags.length));
        return candidates;
      case 'MostLiked':
        candidates.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        return candidates;
      case 'MostViewed':
        candidates.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        return candidates;
      case 'Viral':
        candidates.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'FYP':
      case 'All':
      default:
        return candidates;
    }
  }

  Future<void> _openSuggestedPost(FeedPost post) async {
    await _repository.recordPresetView(post.preset.id);
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _PresetDetailPage(initialPost: post),
      ),
    );
  }

  String? _ambientImageUrlFromPayload(Map<String, dynamic> payload) {
    try {
      final adapted = PresetPayloadV2.fromMap(payload, fallbackMode: '2d');
      if (adapted.mode != '2d') return null;
      final scene = adapted.scene;
      final layers = scene.entries
          .where((e) => e.value is Map)
          .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value as Map)))
          .where((entry) =>
              entry.key != 'turning_point' &&
              entry.value['isVisible'] != false &&
              (entry.value['url'] ?? '').toString().trim().isNotEmpty)
          .toList();
      layers.sort((a, b) {
        final double ao = _safeDouble(a.value['order'], 0);
        final double bo = _safeDouble(b.value['order'], 0);
        return ao.compareTo(bo);
      });
      if (layers.isEmpty) return null;
      return (layers.last.value['url'] ?? '').toString().trim();
    } catch (_) {
      return null;
    }
  }

  double _safeDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewer = PresetViewer(
      mode: _post.preset.mode,
      payload: _post.preset.payload,
      cleanView: true,
      embedded: true,
      disableAudio: true,
    );
    final String? ambientUrl = _ambientImageUrlFromPayload(_post.preset.payload);
    final List<FeedPost> suggestions = _filteredSuggestions();

    Widget buildBackdrop() {
      if (ambientUrl == null || ambientUrl.isEmpty) {
        return const ColoredBox(color: Colors.black);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            ambientUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 56, sigmaY: 56),
            child: Container(color: Colors.black.withValues(alpha: 0.72)),
          ),
        ],
      );
    }

    Widget buildHeader() {
      return AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        offset: _immersive ? const Offset(0, -1) : Offset.zero,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 10),
              Text(
                'DeepX',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _immersive ? 'Exit Fullscreen' : 'Fullscreen',
                onPressed: _toggleImmersive,
                icon: Icon(
                  _immersive ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildDetailMetaPanel(double width) {
      final bool narrow = width < 1140;
      return Container(
        width: narrow ? double.infinity : 420,
        constraints: const BoxConstraints(minHeight: 420),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post.preset.title.isNotEmpty
                            ? _post.preset.title
                            : _post.preset.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_friendlyCount(_post.viewsCount)} views · ${_friendlyTime(_post.preset.createdAt)}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                      ),
                    ],
                  ),
                ),
                if (_mine)
                  PopupMenuButton<String>(
                    color: cs.surfaceContainerHighest,
                    onSelected: (value) {
                      if (value == 'edit') _editOwnPost();
                      if (value == 'visibility') _toggleOwnVisibility();
                      if (value == 'delete') _deleteOwnPost();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Update'),
                      ),
                      PopupMenuItem<String>(
                        value: 'visibility',
                        child: Text(
                          _post.preset.isPublic ? 'Make Private' : 'Make Public',
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openPublicProfileRoute(context, _post.author),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: (_post.author?.avatarUrl != null &&
                            _post.author!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(_post.author!.avatarUrl!)
                        : null,
                    child: (_post.author?.avatarUrl == null ||
                            _post.author!.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openPublicProfileRoute(context, _post.author),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post.author?.displayName ?? 'Unknown creator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _post.author?.username?.isNotEmpty == true
                              ? '@${_post.author!.username}'
                              : 'Creator',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_mine)
                  FilledButton.tonal(
                    onPressed: _toggleFollow,
                    child: Text(_post.isFollowingAuthor ? 'Following' : 'Follow'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _engagementButton(
                  icon: _post.myReaction == 1
                      ? Icons.thumb_up_alt
                      : Icons.thumb_up_alt_outlined,
                  active: _post.myReaction == 1,
                  activeColor: cs.primary,
                  label: _friendlyCount(_post.likesCount),
                  onTap: () => _toggleReaction(1),
                ),
                _engagementButton(
                  icon: _post.myReaction == -1
                      ? Icons.thumb_down_alt
                      : Icons.thumb_down_alt_outlined,
                  active: _post.myReaction == -1,
                  activeColor: Colors.redAccent,
                  label: _friendlyCount(_post.dislikesCount),
                  onTap: () => _toggleReaction(-1),
                ),
                _engagementButton(
                  icon: Icons.mode_comment_outlined,
                  active: _commentsOpen,
                  activeColor: cs.primary,
                  label: _friendlyCount(_post.commentsCount),
                  onTap: () => setState(() => _commentsOpen = true),
                ),
                _engagementButton(
                  icon: Icons.send_outlined,
                  active: false,
                  activeColor: cs.primary,
                  label: '',
                  onTap: _openShareSheet,
                ),
                _engagementButton(
                  icon: _post.isWatchLater
                      ? Icons.watch_later
                      : Icons.watch_later_outlined,
                  active: _post.isWatchLater,
                  activeColor: Colors.tealAccent,
                  label: '',
                  onTap: _toggleWatchLater,
                ),
                _engagementButton(
                  icon: _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  active: _post.isSaved,
                  activeColor: Colors.amberAccent,
                  label: _friendlyCount(_post.savesCount),
                  onTap: _toggleSave,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _descriptionExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _post.preset.description.trim().isNotEmpty
                          ? _post.preset.description
                          : 'No description provided.',
                      maxLines: _descriptionExpanded ? null : 2,
                      overflow: _descriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestionFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _suggestionFilters[index];
                  final selected = filter == _suggestionFilter;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_displayFilterName(filter)),
                    selectedColor: cs.primary.withValues(alpha: 0.22),
                    side: BorderSide(color: Colors.white24),
                    onSelected: (_) => setState(() => _suggestionFilter = filter),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _commentsOpen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Comments',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close comments',
                              onPressed: () => setState(() => _commentsOpen = false),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white70, size: 18),
                            ),
                          ],
                        ),
                        Expanded(
                          child: _loadingComments
                              ? const _TopEdgeLoadingPane(
                                  label: 'Loading comments...',
                                  backgroundColor: Colors.transparent,
                                  minHeight: 2,
                                )
                              : _comments.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No comments yet',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.68),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _comments.length,
                                      itemBuilder: (context, index) {
                                        final c = _comments[index];
                                        return Padding(
                                          padding:
                                              const EdgeInsets.symmetric(vertical: 6),
                                          child: RichText(
                                            text: TextSpan(
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.78),
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${c.author?.displayName ?? 'User'}: ',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(text: c.content),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment...',
                                  filled: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _sendingComment ? null : _sendComment,
                              child: Text(_sendingComment ? '...' : 'Send'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : _loadingSuggestions
                      ? const _TopEdgeLoadingPane(
                          label: 'Loading suggestions...',
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        )
                      : ListView.separated(
                          itemCount: suggestions.length.clamp(0, 24),
                          separatorBuilder: (_, __) => const Divider(
                            color: Colors.white24,
                            height: 14,
                          ),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return InkWell(
                              onTap: () => _openSuggestedPost(item),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 140,
                                    height: 78,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: IgnorePointer(
                                        child: _GridPresetPreview(
                                          mode: item.preset.thumbnailMode ??
                                              item.preset.mode,
                                          payload:
                                              item.preset.thumbnailPayload.isNotEmpty
                                                  ? item.preset.thumbnailPayload
                                                  : item.preset.payload,
                                          pointerPassthrough: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.preset.title.isNotEmpty
                                              ? item.preset.title
                                              : item.preset.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.author?.displayName ??
                                              'Unknown creator',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${_friendlyCount(item.viewsCount)} views · ${_friendlyTime(item.preset.createdAt)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.62),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        autofocus: true,
        focusNode: _immersiveFocusNode,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.keyF ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            _toggleImmersive();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: buildBackdrop()),
            Positioned(top: 0, left: 0, right: 0, child: buildHeader()),
            Positioned.fill(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                padding: _immersive
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(14, 66, 14, 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _immersive
                      ? GestureDetector(
                          key: const ValueKey<String>('immersive-post-detail'),
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: _toggleImmersive,
                          child: Stack(
                            children: [
                              Positioned.fill(child: viewer),
                              Positioned(
                                top: 14,
                                left: 14,
                                child: IconButton.filledTonal(
                                  onPressed: _toggleImmersive,
                                  icon: const Icon(Icons.fullscreen_exit),
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          key: const ValueKey<String>('compact-post-detail'),
                          builder: (context, constraints) {
                            final bool narrow = constraints.maxWidth < 1140;
                            final Widget previewCard = GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _commentsOpen
                                  ? () => setState(() => _commentsOpen = false)
                                  : null,
                              onDoubleTap: _toggleImmersive,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: viewer,
                                ),
                              ),
                            );
                            final Widget metaPanel =
                                buildDetailMetaPanel(constraints.maxWidth);
                            if (narrow) {
                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    previewCard,
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 640,
                                      child: metaPanel,
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [previewCard],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(width: 420, child: metaPanel),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _engagementButton({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: active ? 1.08 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? activeColor : Colors.white,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostStudioTab extends StatefulWidget {
  const _PostStudioTab({required this.topInset});

  final double topInset;

  @override
  State<_PostStudioTab> createState() => _PostStudioTabState();
}

class _PostStudioTabState extends State<_PostStudioTab> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _collectionNameController =
      TextEditingController(text: 'My Collection');

  int _modeIndex = 0;
  int _postTypeIndex = 0; // 0 single, 1 collection
  String? _collectionId;
  int _editorSeed = 0;
  int _selectedItemIndex = -1;
  bool _publishing = false;
  bool _openingComposer = false;
  bool _studioUploadingImage = false;
  bool _studioChromeVisible = true;
  bool _editorFullscreen = false;
  int _studioReanchorToken = 0;
  Timer? _studioChromeTimer;
  Map<String, dynamic>? _studioLivePayload;
  String? _studioSelected2dLayerKey;
  String? _studioSelected3dToken;
  final List<CollectionDraftItem> _draftItems = <CollectionDraftItem>[];

  @override
  void initState() {
    super.initState();
    _wakeStudioChrome();
  }

  @override
  void dispose() {
    debugPrint('Disposing PostStudioTab');
    _collectionNameController.dispose();
    _studioChromeTimer?.cancel();
    super.dispose();
  }

  void _wakeStudioChrome() {
    _studioChromeTimer?.cancel();
    if (!_studioChromeVisible && mounted) {
      setState(() => _studioChromeVisible = true);
    }
    _studioChromeTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _studioChromeVisible = false);
    });
  }

  void _onStudioLivePayloadChanged(Map<String, dynamic> payload) {
    if (!mounted) return;
    final Map<String, dynamic> next = _cloneMap(payload);
    setState(() {
      _studioLivePayload = next;
      if (_postTypeIndex == 1 &&
          _selectedItemIndex >= 0 &&
          _selectedItemIndex < _draftItems.length) {
        final item = _draftItems[_selectedItemIndex];
        _draftItems[_selectedItemIndex] = CollectionDraftItem(
          mode: _modeIndex == 0 ? '2d' : '3d',
          name: item.name,
          snapshot: _cloneMap(next),
        );
      }
    });
  }

  void _saveCurrentStudioItemToCollection() {
    final messenger = ScaffoldMessenger.of(context);
    final payload = _studioLivePayload;
    if (payload == null || payload.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No editor state to save yet.')),
      );
      return;
    }
    final mode = _modeIndex == 0 ? '2d' : '3d';
    setState(() {
      if (_selectedItemIndex >= 0 && _selectedItemIndex < _draftItems.length) {
        final current = _draftItems[_selectedItemIndex];
        _draftItems[_selectedItemIndex] = CollectionDraftItem(
          mode: mode,
          name: current.name,
          snapshot: payload,
        );
      } else {
        final itemName = '${mode.toUpperCase()} Item ${_draftItems.length + 1}';
        _draftItems.add(CollectionDraftItem(
          mode: mode,
          name: itemName,
          snapshot: payload,
        ));
        _selectedItemIndex = _draftItems.length - 1;
      }
    });
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Editor snapshot saved to collection item.')),
    );
  }

  Future<void> _openStudioSingleComposer() async {
    final payload = _studioLivePayload;
    if (payload == null || payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No editor state to compose yet.')),
      );
      return;
    }
    final now = DateTime.now();
    final generatedName =
        'Preset ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _openSingleComposer(
      name: generatedName,
      payload: payload,
    );
  }

  void _onPresetSaved(String name, Map<String, dynamic> payload) {
    if (_postTypeIndex == 0) {
      unawaited(_openSingleComposer(name: name, payload: payload));
      return;
    }
    final item = CollectionDraftItem(
      mode: _modeIndex == 0 ? '2d' : '3d',
      name: name,
      snapshot: payload,
    );

    setState(() {
      if (_selectedItemIndex >= 0 && _selectedItemIndex < _draftItems.length) {
        _draftItems[_selectedItemIndex] = item;
      } else {
        _draftItems.add(item);
        _selectedItemIndex = _draftItems.length - 1;
      }
    });
  }

  void _selectCollectionItem(int index) {
    if (index < 0 || index >= _draftItems.length) return;
    final item = _draftItems[index];
    setState(() {
      _selectedItemIndex = index;
      _modeIndex = item.mode == '2d' ? 0 : 1;
      _studioLivePayload = item.snapshot;
      _editorSeed++;
    });
  }

  void _removeCollectionItem(int index) {
    setState(() {
      _draftItems.removeAt(index);
      if (_selectedItemIndex >= _draftItems.length) {
        _selectedItemIndex = _draftItems.length - 1;
      }
      if (_selectedItemIndex >= 0 && _selectedItemIndex < _draftItems.length) {
        _studioLivePayload = _draftItems[_selectedItemIndex].snapshot;
      } else {
        _studioLivePayload = null;
      }
      _editorSeed++;
    });
  }

  void _duplicateCollectionItem(int index) {
    if (index < 0 || index >= _draftItems.length) return;
    final source = _draftItems[index];
    setState(() {
      _draftItems.insert(
        index + 1,
        CollectionDraftItem(
          mode: source.mode,
          name: '${source.name} Copy',
          snapshot: Map<String, dynamic>.from(source.snapshot),
        ),
      );
      _selectedItemIndex = index + 1;
      _studioLivePayload = _draftItems[_selectedItemIndex].snapshot;
      _editorSeed++;
    });
  }

  void _createNewCollectionItem() {
    setState(() {
      _selectedItemIndex = -1;
      _studioLivePayload = null;
      _editorSeed++;
    });
  }

  Future<void> _publishCollection() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_draftItems.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add at least one preset to publish.')),
      );
      return;
    }
    if (_openingComposer) return;
    setState(() {
      _openingComposer = true;
      _publishing = true;
    });
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PostCardComposerPage.collection(
          collectionId: _collectionId,
          collectionName: _collectionNameController.text.trim(),
          collectionDescription: '',
          tags: const <String>[],
          mentionUserIds: const <String>[],
          published: true,
          items: List<CollectionDraftItem>.from(_draftItems),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _openingComposer = false;
        _publishing = false;
      });
    }
    if (result == true && mounted) {
      await _resetEditorDraftState();
      if (!mounted) return;
      setState(() {
        _collectionId = null;
        _selectedItemIndex = -1;
        _draftItems.clear();
        _studioLivePayload = null;
        _editorSeed++;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Collection published successfully.')),
      );
    }
  }

  Future<void> _openSingleComposer({
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_openingComposer) return;
    setState(() {
      _openingComposer = true;
      _publishing = true;
    });
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PostCardComposerPage.single(
          name: name,
          mode: _modeIndex == 0 ? '2d' : '3d',
          payload: payload,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _openingComposer = false;
        _publishing = false;
      });
    }
    if (result == true && mounted) {
      await _resetEditorDraftState();
      if (!mounted) return;
      setState(() {
        _selectedItemIndex = -1;
        _studioLivePayload = null;
        _editorSeed++;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Post published successfully.')),
      );
    }
  }

  Future<void> _previewCollection() async {
    if (_draftItems.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CollectionPreviewPage(items: List.from(_draftItems)),
      ),
    );
  }

  Future<void> _resetEditorDraftState() async {
    try {
      await _repository.upsertModeState(
        mode: '2d',
        state: <String, dynamic>{
          'layers': <String, dynamic>{},
          'controls': <String, dynamic>{},
          'selectedAspect': null,
        },
      );
      await _repository.upsertModeState(
        mode: '3d',
        state: <String, dynamic>{
          'scene': <String, dynamic>{},
          'controls': <String, dynamic>{},
        },
      );
    } catch (_) {}
  }

  Widget _buildEditor() {
    const bool persistPresets = false;
    final activeItem =
        (_selectedItemIndex >= 0 && _selectedItemIndex < _draftItems.length)
            ? _draftItems[_selectedItemIndex]
            : null;
    final livePayload = _studioLivePayload;

    if (_modeIndex == 0) {
      return LayerMode(
        key: ValueKey('studio-2d-$_editorSeed-${activeItem?.name ?? 'none'}'),
        embedded: true,
        embeddedStudio: true,
        useGlobalTracking: true,
        persistPresets: persistPresets,
        initialPresetPayload: _payloadMatchesMode(livePayload, '2d')
            ? livePayload
            : (activeItem?.mode == '2d' ? activeItem!.snapshot : null),
        onPresetSaved: _onPresetSaved,
        onLivePayloadChanged: _onStudioLivePayloadChanged,
        reanchorToken: _studioReanchorToken,
        studioSurface: true,
      );
    }
    return Engine3DPage(
      key: ValueKey('studio-3d-$_editorSeed-${activeItem?.name ?? 'none'}'),
      embedded: true,
      embeddedStudio: true,
      useGlobalTracking: true,
      persistPresets: persistPresets,
      initialPresetPayload: _payloadMatchesMode(livePayload, '3d')
          ? livePayload
          : (activeItem?.mode == '3d' ? activeItem!.snapshot : null),
      onPresetSaved: _onPresetSaved,
      onLivePayloadChanged: _onStudioLivePayloadChanged,
      reanchorToken: _studioReanchorToken,
      studioSurface: true,
    );
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Widget _studioSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final double clamped = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${clamped.toStringAsFixed(3)}'),
        Slider(
          value: clamped,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  bool _payloadMatchesMode(Map<String, dynamic>? payload, String mode) {
    if (payload == null) return false;
    final raw = payload['mode']?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return true;
    return raw == mode;
  }

  void _applyStudioPayload(Map<String, dynamic> payload,
      {bool remount = false}) {
    final mode = _modeIndex == 0 ? '2d' : '3d';
    setState(() {
      _studioLivePayload = _cloneMap(payload);
      if (_postTypeIndex == 1 &&
          _selectedItemIndex >= 0 &&
          _selectedItemIndex < _draftItems.length) {
        final item = _draftItems[_selectedItemIndex];
        _draftItems[_selectedItemIndex] = CollectionDraftItem(
          mode: mode,
          name: item.name,
          snapshot: _cloneMap(payload),
        );
      }
      if (remount) _editorSeed++;
    });
  }

  Map<String, dynamic> _studio2DScene() {
    final dynamic payload = _studioLivePayload;
    if (payload is! Map) return <String, dynamic>{};
    final dynamic raw = payload['scene'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<String> _studio2DLayerKeys() {
    final scene = _studio2DScene();
    final keys =
        scene.entries.where((e) => e.value is Map).map((e) => e.key).toList();
    keys.sort((a, b) {
      final aOrder = _toDouble((scene[a] as Map?)?['order'], 0);
      final bOrder = _toDouble((scene[b] as Map?)?['order'], 0);
      final int cmp = aOrder.compareTo(bOrder);
      if (cmp != 0) return cmp;
      if (a == 'turning_point' && b != 'turning_point') return 1;
      if (b == 'turning_point' && a != 'turning_point') return -1;
      return a.compareTo(b);
    });
    return keys;
  }

  void _ensureStudio2DSelection() {
    final keys = _studio2DLayerKeys();
    if (keys.isEmpty) {
      _studioSelected2dLayerKey = null;
      return;
    }
    if (_studioSelected2dLayerKey != null &&
        keys.contains(_studioSelected2dLayerKey)) {
      return;
    }
    _studioSelected2dLayerKey = keys.first;
  }

  String _studioLayerPrefixFromImageSource(String imageUrl) {
    final String trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return 'layer_';
    try {
      final Uri uri = Uri.parse(trimmed);
      String candidate = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : trimmed.split('/').last;
      if (candidate.isEmpty) return 'layer_';
      candidate = Uri.decodeComponent(candidate);
      candidate = candidate.split('?').first.split('#').first;
      final int dot = candidate.lastIndexOf('.');
      if (dot > 0) {
        candidate = candidate.substring(0, dot);
      }
      candidate = candidate.trim();
      if (candidate.isEmpty) return 'layer_';
      return '${candidate}_';
    } catch (_) {
      final String fallback = trimmed.split('/').last.split('?').first;
      if (fallback.isEmpty) return 'layer_';
      final int dot = fallback.lastIndexOf('.');
      final String raw =
          dot > 0 ? fallback.substring(0, dot).trim() : fallback.trim();
      return raw.isEmpty ? 'layer_' : '${raw}_';
    }
  }

  String _nextStudio2DLayerKey(String prefix, Map<String, dynamic> scene) {
    String sanitized = prefix.trim();
    if (sanitized.isEmpty) sanitized = 'layer_';
    sanitized = sanitized
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    if (!sanitized.endsWith('_')) {
      sanitized = '${sanitized}_';
    }
    int index = 1;
    while (scene.containsKey('$sanitized$index')) {
      index++;
    }
    return '$sanitized$index';
  }

  void _normalizeStudio2DOrder(Map<String, dynamic> scene) {
    final keys = scene.entries
        .where((e) => e.key != 'turning_point' && e.value is Map)
        .map((e) => e.key)
        .toList();
    keys.sort((a, b) {
      final aOrder = _toDouble((scene[a] as Map?)?['order'], 0);
      final bOrder = _toDouble((scene[b] as Map?)?['order'], 0);
      return aOrder.compareTo(bOrder);
    });
    for (int i = 0; i < keys.length; i++) {
      final raw = scene[keys[i]];
      if (raw is! Map) continue;
      scene[keys[i]] = Map<String, dynamic>.from(raw)..['order'] = i;
    }
  }

  bool _isStudioUtilityLayerKey(String? key) {
    if (key == null) return false;
    return key == 'turning_point' ||
        key == 'top_bezel' ||
        key == 'bottom_bezel';
  }

  void _studioReorder2DLayer(int oldIndex, int newIndex) {
    final scene = _studio2DScene();
    final keys = _studio2DLayerKeys();
    if (oldIndex < 0 || oldIndex >= keys.length) return;
    if (newIndex < 0 || newIndex > keys.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (keys.isEmpty) return;
    newIndex = newIndex.clamp(0, keys.length - 1);
    final moved = keys.removeAt(oldIndex);
    keys.insert(newIndex, moved);
    for (int i = 0; i < keys.length; i++) {
      final raw = scene[keys[i]];
      if (raw is! Map) continue;
      scene[keys[i]] = Map<String, dynamic>.from(raw)..['order'] = i;
    }
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    payload['scene'] = scene;
    _studioSelected2dLayerKey = moved;
    _applyStudioPayload(payload);
  }

  void _studioAdd2DLayer(
    bool textLayer, {
    String imageUrl = '',
    String sourceName = '',
  }) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio2DScene();
    if (!scene.containsKey('turning_point')) {
      scene['turning_point'] = <String, dynamic>{
        'x': 0.0,
        'y': 0.0,
        'scale': 1.0,
        'order': 0.0,
        'isVisible': false,
        'isLocked': true,
        'isText': false,
        'canShift': false,
        'canZoom': false,
        'canTilt': false,
        'minScale': 0.1,
        'maxScale': 5.0,
        'minX': -3000.0,
        'maxX': 3000.0,
        'minY': -3000.0,
        'maxY': 3000.0,
        'shiftSensMult': 1.0,
        'zoomSensMult': 1.0,
        'url': '',
      };
    }
    _normalizeStudio2DOrder(scene);
    final String inferredSource =
        sourceName.trim().isNotEmpty ? sourceName.trim() : imageUrl;
    final String prefix =
        textLayer ? 'text_' : _studioLayerPrefixFromImageSource(inferredSource);
    final key = _nextStudio2DLayerKey(prefix, scene);
    scene[key] = <String, dynamic>{
      'x': 0.0,
      'y': 0.0,
      'scale': 1.0,
      'order': _studio2DLayerKeys().length,
      'isVisible': true,
      'isLocked': false,
      'isText': textLayer,
      'canShift': true,
      'canZoom': true,
      'canTilt': true,
      'minScale': 0.1,
      'maxScale': 5.0,
      if (textLayer) ...{
        'textValue': 'New Text',
        'fontSize': 40.0,
        'fontFamily': 'Poppins',
      } else ...{
        'url': imageUrl,
      },
    };
    payload['scene'] = scene;
    _studioSelected2dLayerKey = key;
    _applyStudioPayload(payload);
  }

  void _studioDuplicate2DLayer() {
    final key = _studioSelected2dLayerKey;
    if (key == null || _isStudioUtilityLayerKey(key)) return;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    _normalizeStudio2DOrder(scene);
    final copyKey = _nextStudio2DLayerKey('${key}_copy_', scene);
    final copy = _cloneMap(Map<String, dynamic>.from(raw));
    copy['order'] = _studio2DLayerKeys().length;
    scene[copyKey] = copy;
    payload['scene'] = scene;
    _studioSelected2dLayerKey = copyKey;
    _applyStudioPayload(payload);
  }

  void _studioDelete2DLayer() {
    final key = _studioSelected2dLayerKey;
    if (key == null || _isStudioUtilityLayerKey(key)) return;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio2DScene();
    scene.remove(key);
    _normalizeStudio2DOrder(scene);
    payload['scene'] = scene;
    final remaining = scene.entries
        .where((e) => e.key != 'turning_point' && e.value is Map)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) {
        final aOrder = _toDouble((scene[a] as Map?)?['order'], 0);
        final bOrder = _toDouble((scene[b] as Map?)?['order'], 0);
        return aOrder.compareTo(bOrder);
      });
    _studioSelected2dLayerKey = remaining.isEmpty ? null : remaining.first;
    _applyStudioPayload(payload);
  }

  void _studioSet2DLayerField(String key, String field, dynamic value) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    scene[key] = Map<String, dynamic>.from(raw)..[field] = value;
    payload['scene'] = scene;
    _applyStudioPayload(payload);
  }

  Map<String, dynamic> _studio2DControls() {
    final dynamic payload = _studioLivePayload;
    if (payload is! Map) return <String, dynamic>{};
    final dynamic raw = payload['controls'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  void _studioSet2DControlField(String field, dynamic value) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final controls = _studio2DControls();
    controls[field] = value;
    payload['controls'] = controls;
    _applyStudioPayload(payload);
  }

  void _studioRecenter2DParallax() {
    final frame = TrackingService.instance.frameNotifier.value;
    final controls = _studio2DControls();
    controls['anchorHeadX'] = frame.headX;
    controls['anchorHeadY'] = frame.headY;
    controls['zBase'] = frame.headZ.abs() < 0.000001
        ? _toDouble(controls['zBase'], 0.2)
        : frame.headZ;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    payload['controls'] = controls;
    _applyStudioPayload(payload);
  }

  Future<void> _studioPromptAddImageUrl() async {
    final TextEditingController controller = TextEditingController();
    final String? url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.png',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) return;
    _studioAdd2DLayer(false, imageUrl: url.trim());
  }

  Future<void> _studioUpload2DImage() async {
    if (_studioUploadingImage) return;
    setState(() => _studioUploadingImage = true);
    try {
      final picked = await pickDeviceFile(accept: 'image/*');
      if (picked == null) return;
      final String publicUrl = await _repository.uploadAssetBytes(
        bytes: picked.bytes,
        fileName: picked.name,
        contentType: picked.contentType,
        folder: 'studio-layers',
      );
      if (!mounted) return;
      _studioAdd2DLayer(
        false,
        imageUrl: publicUrl,
        sourceName: picked.name,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded to studio layer.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _studioUploadingImage = false);
      }
    }
  }

  Map<String, dynamic> _studio3DScene() {
    final dynamic payload = _studioLivePayload;
    if (payload is! Map) return <String, dynamic>{};
    final dynamic raw = payload['scene'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<String> _studioSceneTokens(Map<String, dynamic> scene) {
    final List<String> tokens = <String>[];
    final models = scene['models'];
    if (models is List) {
      for (final item in models.whereType<Map>()) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) tokens.add('model:$id');
      }
    }
    final lights = scene['lights'];
    if (lights is List) {
      for (final item in lights.whereType<Map>()) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) tokens.add('light:$id');
      }
    }
    final audios = scene['audios'];
    if (audios is List) {
      for (final item in audios.whereType<Map>()) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) tokens.add('audio:$id');
      }
    }
    return tokens;
  }

  List<String> _studioOrdered3DTokens() {
    final scene = _studio3DScene();
    final available = _studioSceneTokens(scene);
    final rawOrder = scene['renderOrder'];
    final ordered = rawOrder is List
        ? rawOrder.map((e) => e.toString()).where(available.contains).toList()
        : <String>[];
    for (final token in available) {
      if (!ordered.contains(token)) ordered.add(token);
    }
    return ordered;
  }

  void _studioReorder3DEntity(int oldIndex, int newIndex) {
    final order = _studioOrdered3DTokens();
    if (oldIndex < 0 || oldIndex >= order.length) return;
    if (newIndex < 0 || newIndex > order.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (order.isEmpty) return;
    newIndex = newIndex.clamp(0, order.length - 1);
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene()..['renderOrder'] = order;
    payload['scene'] = scene;
    _studioSelected3dToken = moved;
    _applyStudioPayload(payload);
  }

  List<Map<String, dynamic>> _studioEntityListForType(
    Map<String, dynamic> scene,
    String type,
  ) {
    final key = type == 'model'
        ? 'models'
        : type == 'light'
            ? 'lights'
            : 'audios';
    final raw = scene[key];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .map((e) =>
            e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }

  void _studioSetEntityListForType(
    Map<String, dynamic> scene,
    String type,
    List<Map<String, dynamic>> list,
  ) {
    final key = type == 'model'
        ? 'models'
        : type == 'light'
            ? 'lights'
            : 'audios';
    scene[key] = list;
  }

  String _studioNextEntityId(Map<String, dynamic> scene, String type) {
    final list = _studioEntityListForType(scene, type);
    int index = 1;
    while (list.any((e) => (e['id'] ?? '').toString() == '${type}_$index')) {
      index++;
    }
    return '${type}_$index';
  }

  void _studioAdd3DEntity(String type) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    final list = _studioEntityListForType(scene, type);
    final id = _studioNextEntityId(scene, type);
    if (type == 'model') {
      list.add(<String, dynamic>{
        'id': id,
        'name': 'Model $id',
        'url': '',
        'position': <double>[0, 0, 0],
        'rotation': <double>[0, 0, 0],
        'scale': <double>[1, 1, 1],
        'visible': true,
        'windowLayer': 'inside',
      });
    } else if (type == 'light') {
      list.add(<String, dynamic>{
        'id': id,
        'color': 'ffffff',
        'intensity': 10,
        'position': <double>[0, 5, 0],
        'scale': 1,
        'ghost': false,
        'windowLayer': 'inside',
      });
    } else {
      list.add(<String, dynamic>{
        'id': id,
        'url': '',
        'volume': 1,
        'position': <double>[0, 0, 0],
        'ghost': false,
        'windowLayer': 'inside',
      });
    }
    _studioSetEntityListForType(scene, type, list);
    final order = _studioOrdered3DTokens()..add('$type:$id');
    scene['renderOrder'] = order.toSet().toList();
    scene.putIfAbsent('sunIntensity', () => 2.0);
    scene.putIfAbsent('ambLight', () => 0.5);
    scene.putIfAbsent('bloomIntensity', () => 1.0);
    scene.putIfAbsent('shadowQuality', () => '512');
    scene.putIfAbsent('shadowSoftness', () => 1.0);
    scene.putIfAbsent('envRot', () => 0.0);
    scene.putIfAbsent('initPos', () => <double>[0, 2, 10]);
    scene.putIfAbsent('initRot', () => <double>[0, 0, 0]);
    payload['scene'] = scene;
    _studioSelected3dToken = '$type:$id';
    _applyStudioPayload(payload);
  }

  void _studioDuplicate3DEntity(String token) {
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    final list = _studioEntityListForType(scene, type);
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    final copy = _cloneMap(list[index]);
    final newId = _studioNextEntityId(scene, type);
    copy['id'] = newId;
    list.insert(index + 1, copy);
    _studioSetEntityListForType(scene, type, list);
    final order = _studioOrdered3DTokens();
    final orderIndex = order.indexOf(token);
    if (orderIndex >= 0) {
      order.insert(orderIndex + 1, '$type:$newId');
    } else {
      order.add('$type:$newId');
    }
    scene['renderOrder'] = order;
    payload['scene'] = scene;
    _studioSelected3dToken = '$type:$newId';
    _applyStudioPayload(payload);
  }

  void _studioDelete3DEntity(String token) {
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    final list = _studioEntityListForType(scene, type)
      ..removeWhere((e) => (e['id'] ?? '').toString() == id);
    _studioSetEntityListForType(scene, type, list);
    final order = _studioOrdered3DTokens()..remove(token);
    scene['renderOrder'] = order;
    payload['scene'] = scene;
    if (_studioSelected3dToken == token) {
      _studioSelected3dToken = order.isEmpty ? null : order.first;
    }
    _applyStudioPayload(payload);
  }

  void _studioSet3DWindowLayer(String token, String layer) {
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    final list = _studioEntityListForType(scene, type);
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    list[index] = Map<String, dynamic>.from(list[index])
      ..['windowLayer'] = layer;
    _studioSetEntityListForType(scene, type, list);
    payload['scene'] = scene;
    _applyStudioPayload(payload);
  }

  Map<String, dynamic> _studio3DControls() {
    final dynamic payload = _studioLivePayload;
    if (payload is! Map) return <String, dynamic>{};
    final dynamic raw = payload['controls'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  void _studioSet3DControlField(String field, dynamic value) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final controls = _studio3DControls();
    controls[field] = value;
    payload['controls'] = controls;
    _applyStudioPayload(payload);
  }

  void _studioSet3DSceneField(String field, dynamic value) {
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    scene[field] = value;
    payload['scene'] = scene;
    _applyStudioPayload(payload);
  }

  void _studioSet3DEntityField({
    required String token,
    required String field,
    required dynamic value,
  }) {
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final payload = _cloneMap(_studioLivePayload ?? <String, dynamic>{});
    final scene = _studio3DScene();
    final list = _studioEntityListForType(scene, type);
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    list[index] = Map<String, dynamic>.from(list[index])..[field] = value;
    _studioSetEntityListForType(scene, type, list);
    payload['scene'] = scene;
    _applyStudioPayload(payload);
  }

  double _studioVectorComponent(dynamic raw, int index, double fallback) {
    if (raw is List && index >= 0 && index < raw.length) {
      return _toDouble(raw[index], fallback);
    }
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  void _studioSet3DEntityVectorComponent({
    required String token,
    required String field,
    required int index,
    required double value,
  }) {
    final scene = _studio3DScene();
    final entity = _studioEntityByToken(scene, token);
    if (entity == null) return;
    final dynamic raw = entity[field];
    final List<double> next = <double>[0, 0, 0];
    if (raw is List) {
      for (int i = 0; i < raw.length && i < next.length; i++) {
        next[i] = _toDouble(raw[i], 0);
      }
    } else if (field == 'scale' && raw is num) {
      final double uniform = raw.toDouble();
      for (int i = 0; i < next.length; i++) {
        next[i] = uniform;
      }
    }
    if (index >= 0 && index < next.length) {
      next[index] = value;
    }
    _studioSet3DEntityField(
      token: token,
      field: field,
      value: next,
    );
  }

  void _studioSet3DSceneVectorComponent({
    required String field,
    required int index,
    required double value,
    List<double> fallback = const <double>[0, 0, 0],
  }) {
    final scene = _studio3DScene();
    final dynamic raw = scene[field];
    final List<double> next = <double>[
      fallback.length > 0 ? fallback[0] : 0,
      fallback.length > 1 ? fallback[1] : 0,
      fallback.length > 2 ? fallback[2] : 0,
    ];
    if (raw is List) {
      for (int i = 0; i < raw.length && i < next.length; i++) {
        next[i] = _toDouble(raw[i], next[i]);
      }
    }
    if (index >= 0 && index < next.length) {
      next[index] = value;
    }
    _studioSet3DSceneField(field, next);
  }

  Map<String, dynamic>? _studioEntityByToken(
    Map<String, dynamic> scene,
    String token,
  ) {
    final parts = token.split(':');
    if (parts.length != 2) return null;
    final type = parts.first;
    final id = parts.last;
    final list = _studioEntityListForType(scene, type);
    for (final item in list) {
      if ((item['id'] ?? '').toString() == id) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  String _studioEntityLabel(String token, Map<String, dynamic> scene) {
    final parts = token.split(':');
    if (parts.length != 2) return token;
    final String type = parts.first;
    final String id = parts.last;
    final Map<String, dynamic>? entity = _studioEntityByToken(scene, token);
    final String named =
        (entity?['name'] ?? entity?['id'] ?? '').toString().trim();
    if (named.isNotEmpty) return named;
    final String fallback = type == 'model'
        ? 'Model'
        : type == 'light'
            ? 'Light'
            : 'Audio';
    return '$fallback $id';
  }

  Widget _buildStudioControlsPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_modeIndex == 0) {
      final keys = _studio2DLayerKeys();
      final controls = _studio2DControls();
      final scene = _studio2DScene();
      final dynamic selectedLayerRaw = _studioSelected2dLayerKey == null
          ? null
          : scene[_studioSelected2dLayerKey!];
      final Map<String, dynamic>? selectedLayer = selectedLayerRaw is Map
          ? Map<String, dynamic>.from(selectedLayerRaw)
          : null;
      final dynamic turningRaw = scene['turning_point'];
      final Map<String, dynamic> turningPoint = turningRaw is Map
          ? Map<String, dynamic>.from(turningRaw)
          : <String, dynamic>{};
      _ensureStudio2DSelection();
      return Container(
        color: cs.surface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('2D Layers',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _studioPromptAddImageUrl,
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text('Image URL'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _studioUploadingImage ? null : _studioUpload2DImage,
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label:
                      Text(_studioUploadingImage ? 'Uploading...' : 'Upload'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _studioAdd2DLayer(true),
                  icon: const Icon(Icons.text_fields, size: 16),
                  label: const Text('Text'),
                ),
                OutlinedButton.icon(
                  onPressed: (_studioSelected2dLayerKey == null ||
                          _isStudioUtilityLayerKey(_studioSelected2dLayerKey))
                      ? null
                      : _studioDuplicate2DLayer,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: (_studioSelected2dLayerKey == null ||
                          _isStudioUtilityLayerKey(_studioSelected2dLayerKey))
                      ? null
                      : _studioDelete2DLayer,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (keys.isEmpty)
              const SizedBox(
                height: 120,
                child: Center(child: Text('No layers')),
              )
            else
              SizedBox(
                height: 180,
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: keys.length,
                  onReorder: _studioReorder2DLayer,
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final scene = _studio2DScene();
                    final layer = scene[key];
                    final visible =
                        !(layer is Map && layer['isVisible'] == false);
                    final locked = layer is Map && layer['isLocked'] == true;
                    return ListTile(
                      key: ValueKey<String>('studio-2d-$key'),
                      selected: _studioSelected2dLayerKey == key,
                      selectedTileColor: cs.primary.withValues(alpha: 0.16),
                      title: Text(key,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(locked ? 'Locked' : 'Unlocked'),
                      trailing: SizedBox(
                        width: 132,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () => _studioSet2DLayerField(
                                key,
                                'isVisible',
                                !visible,
                              ),
                              icon: Icon(
                                visible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _studioSet2DLayerField(
                                key,
                                'isLocked',
                                !locked,
                              ),
                              icon: Icon(
                                locked ? Icons.lock_outline : Icons.lock_open,
                                size: 18,
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.drag_handle, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () =>
                          setState(() => _studioSelected2dLayerKey = key),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedLayer != null) ...[
                      Text(
                        'Layer: ${_studioSelected2dLayerKey ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (selectedLayer['isText'] == true)
                        TextFormField(
                          initialValue:
                              (selectedLayer['textValue'] ?? '').toString(),
                          onChanged: (value) => _studioSet2DLayerField(
                            _studioSelected2dLayerKey!,
                            'textValue',
                            value,
                          ),
                          decoration: const InputDecoration(labelText: 'Text'),
                        )
                      else
                        TextFormField(
                          initialValue: (selectedLayer['url'] ?? '').toString(),
                          onChanged: (value) => _studioSet2DLayerField(
                            _studioSelected2dLayerKey!,
                            'url',
                            value.trim(),
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Image URL'),
                        ),
                      _studioSlider(
                        label: 'X',
                        min: -1500,
                        max: 1500,
                        value: _toDouble(selectedLayer['x'], 0),
                        onChanged: (v) => _studioSet2DLayerField(
                          _studioSelected2dLayerKey!,
                          'x',
                          v,
                        ),
                      ),
                      _studioSlider(
                        label: 'Y',
                        min: -1500,
                        max: 1500,
                        value: _toDouble(selectedLayer['y'], 0),
                        onChanged: (v) => _studioSet2DLayerField(
                          _studioSelected2dLayerKey!,
                          'y',
                          v,
                        ),
                      ),
                      _studioSlider(
                        label: 'Scale',
                        min: 0.05,
                        max: 6,
                        value: _toDouble(selectedLayer['scale'], 1),
                        onChanged: (v) => _studioSet2DLayerField(
                          _studioSelected2dLayerKey!,
                          'scale',
                          v,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      '2D Controls',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _studioSlider(
                      label: 'Global Scale',
                      min: 0.5,
                      max: 2.5,
                      value: _toDouble(controls['scale'], 1.2),
                      onChanged: (v) => _studioSet2DControlField('scale', v),
                    ),
                    _studioSlider(
                      label: 'Global Depth',
                      min: 0,
                      max: 1,
                      value: _toDouble(controls['depth'], 0.1),
                      onChanged: (v) => _studioSet2DControlField('depth', v),
                    ),
                    _studioSlider(
                      label: 'Global Shift',
                      min: 0,
                      max: 1,
                      value: _toDouble(controls['shift'], 0.025),
                      onChanged: (v) => _studioSet2DControlField('shift', v),
                    ),
                    _studioSlider(
                      label: 'Global Tilt',
                      min: 0,
                      max: 1,
                      value: _toDouble(controls['tilt'], 0),
                      onChanged: (v) => _studioSet2DControlField('tilt', v),
                    ),
                    _studioSlider(
                      label: 'Dead Zone X',
                      min: 0,
                      max: 0.1,
                      value: _toDouble(controls['deadZoneX'], 0),
                      onChanged: (v) =>
                          _studioSet2DControlField('deadZoneX', v),
                    ),
                    _studioSlider(
                      label: 'Dead Zone Y',
                      min: 0,
                      max: 0.1,
                      value: _toDouble(controls['deadZoneY'], 0),
                      onChanged: (v) =>
                          _studioSet2DControlField('deadZoneY', v),
                    ),
                    _studioSlider(
                      label: 'Dead Zone Z',
                      min: 0,
                      max: 0.1,
                      value: _toDouble(controls['deadZoneZ'], 0),
                      onChanged: (v) =>
                          _studioSet2DControlField('deadZoneZ', v),
                    ),
                    _studioSlider(
                      label: 'Dead Zone Yaw',
                      min: 0,
                      max: 10,
                      value: _toDouble(controls['deadZoneYaw'], 0),
                      onChanged: (v) =>
                          _studioSet2DControlField('deadZoneYaw', v),
                    ),
                    _studioSlider(
                      label: 'Dead Zone Pitch',
                      min: 0,
                      max: 10,
                      value: _toDouble(controls['deadZonePitch'], 0),
                      onChanged: (v) =>
                          _studioSet2DControlField('deadZonePitch', v),
                    ),
                    _studioSlider(
                      label: 'Z Base',
                      min: 0.05,
                      max: 2.0,
                      value: _toDouble(controls['zBase'], 0.2),
                      onChanged: (v) => _studioSet2DControlField('zBase', v),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Manual Mode'),
                      value: controls['manualMode'] == true,
                      onChanged: (v) =>
                          _studioSet2DControlField('manualMode', v),
                    ),
                    if (controls['manualMode'] == true) ...[
                      _studioSlider(
                        label: 'Manual Head X',
                        min: -1,
                        max: 1,
                        value: _toDouble(controls['manualHeadX'], 0),
                        onChanged: (v) =>
                            _studioSet2DControlField('manualHeadX', v),
                      ),
                      _studioSlider(
                        label: 'Manual Head Y',
                        min: -1,
                        max: 1,
                        value: _toDouble(controls['manualHeadY'], 0),
                        onChanged: (v) =>
                            _studioSet2DControlField('manualHeadY', v),
                      ),
                      _studioSlider(
                        label: 'Manual Head Z',
                        min: 0.05,
                        max: 2.0,
                        value: _toDouble(controls['manualHeadZ'], 0.2),
                        onChanged: (v) =>
                            _studioSet2DControlField('manualHeadZ', v),
                      ),
                      _studioSlider(
                        label: 'Manual Yaw',
                        min: -60,
                        max: 60,
                        value: _toDouble(controls['manualYaw'], 0),
                        onChanged: (v) =>
                            _studioSet2DControlField('manualYaw', v),
                      ),
                      _studioSlider(
                        label: 'Manual Pitch',
                        min: -40,
                        max: 40,
                        value: _toDouble(controls['manualPitch'], 0),
                        onChanged: (v) =>
                            _studioSet2DControlField('manualPitch', v),
                      ),
                    ],
                    DropdownButtonFormField<String>(
                      value: (() {
                        final String selectedAspect =
                            (controls['selectedAspect'] ?? '').toString();
                        const options = <String>[
                          '16:9 (width:height)',
                          '18:9 (width:height)',
                          '21:9 (width:height)',
                          '4:3 (width:height)',
                          '1:1 (square)',
                          '9:16 (height:width)',
                          '3:4 (height:width)',
                          '2.35:1 (width:height)',
                          '1.85:1 (width:height)',
                          '2.39:1 (width:height)',
                        ];
                        return options.contains(selectedAspect)
                            ? selectedAspect
                            : null;
                      })(),
                      items: const <String>[
                        '16:9 (width:height)',
                        '18:9 (width:height)',
                        '21:9 (width:height)',
                        '4:3 (width:height)',
                        '1:1 (square)',
                        '9:16 (height:width)',
                        '3:4 (height:width)',
                        '2.35:1 (width:height)',
                        '1.85:1 (width:height)',
                        '2.39:1 (width:height)',
                      ]
                          .map((ratio) => DropdownMenuItem<String>(
                                value: ratio,
                                child: Text(ratio),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          _studioSet2DControlField('selectedAspect', value),
                      decoration:
                          const InputDecoration(labelText: 'Aspect Ratio'),
                    ),
                    _studioSlider(
                      label: 'Turning Point',
                      min: -200,
                      max: 200,
                      value: _toDouble(turningPoint['order'], 0),
                      onChanged: (v) => _studioSet2DLayerField(
                        'turning_point',
                        'order',
                        v,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _studioRecenter2DParallax,
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Recenter'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final scene = _studio3DScene();
    final tokens = _studioOrdered3DTokens();
    if (_studioSelected3dToken == null && tokens.isNotEmpty) {
      _studioSelected3dToken = tokens.first;
    }
    final controls = _studio3DControls();
    final String? selectedToken = _studioSelected3dToken != null &&
            tokens.contains(_studioSelected3dToken)
        ? _studioSelected3dToken
        : (tokens.isEmpty ? null : tokens.first);
    final Map<String, dynamic>? selectedEntity = selectedToken == null
        ? null
        : _studioEntityByToken(scene, selectedToken);
    final String selectedType = selectedToken?.split(':').first ?? '';

    bool asBool(dynamic value, [bool fallback = false]) {
      if (value is bool) return value;
      final String raw = value?.toString().toLowerCase() ?? '';
      if (raw == 'true') return true;
      if (raw == 'false') return false;
      return fallback;
    }

    final bool manualMode =
        asBool(controls['manual-mode']) || asBool(controls['manualMode']);
    final List<double> initPos = <double>[
      _studioVectorComponent(scene['initPos'], 0, 0),
      _studioVectorComponent(scene['initPos'], 1, 2),
      _studioVectorComponent(scene['initPos'], 2, 10),
    ];
    final List<double> initRot = <double>[
      _studioVectorComponent(scene['initRot'], 0, 0),
      _studioVectorComponent(scene['initRot'], 1, 0),
      _studioVectorComponent(scene['initRot'], 2, 0),
    ];
    final String shadowQuality = () {
      const valid = <String>{'256', '512', '1024', '2048'};
      final raw = (scene['shadowQuality'] ?? controls['shadowQuality'] ?? '512')
          .toString();
      return valid.contains(raw) ? raw : '512';
    }();

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('3D Controls',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _studioAdd3DEntity('model'),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Model'),
              ),
              OutlinedButton.icon(
                onPressed: () => _studioAdd3DEntity('light'),
                icon: const Icon(Icons.wb_incandescent_outlined, size: 16),
                label: const Text('Light'),
              ),
              OutlinedButton.icon(
                onPressed: () => _studioAdd3DEntity('audio'),
                icon: const Icon(Icons.graphic_eq_outlined, size: 16),
                label: const Text('Audio'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tokens.isEmpty)
            const SizedBox(
              height: 84,
              child: Center(child: Text('No entities')),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
              ),
              child: ReorderableListView.builder(
                itemCount: tokens.length,
                onReorder: _studioReorder3DEntity,
                itemBuilder: (context, index) {
                  final token = tokens[index];
                  final parts = token.split(':');
                  final type = parts.first;
                  final entity = _studioEntityByToken(scene, token);
                  final layer = (entity?['windowLayer'] ?? 'inside').toString();
                  return InkWell(
                    key: ValueKey<String>('studio-3d-$token'),
                    onTap: () => setState(() => _studioSelected3dToken = token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedToken == token
                            ? cs.primary.withValues(alpha: 0.16)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _studioEntityLabel(token, scene),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(type.toUpperCase()),
                              IconButton(
                                onPressed: () =>
                                    _studioDuplicate3DEntity(token),
                                icon: const Icon(Icons.copy_outlined, size: 18),
                              ),
                              IconButton(
                                onPressed: () => _studioDelete3DEntity(token),
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                              ),
                            ],
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'inside',
                                label: Text('Inside'),
                              ),
                              ButtonSegment<String>(
                                value: 'outside',
                                label: Text('Outside'),
                              ),
                            ],
                            selected: <String>{layer},
                            onSelectionChanged: (values) =>
                                _studioSet3DWindowLayer(token, values.first),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedEntity != null && selectedToken != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Selected: ${_studioEntityLabel(selectedToken, scene)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (selectedType == 'model')
                      TextFormField(
                        key: ValueKey<String>(
                          'studio-model-name-$selectedToken-${selectedEntity['name'] ?? ''}',
                        ),
                        initialValue: (selectedEntity['name'] ?? '').toString(),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'name',
                          value: value.trim(),
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Model Name'),
                      ),
                    if (selectedType == 'model' || selectedType == 'audio') ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey<String>(
                          'studio-entity-url-$selectedToken-${selectedEntity['url'] ?? ''}',
                        ),
                        initialValue: (selectedEntity['url'] ?? '').toString(),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'url',
                          value: value.trim(),
                        ),
                        decoration: InputDecoration(
                          labelText: selectedType == 'model'
                              ? 'Model URL'
                              : 'Audio URL',
                        ),
                      ),
                    ],
                    if (selectedType == 'model') ...[
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visible'),
                        value: asBool(selectedEntity['visible'], true),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'visible',
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos X',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 0, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 0,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Y',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 1, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 1,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Z',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 2, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 2,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Rot X',
                        min: -6.28,
                        max: 6.28,
                        value: _studioVectorComponent(
                            selectedEntity['rotation'], 0, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'rotation',
                          index: 0,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Rot Y',
                        min: -6.28,
                        max: 6.28,
                        value: _studioVectorComponent(
                            selectedEntity['rotation'], 1, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'rotation',
                          index: 1,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Rot Z',
                        min: -6.28,
                        max: 6.28,
                        value: _studioVectorComponent(
                            selectedEntity['rotation'], 2, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'rotation',
                          index: 2,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Scale X',
                        min: 0.01,
                        max: 10,
                        value: _studioVectorComponent(
                            selectedEntity['scale'], 0, 1),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'scale',
                          index: 0,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Scale Y',
                        min: 0.01,
                        max: 10,
                        value: _studioVectorComponent(
                            selectedEntity['scale'], 1, 1),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'scale',
                          index: 1,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Scale Z',
                        min: 0.01,
                        max: 10,
                        value: _studioVectorComponent(
                            selectedEntity['scale'], 2, 1),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'scale',
                          index: 2,
                          value: value,
                        ),
                      ),
                    ] else if (selectedType == 'light') ...[
                      TextFormField(
                        key: ValueKey<String>(
                          'studio-light-color-$selectedToken-${selectedEntity['color'] ?? ''}',
                        ),
                        initialValue:
                            (selectedEntity['color'] ?? 'ffffff').toString(),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'color',
                          value: value.replaceAll('#', '').trim(),
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Color (hex)'),
                      ),
                      _studioSlider(
                        label: 'Intensity',
                        min: 0,
                        max: 50,
                        value: _toDouble(selectedEntity['intensity'], 10),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'intensity',
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos X',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 0, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 0,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Y',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 1, 5),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 1,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Z',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 2, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 2,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Helper Scale',
                        min: 0.1,
                        max: 10,
                        value: _toDouble(selectedEntity['scale'], 1),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'scale',
                          value: value,
                        ),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ghost'),
                        value: asBool(selectedEntity['ghost']),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'ghost',
                          value: value,
                        ),
                      ),
                    ] else if (selectedType == 'audio') ...[
                      _studioSlider(
                        label: 'Volume',
                        min: 0,
                        max: 2,
                        value: _toDouble(selectedEntity['volume'], 1),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'volume',
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos X',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 0, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 0,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Y',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 1, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 1,
                          value: value,
                        ),
                      ),
                      _studioSlider(
                        label: 'Pos Z',
                        min: -30,
                        max: 30,
                        value: _studioVectorComponent(
                            selectedEntity['position'], 2, 0),
                        onChanged: (value) => _studioSet3DEntityVectorComponent(
                          token: selectedToken,
                          field: 'position',
                          index: 2,
                          value: value,
                        ),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ghost'),
                        value: asBool(selectedEntity['ghost']),
                        onChanged: (value) => _studioSet3DEntityField(
                          token: selectedToken,
                          field: 'ghost',
                          value: value,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  const Text('World & FX',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  _studioSlider(
                    label: 'Sun',
                    min: 0,
                    max: 10,
                    value: _toDouble(scene['sunIntensity'], 2.0),
                    onChanged: (value) =>
                        _studioSet3DSceneField('sunIntensity', value),
                  ),
                  _studioSlider(
                    label: 'Ambient',
                    min: 0,
                    max: 2,
                    value: _toDouble(scene['ambLight'], 0.5),
                    onChanged: (value) =>
                        _studioSet3DSceneField('ambLight', value),
                  ),
                  _studioSlider(
                    label: 'Bloom',
                    min: 0,
                    max: 4,
                    value: _toDouble(scene['bloomIntensity'], 1.0),
                    onChanged: (value) =>
                        _studioSet3DSceneField('bloomIntensity', value),
                  ),
                  DropdownButtonFormField<String>(
                    value: shadowQuality,
                    decoration:
                        const InputDecoration(labelText: 'Shadow Quality'),
                    items: const <String>['256', '512', '1024', '2048']
                        .map((value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _studioSet3DSceneField('shadowQuality', value);
                    },
                  ),
                  _studioSlider(
                    label: 'Shadow Softness',
                    min: 0,
                    max: 5,
                    value: _toDouble(scene['shadowSoftness'], 1.0),
                    onChanged: (value) =>
                        _studioSet3DSceneField('shadowSoftness', value),
                  ),
                  TextFormField(
                    key: ValueKey<String>(
                        'studio-sky-url-${scene['skyUrl'] ?? ''}'),
                    initialValue: (scene['skyUrl'] ?? '').toString(),
                    onChanged: (value) =>
                        _studioSet3DSceneField('skyUrl', value.trim()),
                    decoration: const InputDecoration(labelText: 'Sky URL'),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey<String>(
                        'studio-env-url-${scene['envUrl'] ?? ''}'),
                    initialValue: (scene['envUrl'] ?? '').toString(),
                    onChanged: (value) =>
                        _studioSet3DSceneField('envUrl', value.trim()),
                    decoration: const InputDecoration(labelText: 'Env URL'),
                  ),
                  _studioSlider(
                    label: 'Env Rot',
                    min: -6.28,
                    max: 6.28,
                    value: _toDouble(scene['envRot'], 0),
                    onChanged: (value) =>
                        _studioSet3DSceneField('envRot', value),
                  ),
                  const SizedBox(height: 8),
                  const Text('Initial Camera',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  _studioSlider(
                    label: 'Init Pos X',
                    min: -30,
                    max: 30,
                    value: initPos[0],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initPos',
                      index: 0,
                      value: value,
                      fallback: initPos,
                    ),
                  ),
                  _studioSlider(
                    label: 'Init Pos Y',
                    min: -30,
                    max: 30,
                    value: initPos[1],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initPos',
                      index: 1,
                      value: value,
                      fallback: initPos,
                    ),
                  ),
                  _studioSlider(
                    label: 'Init Pos Z',
                    min: -30,
                    max: 30,
                    value: initPos[2],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initPos',
                      index: 2,
                      value: value,
                      fallback: initPos,
                    ),
                  ),
                  _studioSlider(
                    label: 'Init Rot X',
                    min: -6.28,
                    max: 6.28,
                    value: initRot[0],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initRot',
                      index: 0,
                      value: value,
                      fallback: initRot,
                    ),
                  ),
                  _studioSlider(
                    label: 'Init Rot Y',
                    min: -6.28,
                    max: 6.28,
                    value: initRot[1],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initRot',
                      index: 1,
                      value: value,
                      fallback: initRot,
                    ),
                  ),
                  _studioSlider(
                    label: 'Init Rot Z',
                    min: -6.28,
                    max: 6.28,
                    value: initRot[2],
                    onChanged: (value) => _studioSet3DSceneVectorComponent(
                      field: 'initRot',
                      index: 2,
                      value: value,
                      fallback: initRot,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tracking',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButtonFormField<String>(
                    value: () {
                      const modes = <String>{'orbit', 'fps', 'free'};
                      final String raw = (controls['camera-mode'] ?? 'orbit')
                          .toString()
                          .toLowerCase();
                      return modes.contains(raw) ? raw : 'orbit';
                    }(),
                    decoration: const InputDecoration(labelText: 'Camera Mode'),
                    items: const [
                      DropdownMenuItem<String>(
                          value: 'orbit', child: Text('Orbit')),
                      DropdownMenuItem<String>(
                          value: 'fps', child: Text('FPS')),
                      DropdownMenuItem<String>(
                          value: 'free', child: Text('Free')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _studioSet3DControlField('camera-mode', value);
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Manual Mode'),
                    value: manualMode,
                    onChanged: (value) =>
                        _studioSet3DControlField('manual-mode', value),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tracker UI'),
                    value: asBool(controls['show-tracker']),
                    onChanged: (value) =>
                        _studioSet3DControlField('show-tracker', value),
                  ),
                  _studioSlider(
                    label: 'Dead Zone X',
                    min: 0,
                    max: 0.1,
                    value: _toDouble(controls['dz-x'], 0),
                    onChanged: (value) =>
                        _studioSet3DControlField('dz-x', value),
                  ),
                  _studioSlider(
                    label: 'Dead Zone Y',
                    min: 0,
                    max: 0.1,
                    value: _toDouble(controls['dz-y'], 0),
                    onChanged: (value) =>
                        _studioSet3DControlField('dz-y', value),
                  ),
                  _studioSlider(
                    label: 'Dead Zone Z',
                    min: 0,
                    max: 0.1,
                    value: _toDouble(controls['dz-z'], 0),
                    onChanged: (value) =>
                        _studioSet3DControlField('dz-z', value),
                  ),
                  _studioSlider(
                    label: 'Dead Zone Yaw',
                    min: 0,
                    max: 10,
                    value: _toDouble(controls['dz-yaw'], 0),
                    onChanged: (value) =>
                        _studioSet3DControlField('dz-yaw', value),
                  ),
                  _studioSlider(
                    label: 'Dead Zone Pitch',
                    min: 0,
                    max: 10,
                    value: _toDouble(controls['dz-pitch'], 0),
                    onChanged: (value) =>
                        _studioSet3DControlField('dz-pitch', value),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final frame =
                          TrackingService.instance.frameNotifier.value;
                      _studioSet3DControlField('head-x', frame.headX);
                      _studioSet3DControlField('head-y', frame.headY);
                      _studioSet3DControlField('z-value', frame.headZ);
                      _studioSet3DControlField('yaw', frame.yaw);
                      _studioSet3DControlField('pitch', frame.pitch);
                    },
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: const Text('Recenter Manual Anchor'),
                  ),
                  if (manualMode) ...[
                    _studioSlider(
                      label: 'Manual Head X',
                      min: -1,
                      max: 1,
                      value: _toDouble(controls['head-x'], 0),
                      onChanged: (value) =>
                          _studioSet3DControlField('head-x', value),
                    ),
                    _studioSlider(
                      label: 'Manual Head Y',
                      min: -1,
                      max: 1,
                      value: _toDouble(controls['head-y'], 0),
                      onChanged: (value) =>
                          _studioSet3DControlField('head-y', value),
                    ),
                    _studioSlider(
                      label: 'Manual Z',
                      min: 0.05,
                      max: 2,
                      value: _toDouble(controls['z-value'], 0.2),
                      onChanged: (value) =>
                          _studioSet3DControlField('z-value', value),
                    ),
                    _studioSlider(
                      label: 'Manual Yaw',
                      min: -60,
                      max: 60,
                      value: _toDouble(controls['yaw'], 0),
                      onChanged: (value) =>
                          _studioSet3DControlField('yaw', value),
                    ),
                    _studioSlider(
                      label: 'Manual Pitch',
                      min: -40,
                      max: 40,
                      value: _toDouble(controls['pitch'], 0),
                      onChanged: (value) =>
                          _studioSet3DControlField('pitch', value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool collectionMode = _postTypeIndex == 1;
    final TrackingService tracking = TrackingService.instance;
    final bool trackerEnabled = tracking.trackerEnabled;
    final bool trackerUiVisible = tracking.trackerUiVisible;
    final Widget previewPane = _editorFullscreen
        ? Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildEditor(),
          )
        : Center(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              constraints: const BoxConstraints(maxWidth: 1680),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.16),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildEditor(),
                ),
              ),
            ),
          );

    final Widget studioTopRail = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Post Studio',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('2D')),
              ButtonSegment<int>(value: 1, label: Text('3D')),
            ],
            selected: <int>{_modeIndex},
            onSelectionChanged: (values) {
              final next = values.first;
              setState(() {
                _modeIndex = next;
                if (_postTypeIndex == 1 &&
                    _selectedItemIndex >= 0 &&
                    _selectedItemIndex < _draftItems.length) {
                  final current = _draftItems[_selectedItemIndex];
                  _studioLivePayload = current.mode == (next == 0 ? '2d' : '3d')
                      ? current.snapshot
                      : null;
                }
              });
            },
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Single')),
              ButtonSegment<int>(value: 1, label: Text('Collection')),
            ],
            selected: <int>{_postTypeIndex},
            onSelectionChanged: (values) {
              setState(() => _postTypeIndex = values.first);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: trackerUiVisible,
            title: const Text('Show Tracker'),
            onChanged: trackerEnabled
                ? (value) async {
                    await tracking.setTrackerUiVisible(value);
                    if (!mounted) return;
                    setState(() {});
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _studioReanchorToken++);
                  TrackingService.instance.remapHeadBaselineToCurrentFrame();
                },
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Recenter'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _editorFullscreen = !_editorFullscreen);
                },
                icon: Icon(
                  _editorFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                label: Text(_editorFullscreen ? 'Exit Full' : 'Full'),
              ),
              if (!collectionMode)
                FilledButton.icon(
                  onPressed: (_openingComposer || _studioLivePayload == null)
                      ? null
                      : _openStudioSingleComposer,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_openingComposer ? 'Opening...' : 'Compose'),
                ),
              if (collectionMode) ...[
                OutlinedButton.icon(
                  onPressed: _createNewCollectionItem,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Item'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveCurrentStudioItemToCollection,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Item'),
                ),
                OutlinedButton.icon(
                  onPressed: _previewCollection,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Preview'),
                ),
                FilledButton.icon(
                  onPressed: _publishing ? null : _publishCollection,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(_publishing ? 'Publishing...' : 'Compose'),
                ),
              ],
            ],
          ),
          if (collectionMode) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _collectionNameController,
              decoration: const InputDecoration(
                labelText: 'Collection Name',
                prefixIcon: Icon(Icons.collections_bookmark_outlined),
              ),
            ),
            if (_selectedItemIndex >= 0 &&
                _selectedItemIndex < _draftItems.length) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _duplicateCollectionItem(_selectedItemIndex),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Duplicate Selected'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _removeCollectionItem(_selectedItemIndex),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Selected'),
                  ),
                ],
              ),
            ],
            if (_draftItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List<Widget>.generate(_draftItems.length, (index) {
                    final item = _draftItems[index];
                    final bool active = index == _selectedItemIndex;
                    return Padding(
                      padding: EdgeInsets.only(
                          right: index == _draftItems.length - 1 ? 0 : 8),
                      child: ChoiceChip(
                        selected: active,
                        label: Text(
                          '${index + 1}. ${item.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onSelected: (_) => _selectCollectionItem(index),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: widget.topInset),
      child: Row(
        children: [
          Expanded(child: previewPane),
          SizedBox(
            width: 430,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  left: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                children: [
                  studioTopRail,
                  Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
                  Expanded(child: _buildStudioControlsPanel(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionPreviewPage extends StatefulWidget {
  const _CollectionPreviewPage({required this.items});

  final List<CollectionDraftItem> items;

  @override
  State<_CollectionPreviewPage> createState() => _CollectionPreviewPageState();
}

class _CollectionPreviewPageState extends State<_CollectionPreviewPage> {
  final SwipableStackController _stackController = SwipableStackController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    TrackingService.instance.remapHeadBaselineToCurrentFrame();
    _stackController.addListener(_onStackChanged);
  }

  @override
  void dispose() {
    _stackController
      ..removeListener(_onStackChanged)
      ..dispose();
    super.dispose();
  }

  void _onStackChanged() {
    if (!mounted) return;
    if (widget.items.isEmpty) return;
    final next = _stackController.currentIndex;
    if (next == _index) return;
    setState(() {
      final int max = widget.items.length - 1;
      _index = next < 0 ? 0 : (next > max ? max : next);
    });
  }

  Widget _buildCard(CollectionDraftItem item) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: PresetViewer(
            mode: item.mode,
            payload: item.snapshot,
            cleanView: true,
            embedded: true,
            disableAudio: true,
            pointerPassthrough: true,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool hasItems = widget.items.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: hasItems
                  ? SwipableStack(
                      controller: _stackController,
                      itemCount: widget.items.length,
                      allowVerticalSwipe: true,
                      onSwipeCompleted: (index, _) {
                        setState(() {
                          final int next = index + 1;
                          final int max = widget.items.length - 1;
                          _index = next < 0 ? 0 : (next > max ? max : next);
                        });
                      },
                      builder: (context, props) {
                        if (props.index >= widget.items.length) {
                          return const SizedBox.shrink();
                        }
                        return _buildCard(widget.items[props.index]);
                      },
                    )
                  : Center(
                      child: Text(
                        'No items in collection.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 10),
                  IgnorePointer(
                    child: Text(
                      'Collection Preview',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasItems)
                    IgnorePointer(
                      child: Text(
                        '${_index + 1}/${widget.items.length}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionDetailPage extends StatefulWidget {
  const _CollectionDetailPage({
    required this.collectionId,
    this.initialSummary,
  });

  final String collectionId;
  final CollectionSummary? initialSummary;

  @override
  State<_CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<_CollectionDetailPage> {
  final AppRepository _repository = AppRepository.instance;
  final SwipableStackController _stackController = SwipableStackController();
  final TextEditingController _collectionCommentController =
      TextEditingController();
  final FocusNode _swipeFocusNode =
      FocusNode(debugLabel: 'collection-detail-swipe-focus');
  static const List<String> _suggestionFilters = <String>[
    'All',
    'FromUser',
    'Related',
    'FYP',
    'Trending',
    'MostUsedHashtags',
    'MostLiked',
    'MostViewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  CollectionDetail? _detail;
  int _index = 0;
  bool _immersive = false;
  bool _commentsOpen = false;
  bool _descriptionExpanded = false;
  bool _loadingSuggestions = false;
  String _suggestionFilter = _suggestionFilters.first;
  List<CollectionSummary> _suggestedCollections = const <CollectionSummary>[];
  List<PresetComment> _collectionComments = const <PresetComment>[];

  bool get _mine {
    final String? me = _repository.currentUser?.id;
    if (me == null) return false;
    final String ownerId =
        _detail?.summary.userId ?? widget.initialSummary?.userId ?? '';
    return ownerId == me;
  }

  @override
  void initState() {
    super.initState();
    TrackingService.instance.remapHeadBaselineToCurrentFrame();
    _stackController.addListener(_onStackChanged);
    _load();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _collectionCommentController.dispose();
    _swipeFocusNode.dispose();
    _stackController
      ..removeListener(_onStackChanged)
      ..dispose();
    super.dispose();
  }

  void _onStackChanged() {
    if (!mounted) return;
    final next = _stackController.currentIndex;
    if (_detail == null || _detail!.items.isEmpty) return;
    if (next == _index) return;
    setState(() {
      final int max = _detail!.items.length - 1;
      _index = next < 0 ? 0 : (next > max ? max : next);
    });
  }

  Future<bool> _requireAuthAction() async {
    if (_repository.currentUser != null) return true;
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  CollectionSummary _copySummary(
    CollectionSummary summary, {
    int? likesCount,
    int? dislikesCount,
    int? commentsCount,
    int? savesCount,
    int? viewsCount,
    int? myReaction,
    bool? isSavedByCurrentUser,
    bool? isWatchLater,
  }) {
    return CollectionSummary(
      id: summary.id,
      shareId: summary.shareId,
      userId: summary.userId,
      name: summary.name,
      description: summary.description,
      tags: summary.tags,
      mentionUserIds: summary.mentionUserIds,
      published: summary.published,
      thumbnailPayload: summary.thumbnailPayload,
      thumbnailMode: summary.thumbnailMode,
      itemsCount: summary.itemsCount,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      firstItem: summary.firstItem,
      author: summary.author,
      likesCount: likesCount ?? summary.likesCount,
      dislikesCount: dislikesCount ?? summary.dislikesCount,
      commentsCount: commentsCount ?? summary.commentsCount,
      savesCount: savesCount ?? summary.savesCount,
      viewsCount: viewsCount ?? summary.viewsCount,
      myReaction: myReaction ?? summary.myReaction,
      isSavedByCurrentUser:
          isSavedByCurrentUser ?? summary.isSavedByCurrentUser,
      isWatchLater: isWatchLater ?? summary.isWatchLater,
    );
  }

  void _updateSummary(CollectionSummary Function(CollectionSummary) map) {
    final detail = _detail;
    if (detail == null) return;
    setState(() {
      _detail =
          CollectionDetail(summary: map(detail.summary), items: detail.items);
    });
  }

  void _swipeByDirection(SwipeDirection direction) {
    final detail = _detail;
    if (detail == null || detail.items.isEmpty) return;
    _stackController.next(swipeDirection: direction);
  }

  void _rewindSwipe() {
    if (_stackController.canRewind) {
      _stackController.rewind();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repository.fetchCollectionById(widget.collectionId);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = 'Collection not found.';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_repository.recordCollectionView(detail.summary.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleCollectionReaction(int value) async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final int newReaction = summary.myReaction == value ? 0 : value;
    await _repository.setCollectionReaction(
      collectionId: summary.id,
      reaction: newReaction,
    );

    int likes = summary.likesCount;
    int dislikes = summary.dislikesCount;
    if (summary.myReaction == 1) likes = (likes - 1).clamp(0, 999999999);
    if (summary.myReaction == -1) dislikes = (dislikes - 1).clamp(0, 999999999);
    if (newReaction == 1) likes += 1;
    if (newReaction == -1) dislikes += 1;
    _updateSummary(
      (current) => _copySummary(
        current,
        likesCount: likes,
        dislikesCount: dislikes,
        myReaction: newReaction,
      ),
    );
  }

  Future<void> _toggleCollectionSave() async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final bool save = !summary.isSavedByCurrentUser;
    await _repository.toggleSaveCollection(summary.id, save: save);
    _updateSummary(
      (current) => _copySummary(
        current,
        isSavedByCurrentUser: save,
        savesCount: save
            ? current.savesCount + 1
            : (current.savesCount - 1).clamp(0, 999999999),
      ),
    );
  }

  Future<void> _toggleCollectionWatchLater() async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final bool watchLater = !summary.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'collection',
      targetId: summary.id,
      watchLater: watchLater,
    );
    _updateSummary(
      (current) => _copySummary(
        current,
        isWatchLater: watchLater,
      ),
    );
  }

  Future<void> _loadCollectionComments() async {
    final summary = _detail?.summary;
    if (summary == null) return;
    final comments = await _repository.fetchCollectionComments(summary.id);
    if (!mounted) return;
    setState(() {
      _collectionComments = comments;
    });
    _updateSummary(
      (current) => _copySummary(current, commentsCount: comments.length),
    );
  }

  Future<void> _openCollectionCommentsSheet() async {
    await _loadCollectionComments();
    if (!mounted) return;
    List<PresetComment> sheetComments =
        List<PresetComment>.from(_collectionComments);
    bool sending = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  children: [
                    Expanded(
                      child: sheetComments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              itemCount: sheetComments.length,
                              itemBuilder: (context, index) {
                                final comment = sheetComments[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                      comment.author?.displayName ?? 'User'),
                                  subtitle: Text(comment.content),
                                  trailing: Text(
                                    _friendlyTime(comment.createdAt),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _collectionCommentController,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  if (!await _requireAuthAction()) return;
                                  final summary = _detail?.summary;
                                  if (summary == null) return;
                                  final String text =
                                      _collectionCommentController.text.trim();
                                  if (text.isEmpty) return;
                                  setModalState(() => sending = true);
                                  await _repository.addCollectionComment(
                                    collectionId: summary.id,
                                    content: text,
                                  );
                                  _collectionCommentController.clear();
                                  final comments = await _repository
                                      .fetchCollectionComments(summary.id);
                                  if (!mounted) return;
                                  setState(
                                      () => _collectionComments = comments);
                                  _updateSummary(
                                    (current) => _copySummary(
                                      current,
                                      commentsCount: comments.length,
                                    ),
                                  );
                                  setModalState(() {
                                    sending = false;
                                    sheetComments = comments;
                                  });
                                },
                          child: Text(sending ? '...' : 'Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleVisibility() async {
    final summary = _detail?.summary;
    if (summary == null) return;
    try {
      await _repository.setCollectionPublished(
        collectionId: summary.id,
        published: !summary.published,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.published
                ? 'Collection set to private.'
                : 'Collection set to public.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update collection: $e')),
      );
    }
  }

  Future<void> _updateCollection() async {
    final detail = _detail;
    if (detail == null) return;
    final bool updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _PostCardComposerPage.collection(
              collectionId: detail.summary.id,
              collectionName: detail.summary.name,
              collectionDescription: detail.summary.description,
              tags: detail.summary.tags,
              mentionUserIds: detail.summary.mentionUserIds,
              published: detail.summary.published,
              initialCardPayload: detail.summary.thumbnailPayload,
              initialCardMode: detail.summary.thumbnailMode,
              editTarget: _ComposerEditTarget.detail,
              startBlankCard: false,
              items: detail.items
                  .map(
                    (item) => CollectionDraftItem(
                      mode: item.mode,
                      name: item.name,
                      snapshot: item.snapshot,
                    ),
                  )
                  .toList(),
            ),
          ),
        ) ??
        false;
    if (updated) {
      await _load();
    }
  }

  Future<void> _deleteCollection() async {
    final summary = _detail?.summary;
    if (summary == null) return;
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete collection?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deleteCollection(summary.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  CollectionSummary? get _activeSummary =>
      _detail?.summary ?? widget.initialSummary;

  String _displayFilterName(String filter) {
    if (filter == 'FromUser') {
      final username = _activeSummary?.author?.username?.trim();
      if (username != null && username.isNotEmpty) {
        return 'From @$username';
      }
      return 'From creator';
    }
    switch (filter) {
      case 'MostUsedHashtags':
        return 'Most Used Hashtags';
      case 'MostLiked':
        return 'Most Liked';
      case 'MostViewed':
        return 'Most Viewed';
      default:
        return filter;
    }
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final collections = await _repository.fetchPublishedCollections(limit: 120);
      if (!mounted) return;
      setState(() {
        _suggestedCollections = collections;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  List<CollectionSummary> _filteredSuggestions() {
    final summary = _activeSummary;
    final String currentCollectionId = summary?.id ?? '';
    final String currentUserId = summary?.userId ?? '';
    final Set<String> currentTags =
        (summary?.tags ?? const <String>[]).map((e) => e.toLowerCase()).toSet();
    final List<CollectionSummary> candidates = _suggestedCollections
        .where((item) => item.id != currentCollectionId)
        .toList();
    switch (_suggestionFilter) {
      case 'FromUser':
        return candidates.where((item) => item.userId == currentUserId).toList();
      case 'Related':
        return candidates.where((item) {
          final tags = item.tags.map((e) => e.toLowerCase()).toSet();
          return tags.intersection(currentTags).isNotEmpty;
        }).toList();
      case 'Trending':
        candidates.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'MostUsedHashtags':
        candidates.sort((a, b) => b.tags.length.compareTo(a.tags.length));
        return candidates;
      case 'MostLiked':
        candidates.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        return candidates;
      case 'MostViewed':
        candidates.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        return candidates;
      case 'Viral':
        candidates.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'FYP':
      case 'All':
      default:
        return candidates;
    }
  }

  String? _ambientImageUrlFromItem(CollectionItemSnapshot item) {
    try {
      final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
        item.snapshot,
        fallbackMode: item.mode,
      );
      if (adapted.mode != '2d') return null;
      final layers = adapted.scene.entries
          .where((e) => e.value is Map)
          .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value as Map)))
          .where((entry) =>
              entry.key != 'turning_point' &&
              entry.value['isVisible'] != false &&
              (entry.value['url'] ?? '').toString().trim().isNotEmpty)
          .toList();
      layers.sort((a, b) {
        final ao =
            double.tryParse(a.value['order']?.toString() ?? '0') ?? 0.0;
        final bo =
            double.tryParse(b.value['order']?.toString() ?? '0') ?? 0.0;
        return ao.compareTo(bo);
      });
      if (layers.isEmpty) return null;
      return (layers.last.value['url'] ?? '').toString().trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCollectionToUser() async {
    if (!await _requireAuthAction()) return;
    final summary = _activeSummary;
    if (summary == null || !mounted) return;
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Share Collection to User'),
    );
    if (profile == null) return;
    try {
      await _repository.shareCollectionToUser(
        recipientUserId: profile.userId,
        summary: summary,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _copyCollectionLinkToClipboard() async {
    final summary = _activeSummary;
    if (summary == null) return;
    final String link = buildCollectionShareUrl(summary);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection link copied to clipboard.')),
    );
  }

  Future<void> _openCollectionShareUrl(
    String url, {
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyCollectionLinkToClipboard();
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openCollectionShareSheet() async {
    final summary = _activeSummary;
    if (summary == null) return;
    final String link = buildCollectionShareUrl(summary);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Share to user'),
              onTap: () {
                Navigator.pop(context);
                _shareCollectionToUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyCollectionLinkToClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                    'https://t.me/share/url?url=$encodedLink');
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl('https://wa.me/?text=$encodedLink');
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('X (Twitter)'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://twitter.com/intent/tweet?url=$encodedLink',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.instagram.com/',
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.snapchat.com/',
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Reddit'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.reddit.com/submit?url=$encodedLink',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CollectionItemSnapshot item) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.transparent),
        ),
        IgnorePointer(
          child: PresetViewer(
            mode: item.mode,
            payload: item.snapshot,
            cleanView: true,
            embedded: true,
            disableAudio: true,
            pointerPassthrough: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = _detail?.summary ?? widget.initialSummary;
    final detail = _detail;
    final bool hasItems = detail != null && detail.items.isNotEmpty;
    final CollectionItemSnapshot? activeItem = hasItems
        ? detail.items[_index.clamp(0, detail.items.length - 1)]
        : null;
    final String? ambientUrl =
        activeItem == null ? null : _ambientImageUrlFromItem(activeItem);
    final List<CollectionSummary> suggestions = _filteredSuggestions();

    Widget buildBackdrop() {
      if (ambientUrl == null || ambientUrl.isEmpty) {
        return const ColoredBox(color: Colors.black);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            ambientUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 56, sigmaY: 56),
            child: Container(color: Colors.black.withValues(alpha: 0.72)),
          ),
        ],
      );
    }

    Widget buildHeader() {
      return AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        offset: _immersive ? const Offset(0, -1) : Offset.zero,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 10),
              Text(
                'DeepX',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _immersive ? 'Exit Fullscreen' : 'Fullscreen',
                onPressed: () => setState(() => _immersive = !_immersive),
                icon: Icon(
                  _immersive ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildPreviewDeck({required bool immersive}) {
      if (!hasItems || activeItem == null) {
        return Center(
          child: Text(
            'Collection is empty.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      if (immersive) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => setState(() => _immersive = false),
          child: _buildCard(activeItem),
        );
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _commentsOpen ? () => setState(() => _commentsOpen = false) : null,
        onDoubleTap: () => setState(() => _immersive = true),
        child: Stack(
          children: [
            Positioned.fill(
              child: SwipableStack(
                controller: _stackController,
                itemCount: detail.items.length,
                allowVerticalSwipe: true,
                onSwipeCompleted: (index, _) {
                  setState(() {
                    final int next = index + 1;
                    final int max = detail.items.length - 1;
                    _index = next < 0 ? 0 : (next > max ? max : next);
                  });
                },
                builder: (context, props) {
                  if (props.index >= detail.items.length) {
                    return const SizedBox.shrink();
                  }
                  return _buildCard(detail.items[props.index]);
                },
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond;
                  final double absX = velocity.dx.abs();
                  final double absY = velocity.dy.abs();
                  if (absX < 240 && absY < 240) return;
                  if (absX >= absY) {
                    _swipeByDirection(
                      velocity.dx < 0 ? SwipeDirection.left : SwipeDirection.right,
                    );
                  } else {
                    _swipeByDirection(
                      velocity.dy < 0 ? SwipeDirection.up : SwipeDirection.down,
                    );
                  }
                },
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1}/${detail.items.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Swipe left',
                        onPressed: () => _swipeByDirection(SwipeDirection.left),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      IconButton(
                        tooltip: 'Swipe up',
                        onPressed: () => _swipeByDirection(SwipeDirection.up),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        tooltip: 'Revert swipe',
                        onPressed: _stackController.canRewind ? _rewindSwipe : null,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                      IconButton(
                        tooltip: 'Swipe down',
                        onPressed: () => _swipeByDirection(SwipeDirection.down),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      IconButton(
                        tooltip: 'Swipe right',
                        onPressed: () => _swipeByDirection(SwipeDirection.right),
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildMetaPanel(double width) {
      if (summary == null) {
        return const SizedBox.shrink();
      }
      final bool narrow = width < 1140;
      return Container(
        width: narrow ? double.infinity : 420,
        constraints: const BoxConstraints(minHeight: 420),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_friendlyCount(summary.viewsCount)} views · ${_friendlyTime(summary.createdAt)} · ${summary.itemsCount} items',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                      ),
                    ],
                  ),
                ),
                if (_mine)
                  PopupMenuButton<String>(
                    color: cs.surfaceContainerHighest,
                    onSelected: (value) {
                      if (value == 'update') _updateCollection();
                      if (value == 'visibility') _toggleVisibility();
                      if (value == 'delete') _deleteCollection();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'update',
                        child: Text('Update'),
                      ),
                      PopupMenuItem<String>(
                        value: 'visibility',
                        child: Text(summary.published ? 'Make Private' : 'Make Public'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openPublicProfileRoute(context, summary.author),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: (summary.author?.avatarUrl != null &&
                            summary.author!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(summary.author!.avatarUrl!)
                        : null,
                    child: (summary.author?.avatarUrl == null ||
                            summary.author!.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openPublicProfileRoute(context, summary.author),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.author?.displayName ?? 'Unknown creator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          summary.author?.username?.isNotEmpty == true
                              ? '@${summary.author!.username}'
                              : 'Creator',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _collectionEngagementButton(
                  icon: summary.myReaction == 1
                      ? Icons.thumb_up_alt
                      : Icons.thumb_up_alt_outlined,
                  active: summary.myReaction == 1,
                  activeColor: cs.primary,
                  label: _friendlyCount(summary.likesCount),
                  onTap: () => _toggleCollectionReaction(1),
                ),
                _collectionEngagementButton(
                  icon: summary.myReaction == -1
                      ? Icons.thumb_down_alt
                      : Icons.thumb_down_alt_outlined,
                  active: summary.myReaction == -1,
                  activeColor: Colors.redAccent,
                  label: _friendlyCount(summary.dislikesCount),
                  onTap: () => _toggleCollectionReaction(-1),
                ),
                _collectionEngagementButton(
                  icon: Icons.mode_comment_outlined,
                  active: _commentsOpen,
                  activeColor: cs.primary,
                  label: _friendlyCount(summary.commentsCount),
                  onTap: () async {
                    setState(() => _commentsOpen = true);
                    await _loadCollectionComments();
                  },
                ),
                _collectionEngagementButton(
                  icon: summary.isSavedByCurrentUser
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  active: summary.isSavedByCurrentUser,
                  activeColor: Colors.amberAccent,
                  label: _friendlyCount(summary.savesCount),
                  onTap: _toggleCollectionSave,
                ),
                _collectionEngagementButton(
                  icon: summary.isWatchLater
                      ? Icons.watch_later
                      : Icons.watch_later_outlined,
                  active: summary.isWatchLater,
                  activeColor: Colors.tealAccent,
                  label: '',
                  onTap: _toggleCollectionWatchLater,
                ),
                _collectionEngagementButton(
                  icon: Icons.send_outlined,
                  active: false,
                  activeColor: cs.primary,
                  label: '',
                  onTap: _openCollectionShareSheet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _descriptionExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.description.trim().isNotEmpty
                          ? summary.description
                          : 'No description provided.',
                      maxLines: _descriptionExpanded ? null : 2,
                      overflow: _descriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestionFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _suggestionFilters[index];
                  final selected = filter == _suggestionFilter;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_displayFilterName(filter)),
                    selectedColor: cs.primary.withValues(alpha: 0.22),
                    side: BorderSide(color: Colors.white24),
                    onSelected: (_) => setState(() => _suggestionFilter = filter),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _commentsOpen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Comments',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => _commentsOpen = false),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white70, size: 18),
                            ),
                          ],
                        ),
                        Expanded(
                          child: _collectionComments.isEmpty
                              ? Center(
                                  child: Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.68),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _collectionComments.length,
                                  itemBuilder: (context, index) {
                                    final comment = _collectionComments[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        comment.author?.displayName ?? 'User',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        comment.content,
                                        style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.78)),
                                      ),
                                      trailing: Text(
                                        _friendlyTime(comment.createdAt),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.64),
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _collectionCommentController,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                if (!await _requireAuthAction()) return;
                                final summary = _detail?.summary;
                                if (summary == null) return;
                                final String text =
                                    _collectionCommentController.text.trim();
                                if (text.isEmpty) return;
                                await _repository.addCollectionComment(
                                  collectionId: summary.id,
                                  content: text,
                                );
                                _collectionCommentController.clear();
                                await _loadCollectionComments();
                              },
                              child: const Text('Send'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : _loadingSuggestions
                      ? const _TopEdgeLoadingPane(
                          label: 'Loading suggestions...',
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        )
                      : ListView.separated(
                          itemCount: suggestions.length.clamp(0, 24),
                          separatorBuilder: (_, __) => const Divider(
                            color: Colors.white24,
                            height: 14,
                          ),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return InkWell(
                              onTap: () => Navigator.pushReplacementNamed(
                                context,
                                buildCollectionRoutePathForSummary(item),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 140,
                                    height: 78,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: IgnorePointer(
                                        child: _GridPresetPreview(
                                          mode: item.thumbnailMode ??
                                              item.firstItem?.mode ??
                                              '2d',
                                          payload: item.thumbnailPayload.isNotEmpty
                                              ? item.thumbnailPayload
                                              : (item.firstItem?.snapshot ??
                                                  const <String, dynamic>{}),
                                          pointerPassthrough: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.author?.displayName ??
                                              'Unknown creator',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withValues(alpha: 0.75),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${_friendlyCount(item.viewsCount)} views · ${_friendlyTime(item.createdAt)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withValues(alpha: 0.62),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _swipeFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _swipeByDirection(SwipeDirection.left);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _swipeByDirection(SwipeDirection.right);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _swipeByDirection(SwipeDirection.up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _swipeByDirection(SwipeDirection.down);
          } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
            _rewindSwipe();
          } else if (event.logicalKey == LogicalKeyboardKey.keyF ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _immersive = !_immersive);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: buildBackdrop()),
            Positioned(top: 0, left: 0, right: 0, child: buildHeader()),
            if (_loading)
              const Positioned.fill(
                child: _TopEdgeLoadingPane(label: 'Loading collection...'),
              )
            else if (_error != null)
              Positioned.fill(
                child: Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  padding: _immersive
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(14, 66, 14, 14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale:
                              Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _immersive
                        ? GestureDetector(
                            key: const ValueKey<String>(
                                'immersive-collection-detail'),
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () => setState(() => _immersive = false),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: buildPreviewDeck(immersive: true),
                                ),
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: IconButton.filledTonal(
                                    onPressed: () =>
                                        setState(() => _immersive = false),
                                    icon: const Icon(Icons.fullscreen_exit),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            key: const ValueKey<String>('compact-collection-detail'),
                            builder: (context, constraints) {
                              final bool narrow = constraints.maxWidth < 1140;
                              final Widget preview = AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: buildPreviewDeck(immersive: false),
                                ),
                              );
                              final Widget meta = buildMetaPanel(constraints.maxWidth);
                              if (narrow) {
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      preview,
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 640,
                                        child: meta,
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: preview),
                                  const SizedBox(width: 12),
                                  SizedBox(width: 420, child: meta),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _collectionEngagementButton({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final Color color = active ? activeColor : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    super.key,
    required this.onProfileChanged,
    required this.topInset,
  });

  final Future<void> Function() onProfileChanged;
  final double topInset;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

enum _SavedGridFilter {
  all,
  savedPosts,
  savedCollections,
  watchLater,
}

class _ProfileTabState extends State<_ProfileTab> {
  final AppRepository _repository = AppRepository.instance;

  bool _loading = true;
  AppUserProfile? _profile;
  ProfileStats _stats = const ProfileStats(
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
  );
  List<RenderPreset> _saved = const <RenderPreset>[];
  List<CollectionSummary> _savedCollections = const <CollectionSummary>[];
  List<RenderPreset> _posts = const <RenderPreset>[];
  List<RenderPreset> _history = const <RenderPreset>[];
  List<WatchLaterItem> _watchLater = const <WatchLaterItem>[];
  _SavedGridFilter _savedFilter = _SavedGridFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _repository.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    final profile = await _repository.ensureCurrentProfile();
    final stats = await _repository.fetchProfileStats(user.id);
    final saved = await _repository.fetchSavedPresetsForCurrentUser();
    final savedCollections =
        await _repository.fetchSavedCollectionsForCurrentUser();
    final posts = await _repository.fetchUserPosts(user.id);
    final history = await _repository.fetchHistoryPresetsForCurrentUser();
    final watchLater = await _repository.fetchWatchLaterForCurrentUser();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _stats = stats;
      _saved = saved;
      _savedCollections = savedCollections;
      _posts = posts;
      _history = history;
      _watchLater = watchLater;
      _loading = false;
    });
  }

  Future<void> _openPost(RenderPreset preset) async {
    await _repository.recordPresetView(preset.id);
    if (!mounted) return;
    await Navigator.pushNamed(context, buildPostRoutePathForPreset(preset));
    await _load();
  }

  Future<void> _openCollection(CollectionSummary summary) async {
    await Navigator.pushNamed(
        context, buildCollectionRoutePathForSummary(summary));
    await _load();
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(profile: _profile!),
      ),
    );
    await _load();
    await widget.onProfileChanged();
  }

  Future<void> _confirmSignOut() async {
    final bool shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You can sign back in anytime.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSignOut) return;
    await _repository.signOut();
    if (!mounted) return;
    await widget.onProfileChanged();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/feed');
  }

  List<Map<String, dynamic>> _savedEntries() {
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    final Set<String> dedupe = <String>{};

    for (final preset in _saved) {
      final key = 'saved_post:${preset.id}';
      if (!dedupe.add(key)) continue;
      entries.add(
        <String, dynamic>{
          'key': key,
          'kind': 'saved_post',
          'createdAt': preset.createdAt,
          'preset': preset,
        },
      );
    }
    for (final summary in _savedCollections) {
      final key = 'saved_collection:${summary.id}';
      if (!dedupe.add(key)) continue;
      entries.add(
        <String, dynamic>{
          'key': key,
          'kind': 'saved_collection',
          'createdAt': summary.createdAt,
          'collection': summary,
        },
      );
    }
    for (final watch in _watchLater) {
      if (watch.type == WatchLaterTargetType.collection &&
          watch.collection != null) {
        final summary = watch.collection!;
        final key = 'watch_later_collection:${summary.id}';
        if (!dedupe.add(key)) continue;
        entries.add(
          <String, dynamic>{
            'key': key,
            'kind': 'watch_later_collection',
            'createdAt': watch.createdAt,
            'collection': summary,
          },
        );
      } else if (watch.type == WatchLaterTargetType.post &&
          watch.post != null) {
        final preset = watch.post!;
        final key = 'watch_later_post:${preset.id}';
        if (!dedupe.add(key)) continue;
        entries.add(
          <String, dynamic>{
            'key': key,
            'kind': 'watch_later_post',
            'createdAt': watch.createdAt,
            'preset': preset,
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
    return entries;
  }

  List<Map<String, dynamic>> _filteredSavedEntries() {
    final entries = _savedEntries();
    switch (_savedFilter) {
      case _SavedGridFilter.savedPosts:
        return entries
            .where((e) => (e['kind']?.toString() ?? '') == 'saved_post')
            .toList();
      case _SavedGridFilter.savedCollections:
        return entries
            .where((e) => (e['kind']?.toString() ?? '') == 'saved_collection')
            .toList();
      case _SavedGridFilter.watchLater:
        return entries
            .where(
                (e) => (e['kind']?.toString() ?? '').startsWith('watch_later_'))
            .toList();
      case _SavedGridFilter.all:
        return entries;
    }
  }

  Widget _buildSavedUnifiedTab() {
    final cs = Theme.of(context).colorScheme;
    final entries = _filteredSavedEntries();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width >= 1300) {
          crossAxisCount = 6;
        } else if (width >= 1000) {
          crossAxisCount = 5;
        } else if (width >= 760) {
          crossAxisCount = 4;
        } else if (width >= 540) {
          crossAxisCount = 3;
        }
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _savedFilter == _SavedGridFilter.all,
                    onSelected: (_) =>
                        setState(() => _savedFilter = _SavedGridFilter.all),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Saved Posts'),
                    selected: _savedFilter == _SavedGridFilter.savedPosts,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.savedPosts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Saved Collections'),
                    selected: _savedFilter == _SavedGridFilter.savedCollections,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.savedCollections,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Watch Later'),
                    selected: _savedFilter == _SavedGridFilter.watchLater,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.watchLater,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing saved yet.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: entries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final RenderPreset? preset =
                            entry['preset'] as RenderPreset?;
                        final CollectionSummary? collection =
                            entry['collection'] as CollectionSummary?;
                        final bool isCollection = collection != null;
                        final String title = isCollection
                            ? (collection.name.isEmpty
                                ? 'Collection'
                                : collection.name)
                            : ((preset?.title.trim().isNotEmpty == true)
                                ? preset!.title.trim()
                                : (preset?.name ?? 'Post'));
                        final String mode = isCollection
                            ? (collection.thumbnailMode ??
                                collection.firstItem?.mode ??
                                '2d')
                            : (preset?.thumbnailMode ?? preset?.mode ?? '2d');
                        final Map<String, dynamic> payload = isCollection
                            ? (collection.thumbnailPayload.isNotEmpty
                                ? collection.thumbnailPayload
                                : (collection.firstItem?.snapshot ??
                                    const <String, dynamic>{}))
                            : ((preset?.thumbnailPayload.isNotEmpty == true)
                                ? preset!.thumbnailPayload
                                : (preset?.payload ??
                                    const <String, dynamic>{}));
                        final String kind = entry['kind']?.toString() ?? '';
                        final String meta = switch (kind) {
                          'saved_collection' => 'Saved collection',
                          'watch_later_collection' => 'Watch later',
                          'watch_later_post' => 'Watch later',
                          _ => 'Saved post',
                        };
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (isCollection) {
                              _openCollection(collection);
                              return;
                            }
                            if (!isCollection && preset != null) {
                              _openPost(preset);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _GridPresetPreview(
                                      mode: mode,
                                      payload: payload,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$meta · ${_friendlyTime(entry['createdAt'] as DateTime)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color profilePanelColor =
        isDark ? const Color(0xFF1E1E1E) : cs.surface;
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading profile...');
    }

    if (_profile == null) {
      return Center(
        child: Text(
          'Profile unavailable',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: widget.topInset),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: profilePanelColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage: (_profile!.avatarUrl != null &&
                                _profile!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_profile!.avatarUrl!)
                            : null,
                        backgroundColor: cs.surfaceContainerHighest,
                        child: (_profile!.avatarUrl == null ||
                                _profile!.avatarUrl!.isEmpty)
                            ? Icon(Icons.person,
                                color: cs.onSurfaceVariant, size: 34)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile!.fullName?.isNotEmpty == true
                                  ? _profile!.fullName!
                                  : 'No full name set',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _profile!.username?.isNotEmpty == true
                                  ? '@${_profile!.username}'
                                  : '@set_username',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _profile!.email,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FilledButton.tonal(
                            onPressed: _editProfile,
                            child: const Text('Edit Profile'),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _confirmSignOut,
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_profile!.bio.isNotEmpty)
                    Text(
                      _profile!.bio,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _countBlock('Followers', _stats.followersCount),
                      _countBlock('Following', _stats.followingCount),
                      _countBlock('Posts', _stats.postsCount),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              indicatorColor: cs.primary,
              labelColor: cs.onSurface,
              unselectedLabelColor: cs.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Saved'),
                Tab(text: 'My Posts'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSavedUnifiedTab(),
                  _PresetListView(
                    presets: _posts,
                    emptyMessage: 'No posts yet.',
                    onTap: _openPost,
                  ),
                  _PresetListView(
                    presets: _history,
                    emptyMessage: 'No history yet.',
                    onTap: _openPost,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBlock(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PresetListView extends StatelessWidget {
  const _PresetListView({
    required this.presets,
    required this.emptyMessage,
    required this.onTap,
  });

  final List<RenderPreset> presets;
  final String emptyMessage;
  final Future<void> Function(RenderPreset preset) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (presets.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final preset = presets[index];
        return ListTile(
          tileColor: cs.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(preset.name, style: TextStyle(color: cs.onSurface)),
          subtitle: Text(
            '${preset.mode.toUpperCase()} · ${_friendlyTime(preset.createdAt)}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: () => onTap(preset),
        );
      },
    );
  }
}

class _WatchLaterListView extends StatelessWidget {
  const _WatchLaterListView({
    required this.items,
    required this.onOpenPost,
    required this.onOpenCollection,
  });

  final List<WatchLaterItem> items;
  final Future<void> Function(RenderPreset preset) onOpenPost;
  final Future<void> Function(CollectionSummary summary) onOpenCollection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Watch Later is empty.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isCollection = item.type == WatchLaterTargetType.collection;
        final String title = isCollection
            ? (item.collection?.name ?? 'Collection')
            : (item.post?.title.isNotEmpty == true
                ? item.post!.title
                : (item.post?.name ?? 'Post'));
        final String subtitle = isCollection
            ? 'Collection · ${_friendlyTime(item.createdAt)}'
            : '${item.post?.mode.toUpperCase() ?? 'POST'} · ${_friendlyTime(item.createdAt)}';
        return ListTile(
          tileColor: cs.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(
            isCollection
                ? Icons.collections_bookmark_outlined
                : Icons.play_circle_outline,
            color: cs.onSurfaceVariant,
          ),
          title: Text(title, style: TextStyle(color: cs.onSurface)),
          subtitle:
              Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: () {
            if (isCollection && item.collection != null) {
              onOpenCollection(item.collection!);
            } else if (!isCollection && item.post != null) {
              onOpenPost(item.post!);
            }
          },
        );
      },
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({required this.profile});

  final AppUserProfile profile;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final AppRepository _repository = AppRepository.instance;

  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _bioController;

  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.profile.username ?? '');
    _fullNameController =
        TextEditingController(text: widget.profile.fullName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio);
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final file = await pickDeviceFile(accept: 'image/*');
      if (file == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }
      final String url = await _repository.uploadProfileAvatar(
        bytes: file.bytes,
        fileName: file.name,
        contentType: file.contentType,
      );
      await _repository.updateCurrentProfile(avatarUrl: url);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateCurrentProfile(
        username: _usernameController.text,
        fullName: _fullNameController.text,
        bio: _bioController.text,
        avatarUrl: _avatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Edit Profile'),
      ),
      body: Center(
        child: SizedBox(
          width: 560,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? NetworkImage(_avatarUrl!)
                            : null,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person,
                            color: cs.onSurfaceVariant, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _uploadingAvatar ? null : _uploadAvatar,
                    child: Text(
                      _uploadingAvatar
                          ? 'Uploading...'
                          : 'Upload Profile Picture',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                controller: TextEditingController(text: widget.profile.email),
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  const _ChatTab({super.key, required this.topInset});

  final double topInset;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<ChatSummary> _chats = const <ChatSummary>[];
  ChatSummary? _activeChat;
  List<AppUserProfile> _activeMembers = const <AppUserProfile>[];
  List<RenderPreset> _shareablePresets = const <RenderPreset>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    debugPrint('Disposing ChatTab');
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap({String? preferredChatId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await _repository.fetchChatsForCurrentUser();
      final shareables = await _repository.fetchRecentViewedPresetsForSharing();

      ChatSummary? active;
      List<AppUserProfile> members = const <AppUserProfile>[];
      if (chats.isNotEmpty) {
        final String? currentId = preferredChatId ?? _activeChat?.id;
        active = _chatById(chats, currentId) ?? chats.first;
        members = await _repository.fetchChatMembers(active.id);
      }

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _shareablePresets = shareables;
        _activeChat = active;
        _activeMembers = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  ChatSummary? _chatById(List<ChatSummary> chats, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final ChatSummary chat in chats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  void _touchChat(String chatId, String messagePreview) {
    final List<ChatSummary> updated = _chats
        .map((ChatSummary chat) => chat.id == chatId
            ? ChatSummary(
                id: chat.id,
                isGroup: chat.isGroup,
                name: chat.name,
                members: chat.members,
                lastMessage: messagePreview,
                lastMessageAt: DateTime.now(),
              )
            : chat)
        .toList();
    updated.sort((a, b) {
      final DateTime aTime =
          a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime =
          b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    _chats = updated;
  }

  Future<void> _selectChat(ChatSummary chat) async {
    final members = await _repository.fetchChatMembers(chat.id);
    if (!mounted) return;
    setState(() {
      _activeChat = chat;
      _activeMembers = members;
    });
  }

  Future<void> _sendMessage() async {
    final chat = _activeChat;
    if (chat == null) return;

    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await _repository.sendChatMessage(chatId: chat.id, body: text);
      if (!mounted) return;
      setState(() => _touchChat(chat.id, text));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _sharePreset(RenderPreset preset) async {
    final chat = _activeChat;
    if (chat == null) return;
    try {
      await _repository.sendChatMessage(
        chatId: chat.id,
        body: 'Shared a preset',
        sharedPresetId: preset.id,
      );
      if (!mounted) return;
      setState(() => _touchChat(chat.id, 'Shared a preset'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share preset: $e')),
      );
    }
  }

  Future<void> _openSharedPreset(String presetId) async {
    final preset = await _repository.fetchPresetByRouteId(presetId);
    if (!mounted) return;
    if (preset != null) {
      await Navigator.pushNamed(context, buildPostRoutePathForPreset(preset));
      return;
    }
    await Navigator.pushNamed(
      context,
      '/post/${Uri.encodeComponent(presetId)}',
    );
  }

  Future<void> _newDirectChat() async {
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Start Direct Chat'),
    );
    if (profile == null) return;
    try {
      final chatId = await _repository.createOrGetDirectChat(profile.userId);
      await _bootstrap(preferredChatId: chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start direct chat: $e')),
      );
    }
  }

  Future<void> _newGroupChat() async {
    final result = await showDialog<_GroupChatPayload>(
      context: context,
      builder: (context) => const _GroupChatDialog(),
    );
    if (result == null) return;
    try {
      final chatId = await _repository.createGroupChat(
        name: result.name,
        memberIds: result.memberIds,
      );
      if (chatId.isEmpty) {
        throw Exception('Empty chat id returned by server.');
      }
      await _bootstrap(preferredChatId: chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = isDark ? const Color(0xFF1E1E1E) : cs.surface;
    final Color messageInputColor =
        isDark ? const Color(0xFF1E1E1E) : cs.surfaceContainerHighest;
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading chats...');
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _bootstrap,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, widget.topInset, 10, 10),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: _newDirectChat,
                          child: const Text('New Direct'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _newGroupChat,
                          child: const Text('New Group'),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: cs.outline.withValues(alpha: 0.22)),
                  Expanded(
                    child: _chats.isEmpty
                        ? Center(
                            child: Text(
                              'No chats yet',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final bool active = _activeChat?.id == chat.id;
                              return ListTile(
                                selected: active,
                                selectedTileColor:
                                    cs.primary.withValues(alpha: 0.14),
                                title: Text(
                                  chat.titleFor(
                                      _repository.currentUser?.id ?? ''),
                                  style: TextStyle(color: cs.onSurface),
                                ),
                                subtitle: Text(
                                  chat.lastMessage ??
                                      (chat.isGroup
                                          ? 'Group chat'
                                          : 'Direct message'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                onTap: () => _selectChat(chat),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: _activeChat == null
                  ? Center(
                      child: Text(
                        'Select a chat',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.22)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _activeChat!.titleFor(
                                  _repository.currentUser?.id ?? '',
                                ),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<RenderPreset>(
                                tooltip: 'Share preset',
                                onSelected: _sharePreset,
                                color: cs.surfaceContainerHighest,
                                itemBuilder: (context) {
                                  if (_shareablePresets.isEmpty) {
                                    return const [
                                      PopupMenuItem<RenderPreset>(
                                        enabled: false,
                                        child: Text('No presets found'),
                                      ),
                                    ];
                                  }

                                  return _shareablePresets
                                      .take(20)
                                      .map(
                                        (preset) => PopupMenuItem<RenderPreset>(
                                          value: preset,
                                          child: Text(
                                            preset.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(Icons.share_outlined,
                                      color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<ChatMessageItem>>(
                            stream: _repository.streamMessagesForChat(
                              _activeChat!.id,
                            ),
                            builder: (context, snapshot) {
                              final messages =
                                  snapshot.data ?? const <ChatMessageItem>[];
                              if (messages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No messages yet',
                                    style:
                                        TextStyle(color: cs.onSurfaceVariant),
                                  ),
                                );
                              }

                              final String? me = _repository.currentUser?.id;
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final bool mine =
                                      me != null && msg.senderId == me;
                                  final AppUserProfile? author = _activeMembers
                                      .cast<AppUserProfile?>()
                                      .firstWhere(
                                        (p) =>
                                            p != null &&
                                            p.userId == msg.senderId,
                                        orElse: () => null,
                                      );

                                  return Align(
                                    alignment: mine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      constraints:
                                          const BoxConstraints(maxWidth: 420),
                                      decoration: BoxDecoration(
                                        color: mine
                                            ? cs.primary.withValues(alpha: 0.18)
                                            : panelColor.withValues(
                                                alpha: 0.95),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mine
                                                ? 'You'
                                                : (author?.displayName ??
                                                    'User'),
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (msg.body.trim().isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                msg.body,
                                                style: TextStyle(
                                                    color: cs.onSurface),
                                              ),
                                            ),
                                          if (msg.sharedPresetId != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openSharedPreset(
                                                  msg.sharedPresetId!,
                                                ),
                                                icon: const Icon(
                                                    Icons.open_in_new,
                                                    size: 16),
                                                label: const Text(
                                                    'Open shared preset'),
                                              ),
                                            ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              _friendlyTime(msg.createdAt),
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    filled: true,
                                    fillColor: messageInputColor.withValues(
                                        alpha: 0.4),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _sendMessage,
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePickerDialog extends StatefulWidget {
  const _ProfilePickerDialog({required this.title});

  final String title;

  @override
  State<_ProfilePickerDialog> createState() => _ProfilePickerDialogState();
}

class _ProfilePickerDialogState extends State<_ProfilePickerDialog> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  List<AppUserProfile> _profiles = const <AppUserProfile>[];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _search();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _search);
  }

  Future<void> _search() async {
    final int token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await _repository.searchProfiles(_searchController.text);
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text(widget.title, style: TextStyle(color: cs.onSurface)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search username/full name/email',
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 72,
                child: _TopEdgeLoadingPane(label: 'Searching users...'),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Search failed: $_error',
                  style: TextStyle(color: cs.error),
                ),
              )
            else if (_profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No users found.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 340,
                child: ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final p = _profiles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                        child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        p.displayName,
                        style: TextStyle(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        p.email,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupChatPayload {
  const _GroupChatPayload({required this.name, required this.memberIds});

  final String name;
  final List<String> memberIds;
}

class _GroupChatDialog extends StatefulWidget {
  const _GroupChatDialog();

  @override
  State<_GroupChatDialog> createState() => _GroupChatDialogState();
}

class _GroupChatDialogState extends State<_GroupChatDialog> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AppUserProfile> _profiles = const <AppUserProfile>[];
  final Set<String> _selected = <String>{};
  Timer? _debounce;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _loadProfiles);
  }

  Future<void> _loadProfiles() async {
    final int token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await _repository.searchProfiles(
        _searchController.text,
        limit: 80,
      );
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool canCreate =
        _nameController.text.trim().isNotEmpty && _selected.isNotEmpty;
    final List<AppUserProfile> visibleProfiles = _profiles;
    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text('Create Group Chat', style: TextStyle(color: cs.onSurface)),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 72,
                child: _TopEdgeLoadingPane(label: 'Searching users...'),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Search failed: $_error',
                  style: TextStyle(color: cs.error),
                ),
              )
            else if (visibleProfiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No users found.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: visibleProfiles.length,
                  itemBuilder: (context, index) {
                    final p = visibleProfiles[index];
                    final bool checked = _selected.contains(p.userId);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(p.userId);
                          } else {
                            _selected.remove(p.userId);
                          }
                        });
                      },
                      activeColor: cs.primary,
                      checkColor: Colors.black,
                      title: Text(
                        p.displayName,
                        style: TextStyle(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        p.email,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canCreate
              ? () {
                  final String name = _nameController.text.trim();
                  Navigator.pop(
                    context,
                    _GroupChatPayload(
                        name: name, memberIds: _selected.toList()),
                  );
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PostCardComposerPage extends StatefulWidget {
  const _PostCardComposerPage.single({
    required this.name,
    required this.mode,
    required this.payload,
    this.existingPreset,
    this.editTarget = _ComposerEditTarget.card,
    this.startBlankCard = true,
  })  : kind = _ComposerKind.single,
        collectionId = null,
        collectionName = '',
        collectionDescription = '',
        items = const <CollectionDraftItem>[],
        published = true,
        tags = const <String>[],
        mentionUserIds = const <String>[],
        initialCardPayload = const <String, dynamic>{},
        initialCardMode = null;

  const _PostCardComposerPage.collection({
    this.collectionId,
    required this.collectionName,
    required this.collectionDescription,
    required this.tags,
    required this.mentionUserIds,
    required this.published,
    required this.items,
    this.initialCardPayload = const <String, dynamic>{},
    this.initialCardMode,
    this.editTarget = _ComposerEditTarget.card,
    this.startBlankCard = true,
  })  : kind = _ComposerKind.collection,
        existingPreset = null,
        name = '',
        mode = '',
        payload = const <String, dynamic>{};

  final _ComposerKind kind;
  final String name;
  final String mode;
  final Map<String, dynamic> payload;
  final RenderPreset? existingPreset;

  final String? collectionId;
  final String collectionName;
  final String collectionDescription;
  final List<String> tags;
  final List<String> mentionUserIds;
  final bool published;
  final List<CollectionDraftItem> items;
  final Map<String, dynamic> initialCardPayload;
  final String? initialCardMode;
  final _ComposerEditTarget editTarget;
  final bool startBlankCard;

  bool get isEdit {
    if (kind == _ComposerKind.single) return existingPreset != null;
    return collectionId != null && collectionId!.isNotEmpty;
  }

  @override
  State<_PostCardComposerPage> createState() => _PostCardComposerPageState();
}

class _PostCardComposerPageState extends State<_PostCardComposerPage> {
  final AppRepository _repository = AppRepository.instance;
  static const List<String> _fontOptions = <String>[
    'Poppins',
    'Roboto',
    'Montserrat',
    'Open Sans',
    'Lato',
    'Oswald',
    'Raleway',
    'Playfair Display',
    'Bebas Neue',
    'Pacifico',
  ];
  static const List<String> _aspectOptions = <String>[
    '16:9 (width:height)',
    '18:9 (width:height)',
    '21:9 (width:height)',
    '4:3 (width:height)',
    '1:1 (square)',
    '9:16 (height:width)',
    '3:4 (height:width)',
    '2.35:1 (width:height)',
    '1.85:1 (width:height)',
    '2.39:1 (width:height)',
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  final TextEditingController _mentionController = TextEditingController();

  final Set<String> _selectedMentionIds = <String>{};
  final Map<String, AppUserProfile> _selectedMentionProfiles =
      <String, AppUserProfile>{};

  List<AppUserProfile> _mentionResults = const <AppUserProfile>[];
  Timer? _mentionDebounce;
  int _mentionToken = 0;
  bool _mentionLoading = false;

  bool _submitting = false;
  bool _uploadingLayerImage = false;
  bool _isPublic = true;
  bool _showPublishStep = false;
  int _thumbnailIndex = 0;
  String? _selected2dLayerKey;
  String? _selected3dToken;
  late String _thumbnailMode;
  late Map<String, dynamic> _thumbnailPayload;
  List<CollectionDraftItem> _editableCollectionItems = <CollectionDraftItem>[];
  Map<String, dynamic>? _pullSourcePayload;
  String? _pullSourceMode;

  bool get _isCardEditor => widget.editTarget == _ComposerEditTarget.card;
  bool get _isDetailEditor => widget.editTarget == _ComposerEditTarget.detail;

  Map<String, dynamic> _default2DControls() {
    return <String, dynamic>{
      'scale': 1.2,
      'depth': 0.1,
      'shift': 0.025,
      'tilt': 0.0,
      'tiltSensitivity': 1.0,
      'sensitivity': 1.0,
      'deadZoneX': 0.0,
      'deadZoneY': 0.0,
      'deadZoneZ': 0.0,
      'deadZoneYaw': 0.0,
      'deadZonePitch': 0.0,
      'manualMode': false,
      'manualHeadX': 0.0,
      'manualHeadY': 0.0,
      'manualHeadZ': 0.2,
      'manualYaw': 0.0,
      'manualPitch': 0.0,
      'zBase': 0.2,
      'anchorHeadX': 0.0,
      'anchorHeadY': 0.0,
      'selectedAspect': '16:9 (width:height)',
    };
  }

  Map<String, dynamic> _blankPayloadForMode(String mode) {
    if (mode == '3d') {
      return PresetPayloadV2(
        mode: '3d',
        scene: <String, dynamic>{
          'models': <Map<String, dynamic>>[],
          'lights': <Map<String, dynamic>>[],
          'audios': <Map<String, dynamic>>[],
          'renderOrder': <String>[],
        },
        controls: <String, dynamic>{
          'manual-mode': false,
          'show-tracker': false,
          'camera-mode': 'orbit',
          'dz-x': 0.0,
          'dz-y': 0.0,
          'dz-z': 0.0,
          'dz-yaw': 0.0,
          'dz-pitch': 0.0,
        },
        meta: const <String, dynamic>{'editor': 'composer'},
      ).toMap();
    }
    return PresetPayloadV2(
      mode: '2d',
      scene: <String, dynamic>{
        'top_bezel': <String, dynamic>{
          'isRect': true,
          'bezelType': 'top',
          'order': -1000.0,
          'isVisible': true,
          'isLocked': true,
        },
        'bottom_bezel': <String, dynamic>{
          'isRect': true,
          'bezelType': 'bottom',
          'order': 1000.0,
          'isVisible': true,
          'isLocked': true,
        },
        'turning_point': <String, dynamic>{
          'x': 0.0,
          'y': 0.0,
          'scale': 1.0,
          'order': 0.0,
          'isVisible': false,
          'isLocked': true,
          'isText': false,
          'canShift': false,
          'canZoom': false,
          'canTilt': false,
          'minScale': 0.1,
          'maxScale': 5.0,
          'minX': -3000.0,
          'maxX': 3000.0,
          'minY': -3000.0,
          'maxY': 3000.0,
          'shiftSensMult': 1.0,
          'zoomSensMult': 1.0,
          'url': '',
        },
      },
      controls: _default2DControls(),
      meta: const <String, dynamic>{'editor': 'composer'},
    ).toMap();
  }

  @override
  void initState() {
    super.initState();
    if (widget.kind == _ComposerKind.single) {
      final RenderPreset? existing = widget.existingPreset;
      final String sourceMode = existing?.mode ?? widget.mode;
      final Map<String, dynamic> sourcePayload =
          existing?.payload ?? widget.payload;
      _titleController = TextEditingController(
        text:
            existing?.title.isNotEmpty == true ? existing!.title : widget.name,
      );
      _descriptionController =
          TextEditingController(text: existing?.description ?? '');
      _tagsController = TextEditingController(
        text: (existing?.tags ?? const <String>[]).join(' ').trim(),
      );
      _isPublic = existing?.isPublic ?? true;
      _pullSourceMode = sourceMode;
      _pullSourcePayload =
          jsonDecode(jsonEncode(sourcePayload)) as Map<String, dynamic>;
      if (_isDetailEditor) {
        _thumbnailMode = sourceMode;
        _thumbnailPayload =
            jsonDecode(jsonEncode(sourcePayload)) as Map<String, dynamic>;
      } else if (widget.isEdit && widget.startBlankCard) {
        _thumbnailMode = existing?.thumbnailMode ?? sourceMode;
        _thumbnailPayload = _blankPayloadForMode(_thumbnailMode);
      } else {
        _thumbnailMode = existing?.thumbnailMode ?? widget.mode;
        final payload = existing?.thumbnailPayload.isNotEmpty == true
            ? existing!.thumbnailPayload
            : widget.payload;
        _thumbnailPayload =
            jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      }
      _selectedMentionIds.addAll(existing?.mentionUserIds ?? const <String>[]);
    } else {
      _editableCollectionItems = widget.items
          .map(
            (item) => CollectionDraftItem(
              mode: item.mode,
              name: item.name,
              snapshot:
                  jsonDecode(jsonEncode(item.snapshot)) as Map<String, dynamic>,
            ),
          )
          .toList();
      _titleController = TextEditingController(text: widget.collectionName);
      _descriptionController =
          TextEditingController(text: widget.collectionDescription);
      _tagsController = TextEditingController(text: widget.tags.join(' '));
      _selectedMentionIds.addAll(widget.mentionUserIds);
      _isPublic = widget.published;
      if (_editableCollectionItems.isNotEmpty) {
        _pullSourceMode = _editableCollectionItems.first.mode;
        _pullSourcePayload =
            jsonDecode(jsonEncode(_editableCollectionItems.first.snapshot))
                as Map<String, dynamic>;
      }
      if (_editableCollectionItems.isNotEmpty) {
        if (_isDetailEditor) {
          _thumbnailMode = _editableCollectionItems.first.mode;
          _thumbnailPayload = jsonDecode(
            jsonEncode(_editableCollectionItems.first.snapshot),
          ) as Map<String, dynamic>;
        } else if (widget.isEdit && widget.startBlankCard) {
          _thumbnailMode =
              widget.initialCardMode ?? _editableCollectionItems.first.mode;
          _thumbnailPayload = _blankPayloadForMode(_thumbnailMode);
        } else {
          _thumbnailMode =
              widget.initialCardMode ?? _editableCollectionItems.first.mode;
          final payload = widget.initialCardPayload.isNotEmpty
              ? widget.initialCardPayload
              : _editableCollectionItems.first.snapshot;
          _thumbnailPayload =
              jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
        }
      } else {
        _thumbnailMode = '2d';
        _thumbnailPayload = _blankPayloadForMode('2d');
      }
    }
    _ensure3DWindowLayerDefaults();
    _ensureTurningPointLayer();
    _ensure2DLayerSelection();
    _ensure3DSelection();
    _mentionController.addListener(_onMentionQueryChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _mentionController.removeListener(_onMentionQueryChanged);
    _mentionController.dispose();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  void _onMentionQueryChanged() {
    _mentionDebounce?.cancel();
    _mentionDebounce =
        Timer(const Duration(milliseconds: 260), _searchMentions);
  }

  Future<void> _searchMentions() async {
    final query = _mentionController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _mentionLoading = false;
        _mentionResults = const <AppUserProfile>[];
      });
      return;
    }
    final int token = ++_mentionToken;
    setState(() => _mentionLoading = true);
    try {
      final results = await _repository.searchMentionTargets(query, limit: 12);
      if (!mounted || token != _mentionToken) return;
      setState(() {
        _mentionLoading = false;
        _mentionResults = results
            .where((profile) => !_selectedMentionIds.contains(profile.userId))
            .toList();
      });
    } catch (_) {
      if (!mounted || token != _mentionToken) return;
      setState(() {
        _mentionLoading = false;
        _mentionResults = const <AppUserProfile>[];
      });
    }
  }

  void _addMention(AppUserProfile profile) {
    setState(() {
      _selectedMentionIds.add(profile.userId);
      _selectedMentionProfiles[profile.userId] = profile;
      _mentionResults = _mentionResults
          .where((element) => element.userId != profile.userId)
          .toList();
      _mentionController.clear();
    });
  }

  void _removeMention(String userId) {
    setState(() {
      _selectedMentionIds.remove(userId);
      _selectedMentionProfiles.remove(userId);
    });
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('#') ? e : '#$e')
        .toSet()
        .toList();
  }

  void _persistActiveCollectionItemSnapshot() {
    if (widget.kind != _ComposerKind.collection || !_isDetailEditor) return;
    if (_thumbnailIndex < 0 ||
        _thumbnailIndex >= _editableCollectionItems.length) {
      return;
    }
    _editableCollectionItems[_thumbnailIndex] = CollectionDraftItem(
      mode: _thumbnailMode,
      name: _editableCollectionItems[_thumbnailIndex].name,
      snapshot:
          jsonDecode(jsonEncode(_thumbnailPayload)) as Map<String, dynamic>,
    );
  }

  void _setThumbnailFromCollectionIndex(int index) {
    if (index < 0 || index >= _editableCollectionItems.length) return;
    _persistActiveCollectionItemSnapshot();
    final item = _editableCollectionItems[index];
    _pullSourceMode = item.mode;
    _pullSourcePayload =
        jsonDecode(jsonEncode(item.snapshot)) as Map<String, dynamic>;
    setState(() {
      _thumbnailIndex = index;
      _thumbnailMode = item.mode;
      _thumbnailPayload =
          jsonDecode(jsonEncode(item.snapshot)) as Map<String, dynamic>;
      _ensure3DWindowLayerDefaults();
      _ensureTurningPointLayer();
      _ensure2DLayerSelection();
      _ensure3DSelection();
    });
  }

  void _pullFromSourcePayload() {
    final source = _pullSourcePayload;
    final sourceMode = _pullSourceMode;
    if (source == null || sourceMode == null || sourceMode.isEmpty) return;
    setState(() {
      _thumbnailMode = sourceMode;
      _thumbnailPayload =
          jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      _ensure3DWindowLayerDefaults();
      _ensureTurningPointLayer();
      _ensure2DLayerSelection();
      _ensure3DSelection();
    });
  }

  void _ensure3DWindowLayerDefaults() {
    if (_thumbnailMode != '3d') return;
    final dynamic sceneRaw = _thumbnailPayload['scene'];
    if (sceneRaw is! Map) return;
    final Map<String, dynamic> scene = Map<String, dynamic>.from(sceneRaw);
    final Map<String, dynamic> controls = _thumbnail3DControls();
    bool changed = false;

    final dynamic modelsRaw = scene['models'];
    if (modelsRaw is List) {
      final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
      for (int i = 0; i < modelsRaw.length; i++) {
        final item = modelsRaw[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if ((map['id']?.toString().trim().isEmpty ?? true)) {
          map['id'] = 'model_$i';
          changed = true;
        }
        if ((map['windowLayer']?.toString().isEmpty ?? true)) {
          map['windowLayer'] = 'inside';
          changed = true;
        }
        normalized.add(map);
      }
      scene['models'] = normalized;
    }

    final dynamic lightsRaw = scene['lights'];
    if (lightsRaw is List) {
      final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
      for (int i = 0; i < lightsRaw.length; i++) {
        final item = lightsRaw[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if ((map['id']?.toString().trim().isEmpty ?? true)) {
          map['id'] = 'light_$i';
          changed = true;
        }
        if ((map['windowLayer']?.toString().isEmpty ?? true)) {
          map['windowLayer'] = 'inside';
          changed = true;
        }
        normalized.add(map);
      }
      scene['lights'] = normalized;
    }

    final dynamic audiosRaw = scene['audios'];
    if (audiosRaw is List) {
      final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
      for (int i = 0; i < audiosRaw.length; i++) {
        final item = audiosRaw[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if ((map['id']?.toString().trim().isEmpty ?? true)) {
          map['id'] = 'audio_$i';
          changed = true;
        }
        if ((map['windowLayer']?.toString().isEmpty ?? true)) {
          map['windowLayer'] = 'inside';
          changed = true;
        }
        normalized.add(map);
      }
      scene['audios'] = normalized;
    }

    final List<String> availableTokens = <String>[
      ..._sceneEntityTokens(scene),
    ];
    final dynamic renderOrderRaw = scene['renderOrder'];
    final List<String> renderOrder = renderOrderRaw is List
        ? renderOrderRaw.map((e) => e.toString()).toList()
        : <String>[];
    final List<String> sanitized =
        renderOrder.where((token) => availableTokens.contains(token)).toList();
    for (final token in availableTokens) {
      if (!sanitized.contains(token)) {
        sanitized.add(token);
      }
    }
    if (!const ListEquality<String>().equals(renderOrder, sanitized)) {
      scene['renderOrder'] = sanitized;
      changed = true;
    }

    final Map<String, dynamic> migratedControls =
        Map<String, dynamic>.from(controls);
    if (migratedControls.containsKey('manualMode') &&
        !migratedControls.containsKey('manual-mode')) {
      migratedControls['manual-mode'] = migratedControls['manualMode'];
      changed = true;
    }
    if (migratedControls.containsKey('deadZoneX') &&
        !migratedControls.containsKey('dz-x')) {
      migratedControls['dz-x'] = migratedControls['deadZoneX'];
      changed = true;
    }
    if (migratedControls.containsKey('deadZoneY') &&
        !migratedControls.containsKey('dz-y')) {
      migratedControls['dz-y'] = migratedControls['deadZoneY'];
      changed = true;
    }
    if (migratedControls.containsKey('deadZoneZ') &&
        !migratedControls.containsKey('dz-z')) {
      migratedControls['dz-z'] = migratedControls['deadZoneZ'];
      changed = true;
    }
    if (migratedControls.containsKey('deadZoneYaw') &&
        !migratedControls.containsKey('dz-yaw')) {
      migratedControls['dz-yaw'] = migratedControls['deadZoneYaw'];
      changed = true;
    }
    if (migratedControls.containsKey('deadZonePitch') &&
        !migratedControls.containsKey('dz-pitch')) {
      migratedControls['dz-pitch'] = migratedControls['deadZonePitch'];
      changed = true;
    }
    void ensureControlDefault(String key, dynamic value) {
      if (!migratedControls.containsKey(key)) {
        migratedControls[key] = value;
        changed = true;
      }
    }

    void ensureSceneDefault(String key, dynamic value) {
      if (!scene.containsKey(key)) {
        scene[key] = value;
        changed = true;
      }
    }

    ensureControlDefault('camera-mode', 'orbit');
    ensureControlDefault('manual-mode', false);
    ensureControlDefault('show-tracker', false);
    ensureControlDefault('dz-x', 0.0);
    ensureControlDefault('dz-y', 0.0);
    ensureControlDefault('dz-z', 0.0);
    ensureControlDefault('dz-yaw', 0.0);
    ensureControlDefault('dz-pitch', 0.0);
    ensureControlDefault('head-x', 0.0);
    ensureControlDefault('head-y', 0.0);
    ensureControlDefault('z-value', 0.2);
    ensureControlDefault('yaw', 0.0);
    ensureControlDefault('pitch', 0.0);

    ensureSceneDefault('sunIntensity', 2.0);
    ensureSceneDefault('ambLight', 0.5);
    ensureSceneDefault('bloomIntensity', 1.0);
    ensureSceneDefault('shadowQuality', '512');
    ensureSceneDefault('shadowSoftness', 1.0);
    ensureSceneDefault('envRot', 0.0);
    ensureSceneDefault('initPos', <double>[0, 2, 10]);
    ensureSceneDefault('initRot', <double>[0, 0, 0]);

    if (!changed) return;
    _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
      ..['scene'] = scene
      ..['controls'] = migratedControls;
  }

  List<String> _sceneEntityTokens(Map<String, dynamic> scene) {
    final List<String> tokens = <String>[];
    final dynamic models = scene['models'];
    if (models is List) {
      for (final item in models) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        if (id.isEmpty) continue;
        tokens.add('model:$id');
      }
    }
    final dynamic lights = scene['lights'];
    if (lights is List) {
      for (final item in lights) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        if (id.isEmpty) continue;
        tokens.add('light:$id');
      }
    }
    final dynamic audios = scene['audios'];
    if (audios is List) {
      for (final item in audios) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        if (id.isEmpty) continue;
        tokens.add('audio:$id');
      }
    }
    return tokens;
  }

  void _ensure2DLayerSelection() {
    if (_thumbnailMode != '2d') {
      _selected2dLayerKey = null;
      return;
    }
    final Map<String, dynamic> scene = _thumbnail2DScene();
    if (scene.isEmpty) {
      _selected2dLayerKey = null;
      return;
    }
    if (_selected2dLayerKey != null && scene.containsKey(_selected2dLayerKey)) {
      return;
    }
    final List<String> keys = scene.entries
        .where((e) => e.value is Map<String, dynamic> || e.value is Map)
        .map((e) => e.key.toString())
        .toList();
    _selected2dLayerKey = keys.isEmpty ? null : keys.first;
  }

  Map<String, dynamic> _thumbnail2DScene() {
    final dynamic rawScene = _thumbnailPayload['scene'];
    if (rawScene is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawScene);
    }
    if (rawScene is Map) return Map<String, dynamic>.from(rawScene);
    return <String, dynamic>{};
  }

  void _ensureTurningPointLayer() {
    if (_thumbnailMode != '2d') return;
    final Map<String, dynamic> scene = _thumbnail2DScene();
    if (scene.containsKey('turning_point') &&
        scene['turning_point'] is Map<String, dynamic>) {
      return;
    }
    final List<double> orders = scene.entries
        .where((entry) => entry.value is Map && entry.key != 'turning_point')
        .map((entry) => _toDouble((entry.value as Map)['order'], 0))
        .toList()
      ..sort();
    final int midIndex = orders.isEmpty
        ? 0
        : ((orders.length / 2).floor()).clamp(0, orders.length - 1).toInt();
    final double midpointOrder = orders.isEmpty ? 0 : orders[midIndex];
    scene['turning_point'] = <String, dynamic>{
      'x': 0.0,
      'y': 0.0,
      'scale': 1.0,
      'order': midpointOrder,
      'isVisible': false,
      'isLocked': true,
      'isText': false,
      'canShift': false,
      'canZoom': false,
      'canTilt': false,
      'minScale': 0.1,
      'maxScale': 5.0,
      'minX': -3000.0,
      'maxX': 3000.0,
      'minY': -3000.0,
      'maxY': 3000.0,
      'shiftSensMult': 1.0,
      'zoomSensMult': 1.0,
      'url': '',
    };
    _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
      ..['scene'] = scene;
  }

  Map<String, dynamic> _thumbnailControls() {
    final dynamic raw = _thumbnailPayload['controls'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<String> _thumbnail2DLayerKeys() {
    final scene = _thumbnail2DScene();
    final keys = scene.entries
        .where((e) => e.value is Map<String, dynamic> || e.value is Map)
        .map((e) => e.key.toString())
        .toList();
    keys.sort((a, b) {
      final aOrder = _toDouble((scene[a] as Map?)?['order'], 0);
      final bOrder = _toDouble((scene[b] as Map?)?['order'], 0);
      final int cmp = aOrder.compareTo(bOrder);
      if (cmp != 0) return cmp;
      if (a == 'turning_point' && b != 'turning_point') return 1;
      if (b == 'turning_point' && a != 'turning_point') return -1;
      return a.compareTo(b);
    });
    return keys;
  }

  Map<String, dynamic>? _selected2DLayerMap() {
    final key = _selected2dLayerKey;
    if (key == null) return null;
    final scene = _thumbnail2DScene();
    final raw = scene[key];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  bool _isUtilityLayerKey(String? key) {
    if (key == null) return false;
    return key == 'turning_point' ||
        key == 'top_bezel' ||
        key == 'bottom_bezel';
  }

  void _set2DLayerField(String key, String field, dynamic value) {
    final scene = _thumbnail2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    final layer = Map<String, dynamic>.from(raw);
    layer[field] = value;
    scene[key] = layer;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _ensure2DLayerSelection();
    });
  }

  void _set2DControlField(String field, dynamic value) {
    final controls = _thumbnailControls();
    controls[field] = value;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['controls'] = controls;
    });
  }

  void _setTurningPointOrder(double value) {
    final scene = _thumbnail2DScene();
    final raw = scene['turning_point'];
    if (raw is! Map) return;
    scene['turning_point'] = Map<String, dynamic>.from(raw)..['order'] = value;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
    });
  }

  Future<void> _promptAdd2DImageUrl() async {
    final TextEditingController controller = TextEditingController();
    final String? url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.png',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) return;
    _add2DLayer(textLayer: false, imageUrl: url.trim());
  }

  Future<void> _upload2DImageFromDevice() async {
    if (_uploadingLayerImage) return;
    setState(() => _uploadingLayerImage = true);
    try {
      final picked = await pickDeviceFile(accept: 'image/*');
      if (picked == null) return;
      final String publicUrl = await _repository.uploadAssetBytes(
        bytes: picked.bytes,
        fileName: picked.name,
        contentType: picked.contentType,
        folder: 'composer-layers',
      );
      if (!mounted) return;
      _add2DLayer(
        textLayer: false,
        imageUrl: publicUrl,
        sourceName: picked.name,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded and layer added.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingLayerImage = false);
      }
    }
  }

  void _recenterComposerParallax() {
    final frame = TrackingService.instance.frameNotifier.value;
    final controls = _thumbnailControls();
    final double zBase = frame.headZ.abs() < 0.000001
        ? _toDouble(controls['zBase'], 0.2)
        : frame.headZ;
    controls['anchorHeadX'] = frame.headX;
    controls['anchorHeadY'] = frame.headY;
    controls['zBase'] = zBase;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['controls'] = controls;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parallax baseline recentered.')),
    );
  }

  void _handle2DPreviewPanUpdate(DragUpdateDetails details) {
    if (_thumbnailMode != '2d') return;
    final key = _selected2dLayerKey;
    if (key == null) return;
    final scene = _thumbnail2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    final layer = Map<String, dynamic>.from(raw);
    if (layer['isLocked'] == true) return;
    final double x = _toDouble(layer['x'], 0) + details.delta.dx;
    final double y = _toDouble(layer['y'], 0) + details.delta.dy;
    layer['x'] = x;
    layer['y'] = y;
    scene[key] = layer;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
    });
  }

  void _handle2DPreviewPointerSignal(PointerSignalEvent event) {
    if (_thumbnailMode != '2d' || event is! PointerScrollEvent) return;
    final key = _selected2dLayerKey;
    if (key == null) return;
    final scene = _thumbnail2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    final layer = Map<String, dynamic>.from(raw);
    if (layer['isLocked'] == true) return;
    final double current = _toDouble(layer['scale'], 1);
    layer['scale'] = (current - event.scrollDelta.dy / 700).clamp(0.05, 10.0);
    scene[key] = layer;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
    });
  }

  String _next2DLayerKey(String prefix) {
    String sanitized = prefix.trim();
    if (sanitized.isEmpty) sanitized = 'layer_';
    sanitized = sanitized
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    if (!sanitized.endsWith('_')) {
      sanitized = '${sanitized}_';
    }
    final scene = _thumbnail2DScene();
    int index = 1;
    while (scene.containsKey('$sanitized$index')) {
      index++;
    }
    return '$sanitized$index';
  }

  String _layerPrefixFromImageSource(String imageUrl) {
    final String trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return 'layer_';
    try {
      final Uri uri = Uri.parse(trimmed);
      String candidate = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : trimmed.split('/').last;
      if (candidate.isEmpty) return 'layer_';
      candidate = Uri.decodeComponent(candidate);
      candidate = candidate.split('?').first.split('#').first;
      final int dot = candidate.lastIndexOf('.');
      if (dot > 0) {
        candidate = candidate.substring(0, dot);
      }
      candidate = candidate.trim();
      if (candidate.isEmpty) return 'layer_';
      return '${candidate}_';
    } catch (_) {
      final String fallback = trimmed.split('/').last.split('?').first;
      if (fallback.isEmpty) return 'layer_';
      final int dot = fallback.lastIndexOf('.');
      final String raw =
          dot > 0 ? fallback.substring(0, dot).trim() : fallback.trim();
      return raw.isEmpty ? 'layer_' : '${raw}_';
    }
  }

  void _normalize2DOrders(Map<String, dynamic> scene) {
    final keys = scene.entries
        .where((e) => e.key != 'turning_point' && e.value is Map)
        .map((e) => e.key)
        .toList();
    keys.sort((a, b) {
      final aOrder = _toDouble((scene[a] as Map?)?['order'], 0);
      final bOrder = _toDouble((scene[b] as Map?)?['order'], 0);
      return aOrder.compareTo(bOrder);
    });
    for (int i = 0; i < keys.length; i++) {
      final raw = scene[keys[i]];
      if (raw is! Map) continue;
      final layer = Map<String, dynamic>.from(raw);
      layer['order'] = i;
      scene[keys[i]] = layer;
    }
  }

  void _reorder2DLayer(int oldIndex, int newIndex) {
    final scene = _thumbnail2DScene();
    final keys = _thumbnail2DLayerKeys();
    if (oldIndex < 0 || oldIndex >= keys.length) return;
    if (newIndex < 0 || newIndex > keys.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (keys.isEmpty) return;
    newIndex = newIndex.clamp(0, keys.length - 1);
    final moved = keys.removeAt(oldIndex);
    keys.insert(newIndex, moved);
    for (int i = 0; i < keys.length; i++) {
      final raw = scene[keys[i]];
      if (raw is! Map) continue;
      final layer = Map<String, dynamic>.from(raw);
      layer['order'] = i;
      scene[keys[i]] = layer;
    }
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _selected2dLayerKey = moved;
    });
  }

  void _add2DLayer({
    required bool textLayer,
    String imageUrl = '',
    String sourceName = '',
  }) {
    final scene = _thumbnail2DScene();
    if (!scene.containsKey('turning_point')) {
      scene['turning_point'] = <String, dynamic>{
        'x': 0.0,
        'y': 0.0,
        'scale': 1.0,
        'order': 0.0,
        'isVisible': false,
        'isLocked': true,
        'isText': false,
        'canShift': false,
        'canZoom': false,
        'canTilt': false,
        'minScale': 0.1,
        'maxScale': 5.0,
        'minX': -3000.0,
        'maxX': 3000.0,
        'minY': -3000.0,
        'maxY': 3000.0,
        'shiftSensMult': 1.0,
        'zoomSensMult': 1.0,
        'url': '',
      };
    }
    final String inferredSource =
        sourceName.trim().isNotEmpty ? sourceName.trim() : imageUrl;
    final key = _next2DLayerKey(
      textLayer ? 'text_' : _layerPrefixFromImageSource(inferredSource),
    );
    _normalize2DOrders(scene);
    final int order = _thumbnail2DLayerKeys().length;
    final Map<String, dynamic> layer = <String, dynamic>{
      'x': 0.0,
      'y': 0.0,
      'scale': 1.0,
      'order': order,
      'isVisible': true,
      'isLocked': false,
      'isText': textLayer,
      'canShift': true,
      'canZoom': true,
      'canTilt': true,
      'minScale': 0.1,
      'maxScale': 5.0,
      'minX': -3000.0,
      'maxX': 3000.0,
      'minY': -3000.0,
      'maxY': 3000.0,
      'shiftSensMult': 1.0,
      'zoomSensMult': 1.0,
      if (textLayer) ...{
        'textValue': 'New Text',
        'fontSize': 40.0,
        'fontWeightIndex': 4,
        'isItalic': false,
        'shadowBlur': 0.0,
        'shadowColorHex': '#000000',
        'strokeWidth': 0.0,
        'strokeColorHex': '#000000',
        'textColorHex': '#FFFFFF',
        'fontFamily': 'Poppins',
      } else ...{
        'url': imageUrl,
      },
    };
    scene[key] = layer;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _selected2dLayerKey = key;
    });
  }

  void _duplicateSelected2DLayer() {
    final key = _selected2dLayerKey;
    if (key == null || _isUtilityLayerKey(key)) return;
    final scene = _thumbnail2DScene();
    final raw = scene[key];
    if (raw is! Map) return;
    _normalize2DOrders(scene);
    final copyKey = _next2DLayerKey('${key}_copy_');
    final Map<String, dynamic> copy =
        jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    copy['order'] = _thumbnail2DLayerKeys().length;
    scene[copyKey] = copy;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _selected2dLayerKey = copyKey;
    });
  }

  void _deleteSelected2DLayer() {
    final key = _selected2dLayerKey;
    if (key == null || _isUtilityLayerKey(key)) return;
    final scene = _thumbnail2DScene();
    scene.remove(key);
    _normalize2DOrders(scene);
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _ensure2DLayerSelection();
    });
  }

  Map<String, dynamic> _thumbnail3DScene() {
    final dynamic sceneRaw = _thumbnailPayload['scene'];
    if (sceneRaw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(sceneRaw);
    }
    if (sceneRaw is Map) return Map<String, dynamic>.from(sceneRaw);
    return <String, dynamic>{};
  }

  String _sceneKeyForType(String type) {
    switch (type) {
      case 'model':
        return 'models';
      case 'light':
        return 'lights';
      case 'audio':
        return 'audios';
      default:
        return 'models';
    }
  }

  List<Map<String, dynamic>> _listForEntityType(
      Map<String, dynamic> scene, String type) {
    final dynamic raw = scene[_sceneKeyForType(type)];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .map((e) =>
            e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }

  void _setListForEntityType(
    Map<String, dynamic> scene,
    String type,
    List<Map<String, dynamic>> list,
  ) {
    scene[_sceneKeyForType(type)] = list;
  }

  List<String> _ordered3dEntityTokens([Map<String, dynamic>? inputScene]) {
    final scene = inputScene ?? _thumbnail3DScene();
    final available = _sceneEntityTokens(scene);
    final dynamic rawOrder = scene['renderOrder'];
    final List<String> stored = rawOrder is List
        ? rawOrder.map((e) => e.toString()).toList()
        : <String>[];
    final List<String> ordered =
        stored.where((token) => available.contains(token)).toList();
    for (final token in available) {
      if (!ordered.contains(token)) {
        ordered.add(token);
      }
    }
    return ordered;
  }

  void _ensure3DSelection() {
    if (_thumbnailMode != '3d') {
      _selected3dToken = null;
      return;
    }
    final List<String> tokens = _ordered3dEntityTokens();
    if (tokens.isEmpty) {
      _selected3dToken = null;
      return;
    }
    if (_selected3dToken != null && tokens.contains(_selected3dToken)) {
      return;
    }
    _selected3dToken = tokens.first;
  }

  Map<String, dynamic> _thumbnail3DControls() {
    final dynamic raw = _thumbnailPayload['controls'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  void _set3DControlField(String field, dynamic value) {
    final controls = _thumbnail3DControls();
    controls[field] = value;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['controls'] = controls;
    });
  }

  void _set3DSceneField(String field, dynamic value) {
    final scene = _thumbnail3DScene();
    scene[field] = value;
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _ensure3DSelection();
    });
  }

  void _set3DEntityField({
    required String token,
    required String field,
    required dynamic value,
  }) {
    final parts = token.split(':');
    if (parts.length != 2) return;
    final String type = parts.first;
    final String id = parts.last;
    final scene = _thumbnail3DScene();
    final list = _listForEntityType(scene, type);
    final int index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    list[index] = Map<String, dynamic>.from(list[index])..[field] = value;
    _setListForEntityType(scene, type, list);
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
    });
  }

  void _set3DEntityVectorComponent({
    required String token,
    required String field,
    required int index,
    required double value,
  }) {
    final entity = _entityByToken(_thumbnail3DScene(), token);
    if (entity == null) return;
    final dynamic raw = entity[field];
    final List<double> next = <double>[
      0,
      0,
      0,
    ];
    if (raw is List) {
      for (int i = 0; i < raw.length && i < next.length; i++) {
        next[i] = _toDouble(raw[i], 0);
      }
    } else if (field == 'scale' && raw is num) {
      final double uniform = raw.toDouble();
      for (int i = 0; i < next.length; i++) {
        next[i] = uniform;
      }
    }
    if (index >= 0 && index < next.length) {
      next[index] = value;
    }
    _set3DEntityField(token: token, field: field, value: next);
  }

  double _vectorComponent(
    dynamic raw,
    int index,
    double fallback,
  ) {
    if (raw is List && index >= 0 && index < raw.length) {
      return _toDouble(raw[index], fallback);
    }
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  void _set3DSceneVectorComponent({
    required String field,
    required int index,
    required double value,
    List<double> fallback = const <double>[0, 0, 0],
  }) {
    final scene = _thumbnail3DScene();
    final dynamic raw = scene[field];
    final List<double> next = <double>[
      fallback.length > 0 ? fallback[0] : 0,
      fallback.length > 1 ? fallback[1] : 0,
      fallback.length > 2 ? fallback[2] : 0,
    ];
    if (raw is List) {
      for (int i = 0; i < raw.length && i < next.length; i++) {
        next[i] = _toDouble(raw[i], next[i]);
      }
    }
    if (index >= 0 && index < next.length) {
      next[index] = value;
    }
    _set3DSceneField(field, next);
  }

  String _next3dEntityId(Map<String, dynamic> scene, String type) {
    final list = _listForEntityType(scene, type);
    int idx = 1;
    while (list.any((e) => (e['id'] ?? '').toString() == '${type}_$idx')) {
      idx++;
    }
    return '${type}_$idx';
  }

  Map<String, dynamic>? _entityByToken(
    Map<String, dynamic> scene,
    String token, {
    bool clone = true,
  }) {
    final parts = token.split(':');
    if (parts.length != 2) return null;
    final type = parts.first;
    final id = parts.last;
    final list = _listForEntityType(scene, type);
    for (final item in list) {
      if ((item['id'] ?? '').toString() == id) {
        return clone ? Map<String, dynamic>.from(item) : item;
      }
    }
    return null;
  }

  String _labelForEntityToken(String token, Map<String, dynamic> scene) {
    final parts = token.split(':');
    if (parts.length != 2) return token;
    final type = parts.first;
    final id = parts.last;
    final entity = _entityByToken(scene, token);
    final fallbackPrefix = type == 'model'
        ? 'Model'
        : type == 'light'
            ? 'Light'
            : 'Audio';
    final named = (entity?['name'] ?? entity?['id'] ?? '').toString().trim();
    if (named.isNotEmpty) return named;
    return '$fallbackPrefix $id';
  }

  void _set3dWindowLayerByToken({
    required String token,
    required String layer,
  }) {
    if (_thumbnailMode != '3d') return;
    final scene = _thumbnail3DScene();
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final list = _listForEntityType(scene, type);
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    list[index] = Map<String, dynamic>.from(list[index])
      ..['windowLayer'] = layer;
    _setListForEntityType(scene, type, list);
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = scene;
      _selected3dToken = token;
    });
  }

  void _reorder3dEntity(int oldIndex, int newIndex) {
    final scene = _thumbnail3DScene();
    final order = _ordered3dEntityTokens(scene);
    if (oldIndex < 0 || oldIndex >= order.length) return;
    if (newIndex < 0 || newIndex > order.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (order.isEmpty) return;
    newIndex = newIndex.clamp(0, order.length - 1);
    final token = order.removeAt(oldIndex);
    order.insert(newIndex, token);
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = (scene..['renderOrder'] = order);
      _selected3dToken = token;
    });
  }

  void _add3dEntity(String type) {
    final scene = _thumbnail3DScene();
    final list = _listForEntityType(scene, type);
    final id = _next3dEntityId(scene, type);
    if (type == 'model') {
      list.add(<String, dynamic>{
        'id': id,
        'name': 'Model $id',
        'url': '',
        'position': <double>[0, 0, 0],
        'rotation': <double>[0, 0, 0],
        'scale': <double>[1, 1, 1],
        'visible': true,
        'windowLayer': 'inside',
      });
    } else if (type == 'light') {
      list.add(<String, dynamic>{
        'id': id,
        'color': 'ffffff',
        'intensity': 10,
        'position': <double>[0, 5, 0],
        'scale': 1,
        'ghost': false,
        'windowLayer': 'inside',
      });
    } else {
      list.add(<String, dynamic>{
        'id': id,
        'url': '',
        'volume': 1,
        'position': <double>[0, 0, 0],
        'ghost': false,
        'windowLayer': 'inside',
      });
    }
    _setListForEntityType(scene, type, list);
    final order = _ordered3dEntityTokens(scene)..add('$type:$id');
    final String newToken = '$type:$id';
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = (scene..['renderOrder'] = order.toSet().toList());
      _selected3dToken = newToken;
    });
  }

  void _duplicate3dEntity(String token) {
    final scene = _thumbnail3DScene();
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final list = _listForEntityType(scene, type);
    final index = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index < 0) return;
    final copy = Map<String, dynamic>.from(list[index]);
    final newId = _next3dEntityId(scene, type);
    copy['id'] = newId;
    list.insert(index + 1, copy);
    _setListForEntityType(scene, type, list);
    final order = _ordered3dEntityTokens(scene);
    final orderIndex = order.indexOf(token);
    if (orderIndex >= 0) {
      order.insert(orderIndex + 1, '$type:$newId');
    } else {
      order.add('$type:$newId');
    }
    final String newToken = '$type:$newId';
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = (scene..['renderOrder'] = order);
      _selected3dToken = newToken;
    });
  }

  void _delete3dEntity(String token) {
    final scene = _thumbnail3DScene();
    final parts = token.split(':');
    if (parts.length != 2) return;
    final type = parts.first;
    final id = parts.last;
    final list = _listForEntityType(scene, type);
    list.removeWhere((e) => (e['id'] ?? '').toString() == id);
    _setListForEntityType(scene, type, list);
    final order = _ordered3dEntityTokens(scene)..remove(token);
    setState(() {
      _thumbnailPayload = Map<String, dynamic>.from(_thumbnailPayload)
        ..['scene'] = (scene..['renderOrder'] = order);
      if (_selected3dToken == token) {
        _selected3dToken = order.isEmpty ? null : order.first;
      }
    });
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Widget _build3DWindowLayerPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scene = _thumbnail3DScene();
    final controls = _thumbnail3DControls();
    final List<String> tokens = _ordered3dEntityTokens(scene);
    final String? selectedToken =
        _selected3dToken != null && tokens.contains(_selected3dToken)
            ? _selected3dToken
            : (tokens.isEmpty ? null : tokens.first);
    final Map<String, dynamic>? selectedEntity =
        selectedToken == null ? null : _entityByToken(scene, selectedToken);
    final String selectedType = selectedToken?.split(':').first ?? '';

    bool asBool(dynamic value, [bool fallback = false]) {
      if (value is bool) return value;
      final String raw = value?.toString().toLowerCase() ?? '';
      if (raw == 'true') return true;
      if (raw == 'false') return false;
      return fallback;
    }

    final bool manualMode =
        asBool(controls['manual-mode']) || asBool(controls['manualMode']);

    final List<double> initPos = <double>[
      _vectorComponent(scene['initPos'], 0, 0),
      _vectorComponent(scene['initPos'], 1, 2),
      _vectorComponent(scene['initPos'], 2, 10),
    ];
    final List<double> initRot = <double>[
      _vectorComponent(scene['initRot'], 0, 0),
      _vectorComponent(scene['initRot'], 1, 0),
      _vectorComponent(scene['initRot'], 2, 0),
    ];

    final String shadowQuality = () {
      final raw = (scene['shadowQuality'] ?? controls['shadowQuality'] ?? '512')
          .toString();
      const valid = <String>{'256', '512', '1024', '2048'};
      return valid.contains(raw) ? raw : '512';
    }();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3D Card Editor',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Full 3D controls (entities, world/FX, camera, and tracking).',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _add3dEntity('model'),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Add Model'),
              ),
              OutlinedButton.icon(
                onPressed: () => _add3dEntity('light'),
                icon: const Icon(Icons.wb_incandescent_outlined, size: 16),
                label: const Text('Add Light'),
              ),
              OutlinedButton.icon(
                onPressed: () => _add3dEntity('audio'),
                icon: const Icon(Icons.graphic_eq_outlined, size: 16),
                label: const Text('Add Audio'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tokens.isEmpty)
            Text(
              'No 3D entities found. Add a model/light/audio to start.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: tokens.length,
                onReorder: _reorder3dEntity,
                itemBuilder: (context, index) {
                  final token = tokens[index];
                  final parts = token.split(':');
                  final type = parts.first;
                  final entity = _entityByToken(scene, token);
                  final String layer =
                      (entity?['windowLayer'] ?? 'inside').toString();
                  return InkWell(
                    key: ValueKey<String>('entity-$token'),
                    onTap: () => setState(() => _selected3dToken = token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedToken == token
                            ? cs.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _labelForEntityToken(token, scene),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Duplicate',
                                onPressed: () => _duplicate3dEntity(token),
                                icon: const Icon(Icons.copy_outlined, size: 16),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete3dEntity(token),
                                icon:
                                    const Icon(Icons.delete_outline, size: 16),
                              ),
                            ],
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'inside',
                                label: Text('Inside'),
                              ),
                              ButtonSegment<String>(
                                value: 'outside',
                                label: Text('Outside'),
                              ),
                            ],
                            selected: <String>{layer},
                            onSelectionChanged: (values) {
                              _set3dWindowLayerByToken(
                                token: token,
                                layer: values.first,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (selectedEntity != null && selectedToken != null) ...[
            const SizedBox(height: 12),
            Text(
              'Selected: ${_labelForEntityToken(selectedToken, scene)}',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (selectedType == 'model')
              TextFormField(
                key: ValueKey<String>(
                  'model-name-$selectedToken-${selectedEntity['name'] ?? ''}',
                ),
                initialValue: (selectedEntity['name'] ?? '').toString(),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'name',
                  value: value.trim(),
                ),
                decoration: const InputDecoration(labelText: 'Model Name'),
              ),
            if (selectedType == 'model' || selectedType == 'audio') ...[
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey<String>(
                  'entity-url-$selectedToken-${selectedEntity['url'] ?? ''}',
                ),
                initialValue: (selectedEntity['url'] ?? '').toString(),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'url',
                  value: value.trim(),
                ),
                decoration: InputDecoration(
                  labelText:
                      selectedType == 'model' ? 'Model URL' : 'Audio URL',
                ),
              ),
            ],
            if (selectedType == 'model') ...[
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible'),
                value: asBool(selectedEntity['visible'], true),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'visible',
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position X',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 0, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 0,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Y',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 1, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 1,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Z',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 2, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 2,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Rotation X',
                min: -6.28,
                max: 6.28,
                value: _vectorComponent(selectedEntity['rotation'], 0, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'rotation',
                  index: 0,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Rotation Y',
                min: -6.28,
                max: 6.28,
                value: _vectorComponent(selectedEntity['rotation'], 1, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'rotation',
                  index: 1,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Rotation Z',
                min: -6.28,
                max: 6.28,
                value: _vectorComponent(selectedEntity['rotation'], 2, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'rotation',
                  index: 2,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Scale X',
                min: 0.01,
                max: 10,
                value: _vectorComponent(selectedEntity['scale'], 0, 1),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'scale',
                  index: 0,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Scale Y',
                min: 0.01,
                max: 10,
                value: _vectorComponent(selectedEntity['scale'], 1, 1),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'scale',
                  index: 1,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Scale Z',
                min: 0.01,
                max: 10,
                value: _vectorComponent(selectedEntity['scale'], 2, 1),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'scale',
                  index: 2,
                  value: value,
                ),
              ),
            ] else if (selectedType == 'light') ...[
              TextFormField(
                key: ValueKey<String>(
                  'light-color-$selectedToken-${selectedEntity['color'] ?? ''}',
                ),
                initialValue: (selectedEntity['color'] ?? 'ffffff').toString(),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'color',
                  value: value.replaceAll('#', '').trim(),
                ),
                decoration: const InputDecoration(labelText: 'Color (hex)'),
              ),
              _composerSlider(
                label: 'Intensity',
                min: 0,
                max: 50,
                value: _toDouble(selectedEntity['intensity'], 10),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'intensity',
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position X',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 0, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 0,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Y',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 1, 5),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 1,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Z',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 2, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 2,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Helper Scale',
                min: 0.1,
                max: 10,
                value: _toDouble(selectedEntity['scale'], 1),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'scale',
                  value: value,
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ghost (hide helper)'),
                value: asBool(selectedEntity['ghost']),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'ghost',
                  value: value,
                ),
              ),
            ] else if (selectedType == 'audio') ...[
              _composerSlider(
                label: 'Volume',
                min: 0,
                max: 2,
                value: _toDouble(selectedEntity['volume'], 1),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'volume',
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position X',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 0, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 0,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Y',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 1, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 1,
                  value: value,
                ),
              ),
              _composerSlider(
                label: 'Position Z',
                min: -30,
                max: 30,
                value: _vectorComponent(selectedEntity['position'], 2, 0),
                onChanged: (value) => _set3DEntityVectorComponent(
                  token: selectedToken,
                  field: 'position',
                  index: 2,
                  value: value,
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ghost (hide helper)'),
                value: asBool(selectedEntity['ghost']),
                onChanged: (value) => _set3DEntityField(
                  token: selectedToken,
                  field: 'ghost',
                  value: value,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            'World & FX',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          _composerSlider(
            label: 'Sun Intensity',
            min: 0,
            max: 10,
            value: _toDouble(scene['sunIntensity'], 2.0),
            onChanged: (value) => _set3DSceneField('sunIntensity', value),
          ),
          _composerSlider(
            label: 'Ambient Light',
            min: 0,
            max: 2,
            value: _toDouble(scene['ambLight'], 0.5),
            onChanged: (value) => _set3DSceneField('ambLight', value),
          ),
          _composerSlider(
            label: 'Bloom Intensity',
            min: 0,
            max: 4,
            value: _toDouble(scene['bloomIntensity'], 1.0),
            onChanged: (value) => _set3DSceneField('bloomIntensity', value),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('shadow-quality-$shadowQuality'),
            value: shadowQuality,
            decoration: const InputDecoration(labelText: 'Shadow Quality'),
            items: const <String>[
              '256',
              '512',
              '1024',
              '2048',
            ]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _set3DSceneField('shadowQuality', value);
            },
          ),
          _composerSlider(
            label: 'Shadow Softness',
            min: 0,
            max: 5,
            value: _toDouble(scene['shadowSoftness'], 1.0),
            onChanged: (value) => _set3DSceneField('shadowSoftness', value),
          ),
          TextFormField(
            key: ValueKey<String>('sky-url-${scene['skyUrl'] ?? ''}'),
            initialValue: (scene['skyUrl'] ?? '').toString(),
            onChanged: (value) => _set3DSceneField('skyUrl', value.trim()),
            decoration: const InputDecoration(labelText: 'Sky URL'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey<String>('env-url-${scene['envUrl'] ?? ''}'),
            initialValue: (scene['envUrl'] ?? '').toString(),
            onChanged: (value) => _set3DSceneField('envUrl', value.trim()),
            decoration: const InputDecoration(labelText: 'Environment URL'),
          ),
          _composerSlider(
            label: 'Environment Rotation',
            min: -6.28,
            max: 6.28,
            value: _toDouble(scene['envRot'], 0.0),
            onChanged: (value) => _set3DSceneField('envRot', value),
          ),
          const SizedBox(height: 10),
          Text(
            'Initial Camera',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          _composerSlider(
            label: 'Init Pos X',
            min: -30,
            max: 30,
            value: initPos[0],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initPos',
              index: 0,
              value: value,
              fallback: initPos,
            ),
          ),
          _composerSlider(
            label: 'Init Pos Y',
            min: -30,
            max: 30,
            value: initPos[1],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initPos',
              index: 1,
              value: value,
              fallback: initPos,
            ),
          ),
          _composerSlider(
            label: 'Init Pos Z',
            min: -30,
            max: 30,
            value: initPos[2],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initPos',
              index: 2,
              value: value,
              fallback: initPos,
            ),
          ),
          _composerSlider(
            label: 'Init Rot X',
            min: -6.28,
            max: 6.28,
            value: initRot[0],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initRot',
              index: 0,
              value: value,
              fallback: initRot,
            ),
          ),
          _composerSlider(
            label: 'Init Rot Y',
            min: -6.28,
            max: 6.28,
            value: initRot[1],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initRot',
              index: 1,
              value: value,
              fallback: initRot,
            ),
          ),
          _composerSlider(
            label: 'Init Rot Z',
            min: -6.28,
            max: 6.28,
            value: initRot[2],
            onChanged: (value) => _set3DSceneVectorComponent(
              field: 'initRot',
              index: 2,
              value: value,
              fallback: initRot,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tracking',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          DropdownButtonFormField<String>(
            value: () {
              const modes = <String>{'orbit', 'fps', 'free'};
              final String raw =
                  (controls['camera-mode'] ?? 'orbit').toString().toLowerCase();
              return modes.contains(raw) ? raw : 'orbit';
            }(),
            decoration: const InputDecoration(labelText: 'Camera Mode'),
            items: const [
              DropdownMenuItem<String>(value: 'orbit', child: Text('Orbit')),
              DropdownMenuItem<String>(value: 'fps', child: Text('FPS')),
              DropdownMenuItem<String>(value: 'free', child: Text('Free')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _set3DControlField('camera-mode', value);
            },
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Manual Mode'),
            value: manualMode,
            onChanged: (value) => _set3DControlField('manual-mode', value),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Tracker UI'),
            value: asBool(controls['show-tracker']),
            onChanged: (value) => _set3DControlField('show-tracker', value),
          ),
          _composerSlider(
            label: 'Dead Zone X',
            min: 0,
            max: 0.1,
            value: _toDouble(controls['dz-x'], 0),
            onChanged: (value) => _set3DControlField('dz-x', value),
          ),
          _composerSlider(
            label: 'Dead Zone Y',
            min: 0,
            max: 0.1,
            value: _toDouble(controls['dz-y'], 0),
            onChanged: (value) => _set3DControlField('dz-y', value),
          ),
          _composerSlider(
            label: 'Dead Zone Z',
            min: 0,
            max: 0.1,
            value: _toDouble(controls['dz-z'], 0),
            onChanged: (value) => _set3DControlField('dz-z', value),
          ),
          _composerSlider(
            label: 'Dead Zone Yaw',
            min: 0,
            max: 10,
            value: _toDouble(controls['dz-yaw'], 0),
            onChanged: (value) => _set3DControlField('dz-yaw', value),
          ),
          _composerSlider(
            label: 'Dead Zone Pitch',
            min: 0,
            max: 10,
            value: _toDouble(controls['dz-pitch'], 0),
            onChanged: (value) => _set3DControlField('dz-pitch', value),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final frame = TrackingService.instance.frameNotifier.value;
              _set3DControlField('head-x', frame.headX);
              _set3DControlField('head-y', frame.headY);
              _set3DControlField('z-value', frame.headZ);
              _set3DControlField('yaw', frame.yaw);
              _set3DControlField('pitch', frame.pitch);
            },
            icon: const Icon(Icons.gps_fixed, size: 16),
            label: const Text('Recenter Manual Anchor'),
          ),
          if (manualMode) ...[
            _composerSlider(
              label: 'Manual Head X',
              min: -1,
              max: 1,
              value: _toDouble(controls['head-x'], 0),
              onChanged: (value) => _set3DControlField('head-x', value),
            ),
            _composerSlider(
              label: 'Manual Head Y',
              min: -1,
              max: 1,
              value: _toDouble(controls['head-y'], 0),
              onChanged: (value) => _set3DControlField('head-y', value),
            ),
            _composerSlider(
              label: 'Manual Z',
              min: 0.05,
              max: 2,
              value: _toDouble(controls['z-value'], 0.2),
              onChanged: (value) => _set3DControlField('z-value', value),
            ),
            _composerSlider(
              label: 'Manual Yaw',
              min: -60,
              max: 60,
              value: _toDouble(controls['yaw'], 0),
              onChanged: (value) => _set3DControlField('yaw', value),
            ),
            _composerSlider(
              label: 'Manual Pitch',
              min: -40,
              max: 40,
              value: _toDouble(controls['pitch'], 0),
              onChanged: (value) => _set3DControlField('pitch', value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _build2DCardEditorPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<String> keys = _thumbnail2DLayerKeys();
    final Map<String, dynamic>? selected = _selected2DLayerMap();
    final controls = _thumbnailControls();
    final dynamic turningRaw = _thumbnail2DScene()['turning_point'];
    final Map<String, dynamic> turningPoint = turningRaw is Map
        ? Map<String, dynamic>.from(turningRaw)
        : <String, dynamic>{};
    final String? selectedKey = _selected2dLayerKey;
    final bool selectedEditable = selectedKey != null;
    final bool selectedDeletable =
        selectedKey != null && !_isUtilityLayerKey(selectedKey);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2D Card Editor',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reorder/add/delete/duplicate layers. Drag on preview to move selected layer and use mouse wheel to scale.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _promptAdd2DImageUrl,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Add Image URL'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _uploadingLayerImage ? null : _upload2DImageFromDevice,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(
                    _uploadingLayerImage ? 'Uploading...' : 'Upload Image'),
              ),
              OutlinedButton.icon(
                onPressed: () => _add2DLayer(textLayer: true),
                icon: const Icon(Icons.text_fields, size: 16),
                label: const Text('Add Text'),
              ),
              OutlinedButton.icon(
                onPressed: _recenterComposerParallax,
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text('Recenter'),
              ),
              OutlinedButton.icon(
                onPressed: selectedDeletable ? _duplicateSelected2DLayer : null,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Duplicate'),
              ),
              OutlinedButton.icon(
                onPressed: selectedDeletable ? _deleteSelected2DLayer : null,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (keys.isEmpty)
            Text(
              'No editable layers found in this preset.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: keys.length,
                onReorder: _reorder2DLayer,
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final layerMap = _thumbnail2DScene()[key];
                  final bool visible =
                      !(layerMap is Map && layerMap['isVisible'] == false);
                  final bool locked =
                      layerMap is Map && layerMap['isLocked'] == true;
                  final bool selectedLayer = key == _selected2dLayerKey;
                  return Container(
                    key: ValueKey<String>('2d-layer-$key'),
                    decoration: BoxDecoration(
                      color: selectedLayer
                          ? cs.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: cs.outline.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 124,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: visible ? 'Hide layer' : 'Show layer',
                              onPressed: () => _set2DLayerField(
                                key,
                                'isVisible',
                                !visible,
                              ),
                              icon: Icon(
                                visible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: locked ? 'Unlock layer' : 'Lock layer',
                              onPressed: () =>
                                  _set2DLayerField(key, 'isLocked', !locked),
                              icon: Icon(
                                locked ? Icons.lock_outline : Icons.lock_open,
                                size: 18,
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, size: 18),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => setState(() => _selected2dLayerKey = key),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (selected != null) ...[
              Text(
                'Layer: ${selectedKey ?? ''}',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (selected['isText'] == true)
                TextFormField(
                  initialValue: (selected['textValue'] ?? '').toString(),
                  onChanged: (value) =>
                      _set2DLayerField(selectedKey!, 'textValue', value),
                  decoration: const InputDecoration(
                    labelText: 'Text',
                  ),
                )
              else
                TextFormField(
                  initialValue: (selected['url'] ?? '').toString(),
                  onChanged: (value) =>
                      _set2DLayerField(selectedKey!, 'url', value.trim()),
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _set2DLayerField(
                        selectedKey!,
                        'isVisible',
                        !(selected['isVisible'] == false),
                      ),
                      icon: Icon(
                        selected['isVisible'] == false
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                      ),
                      label: Text(
                        selected['isVisible'] == false ? 'Show' : 'Hide',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _set2DLayerField(
                        selectedKey!,
                        'isLocked',
                        !(selected['isLocked'] == true),
                      ),
                      icon: Icon(
                        selected['isLocked'] == true
                            ? Icons.lock_outline
                            : Icons.lock_open,
                        size: 16,
                      ),
                      label: Text(
                        selected['isLocked'] == true ? 'Unlock' : 'Lock',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _composerSlider(
                label: 'X Position',
                min: -1500,
                max: 1500,
                value: _toDouble(selected['x'], 0),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'x', v),
              ),
              _composerSlider(
                label: 'Y Position',
                min: -1500,
                max: 1500,
                value: _toDouble(selected['y'], 0),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'y', v),
              ),
              _composerSlider(
                label: 'Scale',
                min: 0.05,
                max: 6,
                value: _toDouble(selected['scale'], 1),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'scale', v),
              ),
              _composerSlider(
                label: 'Depth Order',
                min: -200,
                max: 200,
                value: _toDouble(selected['order'], 0),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'order', v),
              ),
              if (selected['isText'] == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _composerSlider(
                      label: 'Font Size',
                      min: 8,
                      max: 300,
                      value: _toDouble(selected['fontSize'], 40),
                      onChanged: (v) =>
                          _set2DLayerField(selectedKey!, 'fontSize', v),
                    ),
                    _composerSlider(
                      label: 'Font Weight',
                      min: 0,
                      max: 8,
                      value: _toDouble(selected['fontWeightIndex'], 4),
                      onChanged: (v) => _set2DLayerField(
                        selectedKey!,
                        'fontWeightIndex',
                        v.round(),
                      ),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Italic'),
                      value: selected['isItalic'] == true,
                      onChanged: (v) =>
                          _set2DLayerField(selectedKey!, 'isItalic', v),
                    ),
                    DropdownButtonFormField<String>(
                      value: (() {
                        final String font =
                            (selected['fontFamily'] ?? 'Poppins').toString();
                        return _fontOptions.contains(font)
                            ? font
                            : _fontOptions.first;
                      })(),
                      items: _fontOptions
                          .map((font) => DropdownMenuItem<String>(
                                value: font,
                                child: Text(font),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _set2DLayerField(selectedKey!, 'fontFamily', value);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Font Family'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue:
                          (selected['textColorHex'] ?? '#FFFFFF').toString(),
                      onChanged: (value) => _set2DLayerField(
                        selectedKey!,
                        'textColorHex',
                        value.trim(),
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Text Color (Hex)'),
                    ),
                    const SizedBox(height: 8),
                    _composerSlider(
                      label: 'Stroke Width',
                      min: 0,
                      max: 20,
                      value: _toDouble(selected['strokeWidth'], 0),
                      onChanged: (v) =>
                          _set2DLayerField(selectedKey!, 'strokeWidth', v),
                    ),
                    TextFormField(
                      initialValue:
                          (selected['strokeColorHex'] ?? '#000000').toString(),
                      onChanged: (value) => _set2DLayerField(
                        selectedKey!,
                        'strokeColorHex',
                        value.trim(),
                      ),
                      decoration: const InputDecoration(
                          labelText: 'Stroke Color (Hex)'),
                    ),
                    const SizedBox(height: 8),
                    _composerSlider(
                      label: 'Shadow Blur',
                      min: 0,
                      max: 40,
                      value: _toDouble(selected['shadowBlur'], 0),
                      onChanged: (v) =>
                          _set2DLayerField(selectedKey!, 'shadowBlur', v),
                    ),
                    TextFormField(
                      initialValue:
                          (selected['shadowColorHex'] ?? '#000000').toString(),
                      onChanged: (value) => _set2DLayerField(
                        selectedKey!,
                        'shadowColorHex',
                        value.trim(),
                      ),
                      decoration: const InputDecoration(
                          labelText: 'Shadow Color (Hex)'),
                    ),
                  ],
                ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Can Shift'),
                value: selected['canShift'] != false,
                onChanged: (v) => _set2DLayerField(selectedKey!, 'canShift', v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Can Zoom'),
                value: selected['canZoom'] != false,
                onChanged: (v) => _set2DLayerField(selectedKey!, 'canZoom', v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Can Tilt'),
                value: selected['canTilt'] != false,
                onChanged: (v) => _set2DLayerField(selectedKey!, 'canTilt', v),
              ),
              _composerSlider(
                label: 'Shift Sensitivity Mult',
                min: 0,
                max: 3,
                value: _toDouble(selected['shiftSensMult'], 1),
                onChanged: (v) =>
                    _set2DLayerField(selectedKey!, 'shiftSensMult', v),
              ),
              _composerSlider(
                label: 'Zoom Sensitivity Mult',
                min: 0,
                max: 3,
                value: _toDouble(selected['zoomSensMult'], 1),
                onChanged: (v) =>
                    _set2DLayerField(selectedKey!, 'zoomSensMult', v),
              ),
              _composerSlider(
                label: 'Min Scale',
                min: 0.01,
                max: 5,
                value: _toDouble(selected['minScale'], 0.1),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'minScale', v),
              ),
              _composerSlider(
                label: 'Max Scale',
                min: 0.05,
                max: 10,
                value: _toDouble(selected['maxScale'], 5),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'maxScale', v),
              ),
              _composerSlider(
                label: 'Min X',
                min: -3000,
                max: 3000,
                value: _toDouble(selected['minX'], -3000),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'minX', v),
              ),
              _composerSlider(
                label: 'Max X',
                min: -3000,
                max: 3000,
                value: _toDouble(selected['maxX'], 3000),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'maxX', v),
              ),
              _composerSlider(
                label: 'Min Y',
                min: -3000,
                max: 3000,
                value: _toDouble(selected['minY'], -3000),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'minY', v),
              ),
              _composerSlider(
                label: 'Max Y',
                min: -3000,
                max: 3000,
                value: _toDouble(selected['maxY'], 3000),
                onChanged: (v) => _set2DLayerField(selectedKey!, 'maxY', v),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Scene Controls',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _composerSlider(
              label: 'Global Scale',
              min: 0.5,
              max: 2.5,
              value: _toDouble(controls['scale'], 1.2),
              onChanged: (v) => _set2DControlField('scale', v),
            ),
            _composerSlider(
              label: 'Global Depth',
              min: 0,
              max: 1,
              value: _toDouble(controls['depth'], 0.1),
              onChanged: (v) => _set2DControlField('depth', v),
            ),
            _composerSlider(
              label: 'Global Shift',
              min: 0,
              max: 1,
              value: _toDouble(controls['shift'], 0.025),
              onChanged: (v) => _set2DControlField('shift', v),
            ),
            _composerSlider(
              label: 'Global Tilt',
              min: 0,
              max: 1,
              value: _toDouble(controls['tilt'], 0),
              onChanged: (v) => _set2DControlField('tilt', v),
            ),
            _composerSlider(
              label: 'Tilt Sensitivity',
              min: 0,
              max: 2,
              value: _toDouble(controls['tiltSensitivity'], 1),
              onChanged: (v) => _set2DControlField('tiltSensitivity', v),
            ),
            _composerSlider(
              label: 'Dead Zone X',
              min: 0,
              max: 0.1,
              value: _toDouble(controls['deadZoneX'], 0),
              onChanged: (v) => _set2DControlField('deadZoneX', v),
            ),
            _composerSlider(
              label: 'Dead Zone Y',
              min: 0,
              max: 0.1,
              value: _toDouble(controls['deadZoneY'], 0),
              onChanged: (v) => _set2DControlField('deadZoneY', v),
            ),
            _composerSlider(
              label: 'Dead Zone Z',
              min: 0,
              max: 0.1,
              value: _toDouble(controls['deadZoneZ'], 0),
              onChanged: (v) => _set2DControlField('deadZoneZ', v),
            ),
            _composerSlider(
              label: 'Dead Zone Yaw',
              min: 0,
              max: 10,
              value: _toDouble(controls['deadZoneYaw'], 0),
              onChanged: (v) => _set2DControlField('deadZoneYaw', v),
            ),
            _composerSlider(
              label: 'Dead Zone Pitch',
              min: 0,
              max: 10,
              value: _toDouble(controls['deadZonePitch'], 0),
              onChanged: (v) => _set2DControlField('deadZonePitch', v),
            ),
            _composerSlider(
              label: 'Z Base',
              min: 0.05,
              max: 2.0,
              value: _toDouble(controls['zBase'], 0.2),
              onChanged: (v) => _set2DControlField('zBase', v),
            ),
            _composerSlider(
              label: 'Anchor Head X',
              min: -1,
              max: 1,
              value: _toDouble(controls['anchorHeadX'], 0),
              onChanged: (v) => _set2DControlField('anchorHeadX', v),
            ),
            _composerSlider(
              label: 'Anchor Head Y',
              min: -1,
              max: 1,
              value: _toDouble(controls['anchorHeadY'], 0),
              onChanged: (v) => _set2DControlField('anchorHeadY', v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Manual Mode'),
              subtitle: const Text('Use sliders/manual camera values only'),
              value: controls['manualMode'] == true,
              onChanged: (v) => _set2DControlField('manualMode', v),
            ),
            if (controls['manualMode'] == true) ...[
              _composerSlider(
                label: 'Manual Head X',
                min: -1,
                max: 1,
                value: _toDouble(controls['manualHeadX'], 0),
                onChanged: (v) => _set2DControlField('manualHeadX', v),
              ),
              _composerSlider(
                label: 'Manual Head Y',
                min: -1,
                max: 1,
                value: _toDouble(controls['manualHeadY'], 0),
                onChanged: (v) => _set2DControlField('manualHeadY', v),
              ),
              _composerSlider(
                label: 'Manual Head Z',
                min: 0.05,
                max: 2.0,
                value: _toDouble(controls['manualHeadZ'], 0.2),
                onChanged: (v) => _set2DControlField('manualHeadZ', v),
              ),
              _composerSlider(
                label: 'Manual Yaw',
                min: -60,
                max: 60,
                value: _toDouble(controls['manualYaw'], 0),
                onChanged: (v) => _set2DControlField('manualYaw', v),
              ),
              _composerSlider(
                label: 'Manual Pitch',
                min: -40,
                max: 40,
                value: _toDouble(controls['manualPitch'], 0),
                onChanged: (v) => _set2DControlField('manualPitch', v),
              ),
            ],
            DropdownButtonFormField<String>(
              value: (() {
                final String selectedAspect =
                    (controls['selectedAspect'] ?? '').toString();
                if (_aspectOptions.contains(selectedAspect)) {
                  return selectedAspect;
                }
                return null;
              })(),
              items: _aspectOptions
                  .map((ratio) => DropdownMenuItem<String>(
                      value: ratio, child: Text(ratio)))
                  .toList(),
              onChanged: (value) {
                _set2DControlField('selectedAspect', value);
              },
              decoration: const InputDecoration(
                labelText: 'Aspect Ratio',
              ),
            ),
            _composerSlider(
              label: 'Turning Point Depth',
              min: -200,
              max: 200,
              value: _toDouble(turningPoint['order'], 0),
              onChanged: _setTurningPointOrder,
            ),
          ],
          if (!selectedEditable)
            Text(
              'Select a layer to edit and drag directly in the card preview.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _composerSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final double clamped = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${clamped.toStringAsFixed(3)}'),
          Slider(
            value: clamped,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final tags = _parseTags(_tagsController.text);
      final mentions = _selectedMentionIds.toList();
      _persistActiveCollectionItemSnapshot();
      final Map<String, dynamic> canonicalPayload =
          jsonDecode(jsonEncode(_thumbnailPayload)) as Map<String, dynamic>;

      if (widget.kind == _ComposerKind.single) {
        final String presetId;
        if (widget.existingPreset != null) {
          presetId = widget.existingPreset!.id;
          if (_isDetailEditor) {
            await _repository.updatePresetDetail(
              presetId: presetId,
              title: title,
              description: description,
              tags: tags,
              mentionUserIds: mentions,
              payload: canonicalPayload,
              mode: _thumbnailMode,
              visibility: _isPublic ? 'public' : 'private',
            );
          } else {
            await _repository.updatePresetCard(
              presetId: presetId,
              title: title,
              description: description,
              tags: tags,
              mentionUserIds: mentions,
              thumbnailPayload: canonicalPayload,
              thumbnailMode: _thumbnailMode,
              visibility: _isPublic ? 'public' : 'private',
            );
          }
        } else {
          presetId = await _repository.publishPresetPost(
            mode: _thumbnailMode,
            name: widget.name.isEmpty ? title : widget.name,
            payload: canonicalPayload,
            title: title,
            description: description,
            tags: tags,
            mentionUserIds: mentions,
            visibility: _isPublic ? 'public' : 'private',
            thumbnailPayload: canonicalPayload,
            thumbnailMode: _thumbnailMode,
          );
        }
        if (mentions.isNotEmpty) {
          await _repository.createMentionNotifications(
            mentionedUserIds: mentions,
            presetId: presetId,
            presetTitle: title,
          );
        }
      } else {
        if (_editableCollectionItems.isEmpty) {
          throw Exception('Collection is empty.');
        }
        final String collectionId = widget.collectionId ?? '';
        final String resolvedCollectionId;
        if (collectionId.isEmpty) {
          resolvedCollectionId = await _repository.saveCollectionWithItems(
            collectionId: null,
            name: title,
            description: description,
            tags: tags,
            mentionUserIds: mentions,
            thumbnailPayload: canonicalPayload,
            thumbnailMode: _thumbnailMode,
            publish: _isPublic,
            items: _editableCollectionItems,
          );
        } else {
          resolvedCollectionId = collectionId;
          if (_isDetailEditor) {
            await _repository.updateCollectionItemsDetail(
              collectionId: collectionId,
              name: title,
              description: description,
              tags: tags,
              mentionUserIds: mentions,
              publish: _isPublic,
              items: _editableCollectionItems,
            );
          } else {
            await _repository.updateCollectionCard(
              collectionId: collectionId,
              name: title,
              description: description,
              tags: tags,
              mentionUserIds: mentions,
              publish: _isPublic,
              items: _editableCollectionItems,
              thumbnailPayload: canonicalPayload,
              thumbnailMode: _thumbnailMode,
            );
          }
        }
        if (mentions.isNotEmpty) {
          await _repository.createMentionNotifications(
            mentionedUserIds: mentions,
            presetId: resolvedCollectionId,
            presetTitle: title,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final BorderRadius previewRadius = BorderRadius.circular(18);
    final bool enable3dMousePreview =
        !_showPublishStep && _thumbnailMode == '3d';
    Widget previewSurface = _GridPresetPreview(
      mode: _thumbnailMode,
      payload: _thumbnailPayload,
      borderRadius: previewRadius,
      pointerPassthrough: !enable3dMousePreview,
    );
    if (!_showPublishStep && _thumbnailMode == '2d') {
      previewSurface = Listener(
        onPointerSignal: _handle2DPreviewPointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _handle2DPreviewPanUpdate,
          child: previewSurface,
        ),
      );
    }
    final preview = AspectRatio(
      aspectRatio: 16 / 9,
      child: previewSurface,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(
          () {
            if (_isDetailEditor) {
              return widget.kind == _ComposerKind.single
                  ? (widget.isEdit ? 'Update Preset Detail' : 'Compose Preset')
                  : (widget.isEdit
                      ? 'Update Collection Detail'
                      : 'Compose Collection Detail');
            }
            return widget.kind == _ComposerKind.single
                ? (widget.isEdit ? 'Update Feed Card' : 'Compose Card')
                : (widget.isEdit
                    ? 'Update Collection Card'
                    : 'Compose Collection Card');
          }(),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDetailEditor
                        ? 'Detail Preview (16:9)'
                        : 'Card Preview (16:9)',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.kind == _ComposerKind.collection &&
                      _editableCollectionItems.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(
                          _editableCollectionItems.length,
                          (index) {
                            final bool active = index == _thumbnailIndex;
                            return ChoiceChip(
                              selected: active,
                              label: Text(
                                '${index + 1}. ${_editableCollectionItems[index].name}',
                              ),
                              onSelected: (_) =>
                                  _setThumbnailFromCollectionIndex(index),
                            );
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: widget.kind == _ComposerKind.collection
                            ? Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    top: 12,
                                    left: 12,
                                    right: 12,
                                    bottom: -12,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: cs.surfaceContainerHighest
                                            .withValues(alpha: 0.32),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    top: 6,
                                    left: 6,
                                    right: 6,
                                    bottom: -6,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: cs.surfaceContainerHighest
                                            .withValues(alpha: 0.48),
                                      ),
                                    ),
                                  ),
                                  preview,
                                ],
                              )
                            : preview,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_showPublishStep)
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _showPublishStep = true);
                            },
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Save & Next'),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _showPublishStep = false);
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to Editing'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 430,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  left: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_showPublishStep) ...[
                    Text(
                      _isDetailEditor ? 'Detail Editing' : 'Card Editing',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDetailEditor
                          ? 'Adjust the preset/collection detail payload, then continue to metadata.'
                          : 'Adjust the feed card payload (independent from detail), then continue to metadata.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    if (_isCardEditor && _pullSourcePayload != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: _pullFromSourcePayload,
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: Text(
                            widget.kind == _ComposerKind.single
                                ? 'Pull From Preset'
                                : 'Pull From Active Collection Item',
                          ),
                        ),
                      ),
                    if (_thumbnailMode == '3d')
                      _build3DWindowLayerPanel(context)
                    else
                      _build2DCardEditorPanel(context),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                setState(() => _showPublishStep = true),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Save & Next'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: '#parallax #fyp',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _mentionController,
                      decoration: const InputDecoration(
                        labelText: 'Mention',
                        hintText: '@username',
                      ),
                    ),
                    if (_mentionLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (_mentionResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _mentionResults.length,
                          itemBuilder: (context, index) {
                            final user = _mentionResults[index];
                            return ListTile(
                              dense: true,
                              title: Text(user.displayName),
                              subtitle: Text(user.email),
                              onTap: () => _addMention(user),
                            );
                          },
                        ),
                      ),
                    if (_selectedMentionIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedMentionIds.map((id) {
                            final profile = _selectedMentionProfiles[id];
                            final label = profile != null
                                ? '@${profile.username ?? profile.displayName}'
                                : '@${id.substring(0, math.min(8, id.length))}';
                            return InputChip(
                              label: Text(label),
                              onDeleted: () => _removeMention(id),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Public'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Private'),
                        ),
                      ],
                      selected: <bool>{_isPublic},
                      onSelectionChanged: (values) {
                        setState(() => _isPublic = values.first);
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting
                                  ? 'Working...'
                                  : widget.isEdit
                                      ? 'Update'
                                      : 'Publish',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  final String currentThemeMode;
  final ValueChanged<String>? onThemeModeChanged;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final AppRepository _repository = AppRepository.instance;

  late String _themeMode;
  bool _trackerEnabled = true;
  bool _trackerUiVisible = false;
  bool _cursorEnabled = false;
  bool _prefsLoading = true;
  TrackerRuntimeConfig _trackerConfig = TrackerRuntimeConfig.defaults;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.currentThemeMode;
    _cursorEnabled = TrackingService.instance.dartCursorEnabled;
    _loadTrackerPrefs();
  }

  @override
  void didUpdateWidget(covariant _SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentThemeMode != widget.currentThemeMode) {
      _themeMode = widget.currentThemeMode;
    }
  }

  Future<void> _setTheme(String mode) async {
    setState(() => _themeMode = mode);
    await _repository.updateThemeModeForCurrentUser(mode);
    widget.onThemeModeChanged?.call(mode);
  }

  Future<void> _loadTrackerPrefs() async {
    try {
      final prefs = await _repository.fetchTrackerPreferencesForCurrentUser();
      var config =
          await _repository.fetchTrackerRuntimeConfigForCurrentUser();
      final normalized = _normalizeInputModeForDevice(config);
      if (normalized.inputMode != config.inputMode) {
        config = normalized;
        await _repository.updateTrackerRuntimeConfigForCurrentUser(config);
      }
      if (!mounted) return;
      setState(() {
        _trackerEnabled = prefs['trackerEnabled'] ?? true;
        _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
        _trackerConfig = config;
        _cursorEnabled = config.dartCursorEnabled;
        _prefsLoading = false;
      });
      TrackingService.instance.setRuntimeConfig(config);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefsLoading = false);
    }
  }

  TrackerRuntimeConfig _normalizeInputModeForDevice(
    TrackerRuntimeConfig config,
  ) {
    final tracking = TrackingService.instance;
    final String mode = config.inputMode;
    if (mode == 'mouse_hover' && !tracking.supportsMouseHover) {
      return config.copyWith(inputMode: 'mediapipe');
    }
    if (mode == 'accelerometer' && !tracking.supportsAccelerometer) {
      return config.copyWith(inputMode: 'mediapipe');
    }
    if (mode == 'gyro' && !tracking.supportsGyro) {
      return config.copyWith(inputMode: 'mediapipe');
    }
    return config;
  }

  Future<void> _setTrackerEnabled(bool value) async {
    setState(() => _trackerEnabled = value);
    await TrackingService.instance.setTrackerEnabled(value);
  }

  Future<void> _setTrackerUiVisible(bool value) async {
    setState(() => _trackerUiVisible = value);
    await TrackingService.instance.setTrackerUiVisible(value);
  }

  void _setCursorEnabled(bool value) {
    setState(() => _cursorEnabled = value);
    unawaited(
      _updateTrackerConfig(
        _trackerConfig.copyWith(dartCursorEnabled: value),
      ),
    );
  }

  Future<void> _updateTrackerConfig(TrackerRuntimeConfig next) async {
    setState(() {
      _trackerConfig = next;
      _cursorEnabled = next.dartCursorEnabled;
      if (next.inputMode != 'mediapipe') {
        _trackerUiVisible = false;
      }
    });
    TrackingService.instance.setRuntimeConfig(next);
    if (next.inputMode != 'mediapipe') {
      await TrackingService.instance.setTrackerUiVisible(false);
    }
    await _repository.updateTrackerRuntimeConfigForCurrentUser(next);
  }

  Future<void> _setInputMode(String mode) async {
    if (!_trackerEnabled) return;
    final resolvedConfig = _normalizeInputModeForDevice(
      _trackerConfig.copyWith(inputMode: mode),
    );
    final String resolved = resolvedConfig.inputMode;
    await _updateTrackerConfig(_trackerConfig.copyWith(inputMode: resolved));
  }

  Future<void> _confirmSignOut() async {
    final bool shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You can sign back in anytime.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSignOut) return;
    await _repository.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/feed');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tracking = TrackingService.instance;
    final bool mouseHoverSupported = tracking.supportsMouseHover;
    final bool accelerometerSupported = tracking.supportsAccelerometer;
    final bool gyroSupported = tracking.supportsGyro;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how DeepX looks.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _themeMode,
                dropdownColor: cs.surfaceContainerHighest,
                style: TextStyle(color: cs.onSurface),
                items: const [
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'system', child: Text('System')),
                ],
                onChanged: (value) {
                  if (value != null) _setTheme(value);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracker Runtime',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Control app-wide tracking, UI visibility, and Dart-side cursor interactions.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (_prefsLoading)
                const SizedBox(
                  height: 60,
                  child:
                      _TopEdgeLoadingPane(label: 'Loading tracker config...'),
                )
              else ...[
                SwitchListTile(
                  value: _trackerEnabled,
                  title: const Text('Enable Tracking'),
                  subtitle: const Text(
                    'Keeps head tracking active app-wide for parallax and interactions.',
                  ),
                  onChanged: _setTrackerEnabled,
                ),
                SwitchListTile(
                  value: _trackerUiVisible,
                  title: const Text('Show Tracker UI'),
                  subtitle: const Text(
                    'Display tracker panel, mesh, and camera preview overlay.',
                  ),
                  onChanged: _trackerEnabled ? _setTrackerUiVisible : null,
                ),
                SwitchListTile(
                  value: _cursorEnabled,
                  title: const Text('Dart Cursor Overlay'),
                  subtitle: const Text(
                    'Render a global cursor and bridge wink/pinch interactions.',
                  ),
                  onChanged: _trackerEnabled ? _setCursorEnabled : null,
                ),
                const SizedBox(height: 4),
                _settingsSectionTitle('Parallax Input Mode'),
                Opacity(
                  opacity: mouseHoverSupported ? 1 : 0.45,
                  child: SwitchListTile(
                    value: _trackerConfig.inputMode == 'mouse_hover',
                    title: const Text('Use mouse hover'),
                    subtitle: Text(
                      mouseHoverSupported
                          ? 'Uses real mouse movement for parallax.'
                          : 'Mouse hover input is unavailable on this device.',
                    ),
                    onChanged: (_trackerEnabled && mouseHoverSupported)
                        ? (value) =>
                            _setInputMode(value ? 'mouse_hover' : 'mediapipe')
                        : null,
                  ),
                ),
                Opacity(
                  opacity: accelerometerSupported ? 1 : 0.45,
                  child: SwitchListTile(
                    value: _trackerConfig.inputMode == 'accelerometer',
                    title: const Text('Use accelerometer'),
                    subtitle: Text(
                      accelerometerSupported
                          ? 'Uses device accelerometer when supported.'
                          : 'Accelerometer is unavailable on this device.',
                    ),
                    onChanged: (_trackerEnabled && accelerometerSupported)
                        ? (value) => _setInputMode(
                              value ? 'accelerometer' : 'mediapipe',
                            )
                        : null,
                  ),
                ),
                Opacity(
                  opacity: gyroSupported ? 1 : 0.45,
                  child: SwitchListTile(
                    value: _trackerConfig.inputMode == 'gyro',
                    title: const Text('Use gyro'),
                    subtitle: Text(
                      gyroSupported
                          ? 'Uses device gyroscope when supported.'
                          : 'Gyroscope is unavailable on this device.',
                    ),
                    onChanged: (_trackerEnabled && gyroSupported)
                        ? (value) => _setInputMode(value ? 'gyro' : 'mediapipe')
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _trackerConfig.cursorMode,
                  decoration: const InputDecoration(
                    labelText: 'Cursor Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'head', child: Text('Head Pose')),
                    DropdownMenuItem(value: 'iris', child: Text('Iris')),
                    DropdownMenuItem(value: 'hand', child: Text('Hand')),
                  ],
                  onChanged: _trackerEnabled
                      ? (value) {
                          if (value == null) return;
                          _updateTrackerConfig(
                            _trackerConfig.copyWith(cursorMode: value),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _trackerConfig.perfMode,
                  decoration: const InputDecoration(
                    labelText: 'Performance Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: _trackerEnabled
                      ? (value) {
                          if (value == null) return;
                          _updateTrackerConfig(
                            _trackerConfig.copyWith(perfMode: value),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _trackerConfig.inputSource,
                  decoration: const InputDecoration(
                    labelText: 'Input Source',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'local', child: Text('Local')),
                    DropdownMenuItem(value: 'remote', child: Text('Remote')),
                  ],
                  onChanged: _trackerEnabled
                      ? (value) {
                          if (value == null) return;
                          _updateTrackerConfig(
                            _trackerConfig.copyWith(inputSource: value),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _trackerConfig.showCursor,
                  title: const Text('Tracker Internal Cursor'),
                  subtitle: const Text(
                    'Used inside tracker UI; global app cursor remains Dart-side.',
                  ),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(showCursor: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.mouseTracking,
                  title: const Text('Mouse Tracking'),
                  subtitle: const Text(
                    'Enable cursor steering from real mouse deltas for diagnostics.',
                  ),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(mouseTracking: value),
                          )
                      : null,
                ),
                const SizedBox(height: 4),
                _settingsSectionTitle('Core Motion'),
                _settingsSlider(
                  label: 'Sensitivity X',
                  value: _trackerConfig.sensitivityX,
                  min: 1,
                  max: 1000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sensitivityX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Sensitivity Y',
                  value: _trackerConfig.sensitivityY,
                  min: 1,
                  max: 1000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sensitivityY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Smoothing',
                  value: _trackerConfig.smoothing,
                  min: 0,
                  max: 98,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(smoothing: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Head Cursor Sensitivity'),
                _settingsSlider(
                  label: 'Head Sensitivity X',
                  value: _trackerConfig.headSensitivityX,
                  min: 1,
                  max: 10000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headSensitivityX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Sensitivity Y',
                  value: _trackerConfig.headSensitivityY,
                  min: 1,
                  max: 10000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headSensitivityY: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Hand Cursor Sensitivity'),
                _settingsSlider(
                  label: 'Hand Sensitivity X',
                  value: _trackerConfig.handSensitivityX,
                  min: 1,
                  max: 10000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handSensitivityX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Sensitivity Y',
                  value: _trackerConfig.handSensitivityY,
                  min: 1,
                  max: 10000,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handSensitivityY: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Dead Zones'),
                _settingsSlider(
                  label: 'Iris Dead Zone X',
                  value: _trackerConfig.deadZoneIrisX,
                  min: 0.001,
                  max: 0.1,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneIrisX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Iris Dead Zone Y',
                  value: _trackerConfig.deadZoneIrisY,
                  min: 0.001,
                  max: 0.1,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneIrisY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Dead Zone Yaw',
                  value: _trackerConfig.deadZoneHeadYaw,
                  min: 0,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneHeadYaw: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Dead Zone Pitch',
                  value: _trackerConfig.deadZoneHeadPitch,
                  min: 0,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneHeadPitch: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Dead Zone X',
                  value: _trackerConfig.deadZoneHandX,
                  min: 0.001,
                  max: 0.5,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneHandX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Dead Zone Y',
                  value: _trackerConfig.deadZoneHandY,
                  min: 0.001,
                  max: 0.5,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(deadZoneHandY: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Wink + Pinch'),
                _settingsSlider(
                  label: 'Left Closed Threshold',
                  value: _trackerConfig.leftClosedThresh,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(leftClosedThresh: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Left Open Threshold',
                  value: _trackerConfig.leftOpenThresh,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(leftOpenThresh: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Right Closed Threshold',
                  value: _trackerConfig.rightClosedThresh,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(rightClosedThresh: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Right Open Threshold',
                  value: _trackerConfig.rightOpenThresh,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(rightOpenThresh: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Pinch Threshold',
                  value: _trackerConfig.pinchThresh,
                  min: 0.01,
                  max: 0.2,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(pinchThresh: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Head Acceleration'),
                _settingsSlider(
                  label: 'Head Slow X',
                  value: _trackerConfig.headSlowX,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headSlowX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Fast X',
                  value: _trackerConfig.headFastX,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headFastX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Transition X',
                  value: _trackerConfig.headTransX,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headTransX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Slow Y',
                  value: _trackerConfig.headSlowY,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headSlowY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Fast Y',
                  value: _trackerConfig.headFastY,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headFastY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Head Transition Y',
                  value: _trackerConfig.headTransY,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(headTransY: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Hand Acceleration'),
                _settingsSlider(
                  label: 'Hand Slow X',
                  value: _trackerConfig.handSlowX,
                  min: 0.001,
                  max: 15,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handSlowX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Fast X',
                  value: _trackerConfig.handFastX,
                  min: 0.001,
                  max: 20,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handFastX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Transition X',
                  value: _trackerConfig.handTransX,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handTransX: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Slow Y',
                  value: _trackerConfig.handSlowY,
                  min: 0.001,
                  max: 15,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handSlowY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Fast Y',
                  value: _trackerConfig.handFastY,
                  min: 0.001,
                  max: 20,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handFastY: v),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Transition Y',
                  value: _trackerConfig.handTransY,
                  min: 0.001,
                  max: 10,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(handTransY: v),
                          )
                      : null,
                ),
                _settingsSectionTitle('Hand Detection'),
                _settingsSlider(
                  label: 'Hand Detection Confidence',
                  value: _trackerConfig.handDetectionConfidence,
                  min: 0.3,
                  max: 0.99,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(
                              handDetectionConfidence: v,
                            ),
                          )
                      : null,
                ),
                _settingsSlider(
                  label: 'Hand Tracking Confidence',
                  value: _trackerConfig.handTrackingConfidence,
                  min: 0.3,
                  max: 0.99,
                  onChanged: _trackerEnabled
                      ? (v) => _updateTrackerConfig(
                            _trackerConfig.copyWith(
                              handTrackingConfidence: v,
                            ),
                          )
                      : null,
                ),
                _settingsSectionTitle('Remote Stream Flags'),
                SwitchListTile(
                  value: _trackerConfig.sendIris,
                  title: const Text('Send Iris'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendIris: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendNose,
                  title: const Text('Send Nose'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendNose: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendYawPitch,
                  title: const Text('Send Yaw/Pitch'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendYawPitch: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendFingertips,
                  title: const Text('Send Fingertips'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendFingertips: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendFullFace,
                  title: const Text('Send Full Face'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendFullFace: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendFullHand,
                  title: const Text('Send Full Hand'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendFullHand: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendAll,
                  title: const Text('Send All'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendAll: value),
                          )
                      : null,
                ),
                SwitchListTile(
                  value: _trackerConfig.sendNone,
                  title: const Text('Send None'),
                  onChanged: _trackerEnabled
                      ? (value) => _updateTrackerConfig(
                            _trackerConfig.copyWith(sendNone: value),
                          )
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(3)}'),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingsSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

Future<bool> _showSignInRequiredSheet(
  BuildContext context, {
  required String message,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

String _friendlyTime(DateTime value) {
  final DateTime now = DateTime.now();
  final Duration d = now.difference(value);
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final String mm = value.month.toString().padLeft(2, '0');
  final String dd = value.day.toString().padLeft(2, '0');
  final String hh = value.hour.toString().padLeft(2, '0');
  final String min = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd $hh:$min';
}

String _friendlyCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final double k = value / 1000;
    return k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  }
  if (value < 1000000000) {
    final double m = value / 1000000;
    return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  }
  final double b = value / 1000000000;
  return b >= 10 ? '${b.toStringAsFixed(0)}B' : '${b.toStringAsFixed(1)}B';
}
