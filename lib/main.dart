import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'engine3d.dart';
import 'layer_mode.dart';
import 'services/app_repository.dart';
import 'services/tracking_service.dart';
import 'show_feed.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppRepository _repository = AppRepository.instance;

  String _themeMode = 'dark';
  StreamSubscription<AuthState>? _authSub;
  bool _trackerReady = false;

  @override
  void initState() {
    super.initState();
    _initTracking();
    if (SupabaseConfig.isConfigured) {
      _loadThemeMode();
      _authSub = _repository.authChanges.listen((_) {
        _loadThemeMode();
        TrackingService.instance.refreshPreferences();
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    if (!SupabaseConfig.isConfigured) return;
    final mode = await _repository.fetchThemeModeForCurrentUser();
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  void _onThemeModeChanged(String mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _initTracking() async {
    await TrackingService.instance.initialize();
    if (!mounted) return;
    setState(() => _trackerReady = true);
  }

  ThemeMode get _resolvedTheme {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepX',
      themeMode: _resolvedTheme,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0095F6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        cardColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF0095F6),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF121212),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141414),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      initialRoute: SupabaseConfig.isConfigured ? '/auth' : '/config',
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();
        if (!_trackerReady) return safeChild;
        return TrackingService.instance.buildGlobalOverlay(child: safeChild);
      },
      routes: {
        '/auth': (context) => const AuthPage(),
        '/feed': (context) => ShowFeedPage(
              themeMode: _themeMode,
              onThemeModeChanged: _onThemeModeChanged,
            ),
        '/app': (context) => ShowFeedPage(
              themeMode: _themeMode,
              onThemeModeChanged: _onThemeModeChanged,
            ),
        '/2d': (context) => const LayerMode(),
        '/3d': (context) => const Engine3DPage(),
        '/config': (context) => const _SupabaseConfigMissingPage(),
      },
    );
  }
}

class _SupabaseConfigMissingPage extends StatelessWidget {
  const _SupabaseConfigMissingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Missing Supabase config.\nRun with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
