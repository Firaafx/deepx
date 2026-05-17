import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

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

    ui_web.platformViewRegistry.registerViewFactory(viewID, (int viewId) {
      final html.IFrameElement iframe = html.IFrameElement();

      iframe.width = '100%';
      iframe.height = '100%';
      iframe.src = 'tracker.html';
      iframe.style.border = 'none';
      iframe.allow = 'camera; microphone; fullscreen';

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