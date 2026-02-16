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
  late String _iframeElementId;
  late String _bridgeChannel;
  web.HTMLIFrameElement? _trackerIframe;
  final ValueNotifier<int> _overlayTick = ValueNotifier<int>(0);
  DateTime _lastFrameAt =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

  bool _pointerDown = false;
  DateTime? _pointerDownAt;
  html.Element? _pointerTarget;

  Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;
    _initialized = true;

    _viewId = 'global-tracker-${DateTime.now().millisecondsSinceEpoch}';
    _iframeElementId = 'global-tracker-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _bridgeChannel = 'global-tracker-bridge-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final iframe = web.HTMLIFrameElement();
      iframe.id = _iframeElementId;
      iframe.src = 'assets/tracker.html?global=1&headless=1&channel=$_bridgeChannel';
      iframe.style.setProperty('border', 'none');
      iframe.style.setProperty('width', '100%');
      iframe.style.setProperty('height', '100%');
      iframe.style.setProperty('background', 'transparent');
      iframe.allow = 'camera *; microphone *; fullscreen *';
      _trackerIframe = iframe;
      scheduleMicrotask(_postConfig);
      return iframe;
    });

    _messageSub = web.window.onMessage.listen((event) {
      if (!_isFromTracker(event)) return;
      final payload = _extractPayload(event.data);
      if (payload == null) return;
      if (payload['channel'] != null &&
          payload['channel'].toString() != _bridgeChannel) {
        return;
      }

      if (payload['type'] == 'hide_tracker') {
        unawaited(setTrackerUiVisible(false));
        return;
      }

      if (!payload.containsKey('head')) return;
      final frame = TrackingFrame.fromTrackerPayload(
        payload,
        viewportWidth: (html.window.innerWidth ?? 1).toDouble(),
        viewportHeight: (html.window.innerHeight ?? 1).toDouble(),
      );
      _lastFrameAt = DateTime.now();
      frameNotifier.value = frame;
      _bridgePointerInteractions(frame);
    });

    await refreshPreferences();
    _postConfig();
  }

  Future<void> dispose() async {
    _postConfig();
    await _messageSub?.cancel();
    _messageSub = null;
    _overlayTick.dispose();
    frameNotifier.dispose();
  }

  Future<void> refreshPreferences() async {
    if (!kIsWeb) return;
    final prefs =
        await AppRepository.instance.fetchTrackerPreferencesForCurrentUser();
    _trackerEnabled = prefs['trackerEnabled'] ?? true;
    _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
    _postConfig();
    _bumpOverlayTick();
  }

  Future<void> setTrackerEnabled(bool enabled) async {
    _trackerEnabled = enabled;
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerEnabled: enabled);
    _postConfig();
    if (!enabled) _releasePointerAtCurrentPosition();
    _bumpOverlayTick();
  }

  Future<void> setTrackerUiVisible(bool visible) async {
    _trackerUiVisible = visible;
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerUiVisible: visible);
    _postConfig();
    _bumpOverlayTick();
  }

  void setDartCursorEnabled(bool enabled) {
    _dartCursorEnabled = enabled;
    _postConfig();
    if (!enabled) _releasePointerAtCurrentPosition();
    _bumpOverlayTick();
  }

  void _postConfig() {
    if (!kIsWeb || !_initialized) return;
    final element = _trackerIframe;
    if (element == null) return;
    final payload = <String, dynamic>{
      'type': 'tracker_config',
      'channel': _bridgeChannel,
      'enabled': _trackerEnabled,
      'uiVisible': _trackerUiVisible,
      'showCursor': !_dartCursorEnabled,
      'headless': !_trackerUiVisible,
    };
    element.contentWindow?.postMessage(jsonEncode(payload).toJS, '*'.toJS);
  }

  void _bridgePointerInteractions(TrackingFrame frame) {
    if (!_trackerEnabled || !_dartCursorEnabled) {
      _releasePointerAtCurrentPosition();
      return;
    }

    final x = frame.cursorX.round();
    final y = frame.cursorY.round();
    final target = html.document.elementFromPoint(x, y);
    if (target == null) {
      _releasePointerAtCurrentPosition();
      return;
    }

    final bool active = frame.wink || frame.pinch;
    if (active && !_pointerDown) {
      _pointerDown = true;
      _pointerDownAt = DateTime.now();
      _pointerTarget = target;
      _dispatchMouse(
        target: _pointerTarget!,
        type: 'mousedown',
        x: x,
        y: y,
      );
      return;
    }

    if (_pointerDown) {
      final moveTarget = _pointerTarget ?? target;
      _dispatchMouse(
        target: moveTarget,
        type: 'mousemove',
        x: x,
        y: y,
      );
    }

    if (!active && _pointerDown) {
      final downAt = _pointerDownAt;
      final int holdMs =
          downAt == null ? 1000 : DateTime.now().difference(downAt).inMilliseconds;
      final upTarget = _pointerTarget ?? target;
      _dispatchMouse(
        target: upTarget,
        type: 'mouseup',
        x: x,
        y: y,
      );

      if (holdMs < 300) {
        _dispatchMouse(
          target: upTarget,
          type: 'click',
          x: x,
          y: y,
        );
      }

      _pointerDown = false;
      _pointerDownAt = null;
      _pointerTarget = null;
    }
  }

  Widget buildGlobalOverlay({required Widget child}) {
    if (!kIsWeb || !_initialized) return child;

    return ValueListenableBuilder<int>(
      valueListenable: _overlayTick,
      builder: (context, _, __) {
        final cursor = ValueListenableBuilder<TrackingFrame>(
          valueListenable: frameNotifier,
          builder: (context, frame, _) {
            final bool stale =
                DateTime.now().difference(_lastFrameAt).inMilliseconds > 1200;
            if (!_trackerEnabled || !_dartCursorEnabled || stale) {
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
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.8)),
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

        final trackerHost = Positioned.fill(
          child: IgnorePointer(
            ignoring: !_trackerUiVisible,
            child: ClipRect(
              child: Opacity(
                opacity: _trackerUiVisible ? 1 : 0,
                child: HtmlElementView(viewType: _viewId),
              ),
            ),
          ),
        );

        return Stack(
          children: <Widget>[
            child,
            trackerHost,
            cursor,
          ],
        );
      },
    );
  }

  bool _isFromTracker(web.MessageEvent event) {
    final iframe = _trackerIframe;
    if (iframe == null) return false;
    final source = event.source;
    if (source == null) return false;
    return identical(source, iframe.contentWindow) || source == iframe.contentWindow;
  }

  Map<String, dynamic>? _extractPayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is JSString) return _decodeJson(data.toDart);
    if (data is String) return _decodeJson(data);
    return null;
  }

  Map<String, dynamic>? _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  void _dispatchMouse({
    required html.Element target,
    required String type,
    required int x,
    required int y,
  }) {
    target.dispatchEvent(
      html.MouseEvent(
        type,
        canBubble: true,
        cancelable: true,
        view: html.window,
        clientX: x,
        clientY: y,
        button: 0,
      ),
    );
  }

  void _releasePointerAtCurrentPosition() {
    if (!_pointerDown) return;
    final target = _pointerTarget;
    _pointerDown = false;
    _pointerDownAt = null;
    _pointerTarget = null;
    if (target == null) return;
    _dispatchMouse(
      target: target,
      type: 'mouseup',
      x: frameNotifier.value.cursorX.round(),
      y: frameNotifier.value.cursorY.round(),
    );
  }

  void _bumpOverlayTick() {
    _overlayTick.value = _overlayTick.value + 1;
  }
}
