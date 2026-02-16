// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../models/tracking_frame.dart';
import 'app_repository.dart';

class TrackingService {
  TrackingService._();

  static final TrackingService instance = TrackingService._();

  final ValueNotifier<TrackingFrame> frameNotifier =
      ValueNotifier<TrackingFrame>(TrackingFrame.zero);

  bool get initialized => _initialized;
  bool _initialized = false;

  bool get trackerEnabled => _trackerEnabled;
  bool _trackerEnabled = true;

  bool get trackerUiVisible => _trackerUiVisible;
  bool _trackerUiVisible = false;

  bool get dartCursorEnabled => _dartCursorEnabled;
  bool _dartCursorEnabled = true;

  StreamSubscription? _messageSub;
  late String _viewId;

  bool _pointerDown = false;
  DateTime? _pointerDownAt;

  Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;
    _initialized = true;

    _viewId = 'global-tracker-${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final iframe = web.HTMLIFrameElement();
      iframe.id = 'global-tracker-iframe';
      iframe.src = 'assets/tracker.html?global=1&headless=1';
      iframe.style.setProperty('border', 'none');
      iframe.style.setProperty('width', '100%');
      iframe.style.setProperty('height', '100%');
      iframe.allow = 'camera *; microphone *; fullscreen *';
      return iframe;
    });

    _messageSub = web.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! JSString) return;
      final String raw = data.toDart;
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return;
      }

      if (payload['type'] == 'hide_tracker') {
        setTrackerUiVisible(false);
        return;
      }

      if (!payload.containsKey('head')) return;
      final frame = TrackingFrame.fromTrackerPayload(
        payload,
        viewportWidth: (html.window.innerWidth ?? 1).toDouble(),
        viewportHeight: (html.window.innerHeight ?? 1).toDouble(),
      );
      frameNotifier.value = frame;
      _bridgePointerInteractions(frame);
    });

    await refreshPreferences();
    _postConfig();
  }

  Future<void> dispose() async {
    await _messageSub?.cancel();
    _messageSub = null;
    frameNotifier.dispose();
  }

  Future<void> refreshPreferences() async {
    if (!kIsWeb) return;
    final prefs =
        await AppRepository.instance.fetchTrackerPreferencesForCurrentUser();
    _trackerEnabled = prefs['trackerEnabled'] ?? true;
    _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
    _postConfig();
  }

  Future<void> setTrackerEnabled(bool enabled) async {
    _trackerEnabled = enabled;
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerEnabled: enabled);
    _postConfig();
  }

  Future<void> setTrackerUiVisible(bool visible) async {
    _trackerUiVisible = visible;
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerUiVisible: visible);
    _postConfig();
  }

  void setDartCursorEnabled(bool enabled) {
    _dartCursorEnabled = enabled;
    _postConfig();
  }

  void _postConfig() {
    if (!kIsWeb || !_initialized) return;
    final element = web.document.getElementById('global-tracker-iframe');
    if (element is! web.HTMLIFrameElement) return;
    final payload = <String, dynamic>{
      'type': 'tracker_config',
      'enabled': _trackerEnabled,
      'uiVisible': _trackerUiVisible,
      'showCursor': !_dartCursorEnabled,
      'headless': !_trackerUiVisible,
    };
    element.contentWindow?.postMessage(jsonEncode(payload).toJS, '*'.toJS);
  }

  void _bridgePointerInteractions(TrackingFrame frame) {
    if (!_trackerEnabled || !_dartCursorEnabled) return;

    final x = frame.cursorX.round();
    final y = frame.cursorY.round();
    final target = html.document.elementFromPoint(x, y);
    if (target == null) return;

    final bool active = frame.wink || frame.pinch;
    if (active && !_pointerDown) {
      _pointerDown = true;
      _pointerDownAt = DateTime.now();
      target.dispatchEvent(
        html.MouseEvent(
          'mousedown',
          canBubble: true,
          cancelable: true,
          view: html.window,
          clientX: x,
          clientY: y,
          button: 0,
        ),
      );
      return;
    }

    if (_pointerDown) {
      target.dispatchEvent(
        html.MouseEvent(
          'mousemove',
          canBubble: true,
          cancelable: true,
          view: html.window,
          clientX: x,
          clientY: y,
          button: 0,
        ),
      );
    }

    if (!active && _pointerDown) {
      final downAt = _pointerDownAt;
      final int holdMs =
          downAt == null ? 1000 : DateTime.now().difference(downAt).inMilliseconds;

      target.dispatchEvent(
        html.MouseEvent(
          'mouseup',
          canBubble: true,
          cancelable: true,
          view: html.window,
          clientX: x,
          clientY: y,
          button: 0,
        ),
      );

      if (holdMs < 300) {
        target.dispatchEvent(
          html.MouseEvent(
            'click',
            canBubble: true,
            cancelable: true,
            view: html.window,
            clientX: x,
            clientY: y,
            button: 0,
          ),
        );
      }

      _pointerDown = false;
      _pointerDownAt = null;
    }
  }

  Widget buildGlobalOverlay({required Widget child}) {
    if (!kIsWeb || !_initialized) return child;

    final cursor = ValueListenableBuilder<TrackingFrame>(
      valueListenable: frameNotifier,
      builder: (context, frame, _) {
        if (!_trackerEnabled || !_dartCursorEnabled) {
          return const SizedBox.shrink();
        }
        final Color color = frame.wink || frame.pinch
            ? const Color(0xFF38BDF8)
            : const Color(0xFFF8FAFC);
        return Positioned(
          left: frame.cursorX - 10,
          top: frame.cursorY - 10,
          child: IgnorePointer(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.8)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x9938BDF8),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final trackerHost = Positioned(
      left: _trackerUiVisible ? 0 : -10000,
      top: _trackerUiVisible ? 0 : -10000,
      width: _trackerUiVisible ? html.window.innerWidth?.toDouble() ?? 1 : 1,
      height: _trackerUiVisible ? html.window.innerHeight?.toDouble() ?? 1 : 1,
      child: IgnorePointer(
        ignoring: !_trackerUiVisible,
        child: HtmlElementView(viewType: _viewId),
      ),
    );

    return Stack(
      children: <Widget>[
        child,
        trackerHost,
        cursor,
      ],
    );
  }
}
