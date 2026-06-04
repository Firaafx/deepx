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
    this.showRecenter = true,
    this.showLoadingProgress = true,
    this.recenterTop = 8,
    this.recenterRight = 8,
    this.cameraOverride,
    this.autoFitRevision = 0,
    this.autoFitOnMount = false,
    this.onCameraChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool showRecenter;
  final bool showLoadingProgress;
  final double recenterTop;
  final double recenterRight;
  final Map<String, dynamic>? cameraOverride;
  final int autoFitRevision;
  final bool autoFitOnMount;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;

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
  bool _factoryRegistered = false;
  String _mountedAssetKey = '';
  String _lastCameraJson = '';
  bool? _lastEditable;
  int _lastAutoFitRevision = 0;
  String _loadStatus = '';
  String _loadLabel = '';
  double? _loadProgress;

  @override
  void initState() {
    super.initState();
    _elementId = 'deepx-three-viewer-${_nextId++}';
    _viewType = 'deepx-three-viewer-view-$_elementId';
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
    final dynamic viewer = js.context['DeepXThreeViewer'];
    if (viewer != null) {
      viewer.callMethod('dispose', <Object>[_elementId]);
    }
    _messageSub?.cancel();
    _resizeSub?.cancel();
    _visibilitySub?.cancel();
    super.dispose();
  }

  void _mountOrUpdate({bool forceMount = false}) {
    final dynamic viewer = js.context['DeepXThreeViewer'];
    if (viewer == null) return;
    final String nextAssetKey = _assetKey(widget.payload);
    final String cameraJson = jsonEncode(
      widget.cameraOverride ?? _cameraFromPayload(widget.payload),
    );
    final String payloadJson = jsonEncode(widget.payload);
    final String optionsJson = jsonEncode(<String, dynamic>{
      'editable': widget.editable,
      'autoFitOnMount': widget.autoFitOnMount,
    });
    final bool missingViewer =
        _mountedAssetKey.isNotEmpty && !_viewerAlive(viewer);
    if (forceMount || missingViewer || _mountedAssetKey != nextAssetKey) {
      _mountedAssetKey = nextAssetKey;
      _lastCameraJson = cameraJson;
      _lastEditable = widget.editable;
      _lastAutoFitRevision = widget.autoFitRevision;
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
    if (_lastEditable != widget.editable) {
      _lastEditable = widget.editable;
      viewer.callMethod('setEditable', <Object>[_elementId, widget.editable]);
    }
    if (_lastCameraJson != cameraJson) {
      _lastCameraJson = cameraJson;
      viewer.callMethod('setCamera', <Object>[_elementId, cameraJson]);
    }
    if (_lastAutoFitRevision != widget.autoFitRevision) {
      _lastAutoFitRevision = widget.autoFitRevision;
      viewer.callMethod('autoFit', <Object>[_elementId]);
    }
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
    final dynamic viewer = js.context['DeepXThreeViewer'];
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

  Map<String, dynamic> _cameraFromPayload(Map<String, dynamic> payload) {
    final dynamic rawCamera = payload['camera'];
    if (rawCamera is Map) return Map<String, dynamic>.from(rawCamera);
    return const <String, dynamic>{};
  }

  void _handleMessage(html.MessageEvent event) {
    final Map<String, dynamic>? data = _messageMap(event.data);
    if (data == null) return;
    if (data['type'] == 'deepx-three-load-state') {
      if (data['elementId'] != _elementId) return;
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
    final callback = widget.onCameraChanged;
    if (callback == null) return;
    if (data['type'] != 'deepx-three-camera-changed') return;
    if (data['elementId'] != _elementId) return;
    final Map<String, dynamic>? camera = _messageMap(data['camera']);
    if (camera == null) return;
    callback(camera);
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

  void _recenter() {
    final dynamic viewer = js.context['DeepXThreeViewer'];
    if (viewer == null) return;
    viewer.callMethod('recenter', <Object>[_elementId]);
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
        if (widget.showRecenter)
          Positioned(
            top: widget.recenterTop,
            right: widget.recenterRight,
            child: Tooltip(
              message: 'Recenter view',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  color: Colors.white,
                  onPressed: _recenter,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
