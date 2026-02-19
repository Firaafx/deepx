// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../models/tracker_runtime_config.dart';
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

  TrackerRuntimeConfig get runtimeConfig => _runtimeConfig;
  TrackerRuntimeConfig _runtimeConfig = TrackerRuntimeConfig.defaults;

  StreamSubscription? _messageSub;
  Timer? _configRetryTimer;
  late String _viewId;
  late String _iframeElementId;
  late String _bridgeChannel;
  web.HTMLIFrameElement? _trackerIframe;
  bool _trackerReady = false;
  final ValueNotifier<int> _overlayTick = ValueNotifier<int>(0);
  DateTime _lastFrameAt =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
  TrackingFrame _lastRawFrame = TrackingFrame.zero;
  bool _hasHeadBaseline = false;
  bool _pendingInitialHeadBaseline = true;
  double _baselineHeadX = 0;
  double _baselineHeadY = 0;
  double _baselineHeadZ = 0.2;
  double _baselineYaw = 0;
  double _baselinePitch = 0;

  bool _pointerDown = false;
  DateTime? _pointerDownAt;
  html.Element? _pointerTarget;
  html.Element? _hoverTarget;
  int? _lastDispatchX;
  int? _lastDispatchY;

  int get frameAgeMs => DateTime.now().difference(_lastFrameAt).inMilliseconds;
  bool get hasFreshFrame => frameAgeMs <= 450;

  void remapHeadBaselineToCurrentFrame() {
    _setHeadBaseline(_lastRawFrame);
    frameNotifier.value = _applyHeadBaseline(_lastRawFrame);
  }

  Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;
    _initialized = true;

    _viewId = 'global-tracker-${DateTime.now().millisecondsSinceEpoch}';
    _iframeElementId =
        'global-tracker-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _bridgeChannel =
        'global-tracker-bridge-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final iframe = web.HTMLIFrameElement();
      iframe.id = _iframeElementId;
      iframe.src =
          'assets/tracker.html?global=1&headless=1&channel=$_bridgeChannel';
      iframe.style.setProperty('border', 'none');
      iframe.style.setProperty('width', '100%');
      iframe.style.setProperty('height', '100%');
      iframe.style.setProperty('background', 'transparent');
      iframe.allow = 'camera *; microphone *; fullscreen *';
      _trackerIframe = iframe;
      _syncHostVisibilityStyle();
      scheduleMicrotask(() => _postConfig(force: true));
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

      if (payload['type'] == 'tracker_ready') {
        _trackerReady = true;
        _configRetryTimer?.cancel();
        _postConfig(force: true);
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
      _lastRawFrame = frame;
      if (_pendingInitialHeadBaseline) {
        _setHeadBaseline(frame);
        _pendingInitialHeadBaseline = false;
      }
      _lastFrameAt = DateTime.now();
      final mappedFrame = _applyHeadBaseline(frame);
      frameNotifier.value = mappedFrame;
      _bridgePointerInteractions(mappedFrame);
    });

    await refreshPreferences();
    _postConfig(force: true);
  }

  Future<void> dispose() async {
    _postConfig(force: true);
    _configRetryTimer?.cancel();
    _configRetryTimer = null;
    _releasePointerAtCurrentPosition();
    _clearHoverState();
    await _messageSub?.cancel();
    _messageSub = null;
    _overlayTick.dispose();
    frameNotifier.dispose();
  }

  Future<void> refreshPreferences() async {
    if (!kIsWeb) return;
    final prefs =
        await AppRepository.instance.fetchTrackerPreferencesForCurrentUser();
    _runtimeConfig =
        await AppRepository.instance.fetchTrackerRuntimeConfigForCurrentUser();
    _dartCursorEnabled = _runtimeConfig.dartCursorEnabled;
    _trackerEnabled = prefs['trackerEnabled'] ?? true;
    _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
    _syncHostVisibilityStyle();
    _postConfig(force: true);
    _bumpOverlayTick();
  }

  Future<void> setTrackerEnabled(bool enabled) async {
    final bool wasEnabled = _trackerEnabled;
    _trackerEnabled = enabled;
    if (enabled && !wasEnabled) {
      _pendingInitialHeadBaseline = true;
    }
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerEnabled: enabled);
    _syncHostVisibilityStyle();
    _postConfig(force: true);
    if (!enabled) {
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    }
    _bumpOverlayTick();
  }

  Future<void> setTrackerUiVisible(bool visible) async {
    _trackerUiVisible = visible;
    await AppRepository.instance
        .updateTrackerPreferencesForCurrentUser(trackerUiVisible: visible);
    _syncHostVisibilityStyle();
    _postConfig(force: true);
    _bumpOverlayTick();
  }

  void setDartCursorEnabled(bool enabled) {
    _dartCursorEnabled = enabled;
    _runtimeConfig = _runtimeConfig.copyWith(dartCursorEnabled: enabled);
    _postConfig(force: true);
    if (!enabled) {
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    }
    _bumpOverlayTick();
  }

  void setRuntimeConfig(TrackerRuntimeConfig config) {
    _runtimeConfig = config;
    _dartCursorEnabled = config.dartCursorEnabled;
    _postConfig(force: true);
    if (!_dartCursorEnabled) {
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    }
    _bumpOverlayTick();
  }

  void _postConfig({bool force = false}) {
    if (!kIsWeb || !_initialized) return;
    final element = _trackerIframe;
    if (element == null) return;
    final payload = <String, dynamic>{
      'type': 'tracker_config',
      'channel': _bridgeChannel,
      'enabled': _trackerEnabled,
      'uiVisible': _trackerUiVisible,
      'showCursor': !_dartCursorEnabled && _runtimeConfig.showCursor,
      'headless': !_trackerUiVisible,
      'settings': _runtimeConfig.toMap(),
    };
    try {
      element.contentWindow?.postMessage(jsonEncode(payload).toJS, '*'.toJS);
    } catch (_) {}
    if (!_trackerReady && !force) {
      _queueConfigRetry();
    }
    if (!_trackerReady && force) {
      _queueConfigRetry();
    }
  }

  void _setHeadBaseline(TrackingFrame frame) {
    _baselineHeadX = frame.headX;
    _baselineHeadY = frame.headY;
    _baselineHeadZ = frame.headZ;
    _baselineYaw = frame.yaw;
    _baselinePitch = frame.pitch;
    _hasHeadBaseline = true;
  }

  TrackingFrame _applyHeadBaseline(TrackingFrame frame) {
    if (!_hasHeadBaseline) return frame;
    return TrackingFrame(
      headX: frame.headX - _baselineHeadX,
      headY: frame.headY - _baselineHeadY,
      headZ: 0.2 + (frame.headZ - _baselineHeadZ),
      yaw: frame.yaw - _baselineYaw,
      pitch: frame.pitch - _baselinePitch,
      cursorX: frame.cursorX,
      cursorY: frame.cursorY,
      wink: frame.wink,
      pinch: frame.pinch,
      hasHand: frame.hasHand,
    );
  }

  void _bridgePointerInteractions(TrackingFrame frame) {
    if (!_trackerEnabled || !_dartCursorEnabled) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
      return;
    }

    final x = frame.cursorX.round();
    final y = frame.cursorY.round();
    final dispatchSurface = _resolveDispatchSurface();
    final html.Element? targetAtCursor = html.document.elementFromPoint(x, y);
    if (targetAtCursor == null) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
      return;
    }
    if (_isTrackerHostElement(targetAtCursor)) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
      return;
    }
    final html.Element dispatchTarget = targetAtCursor;

    if (!identical(_hoverTarget, dispatchTarget)) {
      final html.Element? previous = _hoverTarget;
      if (previous != null) {
        _dispatchMouseEvent(
          target: previous,
          type: 'mouseout',
          x: x,
          y: y,
        );
      }
      _dispatchMouseEvent(
        target: dispatchTarget,
        type: 'mouseover',
        x: x,
        y: y,
      );
      _hoverTarget = dispatchTarget;
    }

    void dispatchPointerToTargets({
      required String type,
      required int buttons,
      html.Element? primaryTarget,
      bool includeSurfaceFallback = true,
    }) {
      final html.Element target = primaryTarget ?? dispatchTarget;
      _dispatchPointer(
        target: target,
        type: type,
        x: x,
        y: y,
        buttons: buttons,
      );
      final surface = dispatchSurface;
      final bool shouldFallbackToSurface = includeSurfaceFallback &&
          surface != null &&
          !identical(surface, target) &&
          (identical(target, html.document.body) ||
              identical(target, html.document.documentElement));
      if (shouldFallbackToSurface) {
        _dispatchPointer(
          target: surface,
          type: type,
          x: x,
          y: y,
          buttons: buttons,
        );
      }
    }

    final bool moved = _lastDispatchX != x || _lastDispatchY != y;
    if (moved || _pointerDown) {
      dispatchPointerToTargets(
        type: 'pointermove',
        buttons: _pointerDown ? 1 : 0,
      );
      _lastDispatchX = x;
      _lastDispatchY = y;
    }

    final bool active = frame.wink || frame.pinch;

    if (active && !_pointerDown) {
      _pointerDown = true;
      _pointerDownAt = DateTime.now();
      _pointerTarget = dispatchTarget;
      dispatchPointerToTargets(
        primaryTarget: _pointerTarget!,
        type: 'pointerdown',
        buttons: 1,
      );
      return;
    }

    if (_pointerDown) {
      final moveTarget = _pointerTarget ?? dispatchTarget;
      dispatchPointerToTargets(
        primaryTarget: moveTarget,
        type: 'pointermove',
        buttons: 1,
      );
    }

    if (!active && _pointerDown) {
      final downAt = _pointerDownAt;
      final int holdMs = downAt == null
          ? 1000
          : DateTime.now().difference(downAt).inMilliseconds;
      final upTarget = _pointerTarget ?? dispatchTarget;
      dispatchPointerToTargets(
        primaryTarget: upTarget,
        type: 'pointerup',
        buttons: 0,
      );

      if (holdMs < 300) {
        dispatchPointerToTargets(
          primaryTarget: upTarget,
          type: 'click',
          buttons: 0,
          includeSurfaceFallback: false,
        );
        _dispatchMouseClick(
          target: upTarget,
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
        final bool attachTrackerHost = _trackerEnabled;
        final cursor = ValueListenableBuilder<TrackingFrame>(
          valueListenable: frameNotifier,
          builder: (context, frame, _) {
            final bool stale =
                DateTime.now().difference(_lastFrameAt).inMilliseconds > 1200;
            if (!_trackerEnabled || !_dartCursorEnabled || stale) {
              if (stale) {
                _releasePointerAtCurrentPosition(cancel: true);
                _clearHoverState();
              }
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
            // Tracker iframe is visual-only; app interaction is always through
            // native pointer + synthetic Dart cursor bridge.
            ignoring: true,
            child: ClipRect(
              child: Opacity(
                opacity: attachTrackerHost ? 1 : 0,
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
    return identical(source, iframe.contentWindow) ||
        source == iframe.contentWindow;
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

  void _dispatchPointer({
    required html.Element target,
    required String type,
    required int x,
    required int y,
    required int buttons,
  }) {
    final String mouseType;
    if (type == 'pointerdown') {
      mouseType = 'mousedown';
    } else if (type == 'pointerup' || type == 'pointercancel') {
      mouseType = 'mouseup';
    } else {
      mouseType = 'mousemove';
    }
    _dispatchMouseEvent(
      target: target,
      type: mouseType,
      x: x,
      y: y,
    );
  }

  void _dispatchMouseEvent({
    required html.Element target,
    required String type,
    required int x,
    required int y,
  }) {
    try {
      target.dispatchEvent(
        html.MouseEvent(
          type,
          canBubble: true,
          cancelable: true,
          clientX: x,
          clientY: y,
          button: 0,
        ),
      );
    } catch (_) {}
  }

  void _dispatchMouseClick({
    required html.Element target,
    required int x,
    required int y,
  }) {
    try {
      target.dispatchEvent(
        html.MouseEvent(
          'click',
          canBubble: true,
          cancelable: true,
          clientX: x,
          clientY: y,
          button: 0,
        ),
      );
    } catch (_) {}
  }

  void _releasePointerAtCurrentPosition({bool cancel = false}) {
    if (!_pointerDown) return;
    final target = _pointerTarget;
    _pointerDown = false;
    _pointerDownAt = null;
    _pointerTarget = null;
    _lastDispatchX = null;
    _lastDispatchY = null;
    if (target == null) return;
    _dispatchPointer(
      target: target,
      type: cancel ? 'pointercancel' : 'pointerup',
      x: frameNotifier.value.cursorX.round(),
      y: frameNotifier.value.cursorY.round(),
      buttons: 0,
    );
  }

  void _clearHoverState() {
    final html.Element? previous = _hoverTarget;
    if (previous != null) {
      _dispatchMouseEvent(
        target: previous,
        type: 'mouseout',
        x: frameNotifier.value.cursorX.round(),
        y: frameNotifier.value.cursorY.round(),
      );
    }
    _hoverTarget = null;
    _lastDispatchX = null;
    _lastDispatchY = null;
  }

  bool _isTrackerHostElement(html.Element target) {
    if (target.id == _iframeElementId) return true;
    final String id = target.id;
    if (id.contains('global-tracker')) return true;
    final html.Element? iframe = html.document.getElementById(_iframeElementId);
    if (iframe == null) return false;
    if (identical(target, iframe)) return true;
    return iframe.contains(target);
  }

  html.Element? _resolveDispatchSurface() {
    final html.Element? flutterPane =
        html.document.querySelector('flt-glass-pane');
    if (flutterPane != null) return flutterPane;
    return html.document.documentElement;
  }

  void _queueConfigRetry() {
    if (_configRetryTimer != null) return;
    _configRetryTimer =
        Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!_initialized) {
        timer.cancel();
        _configRetryTimer = null;
        return;
      }
      if (_trackerReady || timer.tick > 16) {
        timer.cancel();
        _configRetryTimer = null;
        return;
      }
      _postConfig(force: true);
    });
  }

  void _syncHostVisibilityStyle() {
    final element = _trackerIframe;
    if (element == null) return;
    final bool visibleUi = _trackerEnabled && _trackerUiVisible;
    element.style.setProperty('pointer-events', 'none');
    element.style
        .setProperty('visibility', _trackerEnabled ? 'visible' : 'hidden');
    element.style.setProperty('opacity', visibleUi ? '1' : '0');
    element.style.setProperty('background', 'transparent');
    element.style.setProperty('transform', 'none');
  }

  void _bumpOverlayTick() {
    _overlayTick.value = _overlayTick.value + 1;
  }
}
