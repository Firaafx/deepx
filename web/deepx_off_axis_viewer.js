(function () {
  const viewers = new Map();
  let modulePromise = null;
  let mediaPipePromise = null;
  const loadingMessages = new WeakMap();
  const assetCache = new Map();
  const textureCache = new Map();

  const WII_ROOM = Object.freeze({
    numGridlines: 10,
    boxDepth: 8,
    fogDepth: 5,
    gridColor: 0xcccccc,
    lineColor: 0xffffff,
    numTargets: 10,
    numInFront: 3,
    targetScale: 0.065,
    targetTexture: 'reference/WiiDesktopVR/target.png',
    backgroundTexture: 'reference/WiiDesktopVR/stad_2.png'
  });

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

  const DEFAULT_VIEWER_STATE = Object.freeze({
    gridVisible: true,
    dartsVisible: false,
    objectVisible: true,
    backgroundVisible: false
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
        min-width: 34px;
        width: auto;
        height: 30px;
        padding: 0 6px;
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
        height: 276px;
        border: 2px solid #fff;
        border-radius: 8px;
        overflow: hidden;
        background: #000;
        box-shadow: 0 16px 36px rgba(0,0,0,0.42);
        pointer-events: none;
        display: none;
      }
      .dx-camera-stats {
        position: absolute;
        inset: 0 0 auto 0;
        min-height: 84px;
        padding: 8px;
        box-sizing: border-box;
        background: rgba(0,0,0,0.82);
        color: rgba(255,255,255,0.92);
        font: 600 10px/1.25 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 3px 8px;
        z-index: 2;
      }
      .dx-camera-preview video,
      .dx-camera-preview canvas {
        position: absolute;
        left: 0;
        right: 0;
        bottom: 0;
        top: 84px;
        width: 100%;
        height: calc(100% - 84px);
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

  function safeBool(value, fallback) {
    if (typeof value === 'boolean') return value;
    const raw = String(value == null ? '' : value).trim().toLowerCase();
    if (raw === 'true' || raw === '1' || raw === 'yes') return true;
    if (raw === 'false' || raw === '0' || raw === 'no') return false;
    return fallback;
  }

  function viewerStateFromPayload(payload) {
    const raw = payload && typeof payload.viewer === 'object' ? payload.viewer : {};
    return {
      gridVisible: safeBool(raw.gridVisible, DEFAULT_VIEWER_STATE.gridVisible),
      dartsVisible: safeBool(raw.dartsVisible, DEFAULT_VIEWER_STATE.dartsVisible),
      objectVisible: safeBool(raw.objectVisible, DEFAULT_VIEWER_STATE.objectVisible),
      backgroundVisible: safeBool(raw.backgroundVisible, DEFAULT_VIEWER_STATE.backgroundVisible)
    };
  }

  function viewerStateSnapshot(ctx) {
    return {
      gridVisible: ctx.gridPreference === true,
      dartsVisible: ctx.dartsVisible === true,
      objectVisible: ctx.objectVisible !== false,
      backgroundVisible: ctx.backgroundVisible === true
    };
  }

  function transformKey(transform) {
    return JSON.stringify(transformSnapshot(transform));
  }

  function payloadKey(payload) {
    const asset = payloadAsset(payload);
    return [asset.type, asset.url, asset.path, asset.format].join('|');
  }

  function assetCacheKey(asset) {
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

  function notifyViewerStateChanged(ctx, force) {
    if (!ctx || (!ctx.editable && !force)) return;
    try {
      window.postMessage(JSON.stringify({
        type: 'deepx-off-axis-viewer-state-changed',
        elementId: ctx.elementId,
        viewer: viewerStateSnapshot(ctx)
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
    constructor() {
      this.baseInterOcularDistance = 0.1;
      this.smoothedPose = { x: 0.5, y: 0.5, z: 1 };
      this.hasPose = false;
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
      if (!this.hasPose) {
        this.smoothedPose = { ...clamped };
        this.hasPose = true;
        return { ...this.smoothedPose };
      }
      const delta = Math.hypot(
        clamped.x - this.smoothedPose.x,
        clamped.y - this.smoothedPose.y,
        (clamped.z - this.smoothedPose.z) * 0.5
      );
      const alpha = delta > 0.035 ? 0.86 : 0.58;
      this.smoothedPose.x += alpha * (clamped.x - this.smoothedPose.x);
      this.smoothedPose.y += alpha * (clamped.y - this.smoothedPose.y);
      this.smoothedPose.z += alpha * (clamped.z - this.smoothedPose.z);
      return { ...this.smoothedPose };
    }

    reset() {
      this.smoothedPose = { x: 0.5, y: 0.5, z: 1 };
      this.hasPose = false;
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
    lastWorldPosition: { x: 0, y: 0, z: 0.6 },
    lastSentAt: 0,
    lastResultsAt: 0,
    stats: {
      latencyMs: null,
      faceDetected: false,
      trackingAgeMs: null,
      leftBlink: false,
      rightBlink: false
    },
    poseTracker: new HeadPoseTracker(),

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
      this.lastSentAt = performance.now();
      this.faceMesh.send({ image: this.video })
        .catch((error) => console.warn('MediaPipe frame failed:', error))
        .finally(() => {
          this.sending = false;
        });
    },

    handleResults(results) {
      const now = performance.now();
      const landmarks = results && results.multiFaceLandmarks ? results.multiFaceLandmarks : [];
      const firstFace = landmarks[0] || null;
      const pose = this.poseTracker.extractHeadPoseFromLandmarks(landmarks);
      this.lastPose = pose || this.lastPose || { x: 0.5, y: 0.5, z: 1 };
      this.lastResultsAt = now;
      const blink = this.extractBlinkState(firstFace);
      this.stats = {
        latencyMs: this.lastSentAt ? now - this.lastSentAt : null,
        faceDetected: !!firstFace,
        trackingAgeMs: 0,
        leftBlink: blink.left,
        rightBlink: blink.right
      };
      for (const ctx of viewers.values()) {
        if (ctx.trackingEnabled && !ctx.disposed) {
          if (typeof ctx.receiveHeadPose === 'function') {
            ctx.receiveHeadPose(this.lastPose);
          } else {
            ctx.headPose = this.lastPose;
          }
        }
        if (ctx.previewVisible) ctx.drawPreview(results);
      }
    },

    extractBlinkState(face) {
      if (!face || face.length < 468) return { left: false, right: false };
      const ratio = (upperIndex, lowerIndex, outerIndex, innerIndex) => {
        const upper = face[upperIndex];
        const lower = face[lowerIndex];
        const outer = face[outerIndex];
        const inner = face[innerIndex];
        if (!upper || !lower || !outer || !inner) return 1;
        const vertical = Math.hypot(upper.x - lower.x, upper.y - lower.y);
        const horizontal = Math.hypot(outer.x - inner.x, outer.y - inner.y);
        return horizontal > 0 ? vertical / horizontal : 1;
      };
      return {
        left: ratio(159, 145, 33, 133) < 0.18,
        right: ratio(386, 374, 263, 362) < 0.18
      };
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
      this.stats = {
        latencyMs: null,
        faceDetected: false,
        trackingAgeMs: null,
        leftBlink: false,
        rightBlink: false
      };
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
      this.viewerState = viewerStateFromPayload(payload);
      this.previewVisible = false;
      this.gridPreference = this.viewerState.gridVisible;
      this.gridVisible = true;
      this.dartsVisible = this.viewerState.dartsVisible;
      this.objectVisible = this.viewerState.objectVisible;
      this.backgroundVisible = this.viewerState.backgroundVisible;
      this.debugMode = false;
      this.headPose = { x: 0.5, y: 0.5, z: 1 };
      this.worldHeadPosition = { x: 0, y: 0, z: 0.6 };
      this.assetLoaded = false;
      this.modelBounds = null;
      this.scaleRange = { min: 0.001, max: 1 };
      this.lastFrameAt = 0;
      this.frameCounter = 0;
      this.fpsStartedAt = performance.now();
      this.fps = 0;
      this.objectUrls = [];
      this.cleanup = [];
      this.debugHelpers = [];
      this.roomObjects = [];
      this.dartObjects = [];
      this.backgroundObjects = [];
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
      this.scene.background = new this.THREE.Color(0x000000);
      this.scene.fog = new this.THREE.Fog(0x000000, 0.6, 1.6);
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
      this.createDarts();
      this.createBackgroundPanorama();
      this.createDebugHelpers();
      this.buildChrome();
      this.installContextLossHandler();
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(this.root);
      this.resize();
      this.resumeRender();
      this.ensureTracking();
      notifyViewerStateChanged(this, true);
      notifyTransformChanged(this, true);
      await this.loadAsset();
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

    async loadAsset() {
      this.updateLoading('Loading 3D asset');
      try {
        this.object = supportedMesh(this.asset)
          ? await this.addTriangleMesh()
          : await this.addGaussianSplat();
        if (this.disposed) return;
        this.assetLoaded = true;
        this.applyTransform();
        this.applyObjectVisibility();
        this.updateModelBounds();
        this.computeScaleRange();
        this.setGridVisible(this.gridPreference, { notify: false, preference: false });
        this.resize();
        if (this.controlsOpen) this.refreshControlPanel();
        notifyTransformChanged(this, true);
        notifyViewerStateChanged(this, true);
        notifyLoadState(this.elementId, 'ready', 1, '3D asset ready');
      } catch (error) {
        if (this.disposed) return;
        console.error(error);
        const label = error && error.message ? error.message : 'Unable to load 3D asset.';
        notifyLoadState(this.elementId, 'error', null, label);
      }
    }

    async fetchObjectUrl(url, label, cacheKey) {
      const key = cacheKey || `${url}|blob`;
      const cached = assetCache.get(key);
      if (cached && cached.objectUrl) {
        this.updateLoading(label, 1);
        return cached.objectUrl;
      }
      if (cached && cached.promise) {
        this.updateLoading(label);
        return cached.promise;
      }
      this.updateLoading(label);
      const promise = (async () => {
        const response = await fetch(url, { cache: 'force-cache' });
        if (!response.ok) throw new Error(`Unable to load 3D asset (${response.status}).`);
        const type = response.headers.get('content-type') || 'application/octet-stream';
        const total = Number(response.headers.get('content-length'));
        if (!response.body || !Number.isFinite(total) || total <= 0) {
          const blob = await response.blob();
          const objectUrl = URL.createObjectURL(blob);
          assetCache.set(key, { objectUrl });
          return objectUrl;
        }
        const reader = response.body.getReader();
        const chunks = [];
        let loaded = 0;
        let lastProgressAt = 0;
        for (;;) {
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
        assetCache.set(key, { objectUrl });
        this.updateLoading(label, 1);
        return objectUrl;
      })();
      assetCache.set(key, { promise });
      try {
        const objectUrl = await promise;
        assetCache.set(key, { objectUrl });
        return objectUrl;
      } catch (error) {
        if (assetCache.get(key)?.promise === promise) assetCache.delete(key);
        throw error;
      }
    }

    updateLoading(label, progress) {
      if (this.disposed) return;
      notifyLoadState(this.elementId, 'loading', progress, label);
      setRootLoadingMessage(this.root, label, progress);
    }

    async addTriangleMesh() {
      const key = `${assetCacheKey(this.asset)}|gltf`;
      let entry = assetCache.get(key);
      if (!entry) {
        entry = {};
        assetCache.set(key, entry);
      }
      if (!entry.gltf) {
        if (!entry.promise) {
          entry.promise = this.loadGltfForCache(key);
        }
        entry.gltf = await entry.promise;
      }
      const object = entry.gltf.scene.clone(true);
      this.markSharedAsset(object);
      object.traverse((node) => {
        if (node.isMesh) {
          node.castShadow = true;
          node.receiveShadow = true;
        }
      });
      this.scene.add(object);
      return object;
    }

    async loadGltfForCache(key) {
      const loader = new this.modules.GLTFLoader();
      let dracoLoader = null;
      if (this.modules.DRACOLoader) {
        dracoLoader = new this.modules.DRACOLoader();
        dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.6/');
        dracoLoader.setDecoderConfig({ type: 'js' });
        loader.setDRACOLoader(dracoLoader);
      }
      let loadUrl = this.asset.url;
      if (assetLooksLike(this.asset, 'glb')) {
        loadUrl = await this.fetchObjectUrl(this.asset.url, 'Loading 3D mesh', `${assetCacheKey(this.asset)}|blob`);
      } else {
        this.updateLoading('Loading 3D mesh');
      }
      try {
        const gltf = await loader.loadAsync(loadUrl, (event) => {
          if (event && Number.isFinite(event.total) && event.total > 0) {
            this.updateLoading('Loading 3D mesh', event.loaded / event.total);
          }
        });
        assetCache.set(key, { gltf });
        return gltf;
      } finally {
        if (dracoLoader) dracoLoader.dispose();
      }
    }

    markSharedAsset(object) {
      object.traverse((node) => {
        node.userData = node.userData || {};
        node.userData.deepxSharedAsset = true;
      });
    }

    async addGaussianSplat() {
      const spark = this.modules.spark;
      if (!spark) throw new Error('Spark module failed to load.');
      const Candidate =
        spark.SplatMesh || spark.SparkSplatMesh || spark.GaussianSplatMesh || spark.SplatObject;
      if (!Candidate) throw new Error('Spark loaded, but no supported splat mesh export was found.');
      const loadUrl = await this.fetchObjectUrl(this.asset.url, 'Loading 3D asset', `${assetCacheKey(this.asset)}|blob`);
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
      const roomDepth = roomHeight * (WII_ROOM.boxDepth / 2);
      const gridDivisions = WII_ROOM.numGridlines;
      const wallMaterial = new this.THREE.LineBasicMaterial({
        color: WII_ROOM.gridColor,
        transparent: false,
        opacity: 1,
        depthTest: true,
        depthWrite: true,
        fog: true
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
      this.roomObjects.push(backWall, leftWall, rightWall, floor, ceiling);
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

    async loadTexture(src) {
      const cached = textureCache.get(src);
      if (cached) return cached;
      const loader = new this.THREE.TextureLoader();
      const promise = loader.loadAsync(src).then((texture) => {
        texture.colorSpace = this.THREE.SRGBColorSpace;
        texture.minFilter = this.THREE.LinearFilter;
        texture.magFilter = this.THREE.LinearFilter;
        texture.userData = texture.userData || {};
        texture.userData.deepxCachedTexture = true;
        return texture;
      });
      textureCache.set(src, promise);
      return promise;
    }

    seededRandom(seedText) {
      let seed = 2166136261;
      for (let i = 0; i < seedText.length; i++) {
        seed ^= seedText.charCodeAt(i);
        seed = Math.imul(seed, 16777619);
      }
      return () => {
        seed += 0x6D2B79F5;
        let value = seed;
        value = Math.imul(value ^ value >>> 15, value | 1);
        value ^= value + Math.imul(value ^ value >>> 7, value | 61);
        return ((value ^ value >>> 14) >>> 0) / 4294967296;
      };
    }

    createDarts() {
      this.removeDarts();
      const screenDims = this.offAxisCamera.getScreenDimensions();
      const roomHeight = screenDims.height;
      const screenAspect = screenDims.width / Math.max(roomHeight, 0.0001);
      const depthStep = (WII_ROOM.boxDepth / 2) / WII_ROOM.numTargets;
      const startDepth = WII_ROOM.numInFront * depthStep;
      const random = this.seededRandom(assetCacheKey(this.asset));
      const group = new this.THREE.Group();
      const lineMaterial = new this.THREE.LineBasicMaterial({
        color: WII_ROOM.lineColor,
        fog: true,
        depthTest: true,
        depthWrite: true
      });
      const lineDepth = -200 * WII_ROOM.targetScale * roomHeight;
      for (let i = 0; i < WII_ROOM.numTargets; i++) {
        let x = 0.7 * screenAspect * (random() - 0.5) * roomHeight;
        let y = 0.7 * (random() - 0.5) * roomHeight;
        const z = (startDepth - i * depthStep) * roomHeight;
        if (i < WII_ROOM.numInFront) {
          x *= 0.5;
          y *= 0.5;
        }
        const geometry = new this.THREE.BufferGeometry();
        geometry.setAttribute('position', new this.THREE.Float32BufferAttribute([
          x, y, z,
          x, y, z + lineDepth
        ], 3));
        group.add(new this.THREE.LineSegments(geometry, lineMaterial));
      }
      group.visible = this.dartsVisible;
      this.dartObjects.push(group);
      this.scene.add(group);
      this.loadTexture(WII_ROOM.targetTexture)
        .then((texture) => {
          if (this.disposed) return;
          for (let i = 0; i < WII_ROOM.numTargets; i++) {
            const line = group.children[i];
            if (!line || !line.geometry) continue;
            const position = line.geometry.getAttribute('position');
            const sprite = new this.THREE.Sprite(new this.THREE.SpriteMaterial({
              map: texture,
              transparent: true,
              fog: true,
              depthTest: true,
              depthWrite: false
            }));
            sprite.position.set(position.getX(0), position.getY(0), position.getZ(0));
            const size = WII_ROOM.targetScale * roomHeight;
            sprite.scale.set(size, size, size);
            group.add(sprite);
          }
        })
        .catch((error) => console.warn('Unable to load target texture:', error));
    }

    removeDarts() {
      for (const obj of this.dartObjects) {
        this.scene.remove(obj);
        this.disposeObject(obj);
      }
      this.dartObjects = [];
    }

    createBackgroundPanorama() {
      this.removeBackgroundPanorama();
      const screenDims = this.offAxisCamera.getScreenDimensions();
      const radius = screenDims.height * 3;
      const height = screenDims.height * 2;
      const segments = 24;
      const geometry = new this.THREE.BufferGeometry();
      const vertices = [];
      const uvs = [];
      const indices = [];
      for (let i = 0; i <= segments; i++) {
        const t = i / segments;
        const angle = Math.PI * t;
        const x = Math.cos(angle) * radius;
        const z = -Math.sin(angle) * radius;
        vertices.push(x, -height / 2, z, x, height / 2, z);
        uvs.push(t, 1, t, 0);
        if (i < segments) {
          const base = i * 2;
          indices.push(base, base + 1, base + 2, base + 1, base + 3, base + 2);
        }
      }
      geometry.setAttribute('position', new this.THREE.Float32BufferAttribute(vertices, 3));
      geometry.setAttribute('uv', new this.THREE.Float32BufferAttribute(uvs, 2));
      geometry.setIndex(indices);
      const material = new this.THREE.MeshBasicMaterial({
        color: 0xffffff,
        side: this.THREE.DoubleSide,
        fog: false
      });
      const mesh = new this.THREE.Mesh(geometry, material);
      mesh.visible = this.backgroundVisible;
      this.backgroundObjects.push(mesh);
      this.scene.add(mesh);
      this.loadTexture(WII_ROOM.backgroundTexture)
        .then((texture) => {
          if (this.disposed) return;
          material.map = texture;
          material.needsUpdate = true;
        })
        .catch((error) => console.warn('Unable to load background texture:', error));
    }

    removeBackgroundPanorama() {
      for (const obj of this.backgroundObjects) {
        this.scene.remove(obj);
        this.disposeObject(obj);
      }
      this.backgroundObjects = [];
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

    updateModelBounds() {
      if (!this.object) {
        this.modelBounds = null;
        return;
      }
      const box = new this.THREE.Box3().setFromObject(this.object);
      const size = new this.THREE.Vector3();
      box.getSize(size);
      const maxDimension = Math.max(size.x, size.y, size.z);
      this.modelBounds = {
        maxDimension: Number.isFinite(maxDimension) && maxDimension > 0
          ? maxDimension / Math.max(this.transform.scale, 0.001)
          : 1
      };
    }

    computeScaleRange() {
      const screenDims = this.offAxisCamera ? this.offAxisCamera.getScreenDimensions() : { width: 1, height: 1 };
      const modelMaxDimension = this.modelBounds && this.modelBounds.maxDimension
        ? this.modelBounds.maxDimension
        : 1;
      const fitScale = Math.min(screenDims.width, screenDims.height) / Math.max(modelMaxDimension, 0.000001);
      const current = Math.max(Number(this.transform.scale) || DEFAULT_TRANSFORM.scale, 0.001);
      this.scaleRange = {
        min: clamp(Math.min(0.001, current / 20, fitScale / 20), 0.001, 100),
        max: clamp(Math.max(0.3, current * 20, fitScale * 10), 0.001, 100)
      };
      if (this.scaleRange.max <= this.scaleRange.min) {
        this.scaleRange.max = Math.min(100, this.scaleRange.min + 1);
      }
      return this.scaleRange;
    }

    buildChrome() {
      this.preview = document.createElement('div');
      this.preview.className = 'dx-camera-preview';
      this.statsPanel = document.createElement('div');
      this.statsPanel.className = 'dx-camera-stats';
      this.previewVideo = document.createElement('video');
      this.previewVideo.autoplay = true;
      this.previewVideo.muted = true;
      this.previewVideo.playsInline = true;
      this.previewCanvas = document.createElement('canvas');
      this.previewCanvas.width = 640;
      this.previewCanvas.height = 480;
      this.preview.appendChild(this.statsPanel);
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
      body.appendChild(this.makeRange('Position X', this.transform.position[0], -1, 1, 0.001, (value) => this.setPositionAxis(0, value)));
      body.appendChild(this.makeRange('Position Y', this.transform.position[1], -1, 1, 0.001, (value) => this.setPositionAxis(1, value)));
      body.appendChild(this.makeRange('Position Z', this.transform.position[2], -2, 1, 0.001, (value) => this.setPositionAxis(2, value)));
      const scaleGroup = document.createElement('div');
      scaleGroup.className = 'dx-control-group';
      this.computeScaleRange();
      scaleGroup.appendChild(this.makeRange('Scale', this.transform.scale, this.scaleRange.min, this.scaleRange.max, 0.001, (value) => this.setScale(value)));
      body.appendChild(scaleGroup);
      const rotationGroup = document.createElement('div');
      rotationGroup.className = 'dx-control-group';
      const formatDegrees = (value) => `${(value * 180 / Math.PI).toFixed(1)}deg`;
      rotationGroup.appendChild(this.makeRange('Rotation X', this.transform.rotation[0], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(0, value), formatDegrees));
      rotationGroup.appendChild(this.makeRange('Rotation Y', this.transform.rotation[1], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(1, value), formatDegrees));
      rotationGroup.appendChild(this.makeRange('Rotation Z', this.transform.rotation[2], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(2, value), formatDegrees));
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
        this.setGridVisible(!(this.gridPreference === true), { notify: true, preference: true });
      });
      grid.classList.toggle('is-active', this.gridPreference === true);
      const darts = this.makeButton('DART', 'Toggle darts', () => {
        this.setDartsVisible(!this.dartsVisible, true);
      });
      darts.classList.toggle('is-active', this.dartsVisible);
      const object = this.makeButton('OBJ', 'Toggle 3D object', () => {
        this.setObjectVisible(!this.objectVisible, true);
      });
      object.classList.toggle('is-active', this.objectVisible);
      const background = this.makeButton('BG', 'Toggle background panorama', () => {
        this.setBackgroundVisible(!this.backgroundVisible, true);
      });
      background.classList.toggle('is-active', this.backgroundVisible);
      const preview = this.makeButton('CAM', 'Toggle camera preview', () => {
        this.setPreviewVisible(!this.previewVisible);
        preview.classList.toggle('is-active', this.previewVisible);
      });
      const reset = this.makeButton('RST', 'Reset model transform', () => this.resetTransform());
      this.gridButton = grid;
      this.dartsButton = darts;
      this.objectButton = object;
      this.backgroundButton = background;
      this.previewButton = preview;
      buttons.append(fullscreen, settings, debug, grid, darts, object, background, preview, reset);
      this.root.appendChild(buttons);
      document.addEventListener('fullscreenchange', () => {
        fullscreen.textContent = document.fullscreenElement ? 'MIN' : 'FS';
        fullscreen.title = document.fullscreenElement ? 'Exit fullscreen' : 'Enter fullscreen';
      });
      const onKeyDown = (event) => this.handleShortcut(event);
      window.addEventListener('keydown', onKeyDown);
      this.cleanup.push(() => window.removeEventListener('keydown', onKeyDown));
    }

    handleShortcut(event) {
      if (event.defaultPrevented) return;
      const target = event.target;
      const tag = target && target.tagName ? target.tagName.toLowerCase() : '';
      if (tag === 'input' || tag === 'textarea' || tag === 'select' || (target && target.isContentEditable)) return;
      const key = String(event.key || '').toLowerCase();
      if (key === 'g') {
        event.preventDefault();
        this.setGridVisible(!(this.gridPreference === true), { notify: true, preference: true });
      } else if (key === 't') {
        event.preventDefault();
        this.setDartsVisible(!this.dartsVisible, true);
      } else if (key === 'o') {
        event.preventDefault();
        this.setObjectVisible(!this.objectVisible, true);
      } else if (key === 'b') {
        event.preventDefault();
        this.setBackgroundVisible(!this.backgroundVisible, true);
      } else if (key === 'c') {
        event.preventDefault();
        this.setPreviewVisible(!this.previewVisible);
      }
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
      this.createDarts();
      this.createBackgroundPanorama();
      this.setGridVisible(this.gridVisible, { notify: false, preference: false });
      this.setDartsVisible(this.dartsVisible, false);
      this.setBackgroundVisible(this.backgroundVisible, false);
    }

    setGridVisible(visible, options) {
      this.gridVisible = visible === true;
      if (!options || options.preference !== false) {
        this.gridPreference = this.gridVisible;
      }
      for (const obj of this.roomObjects) obj.visible = this.gridVisible;
      if (this.gridButton) this.gridButton.classList.toggle('is-active', this.gridPreference === true);
      if (options && options.notify) notifyViewerStateChanged(this);
    }

    setDartsVisible(visible, notify) {
      this.dartsVisible = visible === true;
      for (const obj of this.dartObjects) obj.visible = this.dartsVisible;
      if (this.dartsButton) this.dartsButton.classList.toggle('is-active', this.dartsVisible);
      if (notify) notifyViewerStateChanged(this);
    }

    setObjectVisible(visible, notify) {
      this.objectVisible = visible === true;
      this.applyObjectVisibility();
      if (this.objectButton) this.objectButton.classList.toggle('is-active', this.objectVisible);
      if (notify) notifyViewerStateChanged(this);
    }

    applyObjectVisibility() {
      if (this.object) this.object.visible = this.objectVisible;
    }

    setBackgroundVisible(visible, notify) {
      this.backgroundVisible = visible === true;
      for (const obj of this.backgroundObjects) obj.visible = this.backgroundVisible;
      if (this.backgroundButton) this.backgroundButton.classList.toggle('is-active', this.backgroundVisible);
      if (notify) notifyViewerStateChanged(this);
    }

    setViewerState(state, notify) {
      const next = {
        ...DEFAULT_VIEWER_STATE,
        ...(state && typeof state === 'object' ? state : {})
      };
      this.gridPreference = safeBool(next.gridVisible, DEFAULT_VIEWER_STATE.gridVisible);
      const shouldShowGrid = this.assetLoaded ? this.gridPreference : (this.gridPreference || !this.assetLoaded);
      this.setGridVisible(shouldShowGrid, { notify: false, preference: false });
      this.setDartsVisible(safeBool(next.dartsVisible, DEFAULT_VIEWER_STATE.dartsVisible), false);
      this.setObjectVisible(safeBool(next.objectVisible, DEFAULT_VIEWER_STATE.objectVisible), false);
      this.setBackgroundVisible(safeBool(next.backgroundVisible, DEFAULT_VIEWER_STATE.backgroundVisible), false);
      if (notify) notifyViewerStateChanged(this);
    }

    setDebugMode(enabled) {
      this.debugMode = enabled === true;
      for (const helper of this.debugHelpers) helper.visible = this.debugMode;
    }

    setPreviewVisible(visible) {
      this.previewVisible = visible === true;
      if (this.preview) this.preview.style.display = this.previewVisible ? 'block' : 'none';
      if (this.previewButton) this.previewButton.classList.toggle('is-active', this.previewVisible);
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
      this.updateStatsPanel();
    }

    clearPreview() {
      if (!this.previewCanvas) return;
      const ctx = this.previewCanvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, this.previewCanvas.width, this.previewCanvas.height);
    }

    updateStatsPanel() {
      if (!this.statsPanel || !this.previewVisible) return;
      const stats = faceTracker.stats || {};
      const age = faceTracker.lastResultsAt ? performance.now() - faceTracker.lastResultsAt : null;
      const pose = this.headPose || { x: 0.5, y: 0.5, z: 1 };
      const world = this.worldHeadPosition || this.offAxisCamera.headPoseToWorldPosition(pose);
      const calibration = this.offAxisCamera.calibration || getCalibration();
      const item = (label, value) => `<span>${label}: ${value}</span>`;
      const fixed = (value, digits) => Number.isFinite(value) ? Number(value).toFixed(digits) : '--';
      this.statsPanel.innerHTML = [
        item('FPS', fixed(this.fps, 1)),
        item('Latency', stats.latencyMs == null ? '--' : `${Math.round(stats.latencyMs)}ms`),
        item('Face', stats.faceDetected ? 'yes' : 'no'),
        item('Age', age == null ? '--' : `${Math.round(age)}ms`),
        item('L blink', stats.leftBlink ? 'closed' : 'open'),
        item('R blink', stats.rightBlink ? 'closed' : 'open'),
        item('Head N', `${fixed(pose.x, 3)},${fixed(pose.y, 3)},${fixed(pose.z, 3)}`),
        item('Head W', `${fixed(world.x, 3)},${fixed(world.y, 3)},${fixed(world.z, 3)}`),
        item('Dist', `${fixed(world.z * 100, 1)}cm`),
        item('Cal', `${fixed(calibration.screenWidthCm, 1)}x${fixed(calibration.screenHeightCm, 1)}cm`)
      ].join('');
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
      this.computeScaleRange();
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

    receiveHeadPose(headPose) {
      this.headPose = headPose || { x: 0.5, y: 0.5, z: 1 };
      this.updateOffAxisCamera();
      if (this.renderer && this.scene && this.camera && this.rendering) {
        this.renderer.render(this.scene, this.camera);
      }
    }

    updateOffAxisCamera() {
      const pose = this.trackingEnabled ? this.headPose : { x: 0.5, y: 0.5, z: 1 };
      this.worldHeadPosition = this.offAxisCamera.headPoseToWorldPosition(pose);
      this.offAxisCamera.setCameraPosition(this.worldHeadPosition);
      this.offAxisCamera.updateProjectionMatrix(this.worldHeadPosition);
      this.updateFog();
      if (this.debugMode && this.debugHelpers.length > 1) {
        const worldPos = this.worldHeadPosition;
        this.debugHelpers[1].position.set(worldPos.x, worldPos.y, worldPos.z);
      }
    }

    updateFog() {
      if (!this.scene || !this.scene.fog) return;
      const screenDims = this.offAxisCamera.getScreenDimensions();
      const start = Math.max(0.001, this.worldHeadPosition ? this.worldHeadPosition.z : this.camera.position.z);
      this.scene.fog.near = start;
      this.scene.fog.far = start + screenDims.height * WII_ROOM.fogDepth;
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
      const now = performance.now();
      this.frameCounter++;
      if (now - this.fpsStartedAt >= 500) {
        this.fps = this.frameCounter * 1000 / (now - this.fpsStartedAt);
        this.frameCounter = 0;
        this.fpsStartedAt = now;
      }
      this.updateOffAxisCamera();
      this.updateStatsPanel();
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
      this.createDarts();
      this.createBackgroundPanorama();
      this.setGridVisible(this.gridVisible, { notify: false, preference: false });
      this.setDartsVisible(this.dartsVisible, false);
      this.setBackgroundVisible(this.backgroundVisible, false);
      this.computeScaleRange();
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
        if (value && value.isTexture && typeof value.dispose === 'function' && !(value.userData && value.userData.deepxCachedTexture)) {
          value.dispose();
        }
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
          if (node.userData && node.userData.deepxSharedAsset) return;
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

  function setViewerState(elementId, viewerJson) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    ctx.setViewerState(parseJson(viewerJson), false);
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
    setViewerState,
    resetTransform,
    resize: resizeViewer,
    isAlive
  };
})();
