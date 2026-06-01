import 'package:flutter/widgets.dart';

class ThreeDViewer extends StatelessWidget {
  const ThreeDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.showRecenter = true,
    this.onCameraChanged,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool showRecenter;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('3D viewer is available on web.'));
  }
}
