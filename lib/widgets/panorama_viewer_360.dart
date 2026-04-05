import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../models/preset_payload_v2.dart';
import '../models/tracking_frame.dart';
import '../rendering_support.dart';
import '../services/tracking_service.dart';

String _normalizeQualityTier(String? raw) {
  final String value = (raw ?? 'auto').trim().toLowerCase();
  if (value == 'high' || value == 'medium' || value == 'low') {
    return value;
  }
  return 'auto';
}

class PanoramaViewer360Status {
  const PanoramaViewer360Status({
    required this.connected,
    required this.ready,
    required this.isVideo,
    required this.playing,
    required this.paused,
    required this.currentTimeMs,
    required this.durationMs,
    required this.volume,
    required this.muted,
    required this.loop,
    required this.playbackRate,
    required this.qualityTier,
    required this.fullscreen,
    required this.assetKind,
  });

  const PanoramaViewer360Status.initial()
      : connected = false,
        ready = false,
        isVideo = false,
        playing = false,
        paused = true,
        currentTimeMs = 0,
        durationMs = 0,
        volume = 1,
        muted = true,
        loop = true,
        playbackRate = 1,
        qualityTier = 'auto',
        fullscreen = false,
        assetKind = 'image';

  final bool connected;
  final bool ready;
  final bool isVideo;
  final bool playing;
  final bool paused;
  final int currentTimeMs;
  final int durationMs;
  final double volume;
  final bool muted;
  final bool loop;
  final double playbackRate;
  final String qualityTier;
  final bool fullscreen;
  final String assetKind;

  PanoramaViewer360Status copyWith({
    bool? connected,
    bool? ready,
    bool? isVideo,
    bool? playing,
    bool? paused,
    int? currentTimeMs,
    int? durationMs,
    double? volume,
    bool? muted,
    bool? loop,
    double? playbackRate,
    String? qualityTier,
    bool? fullscreen,
    String? assetKind,
  }) {
    return PanoramaViewer360Status(
      connected: connected ?? this.connected,
      ready: ready ?? this.ready,
      isVideo: isVideo ?? this.isVideo,
      playing: playing ?? this.playing,
      paused: paused ?? this.paused,
      currentTimeMs: currentTimeMs ?? this.currentTimeMs,
      durationMs: durationMs ?? this.durationMs,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      loop: loop ?? this.loop,
      playbackRate: playbackRate ?? this.playbackRate,
      qualityTier: qualityTier ?? this.qualityTier,
      fullscreen: fullscreen ?? this.fullscreen,
      assetKind: assetKind ?? this.assetKind,
    );
  }
}

class PanoramaViewer360Controller {
  PanoramaViewer360Controller({
    PanoramaViewer360Status? initialStatus,
  }) : status = ValueNotifier<PanoramaViewer360Status>(
          initialStatus ?? const PanoramaViewer360Status.initial(),
        );

  final ValueNotifier<PanoramaViewer360Status> status;
  _PanoramaViewer360State? _state;

  PanoramaViewer360Status get value => status.value;

  void _attach(_PanoramaViewer360State state) {
    _state = state;
    _updateStatus(status.value.copyWith(connected: true));
  }

  void _detach(_PanoramaViewer360State state) {
    if (_state != state) return;
    _state = null;
    _updateStatus(
      status.value.copyWith(
        connected: false,
        ready: false,
        playing: false,
        paused: true,
        fullscreen: false,
      ),
    );
  }

  void _updateStatus(PanoramaViewer360Status next) {
    final PanoramaViewer360Status current = status.value;
    if (current.connected == next.connected &&
        current.ready == next.ready &&
        current.isVideo == next.isVideo &&
        current.playing == next.playing &&
        current.paused == next.paused &&
        current.currentTimeMs == next.currentTimeMs &&
        current.durationMs == next.durationMs &&
        current.volume == next.volume &&
        current.muted == next.muted &&
        current.loop == next.loop &&
        current.playbackRate == next.playbackRate &&
        current.qualityTier == next.qualityTier &&
        current.fullscreen == next.fullscreen &&
        current.assetKind == next.assetKind) {
      return;
    }
    status.value = next;
  }

  void dispose() {
    status.dispose();
  }

  void play() => _state?._postCommand('play');
  void pause() => _state?._postCommand('pause');
  void togglePlayPause() => _state?._postCommand('toggle_play');
  void seekToMs(int milliseconds) =>
      _state?._postCommand('seek', value: milliseconds.clamp(0, 86400000));
  void seekByMs(int deltaMs) => _state?._postCommand('seek_by', value: deltaMs);
  void setVolume(double value) => _state?._postCommand(
        'set_volume',
        value: value.clamp(0, 1),
      );
  void adjustVolume(double delta) => _state?._postCommand(
        'adjust_volume',
        value: delta,
      );
  void setMuted(bool value) => _state?._postCommand('set_muted', value: value);
  void toggleMuted() => _state?._postCommand('toggle_muted');
  void setLoop(bool value) => _state?._postCommand('set_loop', value: value);
  void setPlaybackRate(double value) =>
      _state?._postCommand('set_rate', value: value);
  void setQualityTier(String value) =>
      _state?._postCommand('set_quality', value: _normalizeQualityTier(value));
  void toggleFullscreen() => _state?._postCommand('toggle_fullscreen');
  void setFullscreen(bool value) =>
      _state?._postCommand('set_fullscreen', value: value);
  void resetPlayerSettings() => _state?._postCommand('reset_settings');
  void requestStatus() => _state?._postCommand('request_status');
}

class PanoramaViewer360 extends StatefulWidget {
  const PanoramaViewer360({
    super.key,
    this.initialPresetPayload,
    this.cleanView = false,
    this.embedded = false,
    this.embeddedStudio = false,
    this.externalHeadPose,
    this.useGlobalTracking = true,
    this.pointerPassthrough = false,
    this.reanchorToken = 0,
    this.studioSurface = false,
    this.controller,
    this.showPlayerControls = false,
    this.previewPlaybackMode = false,
    this.videoPlayActive = true,
    this.posterTimeMs = 0,
    this.resetVideoOnActivate = false,
    this.restorePosterOnDeactivate = false,
    this.qualityTier = 'auto',
    this.volume = 1.0,
    this.muted = true,
    this.loop = true,
    this.playbackRate = 1.0,
  });

