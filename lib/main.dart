import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'services/app_repository.dart';
import 'services/appearance_settings_service.dart';
import 'services/cache_service.dart';
import 'services/realtime_cache_invalidator.dart';
import 'show_feed.dart';
import 'supabase_config.dart';
import 'widgets/tracker_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppearanceSettingsService.instance.initialize();
  await CacheService.instance.initialize();
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
        RealtimeCacheInvalidator.instance.start();
      });
      RealtimeCacheInvalidator.instance.start();
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
    List<String> normalizedPathSegments(Uri uri) {
      final List<String> raw =
          uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      final List<String> basePath =
          Uri.base.pathSegments.where((segment) => segment.isNotEmpty).toList();
      final bool hostedOnGithubPages =
          Uri.base.host.toLowerCase().endsWith('github.io');
      final String? repoPrefix =
          hostedOnGithubPages && basePath.isNotEmpty ? basePath.first : null;
      if (repoPrefix != null &&
          raw.isNotEmpty &&
          raw.first.toLowerCase() == repoPrefix.toLowerCase()) {
        return raw.sublist(1);
      }
      return raw;
    }

    Route<dynamic> buildFeedRoute({
      required String name,
      required String initialTab,
    }) {
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => ShowFeedPage(
          themeMode: _themeMode,
          onThemeModeChanged: _onThemeModeChanged,
          initialTab: initialTab,
        ),
      );
    }

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
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.white,
          linearTrackColor: Colors.transparent,
        ),
        chipTheme: const ChipThemeData(
          selectedColor: Colors.white,
          secondarySelectedColor: Colors.white,
          checkmarkColor: Colors.black,
          side: BorderSide(color: Color(0x33000000)),
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          secondaryLabelStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        scaffoldBackgroundColor: const Color(0xFF101213),
        cardColor: const Color(0xFF121212),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.white,
          linearTrackColor: Colors.transparent,
        ),
        chipTheme: const ChipThemeData(
          selectedColor: Colors.white,
          secondarySelectedColor: Colors.white,
          checkmarkColor: Colors.black,
          side: BorderSide(color: Color(0x33FFFFFF)),
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          secondaryLabelStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141414),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      initialRoute: SupabaseConfig.isConfigured ? '/feed/home' : '/config',
      builder: (context, child) => TrackerOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
      onGenerateRoute: (settings) {
        final String name = settings.name ?? '/';
        final Uri uri = Uri.parse(name);
        final List<String> segments = normalizedPathSegments(uri);

        if (name == '/auth') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const AuthPage(),
          );
        }
        if (name == '/config') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const _SupabaseConfigMissingPage(),
          );
        }

        if (name == '/feed' || name == '/app') {
          return buildFeedRoute(name: '/feed/home', initialTab: 'home');
        }

        if (segments.isNotEmpty && segments.first.startsWith('@')) {
          final String username =
              Uri.decodeComponent(segments.first.substring(1)).trim();
          return MaterialPageRoute<void>(
            settings: RouteSettings(name: '/@$username'),
            builder: (_) => StandalonePublicProfileRoutePage(
              username: username,
            ),
          );
        }

        if (segments.isNotEmpty && segments.first == 'post') {
          final String idOrShareId =
              segments.length > 1 ? Uri.decodeComponent(segments[1]) : '';
          return MaterialPageRoute<void>(
            settings: RouteSettings(name: '/post/$idOrShareId'),
            builder: (_) => StandalonePostRoutePage(
              idOrShareId: idOrShareId,
            ),
          );
        }
        if (segments.isNotEmpty && segments.first == 'collection') {
          final String idOrShareId =
              segments.length > 1 ? Uri.decodeComponent(segments[1]) : '';
          return MaterialPageRoute<void>(
            settings: RouteSettings(name: '/collection/$idOrShareId'),
            builder: (_) => StandaloneCollectionRoutePage(
              idOrShareId: idOrShareId,
            ),
          );
        }

        if (segments.isNotEmpty && segments.first == 'feed') {
          final String tab = segments.length > 1 ? segments[1] : 'home';
          return buildFeedRoute(name: '/feed/$tab', initialTab: tab);
        }

        if (!SupabaseConfig.isConfigured) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/config'),
            builder: (_) => const _SupabaseConfigMissingPage(),
          );
        }
        return buildFeedRoute(name: '/feed/home', initialTab: 'home');
      },
    );
  }
}

class _SupabaseConfigMissingPage extends StatelessWidget {
  const _SupabaseConfigMissingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF101213),
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
