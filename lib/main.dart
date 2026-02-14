import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'engine3d.dart';
import 'layer_mode.dart';
import 'services/app_repository.dart';
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

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      _loadThemeMode();
      _authSub = _repository.authChanges.listen((_) {
        _loadThemeMode();
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006E90)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF00B8D4),
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: SupabaseConfig.isConfigured ? '/auth' : '/config',
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
