import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';

import 'engine3d.dart';
import 'layer_mode.dart';
import 'models/render_preset.dart';
import 'services/app_repository.dart';

class ShowFeedPage extends StatefulWidget {
  const ShowFeedPage({super.key});

  @override
  State<ShowFeedPage> createState() => _ShowFeedPageState();
}

class _ShowFeedPageState extends State<ShowFeedPage> {
  final AppRepository _repository = AppRepository.instance;
  final List<RenderPreset> _presets = <RenderPreset>[];

  bool _loading = true;
  String? _error;
  late final String _trackerViewId;
  StreamSubscription? _trackerSubscription;

  Map<String, double> _headPose = <String, double>{
    'x': 0.0,
    'y': 0.0,
    'z': 0.2,
    'yaw': 0.0,
    'pitch': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _trackerViewId = 'feed-tracker-${DateTime.now().millisecondsSinceEpoch}';
    _initTracker();
    _loadFeed();
  }

  void _initTracker() {
    ui_web.platformViewRegistry.registerViewFactory(_trackerViewId,
        (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..setAttribute('width', '100%')
        ..setAttribute('height', '100%')
        ..src = 'assets/tracker.html'
        ..allow = 'camera *; microphone *; fullscreen *';
      iframe.style.setProperty('border', 'none');
      return iframe;
    });

    _trackerSubscription = web.window.onMessage.listen((event) {
      final data = event.data;
      if (!data.isA<JSString>()) return;

      final jsonString = (data as JSString).toDart;
      try {
        final messageData = jsonDecode(jsonString);
        if (messageData is! Map || messageData['head'] is! Map) return;
        final head = Map<String, dynamic>.from(messageData['head'] as Map);
        if (!mounted) return;
        setState(() {
          _headPose = <String, double>{
            'x': (head['x'] ?? 0.0).toDouble(),
            'y': (head['y'] ?? 0.0).toDouble(),
            'z': (head['z'] ?? 0.2).toDouble(),
            'yaw': (head['yaw'] ?? 0.0).toDouble(),
            'pitch': (head['pitch'] ?? 0.0).toDouble(),
          };
        });
      } catch (_) {
        // Ignore non-tracker events.
      }
    });
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchFeedPresets();
      if (!mounted) return;
      setState(() {
        _presets
          ..clear()
          ..addAll(items.where((e) => e.mode == '2d' || e.mode == '3d'));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _trackerSubscription?.cancel();
    super.dispose();
  }

  void _openPreset(RenderPreset preset) {
    final page = preset.mode == '2d'
        ? LayerMode(initialPresetPayload: preset.payload)
        : Engine3DPage(initialPresetPayload: preset.payload);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Show Feed'),
        actions: [
          IconButton(onPressed: _loadFeed, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await _repository.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/auth');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            left: -500,
            top: -500,
            width: 240,
            height: 240,
            child: HtmlElementView(viewType: _trackerViewId),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                itemCount: _presets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 16 / 9,
                ),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  return GestureDetector(
                    onTap: () => _openPreset(preset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: Colors.black,
                        child: IgnorePointer(
                          child: preset.mode == '2d'
                              ? LayerMode(
                                  cleanView: true,
                                  initialPresetPayload: preset.payload,
                                  externalHeadPose: _headPose,
                                )
                              : Engine3DPage(
                                  embedded: true,
                                  cleanView: true,
                                  disableAudio: true,
                                  initialPresetPayload: preset.payload,
                                  externalHeadPose: _headPose,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
