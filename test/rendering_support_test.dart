import 'dart:io';
import 'dart:ui';

import 'package:deepx/models/image_payload.dart';
import 'package:deepx/models/render_preset.dart';
import 'package:deepx/models/three_d_payload.dart';
import 'package:deepx/rendering_support.dart';
import 'package:deepx/services/appearance_settings_service.dart';
import 'package:deepx/show_feed.dart';
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

  test('3D gaussian payload is detected without image normalization', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.gaussianSplat,
      assetUrl: 'https://example.com/scene.ksplat',
      assetPath: 'user/gaussian-splats/job/scene.ksplat',
      format: 'ksplat',
      byteSize: 42,
      sourceKind: 'instantsplat',
      jobId: 'job-1',
      sourceImageCount: 4,
      meta: const <String, dynamic>{'sourceName': 'scene'},
    );

    final ThreeDAssetPayload? asset = threeDAssetFromPayload(payload);

    expect(isThreeDPayload(payload), isTrue);
    expect(mediaTypeFromPayload(payload), DeepXMediaType.gaussianSplat);
    expect(asset, isNotNull);
    expect(asset!.assetUrl, 'https://example.com/scene.ksplat');
    expect(asset.format, 'ksplat');
    expect(asset.sourceKind, 'instantsplat');
    expect(asset.sourceImageCount, 4);
  });

  test('render payload normalization preserves 3D payload contracts', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.triangleMesh,
      assetUrl: 'https://example.com/model.glb',
      format: 'glb',
      meta: const <String, dynamic>{'keep': true},
    );

    final Map<String, dynamic> normalized = normalizeRenderPayload(
      payload,
      editor: 'test_editor',
    );

    expect(mediaTypeFromPayload(normalized), DeepXMediaType.triangleMesh);
    expect(
        (normalized['media'] as Map)['url'], 'https://example.com/model.glb');
    expect((normalized['meta'] as Map)['editor'], 'test_editor');
    expect((normalized['meta'] as Map)['keep'], isTrue);
  });

  test('render payload normalization preserves 3D camera and transform', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.gaussianSplat,
      assetUrl: 'https://example.com/scene.ksplat',
      format: 'ksplat',
      transform: const <String, dynamic>{
        'scale': 1.4,
        'position': <double>[1, 2, 3],
      },
      camera: const <String, dynamic>{
        'initialPosition': <double>[0.2, 1.5, 4.8],
        'initialTarget': <double>[0.1, 0.2, 0.3],
        'fov': 38,
      },
    );

    final Map<String, dynamic> withCamera = payloadWithThreeDCamera(
      normalizeRenderPayload(payload, editor: 'collection_item_snapshot'),
      initialPosition: const <double>[0.5, 2, 5],
      initialTarget: const <double>[0, 0.3, 0],
      fov: 42,
    );
    final ThreeDAssetPayload? asset = threeDAssetFromPayload(withCamera);

    expect(asset, isNotNull);
    expect(asset!.transform['scale'], 1.4);
    expect(asset.camera['initialPosition'], <double>[0.5, 2, 5]);
    expect(asset.camera['initialTarget'], <double>[0, 0.3, 0]);
    expect(asset.camera['fov'], 42);
  });

  test('3D transform defaults match off-axis reference model controls', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.triangleMesh,
      assetUrl: 'https://example.com/model.glb',
      format: 'glb',
    );

    final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(payload);

    expect(asset.transform['position'], <double>[0, -0.09, -0.03]);
    expect(asset.transform['scale'], 0.071);
    expect(asset.transform['rotation'], <double>[0, -0.628, 0]);
  });

  test('3D transform payload preserves model position scale and rotation', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.gaussianSplat,
      assetUrl: 'https://example.com/scene.ksplat',
      format: 'ksplat',
    );

    final Map<String, dynamic> transformed = payloadWithThreeDTransform(
      normalizeRenderPayload(payload, editor: 'transform_test'),
      position: const <double>[0.25, -0.12, -0.8],
      scale: 0.118,
      rotation: const <double>[0.1, -0.7, 0.02],
    );
    final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(transformed);

    expect(asset.transform['position'], <double>[0.25, -0.12, -0.8]);
    expect(asset.transform['scale'], 0.118);
    expect(asset.transform['rotation'], <double>[0.1, -0.7, 0.02]);
    expect(asset.mediaType, DeepXMediaType.gaussianSplat);
  });

  test('collection snapshots accept 3D while thumbnails stay image payloads',
      () {
    final Map<String, dynamic> meshPayload = simpleThreeDPayload(
      mediaType: DeepXMediaType.triangleMesh,
      assetUrl: 'https://example.com/model.glb',
      format: 'glb',
    );
    final Map<String, dynamic> thumbnail = simpleImagePayload(
      imageUrl: 'https://example.com/thumb.webp',
    );

    final Map<String, dynamic> itemSnapshot = normalizeRenderPayload(
      meshPayload,
      editor: 'collection_item_snapshot',
    );
    final Map<String, dynamic> thumbnailSnapshot = normalizeImagePayload(
      thumbnail,
      editor: 'collection_thumbnail',
    );

    expect(mediaTypeFromPayload(itemSnapshot), DeepXMediaType.triangleMesh);
    expect(threeDAssetFromPayload(itemSnapshot), isNotNull);
    expect(mediaTypeFromPayload(thumbnailSnapshot), DeepXMediaType.image);
    expect(imageUrlFromPayload(thumbnailSnapshot),
        'https://example.com/thumb.webp');
  });

  test('image render payloads become missing 3D while thumbnails stay image',
      () {
    final Map<String, dynamic> imagePayload = simpleImagePayload(
      imageUrl: 'https://example.com/thumb.webp',
    );

    final Map<String, dynamic> renderPayload = normalizeRenderPayload(
      imagePayload,
      editor: 'detail_content',
    );
    final Map<String, dynamic> thumbnailPayload = normalizeImagePayload(
      imagePayload,
      editor: 'card_thumbnail',
    );

    expect(mediaTypeFromPayload(renderPayload), DeepXMediaType.missing3d);
    expect(threeDAssetFromPayload(renderPayload), isNull);
    expect(missingThreeDAssetLabel(renderPayload), 'No 3D');
    expect(mediaTypeFromPayload(thumbnailPayload), DeepXMediaType.image);
    expect(imageUrlFromPayload(thumbnailPayload),
        'https://example.com/thumb.webp');
  });

  test('missing 3D asset fallback labels match media type', () {
    expect(
      missingThreeDAssetLabel(<String, dynamic>{
        'media': <String, dynamic>{'type': 'gaussian_splat'},
      }),
      'No 3DGS',
    );
    expect(
      missingThreeDAssetLabel(<String, dynamic>{
        'media': <String, dynamic>{'type': 'triangle_mesh'},
      }),
      'No 3D mesh',
    );
    expect(
      missingThreeDAssetLabel(<String, dynamic>{
        'media': <String, dynamic>{'type': 'missing_3d'},
      }),
      'No 3D',
    );
  });

  test('render preset infers 3D media type while keeping image fallback', () {
    final Map<String, dynamic> splatPayload = simpleThreeDPayload(
      mediaType: DeepXMediaType.gaussianSplat,
      assetUrl: 'https://example.com/scene.ksplat',
      format: 'ksplat',
    );
    final Map<String, dynamic> thumbnail = simpleImagePayload(
      imageUrl: 'https://example.com/thumb.jpg',
    );

    final RenderPreset splatPreset = RenderPreset.fromMap(<String, dynamic>{
      'id': 'preset-1',
      'user_id': 'user-1',
      'name': 'Scene',
      'payload': splatPayload,
      'thumbnail_payload': thumbnail,
      'created_at': '2026-05-30T00:00:00Z',
      'updated_at': '2026-05-30T00:00:00Z',
    });
    final RenderPreset imagePreset = RenderPreset.fromMap(<String, dynamic>{
      'id': 'preset-2',
      'user_id': 'user-1',
      'name': 'Image',
      'payload': thumbnail,
      'thumbnail_payload': thumbnail,
      'created_at': '2026-05-30T00:00:00Z',
      'updated_at': '2026-05-30T00:00:00Z',
    });

    expect(splatPreset.mediaType, 'gaussian_splat');
    expect(imagePreset.mediaType, 'missing_3d');

    final RenderPreset aliasPreset = RenderPreset.fromMap(<String, dynamic>{
      'id': 'preset-3',
      'user_id': 'user-1',
      'name': 'Alias',
      'payload': <String, dynamic>{
        'media': <String, dynamic>{
          'type': 'ksplat',
          'url': 'https://example.com/scene.ksplat',
        },
      },
      'thumbnail_payload': thumbnail,
      'created_at': '2026-05-30T00:00:00Z',
      'updated_at': '2026-05-30T00:00:00Z',
    });
    expect(aliasPreset.mediaType, 'gaussian_splat');
  });

  test('3D media detection accepts supported manual upload extensions', () {
    expect(mediaTypeFromString('ply'), DeepXMediaType.gaussianSplat);
    expect(mediaTypeFromString('ksplat'), DeepXMediaType.gaussianSplat);
    expect(mediaTypeFromString('splat'), DeepXMediaType.gaussianSplat);
    expect(mediaTypeFromString('3dgs'), DeepXMediaType.gaussianSplat);
    expect(mediaTypeFromString('glb'), DeepXMediaType.triangleMesh);
    expect(mediaTypeFromString('gltf'), DeepXMediaType.triangleMesh);
    expect(mediaTypeFromString('missing_3d'), DeepXMediaType.missing3d);
  });

  test('3D camera payload preserves rotation, fov, and distance', () {
    final Map<String, dynamic> payload = simpleThreeDPayload(
      mediaType: DeepXMediaType.triangleMesh,
      assetUrl: 'https://example.com/model.glb',
      format: 'glb',
    );

    final Map<String, dynamic> withCamera = payloadWithThreeDCamera(
      payload,
      initialPosition: const <double>[1, 2, 6],
      initialTarget: const <double>[0.5, 0.2, 0],
      rotationDegrees: const <String, dynamic>{
        'yaw': 12,
        'pitch': -8,
        'roll': 3,
      },
      fov: 41,
      distance: 6.3,
    );
    final ThreeDAssetPayload asset = ThreeDAssetPayload.fromMap(withCamera);

    expect(asset.camera['initialPosition'], <double>[1, 2, 6]);
    expect(asset.camera['initialTarget'], <double>[0.5, 0.2, 0]);
    expect((asset.camera['rotationDegrees'] as Map)['yaw'], 12);
    expect((asset.camera['rotationDegrees'] as Map)['pitch'], -8);
    expect((asset.camera['rotationDegrees'] as Map)['roll'], 3);
    expect(asset.camera['fov'], 41);
    expect(asset.camera['distance'], 6.3);
  });

  test('legacy presets mode migration is guarded and idempotent', () {
    final String sql = File(
      'supabase/migrations/20260601120000_presets_legacy_mode_default.sql',
    ).readAsStringSync();

    expect(sql, contains('do \$\$'));
    expect(sql, contains('if exists'));
    expect(sql,
        contains("alter column mode set default '2d'::public.render_mode"));
    expect(sql, contains("set mode = '2d'::public.render_mode"));
    expect(sql, contains('where mode is null'));
    expect(sql, contains('alter column mode set not null'));
    expect(sql.toLowerCase(), isNot(contains('drop column')));
  });

  test('missing 3D migration converts image content and preserves thumbnails',
      () {
    final String sql = File(
      'supabase/migrations/20260604120000_3d_only_missing_payloads.sql',
    ).readAsStringSync();
    final String lower = sql.toLowerCase();

    expect(lower, contains('missing_3d'));
    expect(lower, contains('public.presets'));
    expect(lower, contains('public.collection_items'));
    expect(lower, contains('preset_snapshot = missing_payload'));
    expect(lower, isNot(contains('thumbnail_payload =')));
    expect(
        lower,
        contains(
            "media_type in ('gaussian_splat', 'triangle_mesh', 'missing_3d')"));
  });

  test('legacy render mode cleanup migration removes mode storage', () {
    final String sql = File(
      'supabase/migrations/20260604123000_drop_legacy_render_mode_columns.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('drop column if exists mode'));
    expect(sql, contains('drop column if exists thumbnail_mode'));
    expect(sql, contains('drop table if exists public.mode_states cascade'));
    expect(sql, contains('drop type if exists public.render_mode'));
  });

  test('parallelogram highlight slant angle does not change with width', () {
    double slope(Offset a, Offset b) => (b.dx - a.dx) / (b.dy - a.dy);
    final List<Offset> short =
        parallelogramHighlightAnglePointsForTesting(const Size(120, 38));
    final List<Offset> long =
        parallelogramHighlightAnglePointsForTesting(const Size(420, 38));

    expect(slope(short[0], short[1]), closeTo(slope(long[0], long[1]), 0.0001));
    expect(slope(short[2], short[3]), closeTo(slope(long[2], long[3]), 0.0001));
  });

  test('svg card two-line title does not extend thumbnail clip downward', () {
    const Size cardSize = Size(1852, 1413);
    final Rect oneLineBounds = const SvgCardClipper(
      usernameCharCount: 6,
      metaSize: SvgCardMetaSize.small,
      twoLineTitle: false,
    ).getClip(cardSize).getBounds();
    final Rect twoLineBounds = const SvgCardClipper(
      usernameCharCount: 6,
      metaSize: SvgCardMetaSize.small,
      twoLineTitle: true,
    ).getClip(cardSize).getBounds();

    expect(twoLineBounds.bottom, oneLineBounds.bottom);
  });

  test('svg card username cutout uses exact discrete username lengths', () {
    final Map<int, Rect> expected = <int, Rect>{
      1: const Rect.fromLTWH(121, 776, 55, 114),
      2: const Rect.fromLTWH(121, 776, 55, 114),
      3: const Rect.fromLTWH(121, 694, 55, 196),
      4: const Rect.fromLTWH(121, 634, 55, 256),
      5: const Rect.fromLTWH(121, 572, 55, 318),
      6: const Rect.fromLTWH(121, 500, 55, 390),
      12: const Rect.fromLTWH(121, 500, 55, 390),
    };

    for (final entry in expected.entries) {
      final Rect notch = svgCardUsernameNotchBoundsForTesting(
        usernameCharCount: entry.key,
      );
      expect(notch.left, closeTo(entry.value.left, 0.1));
      expect(notch.top, closeTo(entry.value.top, 0.1));
      expect(notch.width, closeTo(entry.value.width, 0.1));
      expect(notch.height, closeTo(entry.value.height, 0.1));
    }
  });

  test('svg card metadata cutout uses exact discrete sizes', () {
    final Rect shortMetaNotch = svgCardMetaNotchBoundsForTesting(
      metaSize: SvgCardMetaSize.small,
    );
    final Rect mediumMetaNotch = svgCardMetaNotchBoundsForTesting(
      metaSize: SvgCardMetaSize.medium,
    );
    final Rect largeMetaNotch = svgCardMetaNotchBoundsForTesting(
      metaSize: SvgCardMetaSize.large,
    );

    expect(shortMetaNotch.left, closeTo(1203, 0.1));
    expect(shortMetaNotch.top, closeTo(136, 0.1));
    expect(shortMetaNotch.width, closeTo(441, 0.1));
    expect(shortMetaNotch.height, closeTo(55, 0.1));

    expect(mediumMetaNotch.left, closeTo(1064, 0.1));
    expect(mediumMetaNotch.top, closeTo(136, 0.1));
    expect(mediumMetaNotch.width, closeTo(580, 0.1));
    expect(mediumMetaNotch.height, closeTo(55, 0.1));

    expect(largeMetaNotch.left, closeTo(978, 0.1));
    expect(largeMetaNotch.top, closeTo(136, 0.1));
    expect(largeMetaNotch.width, closeTo(666, 0.1));
    expect(largeMetaNotch.height, closeTo(55, 0.1));
  });

  test('svg card metadata text is inset without changing notch geometry', () {
    final Rect notch = svgCardMetaNotchBoundsForTesting(
      metaSize: SvgCardMetaSize.small,
    );
    final Rect textBounds = svgCardMetaTextBoundsForTesting(
      metaSize: SvgCardMetaSize.small,
    );

    expect(textBounds.left, greaterThan(notch.left));
    expect(textBounds.right, notch.right);
    expect(textBounds.top, greaterThan(notch.top));
  });

  test('appearance settings persist locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppearanceSettingsService.instance.initialize();

    AppearanceSettingsService.instance
        .updateWallpaperImageUrl('https://example.com/wallpaper.jpg');
    AppearanceSettingsService.instance.updateWallpaperOverlayColor(0xFF123456);
    AppearanceSettingsService.instance.updateWallpaperOverlayOpacity(0.42);
    AppearanceSettingsService.instance.updateSvgCardBlurSigma(33);

    final AppearanceSettings settings =
        AppearanceSettingsService.instance.settings.value;
    expect(settings.wallpaperImageUrl, 'https://example.com/wallpaper.jpg');
    expect(settings.wallpaperOverlayColor, 0xFF123456);
    expect(settings.wallpaperOverlayOpacity, 0.42);
    expect(settings.svgCardBlurSigma, 33);
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
      'deepx_' 'tr' 'acker_bridge',
      'deepx_' 'three_viewer',
      'DeepX' 'ThreeViewer',
      'Tr' 'ackerOverlay',
      'tr' 'acker_controller',
    ];

    for (final String value in forbidden) {
      expect(contents.contains(value), isFalse, reason: value);
    }
  });

  test('retired tracker runtime files are removed', () {
    for (final String path in <String>[
      'web/tracker.html',
      'web/tracker.js',
      'web/deepx_tracker_bridge.js',
      'web/deepx_three_viewer.js',
      'lib/widgets/tracker_overlay.dart',
      'lib/widgets/tracker_platform_view.dart',
      'lib/services/tracker_controller.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });
}