  final Map<String, dynamic>? initialPresetPayload;
  final bool cleanView;
  final bool embedded;
  final bool embeddedStudio;
  final Map<String, double>? externalHeadPose;
  final bool useGlobalTracking;
  final bool pointerPassthrough;
  final int reanchorToken;
  final bool studioSurface;
  final PanoramaViewer360Controller? controller;
  final bool showPlayerControls;
  final bool previewPlaybackMode;
  final bool videoPlayActive;
  final int posterTimeMs;
  final bool resetVideoOnActivate;
  final bool restorePosterOnDeactivate;
  final String qualityTier;
  final double volume;
  final bool muted;
  final bool loop;
  final double playbackRate;

  @override
  State<PanoramaViewer360> createState() => _PanoramaViewer360State();
}

class _PanoramaViewer360State extends State<PanoramaViewer360> {
  late final String _viewId;
  late final String _frameElementId;
  late final String _bridgeChannel;

  web.HTMLIFrameElement? _iframe;
  StreamSubscription? _messageSubscription;
  VoidCallback? _globalTrackingListener;
  bool _iframeReady = false;

  @override
  void initState() {
    super.initState();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int nowUs = DateTime.now().microsecondsSinceEpoch;
    _viewId = 'deepx-360-viewer-$nowMs';
    _frameElementId = 'deepx-360-frame-$nowMs';
    _bridgeChannel = 'deepx-360-bridge-$nowUs';
    widget.controller?._attach(this);
    _bootstrap();
    _syncTrackingListener(forcePush: false);
  }

