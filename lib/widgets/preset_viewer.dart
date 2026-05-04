import 'package:flutter/material.dart';

import '../rendering_support.dart';

class PresetViewer extends StatelessWidget {
  const PresetViewer({
    super.key,
    required this.mode,
    required this.payload,
    this.fit = BoxFit.cover,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        imageUrlFromPayload(payload, fallbackMode: mode)?.trim() ?? '';
    if (imageUrl.isEmpty) {
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
    return Image.network(
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
    );
  }
}
