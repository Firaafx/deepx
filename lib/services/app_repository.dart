import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/render_preset.dart';

class AppRepository {
  AppRepository._();

  static final AppRepository instance = AppRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
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
      {
        'user_id': user.id,
        'mode': mode,
        'state': state,
      },
      onConflict: 'user_id,mode',
    );
  }

  Future<List<RenderPreset>> fetchUserPresets({String? mode}) async {
    final user = currentUser;
    if (user == null) return const [];

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
        .map((e) => RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RenderPreset>> fetchFeedPresets({int limit = 200}) async {
    final List<dynamic> rows = await _client
        .from('presets')
        .select('*')
        .order('updated_at', ascending: false)
        .limit(limit);

    return rows
        .map((e) => RenderPreset.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> savePreset({
    required String mode,
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('presets').upsert(
      {
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
}
