import 'package:flutter/material.dart';

import '../engine3d.dart';
import '../layer_mode.dart';
import '../models/preset_payload_v2.dart';

class PresetViewer extends StatelessWidget {
  const PresetViewer({
    super.key,
    required this.mode,
    required this.payload,
    this.cleanView = false,
    this.embedded = false,
    this.disableAudio = true,
    this.embeddedStudio = false,
    this.useGlobalTracking = true,
    this.headPose,
    this.pointerPassthrough = false,
    this.reanchorToken = 0,
    this.studioSurface = false,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final bool cleanView;
  final bool embedded;
  final bool disableAudio;
  final bool embeddedStudio;
  final bool useGlobalTracking;
  final Map<String, double>? headPose;
  final bool pointerPassthrough;
  final int reanchorToken;
  final bool studioSurface;

  @override
  Widget build(BuildContext context) {
    final adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: mode,
    );
    if (adapted.mode == '2d') {
      return LayerMode(
        cleanView: cleanView,
        embedded: embedded,
        embeddedStudio: embeddedStudio,
        initialPresetPayload: adapted.toMap(),
        externalHeadPose: headPose,
        useGlobalTracking: useGlobalTracking,
        pointerPassthrough: pointerPassthrough,
        reanchorToken: reanchorToken,
        studioSurface: studioSurface,
      );
    }
    return Engine3DPage(
      cleanView: cleanView,
      embedded: embedded,
      embeddedStudio: embeddedStudio,
      disableAudio: disableAudio,
      initialPresetPayload: adapted.toMap(),
      externalHeadPose: headPose,
      useGlobalTracking: useGlobalTracking,
      pointerPassthrough: pointerPassthrough,
      reanchorToken: reanchorToken,
      studioSurface: studioSurface,
    );
  }
}
