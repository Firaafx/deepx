import 'dart:io';
import 'dart:ui';

import 'package:deepx/models/preset_payload_v2.dart';
import 'package:deepx/rendering_support.dart';
import 'package:deepx/services/appearance_settings_service.dart';
import 'package:deepx/widgets/svg_card_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('render mode helpers expose only storage-compatible image mode', () {
    expect(renderModeForIndex(0), kImageRenderMode);
    expect(renderModeForIndex(99), kImageRenderMode);
    expect(renderModeIndex('2d'), 0);
    expect(renderModeIndex('3' 'd'), 0);
    expect(renderModeIndex('3' '60'), 0);
  });

  test('simpleImagePayload keeps one canonical image URL', () {
    final Map<String, dynamic> payload = simpleImagePayload(
      imageUrl: ' https://example.com/image.webp ',
      editor: 'test',
      meta: const <String, dynamic>{'sourceMode': '3' 'd'},
    );
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: '2d',
    );

    expect(adapted.mode, '2d');
    expect(adapted.scene, <String, dynamic>{
      'imageUrl': 'https://example.com/image.webp',
    });
    expect(adapted.controls, isEmpty);
    expect(adapted.meta['editor'], 'test');
    expect(adapted.meta['sourceMode'], '3' 'd');
  });

  test('legacy payload normalization chooses one primary uploaded image', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': PresetPayloadV2.schemaVersion,
      'mode': '2d',
      'scene': <String, dynamic>{
        'turning_point': <String, dynamic>{'order': 0},
        'hidden': <String, dynamic>{
          'order': -100,
          'url': 'https://example.com/hidden.png',
          'isVisible': false,
        },
        'background': <String, dynamic>{
          'order': -10,
          'url': 'https://example.com/background.png',
          'isVisible': true,
        },
        'foreground': <String, dynamic>{
          'order': 10,
          'url': 'https://example.com/foreground.png',
          'isVisible': true,
        },
      },
      'controls': <String, dynamic>{'deadZoneX': 0.1},
      'meta': <String, dynamic>{'editor': 'legacy'},
    };

    final Map<String, dynamic> normalized = normalizeImagePayload(
      payload,
      fallbackMode: '2d',
    );
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      normalized,
      fallbackMode: '2d',
    );

    expect(adapted.scene, <String, dynamic>{
      'imageUrl': 'https://example.com/background.png',
    });
    expect(adapted.controls, isEmpty);
    expect(adapted.meta['sourceMode'], '2d');
  });

  test('ambient payload extraction depends on the canonical image', () {
    final Map<String, dynamic> payload = simpleImagePayload(
      imageUrl: 'https://example.com/ambient.jpg',
    );

    expect(
      ambientImageUrlFromPayload(payload, fallbackMode: '2d'),
      'https://example.com/ambient.jpg',
    );

    final Map<String, dynamic>? ambientPayload =
        ambientBackgroundPayloadFromPayload(payload, fallbackMode: '2d');
    expect(ambientPayload, isNotNull);
    expect(
      imageUrlFromPayload(ambientPayload!, fallbackMode: '2d'),
      'https://example.com/ambient.jpg',
    );
  });

  test('svg card two-line title does not extend thumbnail clip downward', () {
    const Size cardSize = Size(1852, 1413);
    final Rect oneLineBounds = const SvgCardClipper(
      usernameCharCount: 6,
      metaWidthFactor: 0,
      twoLineTitle: false,
    ).getClip(cardSize).getBounds();
    final Rect twoLineBounds = const SvgCardClipper(
      usernameCharCount: 6,
      metaWidthFactor: 0,
      twoLineTitle: true,
    ).getClip(cardSize).getBounds();

    expect(twoLineBounds.bottom, oneLineBounds.bottom);
  });

  test('svg card username cutout grows upward while bottom remains anchored',
      () {
    const Size cardSize = Size(1852, 1413);
    final Path longNameClip = const SvgCardClipper(
      usernameCharCount: 6,
    ).getClip(cardSize);
    final Path shortNameClip = const SvgCardClipper(
      usernameCharCount: 1,
    ).getClip(cardSize);

    expect(longNameClip.contains(const Offset(185, 600)), isTrue);
    expect(shortNameClip.contains(const Offset(185, 600)), isFalse);
    expect(longNameClip.contains(const Offset(185, 850)), isTrue);
    expect(shortNameClip.contains(const Offset(185, 850)), isTrue);
  });

  test('wallpaper and overlay settings persist locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppearanceSettingsService.instance.initialize();

    AppearanceSettingsService.instance
        .updateWallpaperImageUrl('https://example.com/wallpaper.jpg');
    AppearanceSettingsService.instance.updateWallpaperOverlayColor(0xFF123456);
    AppearanceSettingsService.instance.updateWallpaperOverlayOpacity(0.42);

    final AppearanceSettings settings =
        AppearanceSettingsService.instance.settings.value;
    expect(settings.wallpaperImageUrl, 'https://example.com/wallpaper.jpg');
    expect(settings.wallpaperOverlayColor, 0xFF123456);
    expect(settings.wallpaperOverlayOpacity, 0.42);
  });

  test('legacy runtime implementations are no longer referenced by app code',
      () {
    final List<File> files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    final String contents =
        files.map((file) => file.readAsStringSync()).join('\n');

    for (final String forbidden in <String>[
      'Tracking' 'Service',
      'Tracker' 'RuntimeConfig',
      'tr' 'ackingFrameFromHeadPose',
      'Engine' '3' 'DPage',
      'Layer' 'Mode(',
      'Window' 'Effect2DPreview',
      'Panorama' 'Viewer3' '60',
      'blank' '3' '60Payload',
      'infer' '3' '60AssetKind',
      'assets/' 'tr' 'acker.html',
    ]) {
      expect(contents.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
