import 'dart:ui';

import 'models/preset_payload_v2.dart';
import 'models/tracking_frame.dart';

const List<String> kSupportedRenderModes = <String>['2d', '3d', '360'];

const Map<String, double> kNeutralPreviewHeadPose = <String, double>{
  'x': 0,
  'y': 0,
  'z': 0.2,
  'yaw': 0,
  'pitch': 0,
};

String renderModeForIndex(int index) {
  if (index < 0 || index >= kSupportedRenderModes.length) {
    return kSupportedRenderModes.first;
  }
  return kSupportedRenderModes[index];
}

int renderModeIndex(String? rawMode) {
  final String normalized = (rawMode ?? '').trim().toLowerCase();
  final int index = kSupportedRenderModes.indexOf(normalized);
  return index >= 0 ? index : 0;
}

String infer360AssetKind({
  required String fileName,
  required String contentType,
}) {
  final String normalizedContentType = contentType.trim().toLowerCase();
  if (normalizedContentType.startsWith('video/')) return 'video';
  if (normalizedContentType.startsWith('image/')) return 'image';
  final String normalizedName = fileName.trim().toLowerCase();
  if (normalizedName.endsWith('.mp4') ||
      normalizedName.endsWith('.webm') ||
      normalizedName.endsWith('.mov') ||
      normalizedName.endsWith('.m4v') ||
      normalizedName.endsWith('.ogv')) {
    return 'video';
  }
  return 'image';
}

Map<String, dynamic> default360Scene() {
  return const <String, dynamic>{
    'assetUrl': '',
    'assetKind': 'image',
  };
}

Map<String, dynamic> default360Controls() {
  return const <String, dynamic>{
    'baseFov': 75,
    'minFov': 45,
    'maxFov': 95,
    'manualMode': false,
    'manualYaw': 0,
    'manualPitch': 0,
    'manualFov': 75,
    'yawSensitivity': 1.0,
    'pitchSensitivity': 1.0,
    'zoomSensitivity': 1.0,
    'posterTimeMs': 0,
  };
}

Map<String, dynamic> blank360Payload({String editor = 'composer'}) {
  return PresetPayloadV2(
    mode: '360',
    scene: default360Scene(),
    controls: default360Controls(),
    meta: <String, dynamic>{'editor': editor},
  ).toMap();
}

TrackingFrame trackingFrameFromHeadPose(Map<String, double>? headPose) {
  final Map<String, double> pose = headPose ?? kNeutralPreviewHeadPose;
  return TrackingFrame(
    headX: pose['x'] ?? 0,
    headY: pose['y'] ?? 0,
    headZ: pose['z'] ?? 0.2,
    yaw: pose['yaw'] ?? 0,
    pitch: pose['pitch'] ?? 0,
    cursorX: 0,
    cursorY: 0,
    wink: false,
    pinch: false,
    hasHand: false,
  );
}

bool isTrackerCursorWithinBounds({
  required Rect bounds,
  required TrackingFrame frame,
  required bool trackerEnabled,
  required bool dartCursorEnabled,
  required bool hasFreshFrame,
}) {
  if (!trackerEnabled || !dartCursorEnabled || !hasFreshFrame) {
    return false;
  }
  if (frame.cursorX <= 0 && frame.cursorY <= 0) {
    return false;
  }
  return bounds.contains(Offset(frame.cursorX, frame.cursorY));
}

String? ambientImageUrlFromPayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
}) {
  try {
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: fallbackMode,
    );
    if (adapted.mode != '2d') return null;
    final List<MapEntry<String, Map<String, dynamic>>> layers =
        adapted.scene.entries
            .where((entry) => entry.value is Map)
            .map(
              (entry) => MapEntry(
                entry.key,
                Map<String, dynamic>.from(entry.value as Map),
              ),
            )
            .where(
              (entry) =>
                  entry.key != 'turning_point' &&
                  entry.value['isVisible'] != false &&
                  (entry.value['url'] ?? '').toString().trim().isNotEmpty,
            )
            .toList();
    layers.sort((a, b) {
      final double aOrder = _safeDouble(a.value['order'], 0);
      final double bOrder = _safeDouble(b.value['order'], 0);
      return aOrder.compareTo(bOrder);
    });
    if (layers.isEmpty) return null;
    final String url = (layers.first.value['url'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? ambientBackgroundPayloadFromPayload(
  Map<String, dynamic> payload, {
  required String fallbackMode,
}) {
  try {
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: fallbackMode,
    );
    if (adapted.mode != '2d') return null;
    final List<MapEntry<String, Map<String, dynamic>>> layers =
        adapted.scene.entries
            .where((entry) => entry.value is Map)
            .map(
              (entry) => MapEntry(
                entry.key,
                Map<String, dynamic>.from(entry.value as Map),
              ),
            )
            .where(
              (entry) =>
                  entry.key != 'turning_point' &&
                  entry.value['isVisible'] != false &&
                  entry.value['isRect'] != true,
            )
            .toList();
    layers.sort((a, b) {
      final double aOrder = _safeDouble(a.value['order'], 0);
      final double bOrder = _safeDouble(b.value['order'], 0);
      return aOrder.compareTo(bOrder);
    });
    if (layers.isEmpty) return null;
    final Map<String, dynamic> nextScene = <String, dynamic>{};
    final dynamic turningPoint = adapted.scene['turning_point'];
    if (turningPoint is Map) {
      nextScene['turning_point'] = Map<String, dynamic>.from(turningPoint);
    }
    nextScene[layers.first.key] = Map<String, dynamic>.from(layers.first.value);
    return PresetPayloadV2(
      mode: adapted.mode,
      scene: nextScene,
      controls: Map<String, dynamic>.from(adapted.controls),
      meta: Map<String, dynamic>.from(adapted.meta),
    ).toMap();
  } catch (_) {
    return null;
  }
}

double _safeDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
