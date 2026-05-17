// lib/tracker.dart
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class Tracker extends StatefulWidget {
  const Tracker({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<Tracker> createState() => _TrackerState();
}

class _TrackerState extends State<Tracker> {
  late String viewID;

  @override
  void initState() {
    super.initState();

    viewID = 'cyber-tracker-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewID, (int viewId) {
      final iframe = html.IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..src = 'tracker.html'
        ..style.border = 'none'
        ..allow = 'camera *; microphone *; fullscreen *';

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: HtmlElementView(viewType: viewID),
    );
  }
}