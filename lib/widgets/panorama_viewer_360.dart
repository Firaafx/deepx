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
    _bootstrap();
    _syncTrackingListener(forcePush: false);
  }

  @override
  void didUpdateWidget(covariant PanoramaViewer360 oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool externalPayloadChanged = !const DeepCollectionEquality().equals(
      widget.initialPresetPayload,
      oldWidget.initialPresetPayload,
    );
    if (externalPayloadChanged) {
      _postPayload();
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
    _messageSubscription?.cancel();
    super.dispose();
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
      if (messageData['type']?.toString() == 'viewer360_ready') {
        _iframeReady = true;
        _postPayload();
        _pushCurrentTrackingFrame();
      }
    });
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

  String _buildSrcdoc() {
    final String bodyBackground = widget.cleanView ? 'transparent' : '#000';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: $bodyBackground;
    }
    #host {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
    }
    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="host"></div>
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
    let headPose = { x: 0, y: 0, z: 0.2, yaw: 0, pitch: 0 };
    let anchorPose = { ...headPose };

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
    }

    async function applyMedia() {
      disposeMedia();
      if (!sphere || !sphere.material) return;
      const scenePayload = (payload && payload.scene && typeof payload.scene === 'object')
        ? payload.scene
        : {};
      const assetUrl = String(scenePayload.assetUrl || '').trim();
      const assetKind = String(scenePayload.assetKind || 'image').trim().toLowerCase();
      if (!assetUrl) return;

      if (assetKind === 'video') {
        const video = document.createElement('video');
        video.src = assetUrl;
        video.preload = 'auto';
        video.loop = true;
        video.muted = true;
        video.autoplay = true;
        video.playsInline = true;
        video.crossOrigin = 'anonymous';
        try { await video.play(); } catch (_) {}
        videoElement = video;
        activeTexture = new THREE.VideoTexture(video);
      } else {
        const loader = new THREE.TextureLoader();
        loader.crossOrigin = 'anonymous';
        activeTexture = await loader.loadAsync(assetUrl);
      }

      activeTexture.colorSpace = THREE.SRGBColorSpace;
      activeTexture.minFilter = THREE.LinearFilter;
      activeTexture.magFilter = THREE.LinearFilter;
      sphere.material.map = activeTexture;
      sphere.material.needsUpdate = true;
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
        yawDegrees =
          (headPose.yaw - anchorPose.yaw) + (deltaX * 42 * yawSensitivity);
        pitchDegrees =
          (headPose.pitch - anchorPose.pitch) - (deltaY * 30 * pitchSensitivity);
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

    async function init() {
      scene = new THREE.Scene();
      camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1100);
      renderer = new THREE.WebGLRenderer({
        antialias: true,
        alpha: CLEAN_VIEW,
      });
      renderer.setPixelRatio(window.devicePixelRatio || 1);
      renderer.setClearColor(0x000000, CLEAN_VIEW ? 0 : 1);
      const host = document.getElementById('host');
      host.appendChild(renderer.domElement);

      const geometry = new THREE.SphereGeometry(100, 64, 40);
      geometry.scale(-1, 1, 1);
      const material = new THREE.MeshBasicMaterial({ color: 0xffffff });
      sphere = new THREE.Mesh(geometry, material);
      scene.add(sphere);

      resize();
      window.addEventListener('resize', resize);
      emit({ type: 'viewer360_ready' });
      animate();
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
