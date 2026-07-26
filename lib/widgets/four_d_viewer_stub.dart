import 'package:flutter/widgets.dart';

class FourDViewer extends StatelessWidget {
  const FourDViewer({
    super.key,
    required this.payload,
    this.editable = false,
    this.trackingEnabled = false,
    this.showLoadingProgress = true,
    this.onSpatialViewRequested,
  });

  final Map<String, dynamic> payload;
  final bool editable;
  final bool trackingEnabled;
  final bool showLoadingProgress;
  final VoidCallback? onSpatialViewRequested;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('4D viewer is available on web.'));
  }
}
