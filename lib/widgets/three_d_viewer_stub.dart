import 'package:flutter/widgets.dart';

class ThreeDViewer extends StatelessWidget {
  const ThreeDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.showRecenter = true,
    this.showLoadingProgress = true,
    this.recenterTop = 8,
    this.recenterRight = 8,
    this.cameraOverride,
    this.autoFitRevision = 0,
    this.autoFitOnMount = false,
    this.onCameraChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool showRecenter;
  final bool showLoadingProgress;
  final double recenterTop;
  final double recenterRight;
  final Map<String, dynamic>? cameraOverride;
  final int autoFitRevision;
  final bool autoFitOnMount;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('3D viewer is available on web.'));
  }
}
