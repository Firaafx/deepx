import 'dart:async';

import 'package:flutter/material.dart';

import 'engine3d.dart';
import 'layer_mode.dart';
import 'models/app_user_profile.dart';
import 'models/chat_models.dart';
import 'models/feed_post.dart';
import 'models/preset_comment.dart';
import 'models/profile_stats.dart';
import 'models/render_preset.dart';
import 'services/app_repository.dart';
import 'services/web_file_upload.dart';

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

  _ShellTab _activeTab = _ShellTab.home;
  bool _navExpanded = false;
  AppUserProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _repository.ensureCurrentProfile();
    if (!mounted) return;
    setState(() => _currentProfile = profile);
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
    return Scaffold(
      backgroundColor: Colors.black,
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
                color: const Color(0xFF090909),
                border: Border(
                  right:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                          const Icon(Icons.blur_on, color: Colors.white),
                          const SizedBox(width: 10),
                          if (_navExpanded)
                            const Text(
                              'DeepX',
                              style: TextStyle(
                                color: Colors.white,
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
                        icon: item.icon,
                        label: item.label,
                        onTap: () => setState(() => _activeTab = item.tab),
                      ),
                    const Spacer(),
                    _NavButton(
                      expanded: _navExpanded,
                      active: _activeTab == _ShellTab.settings,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () =>
                          setState(() => _activeTab = _ShellTab.settings),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        if (_currentProfile != null)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage: (_currentProfile!.avatarUrl !=
                                            null &&
                                        _currentProfile!.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(_currentProfile!.avatarUrl!)
                                    : null,
                                backgroundColor: Colors.white12,
                                child: (_currentProfile!.avatarUrl == null ||
                                        _currentProfile!.avatarUrl!.isEmpty)
                                    ? const Icon(Icons.person,
                                        color: Colors.white70, size: 15)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _currentProfile!.displayName,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: () async {
                            await _repository.signOut();
                            if (!context.mounted) return;
                            Navigator.pushReplacementNamed(context, '/auth');
                          },
                          icon: const Icon(Icons.logout, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTab.index,
                      children: [
                        const _HomeFeedTab(),
                        const _CollectionPlaceholderTab(),
                        const _PostStudioTab(),
                        const _ChatTab(),
                        _ProfileTab(onProfileChanged: _loadProfile),
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.expanded,
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = active ? Colors.black : Colors.white;
    final Color bg = active ? Colors.white : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
              Icon(icon, color: fg, size: 24),
              if (expanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
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
    );
  }
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab();

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
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadFeed,
          icon: const Icon(Icons.refresh, color: Colors.white70),
          label: const Text(
            'Feed is empty. Refresh',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Refresh feed',
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, color: Colors.white70),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              int crossAxisCount = 2;
              if (width >= 1650) {
                crossAxisCount = 5;
              } else if (width >= 1280) {
                crossAxisCount = 4;
              } else if (width >= 900) {
                crossAxisCount = 3;
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: _posts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 9 / 14,
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
          ),
        ),
      ],
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
    final Widget preview = post.preset.mode == '2d'
        ? LayerMode(
            cleanView: true,
            initialPresetPayload: post.preset.payload,
          )
        : Engine3DPage(
            embedded: true,
            cleanView: true,
            disableAudio: true,
            initialPresetPayload: post.preset.payload,
          );

    return Material(
      color: const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(12),
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xD9000000), Color(0x00000000)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author?.displayName ?? 'Unknown creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
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

  Future<void> _shareToChat() async {
    final chats = await _repository.fetchChatsForCurrentUser();
    if (!mounted) return;

    if (chats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chats yet. Create one in Chat page.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Share Preset',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  title: Text(
                    chat.titleFor(_repository.currentUser?.id ?? ''),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    chat.isGroup ? 'Group' : 'Direct',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () async {
                    await _repository.sendChatMessage(
                      chatId: chat.id,
                      body: 'Shared a preset from feed',
                      sharedPresetId: _post.preset.id,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preset shared to chat.')),
    );
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
    final Widget viewer = _post.preset.mode == '2d'
        ? LayerMode(
            cleanView: true,
            initialPresetPayload: _post.preset.payload,
          )
        : Engine3DPage(
            embedded: true,
            cleanView: true,
            disableAudio: true,
            initialPresetPayload: _post.preset.payload,
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('DeepX'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: (_post.author?.avatarUrl != null &&
                          _post.author!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(_post.author!.avatarUrl!)
                      : null,
                  backgroundColor: Colors.white12,
                  child: (_post.author?.avatarUrl == null ||
                          _post.author!.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
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
                        _post.preset.name,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (!_mine)
                  OutlinedButton(
                    onPressed: _toggleFollow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: _post.isFollowingAuthor
                            ? Colors.white38
                            : Colors.cyanAccent,
                      ),
                    ),
                    child:
                        Text(_post.isFollowingAuthor ? 'Following' : 'Follow'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: viewer,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _toggleReaction(1),
                  icon: Icon(
                    _post.myReaction == 1
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_alt_outlined,
                    color: _post.myReaction == 1
                        ? Colors.cyanAccent
                        : Colors.white70,
                  ),
                ),
                Text('${_post.likesCount}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _toggleReaction(-1),
                  icon: Icon(
                    _post.myReaction == -1
                        ? Icons.thumb_down_alt
                        : Icons.thumb_down_alt_outlined,
                    color: _post.myReaction == -1
                        ? Colors.redAccent
                        : Colors.white70,
                  ),
                ),
                Text('${_post.dislikesCount}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _shareToChat,
                  icon: const Icon(Icons.send_outlined, color: Colors.white70),
                ),
                IconButton(
                  onPressed: _toggleSave,
                  icon: Icon(
                    _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _post.isSaved ? Colors.amberAccent : Colors.white70,
                  ),
                ),
                Text('${_post.savesCount}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 130,
                  child: _loadingComments
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.cyanAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : _comments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Text(
                                    '${comment.author?.displayName ?? 'User'}: ${comment.content}',
                                    style:
                                        const TextStyle(color: Colors.white70),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Color(0xFF1A1A1A),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendingComment ? null : _sendComment,
                      child: Text(_sendingComment ? 'Sending...' : 'Comment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  int _modeIndex = 0;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Upload from device is available in both editors and saves assets to Supabase Storage.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _modeIndex,
            children: const [
              LayerMode(embedded: true),
              Engine3DPage(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.onProfileChanged});

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
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_profile == null) {
      return const Center(
        child: Text('Profile unavailable',
            style: TextStyle(color: Colors.white70)),
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
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: (_profile!.avatarUrl != null &&
                          _profile!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(_profile!.avatarUrl!)
                      : null,
                  backgroundColor: Colors.white12,
                  child: (_profile!.avatarUrl == null ||
                          _profile!.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person,
                          color: Colors.white70, size: 34)
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _profile!.username?.isNotEmpty == true
                            ? '@${_profile!.username}'
                            : '@set_username',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _profile!.email,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profile!.bio.isEmpty ? 'No bio yet' : _profile!.bio,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _countBlock('Followers', _stats.followersCount),
                    const SizedBox(height: 8),
                    _countBlock('Following', _stats.followingCount),
                    const SizedBox(height: 8),
                    _countBlock('Posts', _stats.postsCount),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _editProfile,
                      child: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TabBar(
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54)),
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
    if (presets.isEmpty) {
      return Center(
        child:
            Text(emptyMessage, style: const TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final preset = presets[index];
        return ListTile(
          tileColor: const Color(0xFF111111),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(preset.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            '${preset.mode.toUpperCase()} · ${_friendlyTime(preset.updatedAt)}',
            style: const TextStyle(color: Colors.white54),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
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
                    backgroundColor: Colors.white12,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? const Icon(Icons.person,
                            color: Colors.white70, size: 32)
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
                style: const TextStyle(color: Colors.white70),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF121212),
                  border: OutlineInputBorder(),
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
  const _ChatTab();

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
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
    setState(() => _loading = true);
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
    await _repository.sendChatMessage(chatId: chat.id, body: text);
    await _bootstrap();
  }

  Future<void> _sharePreset(RenderPreset preset) async {
    final chat = _activeChat;
    if (chat == null) return;
    await _repository.sendChatMessage(
      chatId: chat.id,
      body: 'Shared a preset',
      sharedPresetId: preset.id,
    );
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
    await _repository.createOrGetDirectChat(profile.userId);
    await _bootstrap();
  }

  Future<void> _newGroupChat() async {
    final result = await showDialog<_GroupChatPayload>(
      context: context,
      builder: (context) => const _GroupChatDialog(),
    );
    if (result == null) return;
    await _repository.createGroupChat(
      name: result.name,
      memberIds: result.memberIds,
    );
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
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
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: _chats.isEmpty
                        ? const Center(
                            child: Text(
                              'No chats yet',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final bool active = _activeChat?.id == chat.id;
                              return ListTile(
                                selected: active,
                                selectedTileColor: Colors.white10,
                                title: Text(
                                  chat.titleFor(
                                      _repository.currentUser?.id ?? ''),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  chat.lastMessage ??
                                      (chat.isGroup
                                          ? 'Group chat'
                                          : 'Direct message'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54),
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
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: _activeChat == null
                  ? const Center(
                      child: Text(
                        'Select a chat',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _activeChat!.titleFor(
                                  _repository.currentUser?.id ?? '',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<RenderPreset>(
                                tooltip: 'Share preset',
                                onSelected: _sharePreset,
                                color: const Color(0xFF1B1B1B),
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
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.share_outlined,
                                      color: Colors.white70),
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
                                return const Center(
                                  child: Text(
                                    'No messages yet',
                                    style: TextStyle(color: Colors.white54),
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
                                            ? Colors.cyanAccent
                                                .withValues(alpha: 0.18)
                                            : Colors.white10,
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
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (msg.body.trim().isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                msg.body,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
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
                                              style: const TextStyle(
                                                color: Colors.white54,
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
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Color(0xFF171717),
                                    border: OutlineInputBorder(),
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
    final profiles = await _repository.searchProfiles(_searchController.text);
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151515),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search username/full name/email',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF1A1A1A),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        p.email,
                        style: const TextStyle(color: Colors.white54),
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
    final profiles = await _repository.searchProfiles('', limit: 40);
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151515),
      title: const Text('Create Group Chat',
          style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                      activeColor: Colors.cyanAccent,
                      checkColor: Colors.black,
                      title: Text(
                        p.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        p.email,
                        style: const TextStyle(color: Colors.white54),
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

  @override
  void initState() {
    super.initState();
    _themeMode = widget.currentThemeMode;
  }

  Future<void> _setTheme(String mode) async {
    setState(() => _themeMode = mode);
    await _repository.updateThemeModeForCurrentUser(mode);
    widget.onThemeModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Theme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how DeepX looks.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _themeMode,
                dropdownColor: const Color(0xFF161616),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'system', child: Text('System')),
                ],
                onChanged: (value) {
                  if (value != null) _setTheme(value);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF171717),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Reserved for upcoming app settings, notifications, privacy, and preferences.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionPlaceholderTab extends StatelessWidget {
  const _CollectionPlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Collection page is reserved for next implementation.',
        style: TextStyle(color: Colors.white54, fontSize: 16),
      ),
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
