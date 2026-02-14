import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'engine3d.dart';
import 'layer_mode.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepX',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: SupabaseConfig.isConfigured ? '/auth' : '/config',
      routes: {
        '/auth': (context) => const AuthPage(),
        '/feed': (context) => const ShowFeedPage(),
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
