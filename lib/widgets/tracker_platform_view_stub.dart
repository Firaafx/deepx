import 'package:flutter/widgets.dart';

class TrackerPlatformView extends StatelessWidget {
  const TrackerPlatformView({
    super.key,
    required this.interactive,
  });

  final bool interactive;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
