import 'app_user_profile.dart';
import 'render_preset.dart';

class FeedPost {
  FeedPost({
    required this.preset,
    required this.author,
    required this.likesCount,
    required this.dislikesCount,
    required this.commentsCount,
    required this.savesCount,
    required this.myReaction,
    required this.isSaved,
    required this.isFollowingAuthor,
    this.viewsCount = 0,
    this.isWatchLater = false,
  });

  final RenderPreset preset;
  final AppUserProfile? author;
  final int likesCount;
  final int dislikesCount;
  final int commentsCount;
  final int savesCount;
  final int myReaction;
  final bool isSaved;
  final bool isFollowingAuthor;
  final int viewsCount;
  final bool isWatchLater;
}
