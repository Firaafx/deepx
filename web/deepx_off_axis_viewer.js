(function () {
  const viewers = new Map();
  let modulePromise = null;
  let mediaPipePromise = null;
  const loadingMessages = new WeakMap();

  const DEFAULT_TRANSFORM = Object.freeze({
    position: Object.freeze([0, -0.09, -0.03]),
    scale: 0.071,
    rotation: Object.freeze([0, -0.628, 0])
  });

  const DEFAULT_CALIBRATION = Object.freeze({
    screenWidthCm: 34,
    screenHeightCm: 19,
    viewingDistanceCm: 60,
    pixelWidth: 1920,
    pixelHeight: 1080,
    isCalibrated: false
  });

  const CALIBRATION_STORAGE_KEY = 'parallax_calibration_v1';

  injectStyles();
  installLifecycleHandlers();

  function injectStyles() {
    if (document.getElementById('deepx-off-axis-style')) return;
    const style = document.createElement('style');
    style.id = 'deepx-off-axis-style';
    style.textContent = `
      .dx-off-axis-root {
        position: relative;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #000;
        color: #fff;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        touch-action: none;
      }
      .dx-off-axis-root canvas.dx-render-canvas {
        width: 100%;
        height: 100%;
        display: block;
        touch-action: none;
      }
      .dx-viewer-button {
        width: 30px;
        height: 30px;
        border: 0;
        border-radius: 4px;
        background: rgba(0,0,0,0.5);
        color: #fff;
        display: grid;
        place-items: center;
        cursor: pointer;
        font: 700 11px/1 system-ui, sans-serif;
        backdrop-filter: blur(6px);
        transition: background 140ms ease, opacity 140ms ease;
      }
      .dx-viewer-button:hover { background: rgba(0,0,0,0.72); }
      .dx-viewer-button.is-active { background: #2563eb; }
      .dx-viewer-button:disabled {
        cursor: default;
        opacity: 0.4;
      }
      .dx-model-panel {
        position: absolute;
        top: 16px;
        left: 16px;
        z-index: 20;
        pointer-events: auto;
      }
      .dx-model-controls {
        width: min(320px, calc(100vw - 32px));
        border-radius: 8px;
        background: rgba(0,0,0,0.70);
        color: #fff;
        box-shadow: 0 16px 36px rgba(0,0,0,0.35);
        backdrop-filter: blur(8px);
      }
      .dx-model-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 14px 16px 6px;
      }
      .dx-model-body {
        display: grid;
        gap: 12px;
        padding: 8px 16px 16px;
      }
      .dx-control {
        display: grid;
        gap: 5px;
      }
      .dx-control + .dx-control-group {
        border-top: 1px solid rgba(255,255,255,0.22);
      }
      .dx-control label {
        display: block;
        font-size: 12px;
        line-height: 1.2;
        color: #fff;
      }
      .dx-control input[type=range] {
        width: 100%;
        height: 4px;
        accent-color: #fff;
        cursor: pointer;
      }
      .dx-control-group {
        display: grid;
        gap: 12px;
        padding-top: 10px;
        border-top: 1px solid rgba(255,255,255,0.22);
      }
      .dx-bottom-buttons {
        position: absolute;
        left: 16px;
        bottom: 16px;
        z-index: 16;
        display: flex;
        flex-direction: column;
        gap: 8px;
        pointer-events: auto;
      }
      .dx-camera-preview {
        position: absolute;
        right: 16px;
        bottom: 16px;
        z-index: 14;
        width: 256px;
        height: 192px;
        border: 2px solid #fff;
        border-radius: 8px;
        overflow: hidden;
        background: #000;
        box-shadow: 0 16px 36px rgba(0,0,0,0.42);
        pointer-events: none;
        display: none;
      }
      .dx-camera-preview video,
      .dx-camera-preview canvas {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
      .dx-camera-preview video { transform: scaleX(-1); }
      .dx-loading-message {
        height: 100%;
        display: grid;
        place-items: center;
        color: #fff;
        text-align: center;
        padding: 16px;
        box-sizing: border-box;
        font: 700 14px system-ui, sans-serif;
        background: #050505;
      }
      .dx-calibration-modal {
        position: absolute;
        inset: 0;
        z-index: 40;
        display: grid;
        place-items: center;
        background: rgba(0,0,0,0.62);
        padding: 18px;
        box-sizing: border-box;
      }
      .dx-calibration-card {
        width: min(420px, 100%);
        border-radius: 8px;
        background: rgba(17,24,39,0.96);
        border: 1px solid rgba(255,255,255,0.14);
        box-shadow: 0 24px 60px rgba(0,0,0,0.45);
        padding: 18px;
        box-sizing: border-box;
      }
      .dx-calibration-card h3 {
        margin: 0 0 12px;
        font-size: 18px;
      }
      .dx-calibration-card label {
        display: grid;
        gap: 5px;
        margin: 10px 0;
        font-size: 12px;
        color: rgba(255,255,255,0.78);
      }
      .dx-calibration-card input {
        border: 1px solid rgba(255,255,255,0.18);
        border-radius: 6px;
        background: rgba(255,255,255,0.08);
        color: #fff;
        padding: 8px;
        font: 600 13px system-ui, sans-serif;
      }
      .dx-calibration-actions {
        display: flex;
        justify-content: flex-end;
        gap: 8px;
        margin-top: 14px;
      }
      .dx-calibration-actions button {
        border: 0;
        border-radius: 6px;
        padding: 8px 12px;
        font: 700 13px system-ui, sans-serif;
        cursor: pointer;
      }
      .dx-calibration-actions .secondary {
        background: rgba(255,255,255,0.12);
        color: #fff;
      }
      .dx-calibration-actions .primary {
        background: #fff;
        color: #111827;
      }
    `;
    document.head.appendChild(style);
  }

  function installLifecycleHandlers() {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        faceTracker.stop('hidden');
        for (const ctx of viewers.values()) ctx.pauseRender();
        return;
      }
      for (const ctx of viewers.values()) {
        ctx.resumeRender();
        ctx.ensureTracking();
        ctx.resize();
      }
    });
    window.addEventListener('pagehide', () => faceTracker.stop('pagehide'));
    window.addEventListener('beforeunload', () => faceTracker.stop('beforeunload'));
  }

  function loadModules() {
    if (!modulePromise) {
      modulePromise = Promise.all([
        import('https://esm.sh/three@0.180.0'),
        import('https://esm.sh/three@0.180.0/examples/jsm/loaders/GLTFLoader.js'),
        import('https://esm.sh/three@0.180.0/examples/jsm/loaders/DRACOLoader.js'),
        import('https://esm.sh/@sparkjsdev/spark@2.1.0?deps=three@0.180.0').catch(() => null)
      ]).then(([three, gltf, draco, spark]) => ({
        THREE: three,
        GLTFLoader: gltf.GLTFLoader,
        DRACOLoader: draco.DRACOLoader,
        spark
      }));
    }
    return modulePromise;
  }

  function loadScriptOnce(src, globalName) {
    if (globalName && window[globalName]) return Promise.resolve();
    const existing = document.querySelector(`script[data-deepx-src="${src}"]`);
    if (existing && existing.__deepxPromise) return existing.__deepxPromise;
    const script = existing || document.createElement('script');
    script.setAttribute('data-deepx-src', src);
    script.crossOrigin = 'anonymous';
    script.src = src;
    script.__deepxPromise = new Promise((resolve, reject) => {
      script.addEventListener('load', () => resolve(), { once: true });
      script.addEventListener('error', () => reject(new Error(`Unable to load ${src}`)), { once: true });
    });
    if (!existing) document.head.appendChild(script);
    return script.__deepxPromise;
  }

  function loadMediaPipe() {
    if (!mediaPipePromise) {
      mediaPipePromise = Promise.all([
        loadScriptOnce('https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/face_mesh.js', 'FaceMesh'),
        loadScriptOnce('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js', 'drawConnectors')
      ]).then(() => {
        if (!window.FaceMesh) throw new Error('MediaPipe FaceMesh is not available.');
      });
    }
    return mediaPipePromise;
  }

  function parseJson(value) {
    if (!value) return {};
    if (typeof value === 'object') return value;
    try {
      const decoded = JSON.parse(String(value));
      return decoded && typeof decoded === 'object' ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function normalizeType(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (['splat', 'ksplat', 'ply', '3dgs'].includes(raw)) return 'gaussian_splat';
    if (['mesh', 'model', 'glb', 'gltf'].includes(raw)) return 'triangle_mesh';
    if (['missing_3d', 'missing3d', 'missing', 'no_3d'].includes(raw)) return 'missing_3d';
    return raw || 'image';
  }

  function payloadAsset(payload) {
    const media = payload && typeof payload.media === 'object' ? payload.media : payload;
    return {
      type: normalizeType(media.type || payload.media_type || payload.mediaType || 'image'),
      url: String(media.url || media.assetUrl || ''),
      path: String(media.path || media.assetPath || ''),
      format: String(media.format || '').trim().toLowerCase()
    };
  }

  function supportedMesh(asset) {
    return asset.type === 'triangle_mesh' || ['glb', 'gltf'].includes(asset.format);
  }

  function supportedSplat(asset) {
    return asset.type === 'gaussian_splat' || ['ply', 'splat', 'ksplat'].includes(asset.format);
  }

  function missingLabel(asset) {
    if (supportedMesh(asset)) return 'No 3D mesh';
    if (supportedSplat(asset)) return 'No 3DGS';
    return 'No 3D';
  }

  function assetLooksLike(asset, extension) {
    const format = String(asset.format || '').toLowerCase();
    const url = String(asset.url || '').split('?')[0].toLowerCase();
    return format === extension || url.endsWith(`.${extension}`);
  }

  function numberList(value, fallback) {
    if (!Array.isArray(value) || value.length < 3) return fallback.slice();
    return [
      Number.isFinite(Number(value[0])) ? Number(value[0]) : fallback[0],
      Number.isFinite(Number(value[1])) ? Number(value[1]) : fallback[1],
      Number.isFinite(Number(value[2])) ? Number(value[2]) : fallback[2]
    ];
  }

  function transformFromPayload(payload) {
    const raw = payload && typeof payload.transform === 'object' ? payload.transform : {};
    return {
      position: numberList(raw.position, DEFAULT_TRANSFORM.position),
      scale: clamp(Number.isFinite(Number(raw.scale)) ? Number(raw.scale) : DEFAULT_TRANSFORM.scale, 0.001, 100),
      rotation: numberList(raw.rotation, DEFAULT_TRANSFORM.rotation)
    };
  }

  function transformSnapshot(transform) {
    return {
      position: transform.position.map((value) => Number(Number(value).toFixed(5))),
      scale: Number(Number(transform.scale).toFixed(5)),
      rotation: transform.rotation.map((value) => Number(Number(value).toFixed(5)))
    };
  }

  function transformKey(transform) {
    return JSON.stringify(transformSnapshot(transform));
  }

  function payloadKey(payload) {
    const asset = payloadAsset(payload);
    return [asset.type, asset.url, asset.path, asset.format].join('|');
  }

  function setMessage(root, text) {
    root.innerHTML = '';
    root.classList.add('dx-off-axis-root');
    const node = document.createElement('div');
    node.className = 'dx-loading-message';
    node.textContent = text;
    root.appendChild(node);
    loadingMessages.set(root, node);
  }

  function setRootLoadingMessage(root, label, progress) {
    const node = loadingMessages.get(root);
    if (!node) return;
    node.textContent = Number.isFinite(progress)
      ? `${label} ${Math.round(clamp(progress, 0, 1) * 100)}%`
      : label;
  }

  function notifyLoadState(elementId, status, progress, label) {
    const safeProgress = Number.isFinite(Number(progress))
      ? clamp(Number(progress), 0, 1)
      : null;
    try {
      window.postMessage(JSON.stringify({
        type: 'deepx-off-axis-load-state',
        elementId,
        status,
        progress: safeProgress,
        label: String(label || '')
      }), window.location.origin);
    } catch (_) {}
  }

  function notifyTransformChanged(ctx, force) {
    if (!ctx || (!ctx.editable && !force)) return;
    try {
      window.postMessage(JSON.stringify({
        type: 'deepx-off-axis-transform-changed',
        elementId: ctx.elementId,
        transform: transformSnapshot(ctx.transform)
      }), window.location.origin);
    } catch (_) {}
  }

  function getCalibration() {
    try {
      const stored = localStorage.getItem(CALIBRATION_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        return { ...DEFAULT_CALIBRATION, ...parsed };
      }
    } catch (_) {}
    return { ...DEFAULT_CALIBRATION };
  }

  function saveCalibration(data) {
    const next = { ...getCalibration(), ...data, isCalibrated: true };
    try {
      localStorage.setItem(CALIBRATION_STORAGE_KEY, JSON.stringify(next));
    } catch (_) {}
    return next;
  }

  class HeadPoseTracker {
    constructor(smoothingFactor) {
      this.smoothingFactor = clamp(Number(smoothingFactor) || 0.3, 0.1, 0.9);
      this.baseInterOcularDistance = 0.1;
      this.smoothedPose = { x: 0.5, y: 0.5, z: 1 };
    }

    extractHeadPoseFromLandmarks(landmarks) {
      if (!landmarks || landmarks.length === 0) return null;
      const firstFace = landmarks[0];
      if (!firstFace || firstFace.length < 468) return null;

      const leftEyeInner = firstFace[133];
      const rightEyeInner = firstFace[362];
      const noseTip = firstFace[1];
      const leftEyeOuter = firstFace[33];
      const rightEyeOuter = firstFace[263];
      if (!leftEyeInner || !rightEyeInner || !noseTip || !leftEyeOuter || !rightEyeOuter) {
        return null;
      }

      const faceX = (leftEyeInner.x + rightEyeInner.x + noseTip.x) / 3;
      const faceY = (leftEyeInner.y + rightEyeInner.y + noseTip.y) / 3;
      const interOcularDist = Math.hypot(
        rightEyeInner.x - leftEyeInner.x,
        rightEyeInner.y - leftEyeInner.y
      );
      const eyeWidth = Math.hypot(
        rightEyeOuter.x - leftEyeOuter.x,
        rightEyeOuter.y - leftEyeOuter.y
      );
      const depthProxy = (interOcularDist + eyeWidth * 0.5) / (this.baseInterOcularDistance * 1.5);
      const clamped = {
        x: clamp(faceX, 0.2, 0.8),
        y: clamp(faceY, 0.2, 0.8),
        z: clamp(depthProxy, 0.5, 2)
      };
      this.smoothedPose.x += this.smoothingFactor * (clamped.x - this.smoothedPose.x);
      this.smoothedPose.y += this.smoothingFactor * (clamped.y - this.smoothedPose.y);
      this.smoothedPose.z += this.smoothingFactor * (clamped.z - this.smoothedPose.z);
      return { ...this.smoothedPose };
    }

    reset() {
      this.smoothedPose = { x: 0.5, y: 0.5, z: 1 };
    }
  }

  class OffAxisCamera {
    constructor(THREE, camera, calibration) {
      this.THREE = THREE;
      this.camera = camera;
      this.nearPlane = 0.05;
      this.farPlane = 1000;
      this.updateCalibration(calibration);
    }

    updateCalibration(calibration) {
      this.calibration = { ...DEFAULT_CALIBRATION, ...calibration };
      const worldScale = 0.01;
      this.screenWidthWorld = this.calibration.screenWidthCm * worldScale;
      this.screenHeightWorld = this.calibration.screenHeightCm * worldScale;
    }

    headPoseToWorldPosition(headPose) {
      const worldScale = 0.01;
      const movementScale = 1.5;
      const normalizedX = headPose ? headPose.x : 0.5;
      const normalizedY = headPose ? headPose.y : 0.5;
      const normalizedZ = headPose ? headPose.z : 1;
      return {
        x: -(normalizedX - 0.5) * this.screenWidthWorld * movementScale,
        y: -(normalizedY - 0.5) * this.screenHeightWorld * movementScale,
        z: this.calibration.viewingDistanceCm * worldScale * (1 / normalizedZ)
      };
    }

    updateProjectionMatrix(headPosition) {
      const near = this.nearPlane;
      const far = this.farPlane;
      const screenLeft = -this.screenWidthWorld / 2;
      const screenRight = this.screenWidthWorld / 2;
      const screenBottom = -this.screenHeightWorld / 2;
      const screenTop = this.screenHeightWorld / 2;
      const eyeX = headPosition.x;
      const eyeY = headPosition.y;
      const eyeZ = headPosition.z;
      const viewerToScreenDistance = eyeZ;
      if (viewerToScreenDistance <= 0) return;
      const nOverD = near / viewerToScreenDistance;
      const left = (screenLeft - eyeX) * nOverD;
      const right = (screenRight - eyeX) * nOverD;
      const bottom = (screenBottom - eyeY) * nOverD;
      const top = (screenTop - eyeY) * nOverD;
      this.camera.projectionMatrix.makePerspective(left, right, top, bottom, near, far);
      this.camera.projectionMatrixInverse.copy(this.camera.projectionMatrix).invert();
    }

    setCameraPosition(headPosition) {
      this.camera.position.set(headPosition.x, headPosition.y, headPosition.z);
      this.camera.lookAt(headPosition.x, headPosition.y, 0);
    }

    updateFromHeadPose(headPose) {
      const worldPosition = this.headPoseToWorldPosition(headPose || { x: 0.5, y: 0.5, z: 1 });
      this.setCameraPosition(worldPosition);
      this.updateProjectionMatrix(worldPosition);
    }

    getScreenDimensions() {
      return {
        width: this.screenWidthWorld,
        height: this.screenHeightWorld
      };
    }
  }

  const faceTracker = {
    stream: null,
    video: null,
    faceMesh: null,
    raf: 0,
    running: false,
    sending: false,
    lastPose: { x: 0.5, y: 0.5, z: 1 },
    poseTracker: new HeadPoseTracker(0.3),

    async ensure() {
      if (document.hidden) return;
      if (![...viewers.values()].some((ctx) => ctx.trackingEnabled && !ctx.disposed)) {
        await this.stop('no-viewers');
        return;
      }
      if (this.running) return;
      await loadMediaPipe();
      this.video = this.video || document.createElement('video');
      this.video.autoplay = true;
      this.video.muted = true;
      this.video.playsInline = true;
      this.video.width = 640;
      this.video.height = 480;
      this.video.style.cssText = 'position:fixed;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;pointer-events:none;';
      if (!this.video.parentNode) document.body.appendChild(this.video);

      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          width: 640,
          height: 480,
          facingMode: 'user'
        }
      });
      this.video.srcObject = this.stream;
      await this.video.play();

      this.faceMesh = new window.FaceMesh({
        locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`
      });
      this.faceMesh.setOptions({
        maxNumFaces: 1,
        refineLandmarks: true,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5
      });
      this.faceMesh.onResults((results) => this.handleResults(results));
      this.running = true;
      this.loop();
      this.syncPreviewStreams();
    },

    syncPreviewStreams() {
      for (const ctx of viewers.values()) {
        if (ctx.previewVideo) {
          ctx.previewVideo.srcObject = this.stream || null;
          if (this.stream && ctx.previewVisible) {
            ctx.previewVideo.play().catch(() => {});
          }
        }
      }
    },

    loop() {
      if (!this.running) return;
      this.raf = requestAnimationFrame(() => this.loop());
      if (!this.faceMesh || !this.video || this.video.readyState < 2 || this.sending) return;
      this.sending = true;
      this.faceMesh.send({ image: this.video })
        .catch((error) => console.warn('MediaPipe frame failed:', error))
        .finally(() => {
          this.sending = false;
        });
    },

    handleResults(results) {
      const landmarks = results && results.multiFaceLandmarks ? results.multiFaceLandmarks : [];
      const pose = this.poseTracker.extractHeadPoseFromLandmarks(landmarks);
      this.lastPose = pose || this.lastPose || { x: 0.5, y: 0.5, z: 1 };
      for (const ctx of viewers.values()) {
        if (ctx.trackingEnabled && !ctx.disposed) ctx.headPose = this.lastPose;
        if (ctx.previewVisible) ctx.drawPreview(results);
      }
    },

    async stop(reason) {
      this.running = false;
      if (this.raf) {
        cancelAnimationFrame(this.raf);
        this.raf = 0;
      }
      if (this.faceMesh) {
        try { await this.faceMesh.close(); } catch (_) {}
        this.faceMesh = null;
      }
      if (this.video) {
        try { this.video.pause(); } catch (_) {}
        this.video.srcObject = null;
      }
      if (this.stream) {
        for (const track of this.stream.getTracks()) track.stop();
        this.stream = null;
      }
      this.sending = false;
      this.poseTracker.reset();
      this.syncPreviewStreams();
      for (const ctx of viewers.values()) ctx.clearPreview();
      if (reason && reason !== 'no-viewers') {
        for (const ctx of viewers.values()) {
          if (ctx.trackingEnabled) ctx.headPose = { x: 0.5, y: 0.5, z: 1 };
        }
      }
    }
  };

  class ViewerContext {
    constructor(elementId, root, payload, options, modules) {
      this.elementId = elementId;
      this.root = root;
      this.payload = payload;
      this.options = options;
      this.modules = modules;
      this.THREE = modules.THREE;
      this.asset = payloadAsset(payload);
      this.transform = transformFromPayload(payload);
      this.initialTransform = transformFromPayload(payload);
      this.editable = options.editable === true;
      this.showModelControls = options.showModelControls === true;
      this.trackingEnabled = options.trackingEnabled === true;
      this.previewVisible = false;
      this.gridVisible = false;
      this.debugMode = false;
      this.headPose = { x: 0.5, y: 0.5, z: 1 };
      this.objectUrls = [];
      this.cleanup = [];
      this.debugHelpers = [];
      this.roomObjects = [];
      this.disposed = false;
      this.raf = 0;
      this.resizeObserver = null;
      this.rendering = false;
    }

    async initialize() {
      this.root.innerHTML = '';
      loadingMessages.delete(this.root);
      this.root.classList.add('dx-off-axis-root');
      this.root.style.pointerEvents = 'auto';
      this.root.style.touchAction = 'none';

      this.scene = new this.THREE.Scene();
      this.scene.background = new this.THREE.Color(0x1a1a1a);
      this.camera = new this.THREE.PerspectiveCamera(75, 1, 0.05, 1000);
      this.camera.position.z = 5;
      const calibration = {
        ...getCalibration(),
        pixelWidth: Math.max(1, this.root.clientWidth),
        pixelHeight: Math.max(1, this.root.clientHeight)
      };
      this.offAxisCamera = new OffAxisCamera(this.THREE, this.camera, calibration);
      this.renderer = new this.THREE.WebGLRenderer({ antialias: true, alpha: false });
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      this.renderer.setSize(Math.max(1, this.root.clientWidth), Math.max(1, this.root.clientHeight), false);
      this.renderer.outputColorSpace = this.THREE.SRGBColorSpace;
      this.renderer.domElement.className = 'dx-render-canvas';
      this.root.appendChild(this.renderer.domElement);

      if (this.modules.spark && this.modules.spark.SparkRenderer) {
        this.scene.add(new this.modules.spark.SparkRenderer({ renderer: this.renderer }));
      }
      this.addLights();
      this.createWireframeRoom();
      this.createDebugHelpers();
      this.buildChrome();
      this.installContextLossHandler();
      this.object = supportedMesh(this.asset)
        ? await this.addTriangleMesh()
        : await this.addGaussianSplat();
      this.applyTransform();
      this.resize();
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(this.root);
      this.resumeRender();
      this.ensureTracking();
      notifyTransformChanged(this, true);
      notifyLoadState(this.elementId, 'ready', 1, '3D asset ready');
    }

    addLights() {
      this.scene.add(new this.THREE.AmbientLight(0xffffff, 0.5));
      const lightOne = new this.THREE.DirectionalLight(0xffffff, 0.8);
      lightOne.position.set(1, 1, 1);
      this.scene.add(lightOne);
      const lightTwo = new this.THREE.DirectionalLight(0xffffff, 0.5);
      lightTwo.position.set(-1, -1, 0.5);
      this.scene.add(lightTwo);
    }

    installContextLossHandler() {
      const onContextLost = (event) => {
        event.preventDefault();
        console.warn('Off-axis viewer WebGL context lost.');
      };
      this.renderer.domElement.addEventListener('webglcontextlost', onContextLost, false);
      this.cleanup.push(() => this.renderer.domElement.removeEventListener('webglcontextlost', onContextLost));
    }

    async fetchObjectUrl(url, label) {
      this.updateLoading(label);
      const response = await fetch(url, { cache: 'no-store' });
      if (!response.ok) throw new Error(`Unable to load 3D asset (${response.status}).`);
      const type = response.headers.get('content-type') || 'application/octet-stream';
      const total = Number(response.headers.get('content-length'));
      if (!response.body || !Number.isFinite(total) || total <= 0) {
        const blob = await response.blob();
        if (this.disposed) throw new Error('3D viewer was disposed while loading.');
        const objectUrl = URL.createObjectURL(blob);
        this.objectUrls.push(objectUrl);
        return objectUrl;
      }
      const reader = response.body.getReader();
      const chunks = [];
      let loaded = 0;
      let lastProgressAt = 0;
      for (;;) {
        if (this.disposed) throw new Error('3D viewer was disposed while loading.');
        const result = await reader.read();
        if (result.done) break;
        chunks.push(result.value);
        loaded += result.value.byteLength;
        const now = performance.now();
        if (now - lastProgressAt > 80 || loaded >= total) {
          lastProgressAt = now;
          this.updateLoading(label, loaded / total);
        }
      }
      const blob = new Blob(chunks, { type });
      const objectUrl = URL.createObjectURL(blob);
      this.objectUrls.push(objectUrl);
      this.updateLoading(label, 1);
      return objectUrl;
    }

    updateLoading(label, progress) {
      if (this.disposed) return;
      notifyLoadState(this.elementId, 'loading', progress, label);
      setRootLoadingMessage(this.root, label, progress);
    }

    async addTriangleMesh() {
      const loader = new this.modules.GLTFLoader();
      if (this.modules.DRACOLoader) {
        const dracoLoader = new this.modules.DRACOLoader();
        dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.6/');
        dracoLoader.setDecoderConfig({ type: 'js' });
        loader.setDRACOLoader(dracoLoader);
        this.cleanup.push(() => dracoLoader.dispose());
      }
      let loadUrl = this.asset.url;
      if (assetLooksLike(this.asset, 'glb')) {
        loadUrl = await this.fetchObjectUrl(this.asset.url, 'Loading 3D mesh');
      } else {
        this.updateLoading('Loading 3D mesh');
      }
      const gltf = await loader.loadAsync(loadUrl, (event) => {
        if (event && Number.isFinite(event.total) && event.total > 0) {
          this.updateLoading('Loading 3D mesh', event.loaded / event.total);
        }
      });
      const object = gltf.scene;
      object.traverse((node) => {
        if (node.isMesh) {
          node.castShadow = true;
          node.receiveShadow = true;
        }
      });
      this.scene.add(object);
      return object;
    }

    async addGaussianSplat() {
      const spark = this.modules.spark;
      if (!spark) throw new Error('Spark module failed to load.');
      const Candidate =
        spark.SplatMesh || spark.SparkSplatMesh || spark.GaussianSplatMesh || spark.SplatObject;
      if (!Candidate) throw new Error('Spark loaded, but no supported splat mesh export was found.');
      const loadUrl = await this.fetchObjectUrl(this.asset.url, 'Loading 3D asset');
      let object;
      try {
        object = new Candidate({ url: loadUrl, fileType: this.asset.format || undefined });
      } catch (_) {
        object = new Candidate(loadUrl);
      }
      this.scene.add(object);
      if (object && object.initialized && typeof object.initialized.then === 'function') {
        await object.initialized;
      }
      return object;
    }

    createWireframeRoom() {
      this.removeWireframeRoom();
      const screenDims = this.offAxisCamera.getScreenDimensions();
      const roomWidth = screenDims.width;
      const roomHeight = screenDims.height;
      const roomDepth = 0.35;
      const gridDivisions = 8;
      const wallMaterial = new this.THREE.LineBasicMaterial({
        color: 0xff8c00,
        transparent: true,
        opacity: 0.8,
        depthTest: true,
        depthWrite: true
      });
      const createGridWall = (width, height) => {
        const geometry = new this.THREE.BufferGeometry();
        const vertices = [];
        for (let i = 0; i <= gridDivisions; i++) {
          const t = i / gridDivisions;
          vertices.push(-width / 2 + t * width, -height / 2, 0);
          vertices.push(-width / 2 + t * width, height / 2, 0);
          vertices.push(-width / 2, -height / 2 + t * height, 0);
          vertices.push(width / 2, -height / 2 + t * height, 0);
        }
        geometry.setAttribute('position', new this.THREE.Float32BufferAttribute(vertices, 3));
        return new this.THREE.LineSegments(geometry, wallMaterial);
      };
      const backWall = createGridWall(roomWidth, roomHeight);
      backWall.position.z = -roomDepth;
      const leftWall = createGridWall(roomDepth, roomHeight);
      leftWall.rotation.y = Math.PI / 2;
      leftWall.position.x = -roomWidth / 2;
      leftWall.position.z = -roomDepth / 2;
      const rightWall = createGridWall(roomDepth, roomHeight);
      rightWall.rotation.y = -Math.PI / 2;
      rightWall.position.x = roomWidth / 2;
      rightWall.position.z = -roomDepth / 2;
      const floor = createGridWall(roomWidth, roomDepth);
      floor.rotation.x = Math.PI / 2;
      floor.position.y = -roomHeight / 2;
      floor.position.z = -roomDepth / 2;
      const ceiling = createGridWall(roomWidth, roomDepth);
      ceiling.rotation.x = -Math.PI / 2;
      ceiling.position.y = roomHeight / 2;
      ceiling.position.z = -roomDepth / 2;
      const screenFrame = new this.THREE.LineSegments(
        new this.THREE.EdgesGeometry(new this.THREE.PlaneGeometry(roomWidth, roomHeight)),
        new this.THREE.LineBasicMaterial({ color: 0xff0000, depthTest: true, depthWrite: true })
      );
      screenFrame.position.z = 0.001;
      this.roomObjects.push(backWall, leftWall, rightWall, floor, ceiling, screenFrame);
      for (const obj of this.roomObjects) {
        obj.visible = this.gridVisible;
        this.scene.add(obj);
      }
    }

    removeWireframeRoom() {
      for (const obj of this.roomObjects) {
        this.scene.remove(obj);
        if (obj.geometry) obj.geometry.dispose();
        if (obj.material && typeof obj.material.dispose === 'function') obj.material.dispose();
      }
      this.roomObjects = [];
    }

    createDebugHelpers() {
      const axes = new this.THREE.AxesHelper(0.1);
      axes.visible = false;
      const headMarker = new this.THREE.Mesh(
        new this.THREE.SphereGeometry(0.02, 8, 8),
        new this.THREE.MeshBasicMaterial({ color: 0xff00ff })
      );
      headMarker.visible = false;
      this.debugHelpers.push(axes, headMarker);
      this.scene.add(axes);
      this.scene.add(headMarker);
    }

    buildChrome() {
      this.preview = document.createElement('div');
      this.preview.className = 'dx-camera-preview';
      this.previewVideo = document.createElement('video');
      this.previewVideo.autoplay = true;
      this.previewVideo.muted = true;
      this.previewVideo.playsInline = true;
      this.previewCanvas = document.createElement('canvas');
      this.previewCanvas.width = 640;
      this.previewCanvas.height = 480;
      this.preview.appendChild(this.previewVideo);
      this.preview.appendChild(this.previewCanvas);
      this.root.appendChild(this.preview);

      if (this.showModelControls) this.buildModelControls();
      this.buildBottomButtons();
    }

    makeButton(label, title, onClick) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'dx-viewer-button';
      button.textContent = label;
      button.title = title;
      button.setAttribute('aria-label', title);
      button.addEventListener('click', onClick);
      return button;
    }

    buildModelControls() {
      this.modelPanel = document.createElement('div');
      this.modelPanel.className = 'dx-model-panel';
      const closedButton = this.makeButton('CTL', 'Model controls', () => {
        this.controlsOpen = true;
        this.refreshControlPanel();
      });
      this.modelPanel.appendChild(closedButton);
      this.root.appendChild(this.modelPanel);
    }

    refreshControlPanel() {
      if (!this.modelPanel) return;
      this.modelPanel.innerHTML = '';
      if (!this.controlsOpen) {
        this.modelPanel.appendChild(this.makeButton('CTL', 'Model controls', () => {
          this.controlsOpen = true;
          this.refreshControlPanel();
        }));
        return;
      }
      const panel = document.createElement('div');
      panel.className = 'dx-model-controls';
      const header = document.createElement('div');
      header.className = 'dx-model-header';
      header.appendChild(this.makeButton('CTL', 'Close controls', () => {
        this.controlsOpen = false;
        this.refreshControlPanel();
      }));
      panel.appendChild(header);
      const body = document.createElement('div');
      body.className = 'dx-model-body';
      body.appendChild(this.makeRange('Position X', this.transform.position[0], -1, 1, 0.01, (value) => this.setPositionAxis(0, value)));
      body.appendChild(this.makeRange('Position Y', this.transform.position[1], -1, 1, 0.01, (value) => this.setPositionAxis(1, value)));
      body.appendChild(this.makeRange('Position Z', this.transform.position[2], -2, 1, 0.01, (value) => this.setPositionAxis(2, value)));
      const scaleGroup = document.createElement('div');
      scaleGroup.className = 'dx-control-group';
      scaleGroup.appendChild(this.makeRange('Scale', this.transform.scale, 0.01, 0.3, 0.001, (value) => this.setScale(value)));
      body.appendChild(scaleGroup);
      const rotationGroup = document.createElement('div');
      rotationGroup.className = 'dx-control-group';
      rotationGroup.appendChild(this.makeRange('Rotation', this.transform.rotation[1], -Math.PI, Math.PI, 0.01, (value) => this.setRotationAxis(1, value), (value) => `${Math.round(value * 180 / Math.PI)}deg`));
      body.appendChild(rotationGroup);
      panel.appendChild(body);
      this.modelPanel.appendChild(panel);
    }

    makeRange(label, value, min, max, step, onInput, formatter) {
      const wrap = document.createElement('div');
      wrap.className = 'dx-control';
      const text = document.createElement('label');
      const renderValue = (next) => {
        const formatted = formatter ? formatter(next) : Number(next).toFixed(3);
        text.textContent = `${label}: ${formatted}`;
      };
      renderValue(value);
      const input = document.createElement('input');
      input.type = 'range';
      input.min = String(min);
      input.max = String(max);
      input.step = String(step);
      input.value = String(clamp(value, min, max));
      input.addEventListener('input', () => {
        const next = Number(input.value);
        renderValue(next);
        onInput(next);
      });
      wrap.appendChild(text);
      wrap.appendChild(input);
      return wrap;
    }

    buildBottomButtons() {
      const buttons = document.createElement('div');
      buttons.className = 'dx-bottom-buttons';
      const fullscreen = this.makeButton('FS', 'Enter fullscreen', () => this.toggleFullscreen());
      const settings = this.makeButton('CAL', 'Calibration settings', () => this.showCalibration());
      const debug = this.makeButton('DBG', 'Toggle debug mode', () => {
        this.setDebugMode(!this.debugMode);
        debug.classList.toggle('is-active', this.debugMode);
      });
      const grid = this.makeButton('GRID', 'Toggle grid', () => {
        this.setGridVisible(!this.gridVisible);
        grid.classList.toggle('is-active', this.gridVisible);
      });
      const preview = this.makeButton('CAM', 'Toggle camera preview', () => {
        this.setPreviewVisible(!this.previewVisible);
        preview.classList.toggle('is-active', this.previewVisible);
      });
      const reset = this.makeButton('RST', 'Reset model transform', () => this.resetTransform());
      buttons.append(fullscreen, settings, debug, grid, preview, reset);
      this.root.appendChild(buttons);
      document.addEventListener('fullscreenchange', () => {
        fullscreen.textContent = document.fullscreenElement ? 'MIN' : 'FS';
        fullscreen.title = document.fullscreenElement ? 'Exit fullscreen' : 'Enter fullscreen';
      });
    }

    async toggleFullscreen() {
      try {
        if (!document.fullscreenElement) {
          await this.root.requestFullscreen();
        } else {
          await document.exitFullscreen();
        }
      } catch (error) {
        console.warn('Fullscreen failed:', error);
      }
    }

    showCalibration() {
      if (this.calibrationModal) {
        this.calibrationModal.remove();
        this.calibrationModal = null;
      }
      const calibration = getCalibration();
      const modal = document.createElement('div');
      modal.className = 'dx-calibration-modal';
      const card = document.createElement('div');
      card.className = 'dx-calibration-card';
      const heading = document.createElement('h3');
      heading.textContent = 'Calibration';
      card.appendChild(heading);
      const inputs = {};
      for (const [key, label] of [
        ['screenWidthCm', 'Screen width cm'],
        ['screenHeightCm', 'Screen height cm'],
        ['viewingDistanceCm', 'Viewing distance cm']
      ]) {
        const wrap = document.createElement('label');
        wrap.textContent = label;
        const input = document.createElement('input');
        input.type = 'number';
        input.step = '0.1';
        input.value = String(calibration[key]);
        wrap.appendChild(input);
        card.appendChild(wrap);
        inputs[key] = input;
      }
      const actions = document.createElement('div');
      actions.className = 'dx-calibration-actions';
      const cancel = document.createElement('button');
      cancel.className = 'secondary';
      cancel.type = 'button';
      cancel.textContent = 'Close';
      cancel.addEventListener('click', () => modal.remove());
      const save = document.createElement('button');
      save.className = 'primary';
      save.type = 'button';
      save.textContent = 'Save';
      save.addEventListener('click', () => {
        const next = saveCalibration({
          screenWidthCm: clamp(Number(inputs.screenWidthCm.value) || 34, 5, 200),
          screenHeightCm: clamp(Number(inputs.screenHeightCm.value) || 19, 5, 200),
          viewingDistanceCm: clamp(Number(inputs.viewingDistanceCm.value) || 60, 10, 300),
          pixelWidth: Math.max(1, this.root.clientWidth),
          pixelHeight: Math.max(1, this.root.clientHeight)
        });
        this.updateCalibration(next);
        modal.remove();
      });
      actions.append(cancel, save);
      card.appendChild(actions);
      modal.appendChild(card);
      this.root.appendChild(modal);
      this.calibrationModal = modal;
    }

    updateCalibration(calibration) {
      this.offAxisCamera.updateCalibration(calibration);
      this.createWireframeRoom();
      this.setGridVisible(this.gridVisible);
    }

    setGridVisible(visible) {
      this.gridVisible = visible === true;
      for (const obj of this.roomObjects) obj.visible = this.gridVisible;
    }

    setDebugMode(enabled) {
      this.debugMode = enabled === true;
      for (const helper of this.debugHelpers) helper.visible = this.debugMode;
    }

    setPreviewVisible(visible) {
      this.previewVisible = visible === true;
      if (this.preview) this.preview.style.display = this.previewVisible ? 'block' : 'none';
      if (!this.previewVisible) {
        this.clearPreview();
        return;
      }
      if (faceTracker.stream && this.previewVideo) {
        this.previewVideo.srcObject = faceTracker.stream;
        this.previewVideo.play().catch(() => {});
      }
    }

    drawPreview(results) {
      if (!this.previewVisible || !this.previewCanvas) return;
      const canvas = this.previewCanvas;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.save();
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.scale(-1, 1);
      ctx.translate(-canvas.width, 0);
      const faces = results && results.multiFaceLandmarks ? results.multiFaceLandmarks : [];
      if (faces.length && window.drawConnectors && window.drawLandmarks) {
        for (const landmarks of faces) {
          window.drawConnectors(ctx, landmarks, window.FACEMESH_TESSELATION, { color: 'rgba(255,255,255,0.2)', lineWidth: 0.8 });
          window.drawConnectors(ctx, landmarks, window.FACEMESH_RIGHT_EYE, { color: 'rgba(255,255,255,0.8)', lineWidth: 1.5 });
          window.drawConnectors(ctx, landmarks, window.FACEMESH_LEFT_EYE, { color: 'rgba(255,255,255,0.8)', lineWidth: 1.5 });
          window.drawConnectors(ctx, landmarks, window.FACEMESH_FACE_OVAL, { color: 'rgba(255,255,255,0.8)', lineWidth: 1.5 });
          window.drawLandmarks(ctx, landmarks, { color: 'rgba(255,255,255,0.6)', lineWidth: 0.8, radius: 1.2 });
        }
      }
      ctx.restore();
    }

    clearPreview() {
      if (!this.previewCanvas) return;
      const ctx = this.previewCanvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, this.previewCanvas.width, this.previewCanvas.height);
    }

    setPositionAxis(index, value) {
      this.transform.position[index] = value;
      this.applyTransform();
      notifyTransformChanged(this);
    }

    setRotationAxis(index, value) {
      this.transform.rotation[index] = value;
      this.applyTransform();
      notifyTransformChanged(this);
    }

    setScale(value) {
      this.transform.scale = value;
      this.applyTransform();
      notifyTransformChanged(this);
    }

    setTransform(transform, forceNotify) {
      this.transform = {
        position: numberList(transform && transform.position, this.transform.position),
        scale: clamp(Number.isFinite(Number(transform && transform.scale)) ? Number(transform.scale) : this.transform.scale, 0.001, 100),
        rotation: numberList(transform && transform.rotation, this.transform.rotation)
      };
      this.applyTransform();
      if (this.controlsOpen) this.refreshControlPanel();
      notifyTransformChanged(this, forceNotify === true);
    }

    resetTransform() {
      this.setTransform(this.initialTransform, true);
    }

    applyTransform() {
      if (!this.object) return;
      this.object.position.set(
        this.transform.position[0],
        this.transform.position[1],
        this.transform.position[2]
      );
      this.object.scale.set(this.transform.scale, this.transform.scale, this.transform.scale);
      this.object.rotation.set(
        this.transform.rotation[0],
        this.transform.rotation[1],
        this.transform.rotation[2]
      );
    }

    ensureTracking() {
      if (this.trackingEnabled && !document.hidden) {
        faceTracker.ensure().catch((error) => {
          console.warn('Unable to start off-axis tracking:', error);
          notifyLoadState(this.elementId, 'tracking-error', null, error && error.message ? error.message : 'Camera unavailable');
        });
      }
    }

    pauseRender() {
      this.rendering = false;
      if (this.raf) {
        cancelAnimationFrame(this.raf);
        this.raf = 0;
      }
    }

    resumeRender() {
      if (this.rendering || this.disposed) return;
      this.rendering = true;
      this.animate();
    }

    animate() {
      if (!this.rendering || this.disposed) return;
      this.raf = requestAnimationFrame(() => this.animate());
      this.offAxisCamera.updateFromHeadPose(this.trackingEnabled ? this.headPose : { x: 0.5, y: 0.5, z: 1 });
      if (this.debugMode && this.debugHelpers.length > 1) {
        const worldPos = this.offAxisCamera.headPoseToWorldPosition(this.headPose);
        this.debugHelpers[1].position.set(worldPos.x, worldPos.y, worldPos.z);
      }
      this.renderer.render(this.scene, this.camera);
    }

    resize() {
      if (!this.root || this.disposed || !this.renderer) return false;
      const width = Math.max(1, this.root.clientWidth);
      const height = Math.max(1, this.root.clientHeight);
      const calibration = {
        ...getCalibration(),
        pixelWidth: width,
        pixelHeight: height
      };
      this.offAxisCamera.updateCalibration(calibration);
      this.renderer.setSize(width, height, false);
      this.createWireframeRoom();
      this.setGridVisible(this.gridVisible);
      return true;
    }

    isAlive() {
      return !!this.renderer && !this.disposed && this.root && this.root.isConnected && this.renderer.domElement.parentNode === this.root;
    }

    dispose() {
      this.disposed = true;
      this.pauseRender();
      if (this.resizeObserver) this.resizeObserver.disconnect();
      for (const cleanup of this.cleanup) {
        try { cleanup(); } catch (_) {}
      }
      if (this.calibrationModal) this.calibrationModal.remove();
      this.disposeObject(this.scene);
      if (this.renderer) {
        try { this.renderer.renderLists && this.renderer.renderLists.dispose && this.renderer.renderLists.dispose(); } catch (_) {}
        try { this.renderer.dispose(); } catch (_) {}
      }
      for (const objectUrl of this.objectUrls) {
        try { URL.revokeObjectURL(objectUrl); } catch (_) {}
      }
      if (this.root) this.root.innerHTML = '';
    }

    disposeMaterial(material) {
      if (!material) return;
      for (const key of Object.keys(material)) {
        const value = material[key];
        if (value && value.isTexture && typeof value.dispose === 'function') value.dispose();
      }
      if (typeof material.dispose === 'function') material.dispose();
    }

    disposeObject(object) {
      if (!object) return;
      if (typeof object.dispose === 'function') {
        try { object.dispose(); } catch (_) {}
      }
      if (typeof object.traverse === 'function') {
        object.traverse((node) => {
          if (node.geometry && typeof node.geometry.dispose === 'function') node.geometry.dispose();
          if (Array.isArray(node.material)) {
            node.material.forEach((material) => this.disposeMaterial(material));
          } else {
            this.disposeMaterial(node.material);
          }
        });
      }
    }
  }

  async function mount(elementId, payloadJson, optionsJson) {
    const root = document.getElementById(elementId);
    if (!root) return;
    const token = (root.__deepxOffAxisMountToken || 0) + 1;
    root.__deepxOffAxisMountToken = token;
    dispose(elementId, { keepRootMessage: true });

    const payload = parseJson(payloadJson);
    const options = parseJson(optionsJson);
    const asset = payloadAsset(payload);
    if (!asset.url) {
      notifyLoadState(elementId, 'missing', null, missingLabel(asset));
      setMessage(root, missingLabel(asset));
      return;
    }
    if (!supportedMesh(asset) && !supportedSplat(asset)) {
      notifyLoadState(elementId, 'missing', null, missingLabel(asset));
      setMessage(root, missingLabel(asset));
      return;
    }
    setMessage(root, 'Loading 3D asset...');
    notifyLoadState(elementId, 'loading', null, 'Loading 3D asset');
    try {
      const modules = await loadModules();
      if (root.__deepxOffAxisMountToken !== token) return;
      const ctx = new ViewerContext(elementId, root, payload, options, modules);
      viewers.set(elementId, ctx);
      await ctx.initialize();
      if (root.__deepxOffAxisMountToken !== token || ctx.disposed) {
        ctx.dispose();
      }
    } catch (error) {
      console.error(error);
      if (root.__deepxOffAxisMountToken === token) {
        const label = error && error.message ? error.message : 'Unable to load 3D asset.';
        notifyLoadState(elementId, 'error', null, label);
        setMessage(root, label);
      }
    }
  }

  function dispose(elementId, options) {
    const ctx = viewers.get(elementId);
    if (!ctx) {
      if (!options || !options.keepRootMessage) {
        const root = document.getElementById(elementId);
        if (root) root.innerHTML = '';
      }
      return;
    }
    ctx.dispose();
    viewers.delete(elementId);
    if (!options || !options.keepRootMessage) {
      const root = document.getElementById(elementId);
      if (root) root.innerHTML = '';
    }
    if (![...viewers.values()].some((item) => item.trackingEnabled && !item.disposed)) {
      faceTracker.stop('no-viewers');
    }
  }

  function setEditable(elementId, editable) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    ctx.editable = editable === true;
  }

  function setTransform(elementId, transformJson) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    ctx.setTransform(parseJson(transformJson), false);
  }

  function resetTransform(elementId) {
    const ctx = viewers.get(elementId);
    if (ctx) ctx.resetTransform();
  }

  function resizeViewer(elementId) {
    const ctx = viewers.get(elementId);
    return ctx ? ctx.resize() : false;
  }

  function isAlive(elementId) {
    const ctx = viewers.get(elementId);
    return ctx ? ctx.isAlive() : false;
  }

  window.DeepXOffAxisViewer = {
    mount,
    dispose,
    setEditable,
    setTransform,
    resetTransform,
    resize: resizeViewer,
    isAlive
  };
})();
