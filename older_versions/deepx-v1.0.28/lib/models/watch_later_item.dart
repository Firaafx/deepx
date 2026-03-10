import 'collection_models.dart';
import 'render_preset.dart';

enum WatchLaterTargetType {
  post,
  collection,
}

class WatchLaterItem {
  WatchLaterItem.post({
    required this.id,
    required this.createdAt,
    required this.post,
  })  : type = WatchLaterTargetType.post,
        collection = null;

  WatchLaterItem.collection({
    required this.id,
    required this.createdAt,
    required this.collection,
  })  : type = WatchLaterTargetType.collection,
        post = null;

  final String id;
  final WatchLaterTargetType type;
  final DateTime createdAt;
  final RenderPreset? post;
  final CollectionSummary? collection;
}
