// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class ThreeDViewer extends StatefulWidget {
  const ThreeDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.trackingEnabled = false,
    this.showModelControls = false,
    this.showLoadingProgress = true,
    this.transformOverride,
    this.onTransformChanged,
    this.onViewerStateChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool trackingEnabled;
  final bool showModelControls;
  final bool showLoadingProgress;
  final Map<String, dynamic>? transformOverride;
  final ValueChanged<Map<String, dynamic>>? onTransformChanged;
  final ValueChanged<Map<String, dynamic>>? onViewerStateChanged;

  @override
  State<ThreeDViewer> createState() => _ThreeDViewerState();
}

class _ThreeDViewerState extends State<ThreeDViewer> {
  static int _nextId = 0;

  late final String _elementId;
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _resizeSub;
  StreamSubscription<html.Event>? _visibilitySub;
  Timer? _mountRetryTimer;
  bool _factoryRegistered = false;
  String _mountedAssetKey = '';
  String _mountedOptionsJson = '';
  String _lastTransformJson = '';
  String _lastViewerJson = '';
  String _loadStatus = '';
  String _loadLabel = '';
  double? _loadProgress;

  @override
  void initState() {
    super.initState();
    _elementId = 'deepx-off-axis-viewer-${_nextId++}';
    _viewType = 'deepx-off-axis-view-$_elementId';
    _messageSub = html.window.onMessage.listen(_handleMessage);
    _resizeSub = html.window.onResize.listen((_) => _resizeOrRecover());
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _resizeOrRecover());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountOrUpdate());
  }

  @override
  void didUpdateWidget(covariant ThreeDViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountOrUpdate());
  }

  @override
  void dispose() {
    final dynamic viewer = js.context['DeepXOffAxisViewer'];
    if (viewer != null) {
      viewer.callMethod('dispose', <Object>[_elementId]);
    }
    _mountRetryTimer?.cancel();
    _messageSub?.cancel();
    _resizeSub?.cancel();
    _visibilitySub?.cancel();
    super.dispose();
  }

  void _mountOrUpdate({bool forceMount = false}) {
    final dynamic viewer = js.context['DeepXOffAxisViewer'];
    if (viewer == null) {
      _scheduleMountRetry(forceMount: forceMount);
      return;
    }
    _mountRetryTimer?.cancel();
    _mountRetryTimer = null;
    final String nextAssetKey = _assetKey(widget.payload);
    final String payloadJson = jsonEncode(widget.payload);
    final String optionsJson = jsonEncode(<String, dynamic>{
      'editable': widget.editable,
      'trackingEnabled': widget.trackingEnabled,
      'showModelControls': widget.showModelControls,
    });
    final String transformJson =
        jsonEncode(widget.transformOverride ?? _transformFromPayload());
    final String viewerJson = jsonEncode(_viewerFromPayload());
    final bool missingViewer =
        _mountedAssetKey.isNotEmpty && !_viewerAlive(viewer);
    if (forceMount ||
        missingViewer ||
        _mountedAssetKey != nextAssetKey ||
        _mountedOptionsJson != optionsJson) {
      _mountedAssetKey = nextAssetKey;
      _mountedOptionsJson = optionsJson;
      _lastTransformJson = transformJson;
      _lastViewerJson = viewerJson;
      if (mounted) {
        setState(() {
          _loadStatus = 'loading';
          _loadLabel = 'Loading 3D asset';
          _loadProgress = null;
        });
      }
      viewer
          .callMethod('mount', <Object>[_elementId, payloadJson, optionsJson]);
      return;
    }
    if (_lastTransformJson != transformJson) {
      _lastTransformJson = transformJson;
      viewer.callMethod('setTransform', <Object>[_elementId, transformJson]);
    }
    if (_lastViewerJson != viewerJson) {
      _lastViewerJson = viewerJson;
      viewer.callMethod('setViewerState', <Object>[_elementId, viewerJson]);
    }
    viewer.callMethod('setEditable', <Object>[_elementId, widget.editable]);
  }

  void _scheduleMountRetry({bool forceMount = false}) {
    if (!mounted || _mountRetryTimer?.isActive == true) return;
    _mountRetryTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _mountOrUpdate(forceMount: forceMount);
    });
  }

  bool _viewerAlive(dynamic viewer) {
    try {
      return viewer.callMethod('isAlive', <Object>[_elementId]) == true;
    } catch (_) {
      return false;
    }
  }

  void _resizeOrRecover() {
    if (!mounted) return;
    final dynamic viewer = js.context['DeepXOffAxisViewer'];
    if (viewer == null) return;
    if (_viewerAlive(viewer)) {
      try {
        viewer.callMethod('resize', <Object>[_elementId]);
      } catch (_) {}
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mountOrUpdate(forceMount: true);
    });
  }

  String _assetKey(Map<String, dynamic> payload) {
    final dynamic rawMedia = payload['media'];
    final Map<String, dynamic> media = rawMedia is Map
        ? Map<String, dynamic>.from(rawMedia)
        : Map<String, dynamic>.from(payload);
    return <String>[
      media['type']?.toString().trim().toLowerCase() ?? '',
      media['url']?.toString().trim() ??
          media['assetUrl']?.toString().trim() ??
          '',
      media['path']?.toString().trim() ??
          media['assetPath']?.toString().trim() ??
          '',
      media['format']?.toString().trim().toLowerCase() ?? '',
    ].join('|');
  }

  Map<String, dynamic> _transformFromPayload() {
    final dynamic rawTransform = widget.payload['transform'];
    if (rawTransform is Map) return Map<String, dynamic>.from(rawTransform);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _viewerFromPayload() {
    final dynamic rawViewer = widget.payload['viewer'];
    if (rawViewer is Map) return Map<String, dynamic>.from(rawViewer);
    return const <String, dynamic>{};
  }

  void _handleMessage(html.MessageEvent event) {
    final Map<String, dynamic>? data = _messageMap(event.data);
    if (data == null || data['elementId'] != _elementId) return;
    if (data['type'] == 'deepx-off-axis-load-state') {
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
    if (data['type'] == 'deepx-off-axis-transform-changed') {
      final callback = widget.onTransformChanged;
      if (callback == null) return;
      final Map<String, dynamic>? transform = _messageMap(data['transform']);
      if (transform == null) return;
      _lastTransformJson = jsonEncode(transform);
      callback(transform);
      return;
    }
    if (data['type'] == 'deepx-off-axis-viewer-state-changed') {
      final callback = widget.onViewerStateChanged;
      if (callback == null) return;
      final Map<String, dynamic>? viewerState = _messageMap(data['viewer']);
      if (viewerState == null) return;
      _lastViewerJson = jsonEncode(viewerState);
      callback(viewerState);
    }
  }

  Widget _buildLoadingProgress(BuildContext context) {
    if (!widget.showLoadingProgress || _loadStatus != 'loading') {
      return const SizedBox.shrink();
    }
    final double? progress = _loadProgress;
    final bool hasProgress = progress != null;
    final String label =
        _loadLabel.trim().isEmpty ? 'Loading 3D asset' : _loadLabel.trim();
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
          ..style.backgroundColor = '#050505';
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
