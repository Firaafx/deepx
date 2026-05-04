import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/image_payload.dart';
import '../rendering_support.dart';

class PresetViewer extends StatelessWidget {
  const PresetViewer({
    super.key,
    required this.payload,
    this.fit = BoxFit.cover,
  });

  final Map<String, dynamic> payload;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final ImagePayloadData data = imagePayloadFromMap(payload);
    if (data.imageUrl.trim().isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 32,
          ),
        ),
      );
    }
    return _TransformedNetworkImage(
      imageUrl: data.imageUrl,
      offsetX: data.offsetX,
      offsetY: data.offsetY,
      scale: data.scale,
      rotationDegrees: data.rotationDegrees,
      flipX: data.flipX,
      flipY: data.flipY,
      fit: fit,
    );
  }
}

class _TransformedNetworkImage extends StatelessWidget {
  const _TransformedNetworkImage({
    required this.imageUrl,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.rotationDegrees,
    required this.flipX,
    required this.flipY,
    required this.fit,
  });

  final String imageUrl;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotationDegrees;
  final bool flipX;
  final bool flipY;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final Matrix4 transform = Matrix4.identity()
          ..translateByDouble(offsetX * width, offsetY * height, 0, 1)
          ..rotateZ(rotationDegrees * math.pi / 180)
          ..scaleByDouble(
            scale * (flipX ? -1.0 : 1.0),
            scale * (flipY ? -1.0 : 1.0),
            1,
            1,
          );

        return ClipRect(
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox.expand(
              child: Image.network(
                imageUrl,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
