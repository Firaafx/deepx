import 'dart:io';
import 'dart:ui';

import 'package:deepx/models/image_payload.dart';
import 'package:deepx/rendering_support.dart';
import 'package:deepx/services/appearance_settings_service.dart';
import 'package:deepx/widgets/svg_card_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('simple image payload stores one editable image contract', () {
    final Map<String, dynamic> payload = simpleImagePayload(
      imageUrl: ' https://example.com/image.webp ',
      editor: 'test',
      offsetX: 0.12,
      offsetY: -0.08,
      scale: 1.6,
      rotationDegrees: 12,
      flipX: true,
      sourceKind: 'custom',
      meta: const <String, dynamic>{'sourceName': 'image.webp'},
    );
    final ImagePayloadData adapted = imagePayloadFromMap(payload);

    expect(payload['schemaVersion'], ImagePayloadData.schemaVersion);
    expect(adapted.imageUrl, 'https://example.com/image.webp');
    expect(adapted.offsetX, 0.12);
    expect(adapted.offsetY, -0.08);
    expect(adapted.scale, 1.6);
    expect(adapted.rotationDegrees, 12);
    expect(adapted.flipX, isTrue);
    expect(adapted.flipY, isFalse);
    expect(adapted.sourceKind, 'custom');
    expect(adapted.meta['editor'], 'test');
  });

  test('legacy payload normalization chooses one primary uploaded image', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': 2,
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

    final Map<String, dynamic> normalized = normalizeImagePayload(payload);
    final ImagePayloadData adapted = imagePayloadFromMap(normalized);

    expect(adapted.imageUrl, 'https://example.com/background.png');
    expect(adapted.sourceKind, 'upload');
    expect(adapted.meta['editor'], 'legacy');
    expect(adapted.meta['upgradedFromLegacy'], isTrue);
  });

  test('ambient payload extraction depends on the canonical image', () {
    final Map<String, dynamic> payload = simpleImagePayload(
      imageUrl: 'https://example.com/ambient.jpg',
    );

    expect(
        ambientImageUrlFromPayload(payload), 'https://example.com/ambient.jpg');

    final Map<String, dynamic>? ambientPayload =
        ambientBackgroundPayloadFromPayload(payload);
    expect(ambientPayload, isNotNull);
    expect(imageUrlFromPayload(ambientPayload!),
        'https://example.com/ambient.jpg');
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

  test('svg card username cutout follows username length from the bottom', () {
    final Rect shortNameNotch = svgCardUsernameNotchBoundsForTesting(
      usernameCharCount: 3,
    );
    final Rect longNameNotch = svgCardUsernameNotchBoundsForTesting(
      usernameCharCount: 5,
    );

    expect(shortNameNotch.top, closeTo(690, 1));
    expect(shortNameNotch.bottom, closeTo(879, 1));
    expect(longNameNotch.top, closeTo(576, 1));
    expect(longNameNotch.bottom, closeTo(900, 1));
    expect(longNameNotch.top, lessThan(shortNameNotch.top));
    expect(longNameNotch.height, greaterThan(shortNameNotch.height));
  });

  test('svg card metadata cutout grows for longer metadata text', () {
    final Rect shortMetaNotch = svgCardMetaNotchBoundsForTesting(
      metaWidthFactor: 0,
    );
    final Rect longMetaNotch = svgCardMetaNotchBoundsForTesting(
      metaWidthFactor: 1,
    );

    expect(shortMetaNotch.left, closeTo(1222, 1));
    expect(shortMetaNotch.width, closeTo(410, 1));
    expect(longMetaNotch.left, closeTo(908, 1));
    expect(longMetaNotch.width, closeTo(723, 1));
    expect(longMetaNotch.left, lessThan(shortMetaNotch.left));
    expect(longMetaNotch.width, greaterThan(shortMetaNotch.width));
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

  test('active runtime no longer references retired renderer paths', () {
    final List<File> files = <String>['lib', 'web']
        .expand((root) => Directory(root).existsSync()
            ? Directory(root).listSync(recursive: true).whereType<File>()
            : const Iterable<File>.empty())
        .where((file) =>
            file.path.endsWith('.dart') || file.path.endsWith('.html'))
        .toList();
    final String contents =
        files.map((file) => file.readAsStringSync()).join('\n');

    final List<String> forbidden = <String>[
      'Tracking' 'Service',
      'Tracker' 'RuntimeConfig',
      'tr' 'ackingFrameFromHeadPose',
      'Engine' '${3}' 'DPage',
      'Layer' 'Mode(',
      'Window' 'Effect' '${2}' 'DPreview',
      'Panorama' 'Viewer' '${3}${6}${0}',
      'blank' '${3}${6}${0}' 'Payload',
      'infer' '${3}${6}${0}' 'AssetKind',
      'assets/' 'tr' 'acker.html',
    ];

    for (final String value in forbidden) {
      expect(contents.contains(value), isFalse, reason: value);
    }
  });
}
