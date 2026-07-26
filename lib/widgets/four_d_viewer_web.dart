// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class FourDViewer extends StatefulWidget {
  const FourDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.trackingEnabled = false,
    this.showLoadingProgress = true,
    this.onSpatialViewRequested,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool trackingEnabled;
  final bool showLoadingProgress;
  final VoidCallback? onSpatialViewRequested;

  @override
  State<FourDViewer> createState() => _FourDViewerState();
}

class _FourDViewerState extends State<FourDViewer> {
  static int _nextId = 0;

  late final String _elementId;
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _resizeSub;
  Timer? _mountRetryTimer;
  bool _factoryRegistered = false;
  String _mountedAssetKey = '';
  String _loadStatus = '';
  String _loadLabel = '';
  double? _loadProgress;

  @override
  void initState() {
    super.initState();
    _elementId = 'raymax-4dv-viewer-${_nextId++}';
    _viewType = 'raymax-4dv-view-$_elementId';
    _messageSub = html.window.onMessage.listen(_handleMessage);
    _resizeSub = html.window.onResize.listen((_) => _resizeIfAlive());
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountOrUpdate());
  }

  @override
  void didUpdateWidget(covariant FourDViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountOrUpdate());
  }

  @override
  void dispose() {
    final dynamic player = js.context['RayMax4DVPlayer'];
    if (player != null) {
      try {
        player.callMethod('dispose', <Object>[_elementId]);
      } catch (_) {}
    }
    _mountRetryTimer?.cancel();
    _messageSub?.cancel();
    _resizeSub?.cancel();
    super.dispose();
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Asset key extraction â€” determines which 4D asset
   *  to load from the payload map.
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  String _assetNameFromPayload() {
    final dynamic rawMedia = widget.payload['media'];
    final Map<String, dynamic> media = rawMedia is Map
        ? Map<String, dynamic>.from(rawMedia)
        : Map<String, dynamic>.from(widget.payload);
    // Prefer explicit 4DV asset name, fall back to URL-derived name, then 'rocket'
    final String explicit =
        (media['fourDAsset'] ?? media['4dv_asset'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;

    final String url =
        (media['url'] ?? media['assetUrl'] ?? '').toString().trim();
    if (url.contains('4dv.ai/assets/')) {
      final Uri? parsed = Uri.tryParse(url);
      if (parsed != null && parsed.pathSegments.isNotEmpty) {
        return parsed.pathSegments.last;
      }
    }
    // Default demo asset
    return 'rocket';
  }

  String _assetKey() => _assetNameFromPayload();

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Mount / update logic
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  void _mountOrUpdate() {
    final dynamic player = js.context['RayMax4DVPlayer'];
    if (player == null) {
      _scheduleMountRetry();
      return;
    }
    final html.Element? host = html.document.getElementById(_elementId);
    if (host == null ||
        host.isConnected != true ||
        host.clientWidth <= 0 ||
        host.clientHeight <= 0) {
      _scheduleMountRetry();
      return;
    }
    _mountRetryTimer?.cancel();
    _mountRetryTimer = null;

    final String nextAssetKey = _assetKey();
    final bool missingPlayer =
        _mountedAssetKey.isNotEmpty && !_playerAlive(player);

    if (missingPlayer || _mountedAssetKey != nextAssetKey) {
      _mountedAssetKey = nextAssetKey;
      if (mounted) {
        setState(() {
          _loadStatus = 'loading';
          _loadLabel = 'Loading 4D player';
          _loadProgress = null;
        });
      }
      final String configJson = jsonEncode(<String, dynamic>{
        'asset': nextAssetKey,
        'showSelector': false,
        'showBadge': true,
        'params': <String, dynamic>{
          'nowheel': '',
          'lang': 'en',
        },
      });
      player.callMethod('mount', <Object>[_elementId, configJson]);
      return;
    }
  }

  void _scheduleMountRetry() {
    if (!mounted || _mountRetryTimer?.isActive == true) return;
    _mountRetryTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _mountOrUpdate();
    });
  }

  bool _playerAlive(dynamic player) {
    try {
      return player.callMethod('isAlive', <Object>[_elementId]) == true;
    } catch (_) {
      return false;
    }
  }

  void _resizeIfAlive() {
    if (!mounted) return;
    final dynamic player = js.context['RayMax4DVPlayer'];
    if (player == null) return;
    try {
      player.callMethod('resize', <Object>[_elementId]);
    } catch (_) {}
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Message handling â€” receives load-state updates
   *  from the JS bridge via window.postMessage.
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  void _handleMessage(html.MessageEvent event) {
    final Map<String, dynamic>? data = _messageMap(event.data);
    if (data == null || data['elementId'] != _elementId) return;
    if (data['type'] == 'raymax-4dv-load-state') {
      final dynamic rawProgress = data['progress'];
      final double? progress = rawProgress is num
          ? rawProgress.toDouble().clamp(0, 1).toDouble()
          : null;
      if (!mounted) return;
      setState(() {
        _loadStatus = data['status']?.toString() ?? '';
        _loadLabel = data['label']?.toString() ?? '';
        _loadProgress = progress;
      });
      return;
    }
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Loading overlay â€” shows progress while player loads
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  Widget _buildLoadingProgress(BuildContext context) {
    if (!widget.showLoadingProgress || _loadStatus != 'loading') {
      return const SizedBox.shrink();
    }
    final double? progress = _loadProgress;
    final bool hasProgress = progress != null;
    final String label =
        _loadLabel.trim().isEmpty ? 'Loading 4D player' : _loadLabel.trim();
    final String text =
        hasProgress ? '$label ${((progress) * 100).round()}%' : label;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(value: progress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Utility
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  Map<String, dynamic>? _messageMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
      return null;
    }
    return null;
  }

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  Build
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  @override
  Widget build(BuildContext context) {
    if (!_factoryRegistered) {
      _factoryRegistered = true;
      ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return html.DivElement()
          ..id = _elementId
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#000';
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        _buildLoadingProgress(context),
      ],
    );
  }
}
