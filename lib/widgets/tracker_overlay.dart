import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tracker_controller.dart';
import 'tracker_platform_view.dart';

class TrackerOverlay extends StatefulWidget {
  const TrackerOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<TrackerOverlay> createState() => _TrackerOverlayState();
}

class _TrackerOverlayState extends State<TrackerOverlay> {
  bool _trackerMounted = isTrackerSupported;
  bool _trackerUiVisible = false;
  StreamSubscription<bool>? _visibilitySub;

  @override
  void initState() {
    super.initState();
    initializeTrackerController();
    _visibilitySub = trackerUiVisibilityChanges.listen((visible) {
      if (!mounted) return;
      setState(() => _trackerUiVisible = visible);
    });
    if (isTrackerSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hideInitialTrackerUi();
        Future<void>.delayed(
          const Duration(milliseconds: 500),
          _hideInitialTrackerUi,
        );
        Future<void>.delayed(
          const Duration(milliseconds: 1400),
          _hideInitialTrackerUi,
        );
      });
    }
  }

  @override
  void dispose() {
    _visibilitySub?.cancel();
    super.dispose();
  }

  void _toggleTracker() {
    if (!isTrackerSupported) return;
    if (!_trackerMounted) {
      setState(() {
        _trackerMounted = true;
        _trackerUiVisible = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTrackerUi();
        Future<void>.delayed(
          const Duration(milliseconds: 350),
          showTrackerUi,
        );
      });
      return;
    }

    if (_trackerUiVisible) {
      setState(() => _trackerUiVisible = false);
      hideTrackerUi();
    } else {
      setState(() => _trackerUiVisible = true);
      showTrackerUi();
    }
  }

  void _hideInitialTrackerUi() {
    if (!mounted || _trackerUiVisible) return;
    hideTrackerUi();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_trackerMounted)
          Positioned.fill(
            child: TrackerPlatformView(interactive: _trackerUiVisible),
          ),
        if (isTrackerSupported)
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 2, right: 2),
              child: Material(
                color: Colors.black.withValues(alpha: 0.46),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Semantics(
                  button: true,
                  label: _trackerUiVisible ? 'Hide tracker UI' : 'Show tracker',
                  child: IconButton(
                    onPressed: _toggleTracker,
                    icon: Icon(
                      _trackerUiVisible
                          ? Icons.visibility_off_outlined
                          : Icons.center_focus_strong,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
