import 'package:flutter/material.dart';

import '../engine3d.dart';
import '../layer_mode.dart';
import '../models/preset_payload_v2.dart';
import '../services/tracking_service.dart';

class PresetViewer extends StatelessWidget {
  const PresetViewer({
    super.key,
    required this.mode,
    required this.payload,
    this.cleanView = false,
    this.embedded = false,
    this.disableAudio = true,
    this.embeddedStudio = false,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final bool cleanView;
  final bool embedded;
  final bool disableAudio;
  final bool embeddedStudio;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: TrackingService.instance.frameNotifier,
      builder: (context, frame, _) {
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
            externalHeadPose: frame.toHeadPoseMap(),
          );
        }

        return Engine3DPage(
          cleanView: cleanView,
          embedded: embedded,
          embeddedStudio: embeddedStudio,
          disableAudio: disableAudio,
          initialPresetPayload: adapted.toMap(),
          externalHeadPose: frame.toHeadPoseMap(),
        );
      },
    );
  }
}
