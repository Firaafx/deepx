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
  final _TrackingRouteObserver _trackingRouteObserver =
      _TrackingRouteObserver();

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
      initialRoute: SupabaseConfig.isConfigured ? '/feed/home' : '/config',
      navigatorObservers: <NavigatorObserver>[_trackingRouteObserver],
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();
        if (!_trackerReady) return safeChild;
        return TrackingService.instance.buildGlobalOverlay(child: safeChild);
      },
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
        if (name == '/2d') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const LayerMode(),
          );
        }
        if (name == '/3d') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Engine3DPage(),
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

class _TrackingRouteObserver extends NavigatorObserver {
  bool _isTrackingActiveRoute(String name) {
    final String trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed == '/auth' || trimmed == '/config') return false;
    if (trimmed == '/feed' || trimmed == '/app') return true;
    if (trimmed == '/2d' || trimmed == '/3d') return true;
    if (trimmed.startsWith('/feed/')) return true;
    if (trimmed.startsWith('/post/')) return true;
    if (trimmed.startsWith('/collection/')) return true;
    if (trimmed.startsWith('/@')) return true;
    return false;
  }

  void _sync(Route<dynamic>? route) {
    final String name = route?.settings.name?.toString() ?? '';
    TrackingService.instance.setRouteActive(_isTrackingActiveRoute(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync(previousRoute);
  }
}
