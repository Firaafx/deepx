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
    this.onCameraChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool showRecenter;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;

  @override
  State<ThreeDViewer> createState() => _ThreeDViewerState();
}

class _ThreeDViewerState extends State<ThreeDViewer> {
  static int _nextId = 0;

  late final String _elementId;
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _factoryRegistered = false;

  @override
  void initState() {
    super.initState();
    _elementId = 'deepx-three-viewer-${_nextId++}';
    _viewType = 'deepx-three-viewer-view-$_elementId';
    _messageSub = html.window.onMessage.listen(_handleMessage);
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
    super.dispose();
  }

  void _mountOrUpdate() {
    final payloadJson = jsonEncode(widget.payload);
    final optionsJson = jsonEncode(<String, dynamic>{
      'editable': widget.editable,
    });
    final dynamic viewer = js.context['DeepXThreeViewer'];
    if (viewer == null) return;
    viewer.callMethod('mount', <Object>[_elementId, payloadJson, optionsJson]);
  }

  void _handleMessage(html.MessageEvent event) {
    final callback = widget.onCameraChanged;
    if (callback == null) return;
    final Map<String, dynamic>? data = _messageMap(event.data);
    if (data == null) return;
    if (data['type'] != 'deepx-three-camera-changed') return;
    if (data['elementId'] != _elementId) return;
    final Map<String, dynamic>? camera = _messageMap(data['camera']);
    if (camera == null) return;
    callback(camera);
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
        if (widget.showRecenter)
          Positioned(
            top: 8,
            right: 8,
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
