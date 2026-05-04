import 'package:flutter/material.dart';

import '../rendering_support.dart';
import 'preset_viewer.dart';

class EditableImageStage extends StatefulWidget {
  const EditableImageStage({
    super.key,
    required this.payload,
    required this.onChanged,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.backgroundColor = const Color(0xFF111111),
    this.emptyLabel = 'Upload an image to begin editing.',
  });

  final Map<String, dynamic> payload;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Color backgroundColor;
  final String emptyLabel;

  @override
  State<EditableImageStage> createState() => _EditableImageStageState();
}

class _EditableImageStageState extends State<EditableImageStage> {
  Offset? _dragStartLocal;
  double _startOffsetX = 0;
  double _startOffsetY = 0;
  double _startScale = 1;

  void _handleScaleStart(ScaleStartDetails details) {
    _dragStartLocal = details.localFocalPoint;
    _startOffsetX = imageOffsetXFromPayload(widget.payload);
    _startOffsetY = imageOffsetYFromPayload(widget.payload);
    _startScale = imageScaleFromPayload(widget.payload);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, BoxConstraints c) {
    final Offset? start = _dragStartLocal;
    if (start == null) return;
    final double width = c.maxWidth <= 0 ? 1 : c.maxWidth;
    final double height = c.maxHeight <= 0 ? 1 : c.maxHeight;
    final Offset delta = details.localFocalPoint - start;
    final double nextOffsetX =
        (_startOffsetX + (delta.dx / width)).clamp(-2.0, 2.0).toDouble();
    final double nextOffsetY =
        (_startOffsetY + (delta.dy / height)).clamp(-2.0, 2.0).toDouble();
    final double nextScale =
        (_startScale * details.scale).clamp(0.35, 8.0).toDouble();
    widget.onChanged(
      payloadWithTransform(
        widget.payload,
        offsetX: nextOffsetX,
        offsetY: nextOffsetY,
        scale: nextScale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = imageUrlFromPayload(widget.payload);
    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: imageUrl == null ? null : _handleScaleStart,
          onScaleUpdate: imageUrl == null
              ? null
              : (details) => _handleScaleUpdate(details, constraints),
          onDoubleTap: imageUrl == null
              ? null
              : () {
                  widget.onChanged(
                    payloadWithTransform(
                      widget.payload,
                      offsetX: 0,
                      offsetY: 0,
                      scale: 1,
                      rotationDegrees: 0,
                      flipX: false,
                      flipY: false,
                    ),
                  );
                },
          child: DecoratedBox(
            decoration: BoxDecoration(color: widget.backgroundColor),
            child: imageUrl == null
                ? Center(
                    child: Text(
                      widget.emptyLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      PresetViewer(
                        payload: widget.payload,
                        fit: widget.fit,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Text(
                                'Drag to position. Pinch or trackpad-zoom to scale. Double tap resets.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );

    if (widget.borderRadius == null) return content;
    return ClipRRect(borderRadius: widget.borderRadius!, child: content);
  }
}
