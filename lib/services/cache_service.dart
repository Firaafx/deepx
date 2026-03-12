import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum CacheDomain {
  feed,
  collections,
  comments,
  profile,
  saved,
}

class CacheEntry {
  CacheEntry({
    required this.data,
    required this.lastFetchedAt,
    required this.dirty,
    required this.domains,
  });

  final Object? data;
  final DateTime lastFetchedAt;
  final bool dirty;
  final Set<CacheDomain> domains;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'data': data,
      'lastFetchedAt': lastFetchedAt.toIso8601String(),
      'dirty': dirty,
      'domains': domains.map((domain) => domain.name).toList(),
    };
  }

  static CacheEntry? fromJson(Map<String, dynamic> json) {
    final Object? rawDomains = json['domains'];
    final List<String> domainNames = rawDomains is List
        ? rawDomains.map((e) => e.toString()).toList()
        : const <String>[];
    final Set<CacheDomain> domains = domainNames
        .map(
          (name) => CacheDomain.values.firstWhere(
            (domain) => domain.name == name,
            orElse: () => CacheDomain.feed,
          ),
        )
        .toSet();
    final String rawDate = json['lastFetchedAt']?.toString() ?? '';
    final DateTime parsed =
        DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return CacheEntry(
      data: json['data'],
      lastFetchedAt: parsed,
      dirty: json['dirty'] == true,
      domains: domains,
    );
  }
}

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  static const String _keysKey = 'cache.keys';
  static const String _entryPrefix = 'cache.entry.';

  final Map<String, CacheEntry> _entries = <String, CacheEntry>{};
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> keys = _prefs?.getStringList(_keysKey) ?? <String>[];
    for (final key in keys) {
      final raw = _prefs?.getString('$_entryPrefix$key');
      if (raw == null || raw.isEmpty) continue;
      try {
        final Map<String, dynamic> json =
            jsonDecode(raw) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(json);
        if (entry != null) _entries[key] = entry;
      } catch (_) {}
    }
  }

  CacheEntry? entryForKey(String key) => _entries[key];

  Future<T> getOrFetch<T>({
    required String key,
    required Set<CacheDomain> domains,
    required Future<T> Function() fetch,
    required Object? Function(T value) encode,
    required T Function(Object? data) decode,
  }) async {
    final CacheEntry? existing = _entries[key];
    if (existing != null && !existing.dirty) {
      return decode(existing.data);
    }
    try {
      final T result = await fetch();
      final CacheEntry next = CacheEntry(
        data: encode(result),
        lastFetchedAt: DateTime.now().toUtc(),
        dirty: false,
        domains: domains,
      );
      _entries[key] = next;
      await _persistEntry(key, next);
      return result;
    } catch (error) {
      if (existing != null) {
        return decode(existing.data);
      }
      rethrow;
    }
  }

  Future<void> markDomainsDirty(Set<CacheDomain> domains) async {
    if (domains.isEmpty) return;
    final List<Future<void>> writes = <Future<void>>[];
    _entries.forEach((key, entry) {
      if (entry.domains.any(domains.contains)) {
        final CacheEntry dirtyEntry = CacheEntry(
          data: entry.data,
          lastFetchedAt: entry.lastFetchedAt,
          dirty: true,
          domains: entry.domains,
        );
        _entries[key] = dirtyEntry;
        writes.add(_persistEntry(key, dirtyEntry));
      }
    });
    if (writes.isNotEmpty) {
      await Future.wait(writes);
    }
  }

  Future<void> markDomainDirty(CacheDomain domain) {
    return markDomainsDirty(<CacheDomain>{domain});
  }

  Future<void> _persistEntry(String key, CacheEntry entry) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final List<String> keys =
        prefs.getStringList(_keysKey) ?? <String>[];
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList(_keysKey, keys);
    }
    await prefs.setString(
      '$_entryPrefix$key',
      jsonEncode(entry.toJson()),
    );
  }
}
