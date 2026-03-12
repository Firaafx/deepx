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
  bool _routeActive = true;
  bool _pageVisible = true;
  bool get _trackingActive => _routeActive && _pageVisible;

  bool get trackerEnabled => _trackerEnabled;
  bool _trackerEnabled = true;

  bool get trackerUiVisible => _trackerUiVisible;
  bool _trackerUiVisible = false;

  bool get dartCursorEnabled => _dartCursorEnabled;
  bool _dartCursorEnabled = false;
  bool _dartCursorSuppressedByMouse = false;
  Timer? _mouseIdleTimer;
  DateTime? _lastMouseMoveAt;

  TrackerRuntimeConfig get runtimeConfig => _runtimeConfig;
  TrackerRuntimeConfig _runtimeConfig = TrackerRuntimeConfig.defaults;

  StreamSubscription? _messageSub;
  StreamSubscription<html.MouseEvent>? _mouseMoveSub;
  StreamSubscription<html.DeviceMotionEvent>? _deviceMotionSub;
  StreamSubscription<html.DeviceOrientationEvent>? _deviceOrientationSub;
  StreamSubscription<html.Event>? _visibilitySub;
  StreamSubscription<html.Event>? _windowBlurSub;
  StreamSubscription<html.Event>? _windowFocusSub;
  Timer? _configRetryTimer;
  Timer? _staleFrameWatchdog;
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
  TrackingFrame _latestTrackerFrame = TrackingFrame.zero;
  double _mouseHeadX = 0;
  double _mouseHeadY = 0;
  double _mouseCursorX = 0;
  double _mouseCursorY = 0;
  double _accelerometerX = 0;
  double _accelerometerY = 0;
  double _gyroYaw = 0;
  double _gyroPitch = 0;
  bool _mouseHoverSupported = true;
  bool _accelerometerSupported = false;
  bool _gyroSupported = false;

  bool _pointerDown = false;
  DateTime? _pointerDownAt;
  html.Element? _pointerTarget;
  int? _lastDispatchX;
  int? _lastDispatchY;

  int get frameAgeMs => DateTime.now().difference(_lastFrameAt).inMilliseconds;
  bool get hasFreshFrame => frameAgeMs <= 450;
  bool get supportsMouseHover => _mouseHoverSupported;
  bool get supportsAccelerometer => _accelerometerSupported;
  bool get supportsGyro => _gyroSupported;
  bool get _effectiveDartCursorEnabled =>
      _dartCursorEnabled && !_dartCursorSuppressedByMouse;

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
      _latestTrackerFrame = mappedFrame;
      if (_runtimeConfig.inputMode == 'mediapipe') {
        frameNotifier.value = mappedFrame;
        _bridgePointerInteractions(mappedFrame);
        _bumpOverlayTick();
      } else {
        _emitInputModeFrame();
      }
    });

    _pageVisible = !(html.document.hidden ?? false);
    _visibilitySub ??= html.document.onVisibilityChange.listen((_) {
      _setPageVisible(!(html.document.hidden ?? false));
    });
    _windowBlurSub ??= html.window.onBlur.listen((_) {
      _setPageVisible(false);
    });
    _windowFocusSub ??= html.window.onFocus.listen((_) {
      _setPageVisible(!(html.document.hidden ?? false));
    });

    _initializeInputModeSources();

    _staleFrameWatchdog?.cancel();
    _staleFrameWatchdog = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) {
        if (!_trackerEnabled || !_dartCursorEnabled) return;
        final int age = DateTime.now().difference(_lastFrameAt).inMilliseconds;
        if (age <= 1200) return;
        _releasePointerAtCurrentPosition(cancel: true);
        _clearHoverState();
        _bumpOverlayTick();
      },
    );

    await refreshPreferences();
    _postConfig(force: true);
  }

  Future<void> dispose() async {
    _postConfig(force: true);
    _configRetryTimer?.cancel();
    _configRetryTimer = null;
    _staleFrameWatchdog?.cancel();
    _staleFrameWatchdog = null;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _mouseMoveSub?.cancel();
    _mouseMoveSub = null;
    _deviceMotionSub?.cancel();
    _deviceMotionSub = null;
    _deviceOrientationSub?.cancel();
    _deviceOrientationSub = null;
    _visibilitySub?.cancel();
    _visibilitySub = null;
    _windowBlurSub?.cancel();
    _windowBlurSub = null;
    _windowFocusSub?.cancel();
    _windowFocusSub = null;
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
    _dartCursorSuppressedByMouse = false;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _trackerEnabled = prefs['trackerEnabled'] ?? true;
    _trackerUiVisible = prefs['trackerUiVisible'] ?? false;
    _syncHostVisibilityStyle();
    _postConfig(force: true);
    _emitInputModeFrame();
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
      _dartCursorSuppressedByMouse = false;
      _mouseIdleTimer?.cancel();
      _mouseIdleTimer = null;
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    } else {
      _emitInputModeFrame();
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

  void setRouteActive(bool active) {
    if (_routeActive == active) return;
    _routeActive = active;
    _dartCursorSuppressedByMouse = false;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _postConfig(force: true);
    if (!active) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
    } else {
      _emitInputModeFrame();
    }
    _bumpOverlayTick();
  }

  void _setPageVisible(bool visible) {
    if (_pageVisible == visible) return;
    _pageVisible = visible;
    _dartCursorSuppressedByMouse = false;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _postConfig(force: true);
    _syncHostVisibilityStyle();
    if (!visible) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
    } else {
      _emitInputModeFrame();
    }
    _bumpOverlayTick();
  }

  void setDartCursorEnabled(bool enabled) {
    _dartCursorEnabled = enabled;
    _dartCursorSuppressedByMouse = false;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _runtimeConfig = _runtimeConfig.copyWith(dartCursorEnabled: enabled);
    _postConfig(force: true);
    if (!enabled) {
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    }
    _bumpOverlayTick();
  }

  void setRuntimeConfig(TrackerRuntimeConfig config) {
    final String previousInputMode = _runtimeConfig.inputMode;
    _runtimeConfig = config;
    _dartCursorEnabled = config.dartCursorEnabled;
    _dartCursorSuppressedByMouse = false;
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = null;
    _postConfig(force: true);
    if (!_dartCursorEnabled) {
      _releasePointerAtCurrentPosition();
      _clearHoverState();
    }
    if (previousInputMode != config.inputMode) {
      _emitInputModeFrame();
    }
    _bumpOverlayTick();
  }

  void _postConfig({bool force = false}) {
    if (!kIsWeb || !_initialized) return;
    final element = _trackerIframe;
    if (element == null) return;
    final bool mediapipeActive = _trackingActive &&
        _trackerEnabled &&
        _runtimeConfig.inputMode == 'mediapipe';
    final bool showTrackerUi = mediapipeActive && _trackerUiVisible;
    final payload = <String, dynamic>{
      'type': 'tracker_config',
      'channel': _bridgeChannel,
      'enabled': mediapipeActive,
      'uiVisible': showTrackerUi,
      'showCursor':
          mediapipeActive && !_dartCursorEnabled && _runtimeConfig.showCursor,
      'headless': !showTrackerUi,
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

  void _initializeInputModeSources() {
    if (!kIsWeb) return;
    final String ua = html.window.navigator.userAgent.toLowerCase();
    final bool likelyMobile = RegExp(r'android|iphone|ipad|ipod').hasMatch(ua);
    final bool hasTouchPoints =
        (html.window.navigator.maxTouchPoints ?? 0) > 0;
    final bool coarsePointer =
        html.window.matchMedia('(pointer: coarse)').matches;
    final bool mobileLike = likelyMobile || coarsePointer;
    _mouseHoverSupported = true;
    _accelerometerSupported = mobileLike && hasTouchPoints;
    _gyroSupported = mobileLike && hasTouchPoints;
    final int width = (html.window.innerWidth ?? 1).clamp(1, 1000000);
    final int height = (html.window.innerHeight ?? 1).clamp(1, 1000000);
    _mouseCursorX = width / 2;
    _mouseCursorY = height / 2;
    _mouseHeadX = 0;
    _mouseHeadY = 0;

    _mouseMoveSub ??= html.window.onMouseMove.listen((event) {
      _handleRealMouseMove();
      final int width = (html.window.innerWidth ?? 1).clamp(1, 1000000);
      final int height = (html.window.innerHeight ?? 1).clamp(1, 1000000);
      _mouseCursorX = event.client.x.clamp(0, width - 1).toDouble();
      _mouseCursorY = event.client.y.clamp(0, height - 1).toDouble();
      final double normX = -(((_mouseCursorX / width) - 0.5) * 2);
      final double normY = ((_mouseCursorY / height) - 0.5) * 2;
      _mouseHeadX = normX.clamp(-1.0, 1.0);
      _mouseHeadY = normY.clamp(-1.0, 1.0);
      if (_runtimeConfig.inputMode == 'mouse_hover') {
        _emitInputModeFrame();
      }
    });

    _deviceMotionSub ??= html.window.onDeviceMotion.listen((event) {
      final acc = event.accelerationIncludingGravity;
      if (acc == null) return;
      final double? x = acc.x?.toDouble();
      final double? y = acc.y?.toDouble();
      if (x != null && x.isFinite) {
        _accelerometerX = (x / 9.81).clamp(-1.2, 1.2).toDouble();
      }
      if (y != null && y.isFinite) {
        _accelerometerY = (y / 9.81).clamp(-1.2, 1.2).toDouble();
      }
      _accelerometerSupported = true;
      if (_runtimeConfig.inputMode == 'accelerometer') {
        _emitInputModeFrame();
      }
    });

    _deviceOrientationSub ??= html.window.onDeviceOrientation.listen((event) {
      final double beta = (event.beta ?? 0).toDouble();
      final double gamma = (event.gamma ?? 0).toDouble();
      if (beta.isFinite) {
        _gyroPitch = (beta / 45).clamp(-1.5, 1.5).toDouble();
      }
      if (gamma.isFinite) {
        _gyroYaw = (gamma / 45).clamp(-1.5, 1.5).toDouble();
      }
      _gyroSupported = true;
      if (_runtimeConfig.inputMode == 'gyro') {
        _emitInputModeFrame();
      }
    });
  }

  void _emitInputModeFrame() {
    if (!_trackerEnabled || !_trackingActive) return;
    final String mode = _runtimeConfig.inputMode;
    if (mode == 'mediapipe') return;
    TrackingFrame frame = _latestTrackerFrame;
    bool usingSyntheticInput = false;
    if (mode == 'mouse_hover') {
      usingSyntheticInput = true;
      frame = TrackingFrame(
        headX: _mouseHeadX,
        headY: _mouseHeadY,
        headZ: 0.2,
        yaw: _mouseHeadX * 18,
        pitch: _mouseHeadY * 12,
        cursorX: _mouseCursorX,
        cursorY: _mouseCursorY,
        wink: false,
        pinch: false,
        hasHand: false,
      );
    } else if (mode == 'accelerometer' && _accelerometerSupported) {
      usingSyntheticInput = true;
      frame = TrackingFrame(
        headX: _accelerometerX,
        headY: _accelerometerY,
        headZ: 0.2,
        yaw: _accelerometerX * 22,
        pitch: _accelerometerY * 18,
        cursorX: _latestTrackerFrame.cursorX,
        cursorY: _latestTrackerFrame.cursorY,
        wink: _latestTrackerFrame.wink,
        pinch: _latestTrackerFrame.pinch,
        hasHand: _latestTrackerFrame.hasHand,
      );
    } else if (mode == 'gyro' && _gyroSupported) {
      usingSyntheticInput = true;
      frame = TrackingFrame(
        headX: _gyroYaw,
        headY: _gyroPitch,
        headZ: 0.2,
        yaw: _gyroYaw * 28,
        pitch: _gyroPitch * 22,
        cursorX: _latestTrackerFrame.cursorX,
        cursorY: _latestTrackerFrame.cursorY,
        wink: _latestTrackerFrame.wink,
        pinch: _latestTrackerFrame.pinch,
        hasHand: _latestTrackerFrame.hasHand,
      );
    } else if (mode != 'mediapipe' &&
        ((mode == 'accelerometer' && !_accelerometerSupported) ||
            (mode == 'gyro' && !_gyroSupported))) {
      // Fallback to mediapipe when a selected sensor is unavailable.
      _runtimeConfig = _runtimeConfig.copyWith(inputMode: 'mediapipe');
      _postConfig(force: true);
      return;
    }
    if (usingSyntheticInput) {
      // Keep cursor/gesture bridge alive when MediaPipe is disabled.
      _lastFrameAt = DateTime.now();
    }
    final TrackingFrame sanitized = _sanitizeFrame(frame);
    frameNotifier.value = sanitized;
    _bridgePointerInteractions(sanitized);
    _bumpOverlayTick();
  }

  void _handleRealMouseMove() {
    _lastMouseMoveAt = DateTime.now();
    if (!_dartCursorEnabled) return;
    if (!_dartCursorSuppressedByMouse) {
      _dartCursorSuppressedByMouse = true;
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
      _bumpOverlayTick();
    }
    _mouseIdleTimer?.cancel();
    _mouseIdleTimer = Timer(const Duration(milliseconds: 1000), () {
      final lastMove = _lastMouseMoveAt;
      if (lastMove == null) return;
      if (DateTime.now().difference(lastMove).inMilliseconds < 1000) return;
      if (!_dartCursorEnabled) return;
      if (_dartCursorSuppressedByMouse) {
        _dartCursorSuppressedByMouse = false;
        _bumpOverlayTick();
      }
    });
  }

  TrackingFrame _sanitizeFrame(TrackingFrame frame) {
    final int viewportW = (html.window.innerWidth ?? 1).clamp(1, 1000000);
    final int viewportH = (html.window.innerHeight ?? 1).clamp(1, 1000000);
    double safe(double value, double fallback) {
      if (value.isNaN || value.isInfinite) return fallback;
      return value;
    }

    return TrackingFrame(
      headX: safe(frame.headX, 0).clamp(-2.0, 2.0).toDouble(),
      headY: safe(frame.headY, 0).clamp(-2.0, 2.0).toDouble(),
      headZ: safe(frame.headZ, 0.2).clamp(0.01, 3.0).toDouble(),
      yaw: safe(frame.yaw, 0).clamp(-180.0, 180.0).toDouble(),
      pitch: safe(frame.pitch, 0).clamp(-180.0, 180.0).toDouble(),
      cursorX: safe(frame.cursorX, viewportW / 2)
          .clamp(0.0, viewportW.toDouble())
          .toDouble(),
      cursorY: safe(frame.cursorY, viewportH / 2)
          .clamp(0.0, viewportH.toDouble())
          .toDouble(),
      wink: frame.wink,
      pinch: frame.pinch,
      hasHand: frame.hasHand,
    );
  }

  void _bridgePointerInteractions(TrackingFrame frame) {
    if (!_trackingActive || !_trackerEnabled || !_effectiveDartCursorEnabled) {
      _releasePointerAtCurrentPosition(cancel: true);
      _clearHoverState();
      return;
    }

    final int viewportW = (html.window.innerWidth ?? 1).clamp(1, 1000000);
    final int viewportH = (html.window.innerHeight ?? 1).clamp(1, 1000000);
    final x = frame.cursorX.round().clamp(0, viewportW - 1);
    final y = frame.cursorY.round().clamp(0, viewportH - 1);
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
            if (!_trackingActive ||
                !_trackerEnabled ||
                !_effectiveDartCursorEnabled ||
                stale) {
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
                opacity: attachTrackerHost && _trackingActive ? 1 : 0,
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
    try {
      target.dispatchEvent(
        html.PointerEvent(
          type,
          <String, dynamic>{
            'bubbles': true,
            'cancelable': true,
            'clientX': x,
            'clientY': y,
            'buttons': buttons,
            'button': 0,
            'pointerId': 731,
            'isPrimary': true,
            'pointerType': 'mouse',
            'composed': true,
          },
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
    final bool visibleUi = _trackerEnabled &&
        _trackingActive &&
        _runtimeConfig.inputMode == 'mediapipe' &&
        _trackerUiVisible;
    element.style.setProperty('pointer-events', 'none');
    element.style.setProperty(
      'visibility',
      (_trackerEnabled &&
              _trackingActive &&
              _runtimeConfig.inputMode == 'mediapipe')
          ? 'visible'
          : 'hidden',
    );
    element.style.setProperty('opacity', visibleUi ? '1' : '0');
    element.style.setProperty('background', 'transparent');
    element.style.setProperty('transform', 'none');
  }

  void _bumpOverlayTick() {
    _overlayTick.value = _overlayTick.value + 1;
  }
}