  @override
  void didUpdateWidget(covariant PanoramaViewer360 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
      if (_iframeReady) {
        widget.controller?._updateStatus(
          widget.controller!.value.copyWith(connected: true),
        );
        widget.controller?.requestStatus();
      }
    }
    final bool externalPayloadChanged = !const DeepCollectionEquality().equals(
      widget.initialPresetPayload,
      oldWidget.initialPresetPayload,
    );
    if (externalPayloadChanged) {
      _postPayload();
    }
    if (!_constConfigEquality.equals(_configSnapshot(), _configSnapshot(oldWidget))) {
      _postViewerConfig();
    }
    if (widget.pointerPassthrough != oldWidget.pointerPassthrough) {
      _iframe?.style.setProperty(
        'pointer-events',
        widget.pointerPassthrough ? 'none' : 'auto',
      );
    }
    if (!const MapEquality<String, double>().equals(
      widget.externalHeadPose,
      oldWidget.externalHeadPose,
    )) {
      if (widget.externalHeadPose != null) {
        _postHeadPose(widget.externalHeadPose!);
      } else {
        _pushCurrentTrackingFrame();
      }
    }
    if (widget.useGlobalTracking != oldWidget.useGlobalTracking) {
      _syncTrackingListener(forcePush: true);
    }
    if (widget.reanchorToken != oldWidget.reanchorToken) {
      _postMessage(<String, dynamic>{'type': 'reanchor'});
    }
  }

  @override
  void dispose() {
    final VoidCallback? listener = _globalTrackingListener;
    if (listener != null) {
      TrackingService.instance.frameNotifier.removeListener(listener);
      _globalTrackingListener = null;
    }
    _postMessage(<String, dynamic>{'type': 'dispose'});
    widget.controller?._detach(this);
    _messageSubscription?.cancel();
    super.dispose();
  }

  static const MapEquality<String, Object?> _constConfigEquality =
      MapEquality<String, Object?>();

  Map<String, Object?> _configSnapshot([PanoramaViewer360? source]) {
    final PanoramaViewer360 target = source ?? widget;
    return <String, Object?>{
      'showPlayerControls': target.showPlayerControls,
      'previewPlaybackMode': target.previewPlaybackMode,
      'videoPlayActive': target.videoPlayActive,
      'posterTimeMs': target.posterTimeMs,
      'resetVideoOnActivate': target.resetVideoOnActivate,
      'restorePosterOnDeactivate': target.restorePosterOnDeactivate,
      'qualityTier': _normalizeQualityTier(target.qualityTier),
      'volume': target.volume.clamp(0, 1),
      'muted': target.muted,
      'loop': target.loop,
      'playbackRate': target.playbackRate.clamp(0.25, 2.0),
    };
  }

  void _bootstrap() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final web.HTMLIFrameElement iframe = web.HTMLIFrameElement();
      iframe.id = _frameElementId;
      iframe.width = '100%';
      iframe.height = '100%';
      iframe.srcdoc = _buildSrcdoc();
      iframe.style.setProperty('border', 'none');
      iframe.style.setProperty('background', 'transparent');
      iframe.style.setProperty(
        'pointer-events',
        widget.pointerPassthrough ? 'none' : 'auto',
      );
      iframe.allow = 'autoplay *; fullscreen *';
      _iframe = iframe;
      return iframe;
    });

    _messageSubscription = web.window.onMessage.listen((event) {
      final Map<String, dynamic>? messageData = _extractPayload(event.data);
      if (messageData == null) return;
      if (messageData['channel']?.toString() != _bridgeChannel) return;
      final String type = (messageData['type'] ?? '').toString();
      if (type == 'viewer360_ready') {
        _iframeReady = true;
        _postPayload();
        _postViewerConfig();
        _pushCurrentTrackingFrame();
        widget.controller?.requestStatus();
        return;
      }
      if (type == 'viewer360_state') {
        _handleStateMessage(messageData);
      }
    });
  }

  void _handleStateMessage(Map<String, dynamic> messageData) {
    final Map<String, dynamic> state =
        messageData['state'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(messageData['state'] as Map)
            : (messageData['state'] is Map
                ? Map<String, dynamic>.from(messageData['state'] as Map)
                : messageData);
    final PanoramaViewer360Status current =
        widget.controller?.value ?? const PanoramaViewer360Status.initial();
    widget.controller?._updateStatus(
      current.copyWith(
        connected: true,
        ready: state['ready'] == true,
        isVideo: state['isVideo'] == true,
        playing: state['playing'] == true,
        paused: state['paused'] != false,
        currentTimeMs: _toInt(state['currentTimeMs'], 0),
        durationMs: _toInt(state['durationMs'], 0),
        volume: _toDouble(state['volume'], current.volume).clamp(0, 1),
        muted: state['muted'] == true,
        loop: state['loop'] == true,
        playbackRate:
            _toDouble(state['playbackRate'], current.playbackRate).clamp(
          0.25,
          2.0,
        ),
        qualityTier:
            _normalizeQualityTier(state['qualityTier']?.toString()),
        fullscreen: state['fullscreen'] == true,
        assetKind: (state['assetKind']?.toString().toLowerCase() == 'video')
            ? 'video'
            : 'image',
      ),
    );
  }

  Map<String, dynamic>? _extractPayload(JSAny? raw) {
    if (raw == null) return null;
    final Object? dartValue = raw.dartify();
    if (dartValue is Map<String, dynamic>) return dartValue;
    if (dartValue is Map) return Map<String, dynamic>.from(dartValue);
    if (dartValue is String) {
      try {
        final Object? decoded = jsonDecode(dartValue);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _syncTrackingListener({required bool forcePush}) {
    final VoidCallback? existing = _globalTrackingListener;
    if (existing != null) {
      TrackingService.instance.frameNotifier.removeListener(existing);
      _globalTrackingListener = null;
    }
    if (widget.externalHeadPose != null) {
      if (forcePush) {
        _postHeadPose(widget.externalHeadPose!);
      }
      return;
    }
    if (!widget.useGlobalTracking) {
      if (forcePush) {
        _postHeadPose(kNeutralPreviewHeadPose);
      }
      return;
    }
    _globalTrackingListener = () => _pushCurrentTrackingFrame();
    TrackingService.instance.frameNotifier
        .addListener(_globalTrackingListener!);
    if (forcePush) {
      _pushCurrentTrackingFrame();
    }
  }

  void _postPayload() {
    final PresetPayloadV2 adapted = PresetPayloadV2.fromMap(
      widget.initialPresetPayload ?? _blankPayload(),
      fallbackMode: '360',
    );
    _postMessage(<String, dynamic>{
      'type': 'apply_payload',
      'payload': adapted.toMap(),
    });
  }

  void _postViewerConfig() {
    _postMessage(<String, dynamic>{
      'type': 'apply_config',
      'config': _configSnapshot(),
    });
  }

  void _pushCurrentTrackingFrame() {
    if (widget.externalHeadPose != null) {
      _postHeadPose(widget.externalHeadPose!);
      return;
    }
    if (!widget.useGlobalTracking) {
      _postHeadPose(kNeutralPreviewHeadPose);
      return;
    }
    final TrackingFrame frame = TrackingService.instance.frameNotifier.value;
    _postTrackingFrame(frame);
  }

  void _postHeadPose(Map<String, double> headPose) {
    _postTrackingFrame(trackingFrameFromHeadPose(headPose));
  }

  void _postTrackingFrame(TrackingFrame frame) {
    _postMessage(<String, dynamic>{
      'type': 'tracking_patch',
      'head': frame.toHeadPoseMap(),
    });
  }

  void _postCommand(String command, {dynamic value}) {
    _postMessage(<String, dynamic>{
      'type': 'viewer360_command',
      'command': command,
      if (value != null) 'value': value,
    });
  }

  void _postMessage(Map<String, dynamic> message) {
    if (!_iframeReady) return;
    final web.Window? contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) return;
    contentWindow.postMessage(
      jsonEncode(<String, dynamic>{
        ...message,
        'channel': _bridgeChannel,
      }).toJS,
      '*'.toJS,
    );
  }

  Map<String, dynamic> _blankPayload() {
    return blank360Payload();
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _buildSrcdoc() {
    final String bodyBackground = widget.cleanView ? 'transparent' : '#000000';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    :root {
      color-scheme: dark;
      --control-bg: rgba(12, 12, 14, 0.72);
      --control-border: rgba(255, 255, 255, 0.12);
      --control-hover: rgba(255, 255, 255, 0.08);
      --control-text: #ffffff;
      --control-muted: rgba(255, 255, 255, 0.72);
      --accent: #ffffff;
      --shadow: 0 20px 60px rgba(0, 0, 0, 0.48);
    }
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: $bodyBackground;
      font-family: Arial, sans-serif;
    }
    body {
      position: relative;
      user-select: none;
    }
    #player-shell {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
      outline: none;
      background: ${widget.cleanView ? 'transparent' : '#000000'};
    }
    #host {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
    }
    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }
    #controls {
      position: absolute;
      left: 0;
      right: 0;
      bottom: 0;
      opacity: 0;
      transform: translateY(18px);
      transition: opacity 180ms ease, transform 180ms ease;
      pointer-events: none;
    }
    #controls.visible {
      opacity: 1;
      transform: translateY(0);
      pointer-events: auto;
    }
    #controls.hidden {
      display: none;
    }
    #controls-gradient {
      position: absolute;
      left: 0;
      right: 0;
      bottom: 0;
      height: 140px;
      background: linear-gradient(
        to top,
        rgba(0, 0, 0, 0.82),
        rgba(0, 0, 0, 0.52),
        rgba(0, 0, 0, 0.0)
      );
      pointer-events: none;
    }
    #controls-inner {
      position: relative;
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 12px 14px 14px;
    }
    #progress-wrap {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    #time-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      color: var(--control-muted);
      font-size: 11px;
      letter-spacing: 0.02em;
    }
    #progress {
      width: 100%;
      appearance: none;
      height: 4px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.18);
      outline: none;
      cursor: pointer;
    }
    #progress::-webkit-slider-thumb {
      appearance: none;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #ffffff;
      box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.35);
    }
    #progress::-moz-range-thumb {
      width: 12px;
      height: 12px;
      border: 0;
      border-radius: 50%;
      background: #ffffff;
      box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.35);
    }
    .control-button {
      width: 40px;
      height: 40px;
      border: 1px solid var(--control-border);
      border-radius: 999px;
      background: var(--control-bg);
      color: var(--control-text);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: var(--shadow);
      transition: background 140ms ease, border-color 140ms ease,
        transform 140ms ease;
    }
    .control-button:hover {
      background: var(--control-hover);
      transform: translateY(-1px);
    }
    #volume-shell {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 0 4px;
      border-radius: 999px;
      background: var(--control-bg);
      border: 1px solid var(--control-border);
      box-shadow: var(--shadow);
      overflow: hidden;
    }
    #volume-wrap {
      width: 0;
      opacity: 0;
      transition: width 180ms ease, opacity 180ms ease;
      overflow: hidden;
    }
    #volume-shell.expanded #volume-wrap {
      width: 96px;
      opacity: 1;
    }
    #volume {
      width: 96px;
      appearance: none;
      height: 4px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.18);
      outline: none;
      cursor: pointer;
    }
    #volume::-webkit-slider-thumb {
      appearance: none;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #ffffff;
    }
    #volume::-moz-range-thumb {
      width: 10px;
      height: 10px;
      border: 0;
      border-radius: 50%;
      background: #ffffff;
    }
    #settings-panel,
    #other-panel {
      position: absolute;
      right: 14px;
      bottom: 68px;
      width: min(280px, calc(100vw - 28px));
      padding: 12px;
      border-radius: 18px;
      border: 1px solid var(--control-border);
      background: rgba(8, 8, 10, 0.92);
      box-shadow: var(--shadow);
      color: var(--control-text);
      backdrop-filter: blur(18px);
      display: none;
    }
    #settings-panel.visible,
    #other-panel.visible {
      display: block;
    }
    .settings-title {
      font-size: 12px;
      font-weight: 700;
      color: rgba(255, 255, 255, 0.82);
      margin: 0 0 10px;
      letter-spacing: 0.03em;
      text-transform: uppercase;
    }
    .settings-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 8px 0;
      color: var(--control-text);
      font-size: 13px;
    }
    .settings-row + .settings-row {
      border-top: 1px solid rgba(255, 255, 255, 0.08);
    }
    .settings-row select,
    .settings-row button {
      border: 1px solid var(--control-border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.08);
      color: #ffffff;
      padding: 6px 10px;
      font-size: 12px;
      cursor: pointer;
    }
    .settings-row input[type="checkbox"] {
      width: 18px;
      height: 18px;
      accent-color: #ffffff;
    }
    .other-block {
      padding: 10px 0 0;
      color: rgba(255, 255, 255, 0.82);
      font-size: 12px;
      line-height: 1.5;
    }
    .other-button-row {
      display: flex;
      gap: 8px;
      margin-top: 10px;
    }
    .other-button-row button {
      flex: 1;
      border: 1px solid var(--control-border);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.08);
      color: #ffffff;
      padding: 8px 10px;
      font-size: 12px;
      cursor: pointer;
    }
    #stats {
      white-space: pre-line;
      color: rgba(255, 255, 255, 0.72);
      font-size: 11px;
      margin-top: 12px;
    }
  </style>
