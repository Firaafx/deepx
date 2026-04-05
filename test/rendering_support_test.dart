import 'dart:ui';

import 'package:deepx/models/collection_models.dart';
import 'package:deepx/models/preset_payload_v2.dart';
import 'package:deepx/models/render_preset.dart';
import 'package:deepx/models/tracking_frame.dart';
import 'package:deepx/rendering_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render mode helpers support 360', () {
    expect(renderModeForIndex(0), '2d');
    expect(renderModeForIndex(1), '3d');
    expect(renderModeForIndex(2), '360');
    expect(renderModeForIndex(99), '2d');

    expect(renderModeIndex('2d'), 0);
    expect(renderModeIndex('3d'), 1);
    expect(renderModeIndex('360'), 2);
    expect(renderModeIndex('unknown'), 0);
  });

  test('blank360Payload keeps the expected structure', () {
    final Map<String, dynamic> payload = blank360Payload();
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: '2d',
    );

    expect(adapted.mode, '360');
    expect(adapted.scene['assetUrl'], '');
    expect(adapted.scene['assetKind'], 'image');
    expect(adapted.controls['baseFov'], 75);
    expect(adapted.controls['zoomSensitivity'], 1.0);
    expect(adapted.controls['posterTimeMs'], 0);
    expect(adapted.meta['editor'], 'composer');
  });

  test('infer360AssetKind prefers content type then file extension', () {
    expect(
      infer360AssetKind(
        fileName: 'scene.mov',
        contentType: 'video/quicktime',
      ),
      'video',
    );
    expect(
      infer360AssetKind(
        fileName: 'pano.webm',
        contentType: '',
      ),
      'video',
    );
    expect(
      infer360AssetKind(
        fileName: 'pano.jpg',
        contentType: '',
      ),
      'image',
    );
  });

  test('ambientImageUrlFromPayload only returns visible 2d image layers', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': PresetPayloadV2.schemaVersion,
      'mode': '2d',
      'scene': <String, dynamic>{
        'turning_point': <String, dynamic>{
          'order': 0,
          'url': 'https://example.com/ignore.png',
        },
        'foreground': <String, dynamic>{
          'order': 10,
          'url': 'https://example.com/fg.png',
          'isVisible': true,
        },
        'background': <String, dynamic>{
          'order': -10,
          'url': 'https://example.com/bg.png',
          'isVisible': true,
        },
        'hidden': <String, dynamic>{
          'order': -20,
          'url': 'https://example.com/hidden.png',
          'isVisible': false,
        },
      },
      'controls': <String, dynamic>{},
      'meta': <String, dynamic>{},
    };

    expect(
      ambientImageUrlFromPayload(payload, fallbackMode: '2d'),
      'https://example.com/bg.png',
    );
    expect(
      ambientImageUrlFromPayload(blank360Payload(), fallbackMode: '360'),
      isNull,
    );
  });

  test('ambientBackgroundPayloadFromPayload keeps only the lowest visible layer',
      () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': PresetPayloadV2.schemaVersion,
      'mode': '2d',
      'scene': <String, dynamic>{
        'turning_point': <String, dynamic>{'order': 0},
        'background': <String, dynamic>{
          'order': -10,
          'url': 'https://example.com/bg.png',
          'isVisible': true,
        },
        'foreground': <String, dynamic>{
          'order': 10,
          'url': 'https://example.com/fg.png',
          'isVisible': true,
        },
        'bezel': <String, dynamic>{
          'order': -20,
          'isRect': true,
          'isVisible': true,
        },
      },
      'controls': <String, dynamic>{'deadZoneX': 0.05},
      'meta': <String, dynamic>{'editor': 'composer'},
    };

    final Map<String, dynamic>? ambientPayload =
        ambientBackgroundPayloadFromPayload(payload, fallbackMode: '2d');
    expect(ambientPayload, isNotNull);

    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      ambientPayload!,
      fallbackMode: '2d',
    );
    expect(adapted.scene.keys, containsAll(<String>['turning_point', 'background']));
    expect(adapted.scene.keys, isNot(contains('foreground')));
    expect(adapted.scene.keys, isNot(contains('bezel')));
    expect(adapted.controls['deadZoneX'], 0.05);
  });

  test('tracking helpers neutralize inactive previews and honor cursor bounds',
      () {
    final TrackingFrame neutral = trackingFrameFromHeadPose(null);
    expect(neutral.headX, 0);
    expect(neutral.headY, 0);
    expect(neutral.headZ, 0.2);

    const TrackingFrame insideFrame = TrackingFrame(
      headX: 0,
      headY: 0,
      headZ: 0.2,
      yaw: 0,
      pitch: 0,
      cursorX: 50,
      cursorY: 50,
      wink: false,
      pinch: false,
      hasHand: false,
    );
    expect(
      isTrackerCursorWithinBounds(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        frame: insideFrame,
        trackerEnabled: true,
        dartCursorEnabled: true,
        hasFreshFrame: true,
      ),
      isTrue,
    );
    expect(
      isTrackerCursorWithinBounds(
        bounds: const Rect.fromLTWH(0, 0, 40, 40),
        frame: insideFrame,
        trackerEnabled: true,
        dartCursorEnabled: true,
        hasFreshFrame: true,
      ),
      isFalse,
    );
  });

  test('render models preserve 360 modes during deserialization', () {
    final DateTime now = DateTime.utc(2026, 4, 4);
    final RenderPreset preset = RenderPreset.fromMap(<String, dynamic>{
      'id': 'preset-1',
      'share_id': 'share-1',
      'user_id': 'user-1',
      'mode': '360',
      'name': 'Panorama',
      'title': 'Panorama',
      'description': '',
      'tags': const <String>[],
      'mention_user_ids': const <String>[],
      'visibility': 'public',
      'thumbnail_payload': blank360Payload(),
      'thumbnail_mode': '360',
      'payload': blank360Payload(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    final CollectionItemSnapshot item = CollectionItemSnapshot.fromMap(
      <String, dynamic>{
        'id': 'item-1',
        'mode': '360',
        'preset_name': 'Panorama',
        'position': 0,
        'preset_snapshot': blank360Payload(),
      },
    );

    expect(preset.mode, '360');
    expect(preset.thumbnailMode, '360');
    expect(item.mode, '360');
  });
}
