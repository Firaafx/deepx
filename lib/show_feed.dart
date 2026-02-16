import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipable_stack/swipable_stack.dart';

import 'engine3d.dart';
import 'layer_mode.dart';
import 'models/app_user_profile.dart';
import 'models/chat_models.dart';
import 'models/collection_models.dart';
import 'models/feed_post.dart';
import 'models/preset_comment.dart';
import 'models/profile_stats.dart';
import 'models/render_preset.dart';
import 'services/app_repository.dart';
import 'services/tracking_service.dart';
import 'services/web_file_upload.dart';
import 'widgets/preset_viewer.dart';

enum _ShellTab {
  home,
  collection,
  post,
  chat,
  profile,
  settings,
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
  });

  final String themeMode;
  final ValueChanged<String>? onThemeModeChanged;

  @override
  State<ShowFeedPage> createState() => _ShowFeedPageState();
}

class _ShowFeedPageState extends State<ShowFeedPage> {
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
  final GlobalKey<_ProfileTabState> _profileKey =
      GlobalKey<_ProfileTabState>();

  _ShellTab _activeTab = _ShellTab.home;
  bool _navExpanded = false;
  AppUserProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    final profile = await _repository.ensureCurrentProfile();
    if (!mounted) return;
    setState(() => _currentProfile = profile);
  }

  void _switchTab(_ShellTab tab) {
    setState(() => _activeTab = tab);
    if (tab == _ShellTab.home) {
      unawaited(_homeKey.currentState?._loadFeed());
    } else if (tab == _ShellTab.collection) {
      unawaited(_collectionKey.currentState?._loadCollections());
    } else if (tab == _ShellTab.chat) {
      unawaited(_chatKey.currentState?._bootstrap());
    } else if (tab == _ShellTab.profile) {
      unawaited(_profileKey.currentState?._load());
    } else if (tab == _ShellTab.settings) {
      unawaited(_loadProfile());
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool hideHomeBrand = _activeTab == _ShellTab.home && _navExpanded;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _navExpanded = true),
            onExit: (_) => setState(() => _navExpanded = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: _navExpanded ? 224 : 78,
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.95),
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
                      child: Row(
                        children: [
                          Icon(Icons.blur_on, color: cs.onSurface),
                          const SizedBox(width: 10),
                          if (_navExpanded)
                            Text(
                              'DeepX',
                              style: GoogleFonts.orbitron(
                                color: cs.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
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
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: hideHomeBrand ? 0 : 1,
                              child: Text(
                                _title,
                                style: (_activeTab == _ShellTab.home
                                        ? GoogleFonts.orbitron(
                                            fontWeight: FontWeight.w700,
                                          )
                                        : null)
                                    ?.copyWith(
                                      color: cs.onSurface,
                                      fontSize: 28,
                                    ) ??
                                    TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const Spacer(),
                            if (_currentProfile != null)
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundImage:
                                        (_currentProfile!.avatarUrl != null &&
                                                _currentProfile!
                                                    .avatarUrl!.isNotEmpty)
                                            ? NetworkImage(
                                                _currentProfile!.avatarUrl!)
                                            : null,
                                    backgroundColor:
                                        cs.surfaceContainerHighest,
                                    child: (_currentProfile!.avatarUrl ==
                                                null ||
                                            _currentProfile!
                                                .avatarUrl!.isEmpty)
                                        ? Icon(Icons.person,
                                            color: cs.onSurfaceVariant,
                                            size: 15)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _currentProfile!.displayName,
                                    style: TextStyle(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            IconButton(
                              tooltip: 'Reload',
                              onPressed: _reloadActiveTab,
                              icon: Icon(Icons.refresh, color: cs.onSurface),
                            ),
                            IconButton(
                              tooltip: 'Sign out',
                              onPressed: () async {
                                await _repository.signOut();
                                if (!context.mounted) return;
                                Navigator.pushReplacementNamed(context, '/auth');
                              },
                              icon: Icon(Icons.logout, color: cs.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTab.index,
                      children: [
                        _HomeFeedTab(key: _homeKey),
                        _CollectionTab(key: _collectionKey),
                        const _PostStudioTab(),
                        _ChatTab(key: _chatKey),
                        _ProfileTab(key: _profileKey, onProfileChanged: _loadProfile),
                        _SettingsTab(
                          currentThemeMode: widget.themeMode,
                          onThemeModeChanged: widget.onThemeModeChanged,
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
    final Color fg = widget.active ? Colors.black : widget.colorScheme.onSurface;
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
  const _HomeFeedTab({super.key});

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab> {
  final AppRepository _repository = AppRepository.instance;

  bool _loading = true;
  String? _error;
  final List<FeedPost> _posts = <FeedPost>[];

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

    final String? me = _repository.currentUser?.id;
    final bool mine = me != null && post.preset.userId == me;

    if (mine) {
      final Widget page = post.preset.mode == '2d'
          ? LayerMode(initialPresetPayload: post.preset.payload)
          : Engine3DPage(initialPresetPayload: post.preset.payload);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      await _loadFeed();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PresetDetailPage(initialPost: post),
      ),
    );
    await _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
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

    return LayoutBuilder(
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
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
          itemCount: _posts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 9,
          ),
          itemBuilder: (context, index) {
            final post = _posts[index];
            return _FeedTile(
              post: post,
              onTap: () => _openPost(post),
            );
          },
        );
      },
    );
  }
}

class _CollectionTab extends StatefulWidget {
  const _CollectionTab({super.key});

  @override
  State<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<_CollectionTab> {
  final AppRepository _repository = AppRepository.instance;

  bool _loading = true;
  String? _error;
  final List<CollectionSummary> _collections = <CollectionSummary>[];

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
      final collections = await _repository.fetchPublishedCollections(limit: 120);
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CollectionDetailPage(
          collectionId: summary.id,
          initialSummary: summary,
        ),
      ),
    );
    await _loadCollections();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
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

    return LayoutBuilder(
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
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
          itemCount: _collections.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 9,
          ),
          itemBuilder: (context, index) {
            final summary = _collections[index];
            return _CollectionFeedTile(
              summary: summary,
              onTap: () => _openCollection(summary),
            );
          },
        );
      },
    );
  }
}

class _CollectionFeedTile extends StatelessWidget {
  const _CollectionFeedTile({
    required this.summary,
    required this.onTap,
  });

  final CollectionSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = summary.firstItem;
    final preview = item == null
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
        : PresetViewer(
            mode: item.mode,
            payload: item.snapshot,
            cleanView: true,
            embedded: true,
            disableAudio: true,
          );

    Widget deckPlate({required double dx, required double dy, required double a}) {
      return Positioned(
        left: dx,
        right: dx,
        top: dy,
        bottom: dy,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: a),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            deckPlate(dx: 12, dy: 8, a: 0.35),
            deckPlate(dx: 6, dy: 4, a: 0.5),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: cs.surfaceContainerLow,
                  child: Stack(
                    children: [
                      Positioned.fill(child: IgnorePointer(child: preview)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                summary.author?.displayName ?? 'Unknown creator',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.82),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.layers, size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${summary.itemsCount} items',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.post,
    required this.onTap,
  });

  final FeedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Widget preview = PresetViewer(
      mode: post.preset.mode,
      payload: post.preset.payload,
      cleanView: true,
      embedded: true,
      disableAudio: true,
    );

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: preview)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author?.displayName ?? 'Unknown creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      children: [
                        _miniStat(Icons.thumb_up_alt_outlined, post.likesCount),
                        _miniStat(
                            Icons.thumb_down_alt_outlined, post.dislikesCount),
                        _miniStat(
                            Icons.mode_comment_outlined, post.commentsCount),
                        _miniStat(Icons.bookmark_border, post.savesCount),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
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

  late FeedPost _post;
  bool _loadingComments = true;
  bool _sendingComment = false;
  bool _commentsOpen = false;
  List<PresetComment> _comments = const <PresetComment>[];

  bool get _mine =>
      _repository.currentUser != null &&
      _repository.currentUser!.id == _post.preset.userId;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
      );
    });
  }

  Future<void> _toggleReaction(int value) async {
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
      );
    });
  }

  Future<void> _toggleSave() async {
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
      );
    });
  }

  Future<void> _toggleFollow() async {
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
      );
    });
  }

  Future<void> _shareToUser() async {
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

  Future<void> _sendComment() async {
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: viewer),
          Positioned(
            top: 14,
            left: 14,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _post.preset.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: (_post.author?.avatarUrl != null &&
                                _post.author!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_post.author!.avatarUrl!)
                            : null,
                        child: (_post.author?.avatarUrl == null ||
                                _post.author!.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _post.author?.displayName ?? 'Unknown creator',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_mine)
                    FilledButton.tonal(
                      onPressed: _toggleFollow,
                      child: Text(
                        _post.isFollowingAuthor ? 'Following' : 'Follow',
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _engagementButton(
                      icon: _post.myReaction == 1
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      active: _post.myReaction == 1,
                      activeColor: cs.primary,
                      label: _post.likesCount.toString(),
                      onTap: () => _toggleReaction(1),
                    ),
                    _engagementButton(
                      icon: _post.myReaction == -1
                          ? Icons.thumb_down_alt
                          : Icons.thumb_down_alt_outlined,
                      active: _post.myReaction == -1,
                      activeColor: Colors.redAccent,
                      label: _post.dislikesCount.toString(),
                      onTap: () => _toggleReaction(-1),
                    ),
                    _engagementButton(
                      icon: Icons.mode_comment_outlined,
                      active: _commentsOpen,
                      activeColor: cs.primary,
                      label: _post.commentsCount.toString(),
                      onTap: () => setState(() => _commentsOpen = !_commentsOpen),
                    ),
                    _engagementButton(
                      icon: Icons.send_outlined,
                      active: false,
                      activeColor: cs.primary,
                      label: '',
                      onTap: _shareToUser,
                    ),
                    _engagementButton(
                      icon:
                          _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      active: _post.isSaved,
                      activeColor: Colors.amberAccent,
                      label: _post.savesCount.toString(),
                      onTap: _toggleSave,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_commentsOpen)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _commentsOpen = false),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          const Text(
                            'Comments',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _loadingComments
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _comments.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No comments yet',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        itemCount: _comments.length,
                                        itemBuilder: (context, index) {
                                          final c = _comments[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                    color: Colors.white70),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${c.author?.displayName ?? 'User'}: ',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: Row(
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
                                  onPressed:
                                      _sendingComment ? null : _sendComment,
                                  child:
                                      Text(_sendingComment ? '...' : 'Send'),
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
            ),
        ],
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
  const _PostStudioTab();

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
  final List<CollectionDraftItem> _draftItems = <CollectionDraftItem>[];

  @override
  void dispose() {
    _collectionNameController.dispose();
    super.dispose();
  }

  void _onPresetSaved(String name, Map<String, dynamic> payload) {
    if (_postTypeIndex == 0) return;
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
      _editorSeed++;
    });
  }

  void _removeCollectionItem(int index) {
    setState(() {
      _draftItems.removeAt(index);
      if (_selectedItemIndex >= _draftItems.length) {
        _selectedItemIndex = _draftItems.length - 1;
      }
      _editorSeed++;
    });
  }

  void _createNewCollectionItem() {
    setState(() {
      _selectedItemIndex = -1;
      _editorSeed++;
    });
  }

  Future<void> _publishCollection() async {
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one preset to publish.')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final id = await _repository.saveCollectionWithItems(
        collectionId: _collectionId,
        name: _collectionNameController.text.trim(),
        publish: true,
        items: _draftItems,
      );
      _collectionId = id;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection published successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
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

  Widget _buildEditor() {
    final bool persistPresets = _postTypeIndex == 0;
    final activeItem = (_selectedItemIndex >= 0 &&
            _selectedItemIndex < _draftItems.length)
        ? _draftItems[_selectedItemIndex]
        : null;

    if (_modeIndex == 0) {
      return LayerMode(
        key: ValueKey('studio-2d-$_editorSeed-${activeItem?.name ?? 'none'}'),
        embedded: true,
        embeddedStudio: true,
        persistPresets: persistPresets,
        initialPresetPayload: activeItem?.mode == '2d' ? activeItem!.snapshot : null,
        onPresetSaved: _onPresetSaved,
      );
    }
    return Engine3DPage(
      key: ValueKey('studio-3d-$_editorSeed-${activeItem?.name ?? 'none'}'),
      embedded: true,
      embeddedStudio: true,
      persistPresets: persistPresets,
      initialPresetPayload: activeItem?.mode == '3d' ? activeItem!.snapshot : null,
      onPresetSaved: _onPresetSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool collectionMode = _postTypeIndex == 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('2D Mode')),
                  ButtonSegment<int>(value: 1, label: Text('3D Mode')),
                ],
                selected: <int>{_modeIndex},
                onSelectionChanged: (values) {
                  setState(() => _modeIndex = values.first);
                },
              ),
              const SizedBox(width: 10),
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
              const Spacer(),
              if (collectionMode) ...[
                OutlinedButton.icon(
                  onPressed: _previewCollection,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _publishing ? null : _publishCollection,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(_publishing ? 'Publishing...' : 'Publish'),
                ),
              ],
            ],
          ),
        ),
        if (collectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _collectionNameController,
              decoration: const InputDecoration(
                labelText: 'Collection Name',
                prefixIcon: Icon(Icons.collections_bookmark_outlined),
              ),
            ),
          ),
        Expanded(
          child: Row(
            children: [
              if (collectionMode)
                Container(
                  width: 320,
                  margin: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Collection Manager',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _createNewCollectionItem,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Add New'),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _draftItems.isEmpty
                            ? const Center(
                                child: Text('Save presets to add them here.'),
                              )
                            : ReorderableListView.builder(
                                itemCount: _draftItems.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = _draftItems.removeAt(oldIndex);
                                    _draftItems.insert(newIndex, item);
                                    _selectedItemIndex = newIndex;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final item = _draftItems[index];
                                  final bool active = index == _selectedItemIndex;
                                  return ListTile(
                                    key: ValueKey('collection-item-$index-${item.name}'),
                                    selected: active,
                                    selectedTileColor:
                                        cs.primary.withValues(alpha: 0.14),
                                    title: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(item.mode.toUpperCase()),
                                    leading: Icon(
                                      item.mode == '2d'
                                          ? Icons.layers_outlined
                                          : Icons.view_in_ar_outlined,
                                    ),
                                    trailing: IconButton(
                                      onPressed: () => _removeCollectionItem(index),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                    onTap: () => _selectCollectionItem(index),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildEditor(),
                ),
              ),
            ],
          ),
        ),
      ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: PresetViewer(
              mode: item.mode,
              payload: item.snapshot,
              cleanView: true,
              embedded: true,
              disableAudio: true,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Collection Preview',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (widget.items.isNotEmpty)
                    Text(
                      '${_index + 1}/${widget.items.length}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Text(
                        'No items in collection.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      child: SwipableStack(
                        controller: _stackController,
                        itemCount: widget.items.length,
                        allowVerticalSwipe: false,
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
                      ),
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

  bool _loading = true;
  String? _error;
  CollectionDetail? _detail;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _stackController.addListener(_onStackChanged);
    _load();
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
    final next = _stackController.currentIndex;
    if (_detail == null || _detail!.items.isEmpty) return;
    if (next == _index) return;
    setState(() {
      final int max = _detail!.items.length - 1;
      _index = next < 0 ? 0 : (next > max ? max : next);
    });
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget _buildCard(CollectionItemSnapshot item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: PresetViewer(
              mode: item.mode,
              payload: item.snapshot,
              cleanView: true,
              embedded: true,
              disableAudio: true,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.76),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = _detail?.summary ?? widget.initialSummary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary?.name ?? 'Collection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          summary?.author?.displayName ?? 'Unknown creator',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (_detail != null && _detail!.items.isNotEmpty)
                    Text(
                      '${_index + 1}/${_detail!.items.length}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_loading) {
                    return Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    );
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
                  final detail = _detail;
                  if (detail == null || detail.items.isEmpty) {
                    return Center(
                      child: Text(
                        'Collection is empty.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: SwipableStack(
                      controller: _stackController,
                      itemCount: detail.items.length,
                      allowVerticalSwipe: false,
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

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({super.key, required this.onProfileChanged});

  final Future<void> Function() onProfileChanged;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
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
  List<RenderPreset> _posts = const <RenderPreset>[];
  List<RenderPreset> _history = const <RenderPreset>[];

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
    final posts = await _repository.fetchUserPosts(user.id);
    final history = await _repository.fetchHistoryPresetsForCurrentUser();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _stats = stats;
      _saved = saved;
      _posts = posts;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _openPost(RenderPreset preset) async {
    final String? me = _repository.currentUser?.id;
    final bool mine = me != null && preset.userId == me;
    await _repository.recordPresetView(preset.id);

    if (mine) {
      final Widget page = preset.mode == '2d'
          ? LayerMode(initialPresetPayload: preset.payload)
          : Engine3DPage(initialPresetPayload: preset.payload);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      await _load();
      return;
    }

    final FeedPost? post = await _repository.fetchFeedPostById(preset.id);
    if (!mounted) return;
    if (post != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PresetDetailPage(initialPost: post)),
      );
      await _load();
    }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
    }

    if (_profile == null) {
      return Center(
        child: Text(
          'Profile unavailable',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
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
                          ? Icon(Icons.person, color: cs.onSurfaceVariant, size: 34)
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
                    FilledButton.tonal(
                      onPressed: _editProfile,
                      child: const Text('Edit Profile'),
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
              Tab(text: 'Saved Collection'),
              Tab(text: 'My Posts'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PresetListView(
                  presets: _saved,
                  emptyMessage: 'Nothing saved yet.',
                  onTap: _openPost,
                ),
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
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
            '${preset.mode.toUpperCase()} · ${_friendlyTime(preset.updatedAt)}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: () => onTap(preset),
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
    final file = await pickDeviceFile(accept: 'image/*');
    if (file == null) return;
    final String url = await _repository.uploadProfileAvatar(
      bytes: file.bytes,
      fileName: file.name,
      contentType: file.contentType,
    );
    if (!mounted) return;
    setState(() => _avatarUrl = url);
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
                        ? Icon(Icons.person, color: cs.onSurfaceVariant, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _uploadAvatar,
                    child: const Text('Upload Profile Picture'),
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
  const _ChatTab({super.key});

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
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
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
        active = chats.first;
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
      await _bootstrap();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share preset: $e')),
      );
    }
  }

  Future<void> _openSharedPreset(String presetId) async {
    final preset = await _repository.fetchPresetById(presetId);
    if (!mounted || preset == null) return;

    final FeedPost? post = await _repository.fetchFeedPostById(presetId);
    if (!mounted) return;
    if (post != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PresetDetailPage(initialPost: post)),
      );
      return;
    }

    final page = preset.mode == '2d'
        ? LayerMode(cleanView: true, initialPresetPayload: preset.payload)
        : Engine3DPage(
            embedded: true,
            cleanView: true,
            disableAudio: true,
            initialPresetPayload: preset.payload,
          );
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _newDirectChat() async {
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Start Direct Chat'),
    );
    if (profile == null) return;
    try {
      await _repository.createOrGetDirectChat(profile.userId);
      await _bootstrap();
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
      await _repository.createGroupChat(
        name: result.name,
        memberIds: result.memberIds,
      );
      await _bootstrap();
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
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
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
                color: cs.surfaceContainerLow,
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
                                    style: TextStyle(color: cs.onSurfaceVariant),
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
                                            ? cs.primary
                                                .withValues(alpha: 0.18)
                                            : cs.surfaceContainerHighest
                                                .withValues(alpha: 0.45),
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
                                                style:
                                                    TextStyle(color: cs.onSurface),
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
                                    fillColor:
                                        cs.surfaceContainerHighest.withValues(alpha: 0.4),
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

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final profiles = await _repository.searchProfiles(_searchController.text);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
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
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(color: cs.primary),
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

  bool _loading = true;
  List<AppUserProfile> _profiles = const <AppUserProfile>[];
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await _repository.searchProfiles('', limit: 40);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: cs.primary),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final p = _profiles[index];
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
          onPressed: () {
            final String name = _nameController.text.trim();
            if (name.isEmpty || _selected.isEmpty) return;
            Navigator.pop(
              context,
              _GroupChatPayload(name: name, memberIds: _selected.toList()),
            );
          },
          child: const Text('Create'),
        ),
      ],
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
  bool _cursorEnabled = true;
  bool _prefsLoading = true;

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
      if (!mounted) return;
      setState(() {
        _trackerEnabled = prefs['trackerEnabled'] ?? true;
        _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
        _prefsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefsLoading = false);
    }
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
    TrackingService.instance.setDartCursorEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(color: cs.primary),
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
              ],
            ],
          ),
        ),
      ],
    );
  }
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