</head>
<body>
  <div id="player-shell" tabindex="0">
    <div id="host"></div>
    <div id="controls" class="hidden">
      <div id="controls-gradient"></div>
      <div id="controls-inner">
        <button id="play-toggle" class="control-button" type="button">►</button>
        <div id="progress-wrap">
          <input id="progress" type="range" min="0" max="1000" value="0" step="1">
          <div id="time-row">
            <span id="time-current">0:00</span>
            <span id="time-duration">0:00</span>
          </div>
        </div>
        <div id="volume-shell">
          <button id="volume-toggle" class="control-button" type="button">🔊</button>
          <div id="volume-wrap">
            <input id="volume" type="range" min="0" max="100" value="100" step="1">
          </div>
        </div>
        <button id="settings-toggle" class="control-button" type="button">⚙</button>
        <button id="fullscreen-toggle" class="control-button" type="button">⛶</button>
      </div>
      <div id="settings-panel">
        <div class="settings-title">Playback</div>
        <div id="loop-row" class="settings-row">
          <span>Loop</span>
          <input id="loop-toggle" type="checkbox">
        </div>
        <div id="speed-row" class="settings-row">
          <span>Playback speed</span>
          <select id="speed-select">
            <option value="0.25">0.25x</option>
            <option value="0.5">0.5x</option>
            <option value="0.75">0.75x</option>
            <option value="1">1x</option>
            <option value="1.25">1.25x</option>
            <option value="1.5">1.5x</option>
            <option value="2">2x</option>
          </select>
        </div>
        <div class="settings-row">
          <span>Quality</span>
          <select id="quality-select">
            <option value="auto">Auto</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>
        </div>
        <div class="settings-row">
          <span>Other</span>
          <button id="other-toggle" type="button">Open</button>
        </div>
      </div>
      <div id="other-panel">
        <div class="settings-title">Other</div>
        <div class="other-block" id="shortcuts-text">
          Space: Play/Pause
          Left/Right: Seek 5 seconds
          Up/Down: Volume 5 percent
          F: Toggle fullscreen
        </div>
        <div class="other-button-row">
          <button id="reset-settings" type="button">Reset settings</button>
          <button id="close-other" type="button">Close</button>
        </div>
        <div id="stats"></div>
      </div>
    </div>
  </div>
  <script type="importmap">
    {
      "imports": {
        "three": "https://unpkg.com/three@0.160.0/build/three.module.js"
      }
    }
  </script>
  <script type="module">
    import * as THREE from 'three';

    const CLEAN_VIEW = ${widget.cleanView ? 'true' : 'false'};
    const BRIDGE_CHANNEL = ${jsonEncode(_bridgeChannel)};

    let scene;
    let camera;
    let renderer;
    let sphere;
    let activeTexture = null;
    let videoElement = null;
    let disposed = false;
    let payload = {
      mode: '360',
      scene: { assetUrl: '', assetKind: 'image' },
      controls: {},
      meta: {},
    };
    let viewerConfig = {
      showPlayerControls: false,
      previewPlaybackMode: false,
      videoPlayActive: true,
      posterTimeMs: 0,
      resetVideoOnActivate: false,
      restorePosterOnDeactivate: false,
      qualityTier: 'auto',
      volume: 1,
      muted: true,
      loop: true,
      playbackRate: 1,
    };
    let headPose = { x: 0, y: 0, z: 0.2, yaw: 0, pitch: 0 };
    let anchorPose = { ...headPose };
    let previousPreviewPlaybackActive = null;
    let controlsHideTimer = null;
    let stateInterval = null;
    let controlsVisible = false;
    let seeking = false;
    let controlsExpanded = false;

    const playerShell = document.getElementById('player-shell');
    const controlsRoot = document.getElementById('controls');
    const playToggle = document.getElementById('play-toggle');
    const progress = document.getElementById('progress');
    const timeCurrent = document.getElementById('time-current');
    const timeDuration = document.getElementById('time-duration');
    const volumeShell = document.getElementById('volume-shell');
    const volumeToggle = document.getElementById('volume-toggle');
    const volume = document.getElementById('volume');
    const settingsToggle = document.getElementById('settings-toggle');
    const fullscreenToggle = document.getElementById('fullscreen-toggle');
    const settingsPanel = document.getElementById('settings-panel');
    const otherPanel = document.getElementById('other-panel');
    const loopRow = document.getElementById('loop-row');
    const speedRow = document.getElementById('speed-row');
    const loopToggle = document.getElementById('loop-toggle');
    const speedSelect = document.getElementById('speed-select');
    const qualitySelect = document.getElementById('quality-select');
    const otherToggle = document.getElementById('other-toggle');
    const resetSettingsButton = document.getElementById('reset-settings');
    const closeOtherButton = document.getElementById('close-other');
    const statsNode = document.getElementById('stats');

    function emit(message) {
      window.parent.postMessage(JSON.stringify({
        ...message,
        channel: BRIDGE_CHANNEL,
      }), '*');
    }

    function toFinite(value, fallback) {
      const numeric = Number(value);
      return Number.isFinite(numeric) ? numeric : fallback;
    }

    function clamp(value, min, max) {
      return Math.max(min, Math.min(max, value));
    }

    function controls() {
      return (payload && payload.controls && typeof payload.controls === 'object')
        ? payload.controls
        : {};
    }

    function formatTime(ms) {
      const totalSeconds = Math.max(0, Math.floor(ms / 1000));
      const hours = Math.floor(totalSeconds / 3600);
      const minutes = Math.floor((totalSeconds % 3600) / 60);
      const seconds = totalSeconds % 60;
      if (hours > 0) {
        return String(hours) + ':' + String(minutes).padStart(2, '0') + ':' +
          String(seconds).padStart(2, '0');
      }
      return String(minutes) + ':' + String(seconds).padStart(2, '0');
    }

    function qualityScale() {
      const tier = String(viewerConfig.qualityTier || 'auto').toLowerCase();
      const dpr = clamp(window.devicePixelRatio || 1, 0.5, 2);
      if (tier === 'high') return clamp(dpr, 0.9, 1.4);
      if (tier === 'medium') return 0.78;
      if (tier === 'low') return 0.42;
      return clamp(dpr * 0.85, 0.65, 1.1);
    }

    function applyQualityTier() {
      if (!renderer) return;
      renderer.setPixelRatio(qualityScale());
      resize();
      if (activeTexture) {
        activeTexture.minFilter = viewerConfig.qualityTier === 'low'
          ? THREE.LinearFilter
          : THREE.LinearMipmapLinearFilter;
        activeTexture.magFilter = THREE.LinearFilter;
        activeTexture.needsUpdate = true;
      }
      qualitySelect.value = String(viewerConfig.qualityTier || 'auto');
    }

    function updateControlsVisibility() {
      const shouldShow = viewerConfig.showPlayerControls === true;
      controlsRoot.classList.toggle('hidden', !shouldShow);
      if (!shouldShow) {
        settingsPanel.classList.remove('visible');
        otherPanel.classList.remove('visible');
        return;
      }
      playToggle.style.display = videoElement ? 'inline-flex' : 'none';
      progress.parentElement.style.display = videoElement ? 'flex' : 'none';
      volumeShell.style.display = videoElement ? 'flex' : 'none';
      loopRow.style.display = videoElement ? 'flex' : 'none';
      speedRow.style.display = videoElement ? 'flex' : 'none';
      fullscreenToggle.style.display = 'inline-flex';
      settingsToggle.style.display = 'inline-flex';
    }

    function showControls(forceKeepVisible = false) {
      if (viewerConfig.showPlayerControls !== true) return;
      controlsVisible = true;
      controlsRoot.classList.add('visible');
      clearTimeout(controlsHideTimer);
      if (forceKeepVisible) return;
      if (!videoElement || videoElement.paused) return;
      controlsHideTimer = window.setTimeout(() => {
        if (settingsPanel.classList.contains('visible') ||
            otherPanel.classList.contains('visible') ||
            controlsExpanded) {
          return;
        }
        controlsVisible = false;
        controlsRoot.classList.remove('visible');
      }, 1800);
    }

    function hidePanels() {
      settingsPanel.classList.remove('visible');
      otherPanel.classList.remove('visible');
    }

    function updateStats() {
      const duration = videoElement && Number.isFinite(videoElement.duration)
        ? Math.round(videoElement.duration * 1000)
        : 0;
      const current = videoElement
        ? Math.round((videoElement.currentTime || 0) * 1000)
        : 0;
      const fps = renderer ? renderer.info.render.frame : 0;
      statsNode.textContent =
        'Asset: ' + String(payload.scene && payload.scene.assetKind || 'image') + '\\n' +
        'Quality: ' + String(viewerConfig.qualityTier || 'auto') + '\\n' +
        'Time: ' + formatTime(current) + ' / ' + formatTime(duration) + '\\n' +
        'Volume: ' + Math.round(clamp(toFinite(videoElement ? videoElement.volume : viewerConfig.volume, 1), 0, 1) * 100) + '%\\n' +
        'Loop: ' + ((videoElement ? videoElement.loop : viewerConfig.loop) ? 'On' : 'Off') + '\\n' +
        'Playback: ' + toFinite(videoElement ? videoElement.playbackRate : viewerConfig.playbackRate, 1).toFixed(2) + 'x\\n' +
        'Frames: ' + fps;
    }

    function updateControls() {
      const isVideo = !!videoElement;
      const currentMs = isVideo
        ? Math.round((videoElement.currentTime || 0) * 1000)
        : 0;
      const durationMs = isVideo && Number.isFinite(videoElement.duration)
        ? Math.round(videoElement.duration * 1000)
        : 0;
      playToggle.textContent = isVideo && !videoElement.paused ? '❚❚' : '►';
      volumeToggle.textContent = (isVideo ? videoElement.muted : viewerConfig.muted)
        ? '🔇'
        : (toFinite(isVideo ? videoElement.volume : viewerConfig.volume, 1) <= 0.01 ? '🔈' : '🔊');
      timeCurrent.textContent = formatTime(currentMs);
      timeDuration.textContent = formatTime(durationMs);
      if (!seeking) {
        progress.value = durationMs > 0
          ? String(Math.round((currentMs / durationMs) * 1000))
          : '0';
      }
      volume.value = String(Math.round(
        clamp(toFinite(isVideo ? videoElement.volume : viewerConfig.volume, 1), 0, 1) * 100,
      ));
      loopToggle.checked = isVideo ? videoElement.loop : viewerConfig.loop;
      speedSelect.value = String(toFinite(
        isVideo ? videoElement.playbackRate : viewerConfig.playbackRate,
        1,
      ));
      qualitySelect.value = String(viewerConfig.qualityTier || 'auto');
      fullscreenToggle.textContent = document.fullscreenElement ? '🡽' : '⛶';
      updateStats();
    }

    function buildState() {
      const isVideo = !!videoElement;
      const durationMs = isVideo && Number.isFinite(videoElement.duration)
        ? Math.round(videoElement.duration * 1000)
        : 0;
      const currentTimeMs = isVideo
        ? Math.round((videoElement.currentTime || 0) * 1000)
        : 0;
      return {
        type: 'viewer360_state',
        state: {
          ready: !!renderer && !!sphere,
          isVideo,
          playing: isVideo ? !videoElement.paused : false,
          paused: isVideo ? videoElement.paused : true,
          currentTimeMs,
          durationMs,
          volume: clamp(toFinite(isVideo ? videoElement.volume : viewerConfig.volume, 1), 0, 1),
          muted: isVideo ? videoElement.muted : viewerConfig.muted,
          loop: isVideo ? videoElement.loop : viewerConfig.loop,
          playbackRate: toFinite(isVideo ? videoElement.playbackRate : viewerConfig.playbackRate, 1),
          qualityTier: String(viewerConfig.qualityTier || 'auto'),
          fullscreen: !!document.fullscreenElement,
          assetKind: String(payload.scene && payload.scene.assetKind || 'image'),
        },
      };
    }

    function emitState() {
      emit(buildState());
      updateControls();
    }

    function safeSeek(seconds) {
      if (!videoElement) return;
      const duration = Number.isFinite(videoElement.duration) ? videoElement.duration : 0;
      const next = clamp(seconds, 0, duration > 0 ? duration : Math.max(seconds, 0));
      try {
        videoElement.currentTime = next;
      } catch (_) {}
      updateControls();
      emitState();
    }

    async function safePlay() {
      if (!videoElement) return;
      try {
        await videoElement.play();
      } catch (_) {}
      emitState();
    }

    function safePause() {
      if (!videoElement) return;
      videoElement.pause();
      emitState();
    }

    function applyVideoElementSettings() {
      if (!videoElement) return;
      videoElement.loop = viewerConfig.loop === true;
      videoElement.muted = viewerConfig.muted === true;
      videoElement.volume = clamp(toFinite(viewerConfig.volume, 1), 0, 1);
      videoElement.playbackRate = clamp(toFinite(viewerConfig.playbackRate, 1), 0.25, 2);
      updateControls();
    }

    function syncPreviewPlayback(forcePoster = false) {
      if (!videoElement) return;
      const posterSeconds = Math.max(0, toFinite(viewerConfig.posterTimeMs, 0) / 1000);
      const nextActive = viewerConfig.videoPlayActive !== false;
      const activationChanged = previousPreviewPlaybackActive !== nextActive;
      previousPreviewPlaybackActive = nextActive;
      if (nextActive) {
        if (activationChanged && viewerConfig.resetVideoOnActivate === true) {
          safeSeek(0);
        }
        safePlay();
        return;
      }
      safePause();
      if (forcePoster || viewerConfig.restorePosterOnDeactivate === true || activationChanged) {
        safeSeek(posterSeconds);
      }
    }

    function applyViewerConfig(forcePoster = false) {
      viewerConfig.qualityTier = String(viewerConfig.qualityTier || 'auto').toLowerCase();
      if (viewerConfig.qualityTier !== 'auto' &&
          viewerConfig.qualityTier !== 'high' &&
          viewerConfig.qualityTier !== 'medium' &&
          viewerConfig.qualityTier !== 'low') {
        viewerConfig.qualityTier = 'auto';
      }
      viewerConfig.volume = clamp(toFinite(viewerConfig.volume, 1), 0, 1);
      viewerConfig.playbackRate = clamp(toFinite(viewerConfig.playbackRate, 1), 0.25, 2);
      viewerConfig.posterTimeMs = Math.max(0, Math.round(toFinite(viewerConfig.posterTimeMs, 0)));
      applyQualityTier();
      updateControlsVisibility();
      applyVideoElementSettings();
      if (videoElement) {
        if (viewerConfig.previewPlaybackMode === true) {
          syncPreviewPlayback(forcePoster);
        } else if (viewerConfig.videoPlayActive !== false) {
          safePlay();
        } else {
          safePause();
        }
      }
      emitState();
    }

    function disposeMedia() {
      if (activeTexture) {
        try { activeTexture.dispose(); } catch (_) {}
        activeTexture = null;
      }
      if (videoElement) {
        try { videoElement.pause(); } catch (_) {}
        try { videoElement.removeAttribute('src'); } catch (_) {}
        try { videoElement.load(); } catch (_) {}
        videoElement = null;
      }
      if (sphere && sphere.material) {
        sphere.material.map = null;
        sphere.material.needsUpdate = true;
      }
      previousPreviewPlaybackActive = null;
      updateControlsVisibility();
      emitState();
    }

    function attachVideoEvents(video) {
      const sync = () => emitState();
      video.addEventListener('play', sync);
      video.addEventListener('pause', sync);
      video.addEventListener('timeupdate', sync);
      video.addEventListener('seeked', sync);
      video.addEventListener('loadedmetadata', () => {
        applyVideoElementSettings();
        if (viewerConfig.previewPlaybackMode === true) {
          syncPreviewPlayback(true);
        } else if (viewerConfig.videoPlayActive === false) {
          safePause();
        } else {
          safePlay();
        }
        emitState();
      });
      video.addEventListener('volumechange', sync);
      video.addEventListener('ratechange', sync);
      video.addEventListener('ended', sync);
      video.addEventListener('canplay', sync);
    }

    async function applyMedia() {
      disposeMedia();
      if (!sphere || !sphere.material) return;
      const scenePayload = (payload && payload.scene && typeof payload.scene === 'object')
        ? payload.scene
        : {};
      const assetUrl = String(scenePayload.assetUrl || '').trim();
      const assetKind = String(scenePayload.assetKind || 'image').trim().toLowerCase();
      if (!assetUrl) {
        emitState();
        return;
      }

      if (assetKind === 'video') {
        const video = document.createElement('video');
        video.src = assetUrl;
        video.preload = 'auto';
        video.loop = viewerConfig.loop === true;
        video.muted = viewerConfig.muted === true;
        video.autoplay = viewerConfig.videoPlayActive !== false;
        video.playsInline = true;
        video.crossOrigin = 'anonymous';
        video.volume = viewerConfig.volume;
        video.playbackRate = viewerConfig.playbackRate;
        attachVideoEvents(video);
        videoElement = video;
        activeTexture = new THREE.VideoTexture(video);
      } else {
        const loader = new THREE.TextureLoader();
        loader.crossOrigin = 'anonymous';
        activeTexture = await loader.loadAsync(assetUrl);
      }

      activeTexture.colorSpace = THREE.SRGBColorSpace;
      sphere.material.map = activeTexture;
      sphere.material.needsUpdate = true;
      applyQualityTier();
      updateControlsVisibility();
      if (videoElement) {
        if (viewerConfig.previewPlaybackMode === true) {
          syncPreviewPlayback(true);
        } else if (viewerConfig.videoPlayActive !== false) {
          safePlay();
        } else {
          safePause();
        }
      } else {
        emitState();
      }
    }

    function updateCamera() {
      if (!camera) return;
      const config = controls();
      const manualMode = config.manualMode === true;
      const baseFov = toFinite(config.baseFov, 75);
      const minFov = toFinite(config.minFov, 45);
      const maxFov = toFinite(config.maxFov, 95);
      const yawSensitivity = toFinite(config.yawSensitivity, 1);
      const pitchSensitivity = toFinite(config.pitchSensitivity, 1);
      const zoomSensitivity = toFinite(config.zoomSensitivity, 1);

      let yawDegrees = 0;
      let pitchDegrees = 0;
      let fov = baseFov;

      if (manualMode) {
        yawDegrees = toFinite(config.manualYaw, 0);
        pitchDegrees = toFinite(config.manualPitch, 0);
        fov = toFinite(config.manualFov, baseFov);
      } else {
        const deltaX = headPose.x - anchorPose.x;
        const deltaY = headPose.y - anchorPose.y;
        const deltaZ = headPose.z - anchorPose.z;
        const deltaYaw = headPose.yaw - anchorPose.yaw;
        const deltaPitch = headPose.pitch - anchorPose.pitch;
        yawDegrees = (deltaYaw + (deltaX * 42)) * yawSensitivity;
        pitchDegrees = (deltaPitch + (deltaY * 30)) * pitchSensitivity;
        fov = baseFov - (deltaZ * 48 * zoomSensitivity);
      }

      const fovMin = Math.min(minFov, maxFov);
      const fovMax = Math.max(minFov, maxFov);
      camera.fov = clamp(fov, fovMin, fovMax);
      camera.updateProjectionMatrix();
      camera.rotation.order = 'YXZ';
      camera.rotation.y = THREE.MathUtils.degToRad(yawDegrees);
      camera.rotation.x = THREE.MathUtils.degToRad(clamp(pitchDegrees, -85, 85));
    }

    function resize() {
      if (!camera || !renderer) return;
      const width = Math.max(window.innerWidth || 0, 1);
      const height = Math.max(window.innerHeight || 0, 1);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height, false);
    }

    function animate() {
      if (disposed) return;
      requestAnimationFrame(animate);
      updateCamera();
      renderer.render(scene, camera);
    }

    async function toggleFullscreen(forceValue = null) {
      try {
        const shouldEnter = forceValue == null
          ? !document.fullscreenElement
          : !!forceValue;
        if (shouldEnter) {
          await playerShell.requestFullscreen();
        } else if (document.fullscreenElement) {
          await document.exitFullscreen();
        }
      } catch (_) {}
      emitState();
    }

    function bindUi() {
      playerShell.addEventListener('mousemove', () => showControls());
      playerShell.addEventListener('mouseenter', () => {
        playerShell.focus();
        showControls(true);
      });
      playerShell.addEventListener('mouseleave', () => {
        if (!videoElement || videoElement.paused) return;
        if (settingsPanel.classList.contains('visible') ||
            otherPanel.classList.contains('visible')) {
          return;
        }
        controlsRoot.classList.remove('visible');
      });
      playerShell.addEventListener('pointerdown', () => {
        playerShell.focus();
        showControls(true);
      });
      playToggle.addEventListener('click', () => {
        if (!videoElement) return;
        if (videoElement.paused) {
          safePlay();
        } else {
          safePause();
        }
        showControls(true);
      });
      progress.addEventListener('input', () => {
        seeking = true;
        if (!videoElement) return;
        const durationMs = Number.isFinite(videoElement.duration)
          ? Math.round(videoElement.duration * 1000)
          : 0;
        if (durationMs <= 0) return;
        const nextMs = (toFinite(progress.value, 0) / 1000) * durationMs;
        timeCurrent.textContent = formatTime(nextMs);
      });
      progress.addEventListener('change', () => {
        if (videoElement) {
          const durationMs = Number.isFinite(videoElement.duration)
            ? Math.round(videoElement.duration * 1000)
            : 0;
          if (durationMs > 0) {
            const nextMs = (toFinite(progress.value, 0) / 1000) * durationMs;
            safeSeek(nextMs / 1000);
          }
        }
        seeking = false;
        showControls(true);
      });
      volumeToggle.addEventListener('click', () => {
        controlsExpanded = !controlsExpanded;
        volumeShell.classList.toggle('expanded', controlsExpanded);
        showControls(true);
      });
      volume.addEventListener('input', () => {
        if (!videoElement) return;
        const nextVolume = clamp(toFinite(volume.value, 100) / 100, 0, 1);
        videoElement.muted = false;
        videoElement.volume = nextVolume;
        emitState();
      });
      settingsToggle.addEventListener('click', () => {
        const visible = settingsPanel.classList.toggle('visible');
        if (visible) {
          otherPanel.classList.remove('visible');
          showControls(true);
        }
      });
      fullscreenToggle.addEventListener('click', () => toggleFullscreen());
      loopToggle.addEventListener('change', () => {
        if (!videoElement) return;
        videoElement.loop = loopToggle.checked;
        emitState();
      });
      speedSelect.addEventListener('change', () => {
        if (!videoElement) return;
        videoElement.playbackRate = clamp(toFinite(speedSelect.value, 1), 0.25, 2);
        emitState();
      });
      qualitySelect.addEventListener('change', () => {
        viewerConfig.qualityTier = String(qualitySelect.value || 'auto');
        applyQualityTier();
        emitState();
      });
      otherToggle.addEventListener('click', () => {
        const visible = otherPanel.classList.toggle('visible');
        if (visible) {
          settingsPanel.classList.remove('visible');
          showControls(true);
        }
      });
      resetSettingsButton.addEventListener('click', () => {
        viewerConfig.loop = true;
        viewerConfig.playbackRate = 1;
        viewerConfig.qualityTier = 'auto';
        viewerConfig.muted = false;
        viewerConfig.volume = 1;
        applyViewerConfig(false);
      });
      closeOtherButton.addEventListener('click', () => otherPanel.classList.remove('visible'));
      document.addEventListener('fullscreenchange', () => {
        showControls(true);
        emitState();
      });
      playerShell.addEventListener('keydown', (event) => {
        const code = event.code || event.key;
        if (code === 'KeyF') {
          event.preventDefault();
          toggleFullscreen();
          return;
        }
        if (!videoElement) return;
        if (code === 'Space') {
          event.preventDefault();
          if (videoElement.paused) {
            safePlay();
          } else {
            safePause();
          }
          showControls(true);
          return;
        }
        if (code === 'ArrowLeft') {
          event.preventDefault();
          safeSeek((videoElement.currentTime || 0) - 5);
          showControls(true);
          return;
        }
        if (code === 'ArrowRight') {
          event.preventDefault();
          safeSeek((videoElement.currentTime || 0) + 5);
          showControls(true);
          return;
        }
        if (code === 'ArrowUp') {
          event.preventDefault();
          videoElement.muted = false;
          videoElement.volume = clamp((videoElement.volume || 0) + 0.05, 0, 1);
          emitState();
          showControls(true);
          return;
        }
        if (code === 'ArrowDown') {
          event.preventDefault();
          videoElement.muted = false;
          videoElement.volume = clamp((videoElement.volume || 0) - 0.05, 0, 1);
          emitState();
          showControls(true);
        }
      });
    }

    async function init() {
      scene = new THREE.Scene();
      camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1100);
      renderer = new THREE.WebGLRenderer({
        antialias: true,
        alpha: CLEAN_VIEW,
      });
      renderer.setClearColor(0x000000, CLEAN_VIEW ? 0 : 1);
      const host = document.getElementById('host');
      host.appendChild(renderer.domElement);

      const geometry = new THREE.SphereGeometry(100, 64, 40);
      geometry.scale(-1, 1, 1);
      const material = new THREE.MeshBasicMaterial({ color: 0xffffff });
      sphere = new THREE.Mesh(geometry, material);
      scene.add(sphere);

      bindUi();
      applyQualityTier();
      resize();
      window.addEventListener('resize', resize);
      if (stateInterval) {
        window.clearInterval(stateInterval);
      }
      stateInterval = window.setInterval(() => emitState(), 250);
      emit({ type: 'viewer360_ready' });
      animate();
      emitState();
    }

    function applyCommand(command, value) {
      if (command === 'play') {
        safePlay();
        return;
      }
      if (command === 'pause') {
        safePause();
        return;
      }
      if (command === 'toggle_play') {
        if (!videoElement) return;
        if (videoElement.paused) {
          safePlay();
        } else {
          safePause();
        }
        return;
      }
      if (command === 'seek') {
        if (!videoElement) return;
        safeSeek(toFinite(value, 0) / 1000);
        return;
      }
      if (command === 'seek_by') {
        if (!videoElement) return;
        safeSeek((videoElement.currentTime || 0) + (toFinite(value, 0) / 1000));
        return;
      }
      if (command === 'set_volume') {
        if (!videoElement) return;
        videoElement.muted = false;
        videoElement.volume = clamp(toFinite(value, videoElement.volume || 1), 0, 1);
        emitState();
        return;
      }
      if (command === 'adjust_volume') {
        if (!videoElement) return;
        videoElement.muted = false;
        videoElement.volume = clamp((videoElement.volume || 0) + toFinite(value, 0), 0, 1);
        emitState();
        return;
      }
      if (command === 'set_muted') {
        if (!videoElement) return;
        videoElement.muted = value === true;
        emitState();
        return;
      }
      if (command === 'toggle_muted') {
        if (!videoElement) return;
        videoElement.muted = !videoElement.muted;
        emitState();
        return;
      }
      if (command === 'set_loop') {
        if (!videoElement) return;
        videoElement.loop = value === true;
        emitState();
        return;
      }
      if (command === 'set_rate') {
        if (!videoElement) return;
        videoElement.playbackRate = clamp(toFinite(value, 1), 0.25, 2);
        emitState();
        return;
      }
      if (command === 'set_quality') {
        viewerConfig.qualityTier = String(value || 'auto').toLowerCase();
        applyQualityTier();
        emitState();
        return;
      }
      if (command === 'toggle_fullscreen') {
        toggleFullscreen();
        return;
      }
      if (command === 'set_fullscreen') {
        toggleFullscreen(value === true);
        return;
      }
      if (command === 'reset_settings') {
        viewerConfig.loop = true;
        viewerConfig.playbackRate = 1;
        viewerConfig.qualityTier = 'auto';
        viewerConfig.muted = false;
        viewerConfig.volume = 1;
        applyViewerConfig(false);
        return;
      }
      if (command === 'request_status') {
        emitState();
      }
    }

    window.addEventListener('message', async (event) => {
      try {
        let data = event.data;
        if (typeof data === 'string') {
          data = JSON.parse(data);
        }
        if (!data || typeof data !== 'object') return;
        if (data.channel && data.channel !== BRIDGE_CHANNEL) return;

        if (data.type === 'dispose') {
          disposed = true;
          if (stateInterval) {
            window.clearInterval(stateInterval);
          }
          hidePanels();
          disposeMedia();
          try { renderer.dispose(); } catch (_) {}
          return;
        }
        if (data.type === 'apply_payload') {
          payload = (data.payload && typeof data.payload === 'object')
            ? data.payload
            : payload;
          await applyMedia();
          return;
        }
        if (data.type === 'apply_config') {
          viewerConfig = {
            ...viewerConfig,
            ...(data.config && typeof data.config === 'object' ? data.config : {}),
          };
          applyViewerConfig(true);
          return;
        }
        if (data.type === 'viewer360_command') {
          applyCommand(String(data.command || ''), data.value);
          return;
        }
        if (data.type === 'tracking_patch' && data.head) {
          const next = data.head;
          headPose = {
            x: toFinite(next.x, headPose.x),
            y: toFinite(next.y, headPose.y),
            z: toFinite(next.z, headPose.z),
            yaw: toFinite(next.yaw, headPose.yaw),
            pitch: toFinite(next.pitch, headPose.pitch),
          };
          return;
        }
        if (data.type === 'reanchor') {
          anchorPose = { ...headPose };
        }
      } catch (_) {}
    });

    init();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
