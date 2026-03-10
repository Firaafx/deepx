import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/preset_payload_v2.dart';
import '../models/tracking_frame.dart';
import '../services/tracking_service.dart';

class WindowEffect2DPreview extends StatelessWidget {
  const WindowEffect2DPreview({
    super.key,
    required this.mode,
    required this.payload,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final String mode;
  final Map<String, dynamic> payload;
  final BorderRadius borderRadius;
  static const double _outsideOverflowMax = 50;

  @override
  Widget build(BuildContext context) {
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      payload,
      fallbackMode: mode,
    );
    final List<_LayerNode> layers = _extractLayers(adapted.scene);
    final _PreviewControls controls =
        _PreviewControls.fromMap(adapted.controls);
    final double turningOrder = _resolveTurningOrder(layers);

    if (layers.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    return ValueListenableBuilder<TrackingFrame>(
      valueListenable: TrackingService.instance.frameNotifier,
      builder: (context, frame, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final Size size = constraints.biggest;
            final List<Widget> inside = <Widget>[];
            final List<Widget> outside = <Widget>[];
            for (final layer in layers) {
              if (!layer.visible || layer.name == 'turning_point') continue;
              final bool isOutside =
                  !layer.isRect && layer.order > turningOrder;
              final Widget item = _buildLayer(
                layer: layer,
                frame: frame,
                controls: controls,
                turningOrder: turningOrder,
                canvasSize: size,
                isOutsideLayer: isOutside,
              );
              if (isOutside) {
                outside.add(item);
              } else {
                inside.add(item);
              }
            }
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: borderRadius,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: inside,
                    ),
                  ),
                ),
                if (outside.isNotEmpty)
                  Positioned(
                    left: -_outsideOverflowMax,
                    right: -_outsideOverflowMax,
                    top: -_outsideOverflowMax,
                    bottom: -_outsideOverflowMax,
                    child: IgnorePointer(
                      child: ClipRect(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          fit: StackFit.expand,
                          children: outside,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLayer({
    required _LayerNode layer,
    required TrackingFrame frame,
    required _PreviewControls controls,
    required double turningOrder,
    required Size canvasSize,
    required bool isOutsideLayer,
  }) {
    if (layer.isRect) {
      final double barHeight = _calcBarHeight(
        selectedAspect: controls.selectedAspect,
        canvasSize: canvasSize,
      );
      return Positioned(
        left: 0,
        right: 0,
        top: layer.bezelType == 'top' ? 0 : null,
        bottom: layer.bezelType == 'bottom' ? 0 : null,
        child: SizedBox(
            height: barHeight, child: const ColoredBox(color: Colors.black)),
      );
    }

    final double depthFactor = layer.order - turningOrder;
    final double shiftSign = depthFactor.sign;
    final double zoomSign = depthFactor.sign;
    final double effectiveDepth = depthFactor.abs();

    final double devX = frame.headX - controls.anchorHeadX;
    final double devY = frame.headY - controls.anchorHeadY;

    final double shiftX = layer.canShift
        ? ((devX *
                    controls.shiftSens *
                    effectiveDepth *
                    80.0 *
                    layer.shiftSensMult *
                    controls.sensitivity *
                    shiftSign) +
                layer.x)
            .clamp(layer.minX, layer.maxX)
        : layer.x;

    final double shiftY = layer.canShift
        ? ((-devY *
                    controls.shiftSens *
                    effectiveDepth *
                    80.0 *
                    layer.shiftSensMult *
                    controls.sensitivity *
                    shiftSign) +
                layer.y)
            .clamp(layer.minY, layer.maxY)
        : layer.y;
    final double shiftScale = _responsiveShiftScale(
      canvasSize: canvasSize,
      selectedAspect: controls.selectedAspect,
    );
    final double adjustedShiftX =
        (shiftX * shiftScale).clamp(-3000.0, 3000.0).toDouble();
    final double adjustedShiftY =
        (shiftY * shiftScale).clamp(-3000.0, 3000.0).toDouble();
    final double boundedShiftX = isOutsideLayer
        ? adjustedShiftX.clamp(-_outsideOverflowMax, _outsideOverflowMax)
            .toDouble()
        : adjustedShiftX;
    final double boundedShiftY = isOutsideLayer
        ? adjustedShiftY.clamp(-_outsideOverflowMax, _outsideOverflowMax)
            .toDouble()
        : adjustedShiftY;

    final double deltaZ = (frame.headZ - controls.zBase) / controls.zBase;
    final double zoomFactor = deltaZ *
        controls.depthZoomSens *
        4.0 *
        (effectiveDepth + 0.5) *
        layer.zoomSensMult *
        controls.sensitivity;

    final double scale = layer.canZoom
        ? (layer.scale *
                controls.currentScale *
                (1.0 + (zoomFactor * zoomSign)))
            .clamp(layer.minScale, layer.maxScale)
        : layer.scale;

    final double tiltXcalc = frame.yaw / 60.0;
    final double tiltYcalc = frame.pitch / 40.0;
    Matrix4 tiltTransform = Matrix4.identity();
    if (layer.canTilt) {
      tiltTransform.setEntry(3, 2, 0.001);
      tiltTransform.rotateX(
        -tiltYcalc *
            controls.tiltSens *
            controls.sensitivity *
            effectiveDepth *
            controls.tiltSensitivity,
      );
      tiltTransform.rotateY(
        tiltXcalc *
            controls.tiltSens *
            controls.sensitivity *
            effectiveDepth *
            controls.tiltSensitivity,
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: tiltTransform,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(boundedShiftX, boundedShiftY),
              child: SizedBox.expand(
                child: Center(
                  child: layer.isText
                      ? _buildTextLayer(layer)
                      : _buildImageLayer(
                          layer,
                          canvasSize: canvasSize,
                          isOutsideLayer: isOutsideLayer,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextLayer(_LayerNode layer) {
    final int weightIndex =
        layer.fontWeightIndex.clamp(0, FontWeight.values.length - 1).toInt();
    final FontWeight weight = FontWeight.values[weightIndex];
    final Color textColor = _colorFromHex(layer.textColorHex, Colors.white);
    final Color strokeColor = _colorFromHex(layer.strokeColorHex, Colors.black);
    final Color shadowColor = _colorFromHex(layer.shadowColorHex, Colors.black);
    final TextStyle fallbackStyle = TextStyle(
      color: textColor,
      fontSize: layer.fontSize,
      fontStyle: layer.isItalic ? FontStyle.italic : FontStyle.normal,
      fontWeight: weight,
      shadows: layer.shadowBlur > 0
          ? <Shadow>[
              Shadow(
                color: shadowColor,
                blurRadius: layer.shadowBlur,
                offset: const Offset(1.5, 1.5),
              ),
            ]
          : null,
    );
    TextStyle style;
    try {
      style = GoogleFonts.getFont(
        layer.fontFamily,
        textStyle: fallbackStyle,
      );
    } catch (_) {
      style = fallbackStyle;
    }
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (layer.strokeWidth > 0)
          Text(
            layer.textValue,
            textAlign: TextAlign.center,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = layer.strokeWidth
                ..color = strokeColor,
            ),
          ),
        Text(
          layer.textValue,
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }

  Widget _buildImageLayer(
    _LayerNode layer, {
    required Size canvasSize,
    required bool isOutsideLayer,
  }) {
    if (layer.url == null || layer.url!.isEmpty) {
      return const SizedBox.shrink();
    }
    final double extra = isOutsideLayer ? _outsideOverflowMax * 2 : 0;
    final double width = (canvasSize.width + extra).clamp(1, 100000).toDouble();
    final double height =
        (canvasSize.height + extra).clamp(1, 100000).toDouble();
    return Image.network(
      layer.url!,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox.shrink();
      },
    );
  }

  double _resolveTurningOrder(List<_LayerNode> layers) {
    for (final layer in layers) {
      if (layer.name == 'turning_point') return layer.order;
    }
    if (layers.isEmpty) return 0;
    return layers.map((e) => e.order).reduce(math.max);
  }

  List<_LayerNode> _extractLayers(Map<String, dynamic> scene) {
    final List<_LayerNode> layers = <_LayerNode>[];
    int index = 0;
    for (final entry in scene.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      layers.add(_LayerNode.fromMap(entry.key, map, index));
      index += 1;
    }
    layers.sort((a, b) => a.order.compareTo(b.order));
    return layers;
  }

  static Color _colorFromHex(String value, Color fallback) {
    final String cleaned = value.replaceAll('#', '');
    final String full = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    final int? parsed = int.tryParse(full, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static double _calcBarHeight({
    required String? selectedAspect,
    required Size canvasSize,
  }) {
    if (selectedAspect == null || selectedAspect.isEmpty) return 0;
    final String ratioLabel = selectedAspect.split(' ').first;
    final List<String> parts = ratioLabel.split(':');
    if (parts.length != 2) return 0;
    final double? numerator = double.tryParse(parts[0]);
    final double? denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) return 0;
    final double aspect = numerator / denominator;
    final double contentHeight = canvasSize.width / aspect;
    if (contentHeight >= canvasSize.height) return 0;
    return (canvasSize.height - contentHeight) / 2;
  }

  static double _responsiveShiftScale({
    required Size canvasSize,
    required String? selectedAspect,
  }) {
    double targetAspect = 16 / 9;
    if (selectedAspect != null && selectedAspect.isNotEmpty) {
      final String ratioLabel = selectedAspect.split(' ').first;
      final List<String> parts = ratioLabel.split(':');
      if (parts.length == 2) {
        final double? a = double.tryParse(parts[0]);
        final double? b = double.tryParse(parts[1]);
        if (a != null && b != null && b != 0) {
          targetAspect = a / b;
        }
      }
    }
    final double baseWidth = targetAspect >= 1 ? 1280 : 720;
    final double baseHeight = baseWidth / targetAspect;
    final double scaleX = canvasSize.width / baseWidth;
    final double scaleY = canvasSize.height / baseHeight;
    return math.min(scaleX, scaleY).clamp(0.1, 1.0);
  }
}

class _LayerNode {
  const _LayerNode({
    required this.name,
    required this.order,
    required this.visible,
    required this.x,
    required this.y,
    required this.scale,
    required this.isRect,
    required this.bezelType,
    required this.isText,
    required this.textValue,
    required this.fontSize,
    required this.fontWeightIndex,
    required this.isItalic,
    required this.shadowBlur,
    required this.shadowColorHex,
    required this.strokeWidth,
    required this.strokeColorHex,
    required this.textColorHex,
    required this.fontFamily,
    required this.minScale,
    required this.maxScale,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.canShift,
    required this.canZoom,
    required this.canTilt,
    required this.shiftSensMult,
    required this.zoomSensMult,
    required this.url,
  });

  final String name;
  final double order;
  final bool visible;
  final double x;
  final double y;
  final double scale;
  final bool isRect;
  final String bezelType;
  final bool isText;
  final String textValue;
  final double fontSize;
  final int fontWeightIndex;
  final bool isItalic;
  final double shadowBlur;
  final String shadowColorHex;
  final double strokeWidth;
  final String strokeColorHex;
  final String textColorHex;
  final String fontFamily;
  final double minScale;
  final double maxScale;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final bool canShift;
  final bool canZoom;
  final bool canTilt;
  final double shiftSensMult;
  final double zoomSensMult;
  final String? url;

  factory _LayerNode.fromMap(
    String name,
    Map<String, dynamic> map,
    int fallbackOrder,
  ) {
    return _LayerNode(
      name: name,
      order: _toDouble(map['order'], fallbackOrder.toDouble()),
      visible: map['isVisible'] != false,
      x: _toDouble(map['x'], 0),
      y: _toDouble(map['y'], 0),
      scale: _toDouble(map['scale'], 1),
      isRect: map['isRect'] == true,
      bezelType: map['bezelType']?.toString() ?? '',
      isText: map['isText'] == true,
      textValue: map['textValue']?.toString() ?? 'Text',
      fontSize: _toDouble(map['fontSize'], 40),
      fontWeightIndex: _toInt(map['fontWeightIndex'], 4),
      isItalic: map['isItalic'] == true,
      shadowBlur: _toDouble(map['shadowBlur'], 0),
      shadowColorHex: map['shadowColorHex']?.toString() ?? '#000000',
      strokeWidth: _toDouble(map['strokeWidth'], 0),
      strokeColorHex: map['strokeColorHex']?.toString() ?? '#000000',
      textColorHex: map['textColorHex']?.toString() ?? '#FFFFFF',
      fontFamily: map['fontFamily']?.toString() ?? 'Poppins',
      minScale: _toDouble(map['minScale'], 0.1),
      maxScale: _toDouble(map['maxScale'], 5),
      minX: _toDouble(map['minX'], -3000),
      maxX: _toDouble(map['maxX'], 3000),
      minY: _toDouble(map['minY'], -3000),
      maxY: _toDouble(map['maxY'], 3000),
      canShift: map['canShift'] != false,
      canZoom: map['canZoom'] != false,
      canTilt: map['canTilt'] != false,
      shiftSensMult: _toDouble(map['shiftSensMult'], 1),
      zoomSensMult: _toDouble(map['zoomSensMult'], 1),
      url: map['url']?.toString(),
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _PreviewControls {
  const _PreviewControls({
    required this.currentScale,
    required this.depthZoomSens,
    required this.shiftSens,
    required this.tiltSens,
    required this.tiltSensitivity,
    required this.sensitivity,
    required this.zBase,
    required this.anchorHeadX,
    required this.anchorHeadY,
    required this.selectedAspect,
  });

  final double currentScale;
  final double depthZoomSens;
  final double shiftSens;
  final double tiltSens;
  final double tiltSensitivity;
  final double sensitivity;
  final double zBase;
  final double anchorHeadX;
  final double anchorHeadY;
  final String? selectedAspect;

  factory _PreviewControls.fromMap(Map<String, dynamic> map) {
    return _PreviewControls(
      currentScale: _toDouble(map['scale'], 1.2),
      depthZoomSens: _toDouble(map['depth'], 0.1),
      shiftSens: _toDouble(map['shift'], 0.025),
      tiltSens: _toDouble(map['tilt'], 0),
      tiltSensitivity: _toDouble(map['tiltSensitivity'], 1),
      sensitivity: _toDouble(map['sensitivity'], 1),
      zBase: math.max(_toDouble(map['zBase'], 0.2), 0.0001),
      anchorHeadX: _toDouble(map['anchorHeadX'], 0),
      anchorHeadY: _toDouble(map['anchorHeadY'], 0),
      selectedAspect: map['selectedAspect']?.toString(),
    );
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
