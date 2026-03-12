import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';
import 'cache_service.dart';

class RealtimeCacheInvalidator {
  RealtimeCacheInvalidator._();

  static final RealtimeCacheInvalidator instance =
      RealtimeCacheInvalidator._();

  RealtimeChannel? _channel;

  Future<void> start() async {
    if (!SupabaseConfig.isConfigured) return;
    await stop();
    final client = Supabase.instance.client;
    final channel = client.channel('cache-invalidator');

    void listenTable(String table, Set<CacheDomain> domains) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          CacheService.instance.markDomainsDirty(domains);
        },
      );
    }

    listenTable('presets', {CacheDomain.feed});
    listenTable('preset_reactions', {CacheDomain.feed});
    listenTable('preset_comments', {CacheDomain.feed, CacheDomain.comments});
    listenTable('saved_presets', {CacheDomain.feed, CacheDomain.profile, CacheDomain.saved});
    listenTable('watch_later_items', {CacheDomain.feed, CacheDomain.collections, CacheDomain.profile, CacheDomain.saved});
    listenTable('follows', {CacheDomain.feed, CacheDomain.profile});

    listenTable('collections', {CacheDomain.collections});
    listenTable('collection_items', {CacheDomain.collections});
    listenTable('collection_reactions', {CacheDomain.collections});
    listenTable('collection_comments', {CacheDomain.collections, CacheDomain.comments});
    listenTable('saved_collections', {CacheDomain.collections, CacheDomain.profile, CacheDomain.saved});

    listenTable('profiles', {CacheDomain.profile});
    listenTable('view_history', {CacheDomain.profile, CacheDomain.saved});

    _channel = channel;
    channel.subscribe();
  }

  Future<void> stop() async {
    final channel = _channel;
    if (channel == null) return;
    await channel.unsubscribe();
    _channel = null;
  }
}
