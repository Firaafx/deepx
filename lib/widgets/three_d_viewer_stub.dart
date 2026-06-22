import 'package:flutter/widgets.dart';

class ThreeDViewer extends StatelessWidget {
  const ThreeDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.trackingEnabled = false,
    this.showModelControls = false,
    this.showLoadingProgress = true,
    this.transformOverride,
    this.onTransformChanged,
    this.onViewerStateChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool trackingEnabled;
  final bool showModelControls;
  final bool showLoadingProgress;
  final Map<String, dynamic>? transformOverride;
  final ValueChanged<Map<String, dynamic>>? onTransformChanged;
  final ValueChanged<Map<String, dynamic>>? onViewerStateChanged;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('3D viewer is available on web.'));
  }
}
