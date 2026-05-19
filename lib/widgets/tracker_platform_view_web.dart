// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

import '../services/tracker_controller.dart';

class TrackerPlatformView extends StatefulWidget {
  const TrackerPlatformView({
    super.key,
    required this.interactive,
  });

  final bool interactive;

  @override
  State<TrackerPlatformView> createState() => _TrackerPlatformViewState();
}

class _TrackerPlatformViewState extends State<TrackerPlatformView> {
  static const String _viewType = 'deepx-tracker-view';
  static bool _registered = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setTrackerFrameInteractive(widget.interactive);
    });
  }

  @override
  void didUpdateWidget(covariant TrackerPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive != widget.interactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setTrackerFrameInteractive(widget.interactive);
      });
    }
  }

  static void _registerViewFactory() {
    if (_registered) return;
    _registered = true;
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..id = 'deepx-tracker-frame'
        ..src = 'tracker.html'
        ..allow = 'camera *; microphone *; fullscreen *'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = 'transparent'
        ..style.pointerEvents = 'auto';
      iframe.setAttribute('title', 'DeepX tracker');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
