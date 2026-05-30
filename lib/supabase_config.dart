class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String instantSplatWorkerUrl =
      String.fromEnvironment('INSTANTSPLAT_WORKER_URL');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get hasInstantSplatWorker => instantSplatWorkerUrl.isNotEmpty;
}
