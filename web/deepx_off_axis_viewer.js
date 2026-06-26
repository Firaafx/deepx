(function () {
  const viewers = new Map();
  let modulePromise = null;
  let mediaPipePromise = null;
  const loadingMessages = new WeakMap();
  const assetCache = new Map();
  const textureCache = new Map();

  const WII_ROOM = Object.freeze({
    numGridlines: 10,
    boxDepth: 10,
    fogDepth: 5,
    fogReachTowardViewer: 2.5,
    gridColor: 0x333333,
    gridOpacity: 0.72,
    defaultFogStrength: 0.35,
    defaultFogDepth: 9,
    lineColor: 0xffffff,
    numTargets: 10,
    numInFront: 3,
    targetScale: 0.065,
    targetTexture: 'reference/WiiDesktopVR/target.png'
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
    fogVisible: true,
    dartsVisible: false,
    objectVisible: true,
    selectedLayerId: '',
    imageLayers: Object.freeze([]),
    modelLayers: Object.freeze([]),
    lightLayers: Object.freeze([]),
    fogStrength: 0.35,
    fogDepth: 9,
    fogColor: '#000000',
    backgroundColor: '#000000',
    gridColor: '#333333',
    ambientColor: '#ffffff',
    ambientIntensity: 0.5,
    sunColor: '#ffffff',
    sunIntensity: 0.8,
    sunDirection: Object.freeze([1, 1, 1]),
    environment: Object.freeze({}),
    environmentLightingEnabled: false,
    autoFitPrimary: false,
    autoFitTargetId: '',
    autoFitNonce: 0,
    trackingSmoothing: 0.3,
    deadZoneX: 0,
    deadZoneY: 0,
    deadZoneZ: 0
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
      .dx-viewer-button.dx-spatial-button {
        min-width: 92px;
        padding: 0 9px;
      }
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
        max-height: calc(100vh - 32px);
        border-radius: 8px;
        background: rgba(0,0,0,0.70);
        color: #fff;
        box-shadow: 0 16px 36px rgba(0,0,0,0.35);
        backdrop-filter: blur(8px);
        display: flex;
        flex-direction: column;
        overflow: hidden;
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
        overflow-y: auto;
        overscroll-behavior: contain;
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
      .dx-layer-select {
        width: 100%;
        border: 1px solid rgba(255,255,255,0.22);
        border-radius: 6px;
        background: rgba(255,255,255,0.10);
        color: #fff;
        padding: 7px 8px;
        font: 700 12px system-ui, sans-serif;
      }
      .dx-layer-select option {
        color: #111827;
      }
      .dx-control-row {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
      }
      .dx-color-control {
        display: grid;
        grid-template-columns: 1fr 44px;
        align-items: center;
        gap: 8px;
      }
      .dx-color-control input[type=color] {
        width: 44px;
        height: 28px;
        padding: 0;
        border: 1px solid rgba(255,255,255,0.22);
        border-radius: 4px;
        background: transparent;
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
        height: 392px;
        border: 2px solid #fff;
        border-radius: 8px;
        overflow: hidden;
        background: #000;
        box-shadow: 0 16px 36px rgba(0,0,0,0.42);
        pointer-events: none;
        display: none;
      }
      .dx-tracking-controls {
        position: absolute;
        inset: 0 0 auto 0;
        min-height: 116px;
        padding: 8px;
        box-sizing: border-box;
        background: rgba(0,0,0,0.86);
        color: rgba(255,255,255,0.92);
        font: 700 10px/1.2 system-ui, sans-serif;
        display: grid;
        gap: 4px;
        z-index: 3;
        pointer-events: auto;
      }
      .dx-tracking-control {
        display: grid;
        grid-template-columns: 70px 1fr 34px;
        align-items: center;
        gap: 5px;
      }
      .dx-tracking-control input[type=range] {
        width: 100%;
        accent-color: #fff;
      }
      .dx-tracking-value {
        text-align: right;
        color: rgba(255,255,255,0.72);
        font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      }
      .dx-camera-stats {
        position: absolute;
        inset: 116px 0 auto 0;
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
        top: 200px;
        width: 100%;
        height: calc(100% - 200px);
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
        import('https://esm.sh/three@0.180.0/examples/jsm/loaders/EXRLoader.js'),
        import('https://esm.sh/@sparkjsdev/spark@2.1.0?deps=three@0.180.0').catch(() => null)
      ]).then(([three, gltf, draco, exr, spark]) => ({
        THREE: three,
        GLTFLoader: gltf.GLTFLoader,
        DRACOLoader: draco.DRACOLoader,
        EXRLoader: exr.EXRLoader,
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

  function transformFromRaw(raw, fallback) {
    const base = fallback || DEFAULT_TRANSFORM;
    const value = raw && typeof raw === 'object' ? raw : {};
    return {
      position: numberList(value.position, base.position),
      scale: clamp(Number.isFinite(Number(value.scale)) ? Number(value.scale) : base.scale, 0.001, 100),
      rotation: numberList(value.rotation, base.rotation)
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

  function normalizeSpatialEye(value) {
    const raw = String(value || '').trim().toLowerCase();
    return raw === 'left' || raw === 'right' ? raw : '';
  }

  function defaultHeadPose() {
    return {
      x: 0.5,
      y: 0.5,
      z: 1,
      eyes: {
        left: { x: 0.53, y: 0.5 },
        right: { x: 0.47, y: 0.5 }
      }
    };
  }

  function cloneHeadPose(pose) {
    const fallback = defaultHeadPose();
    const source = pose && typeof pose === 'object' ? pose : fallback;
    const eyes = source.eyes && typeof source.eyes === 'object' ? source.eyes : fallback.eyes;
    const left = eyes.left && typeof eyes.left === 'object' ? eyes.left : fallback.eyes.left;
    const right = eyes.right && typeof eyes.right === 'object' ? eyes.right : fallback.eyes.right;
    return {
      x: Number.isFinite(Number(source.x)) ? Number(source.x) : fallback.x,
      y: Number.isFinite(Number(source.y)) ? Number(source.y) : fallback.y,
      z: Number.isFinite(Number(source.z)) ? Number(source.z) : fallback.z,
      eyes: {
        left: {
          x: Number.isFinite(Number(left.x)) ? Number(left.x) : fallback.eyes.left.x,
          y: Number.isFinite(Number(left.y)) ? Number(left.y) : fallback.eyes.left.y
        },
        right: {
          x: Number.isFinite(Number(right.x)) ? Number(right.x) : fallback.eyes.right.x,
          y: Number.isFinite(Number(right.y)) ? Number(right.y) : fallback.eyes.right.y
        }
      }
    };
  }

  function safeNumber(value, fallback, min, max) {
    const next = Number(value);
    const resolved = Number.isFinite(next) ? next : fallback;
    return clamp(resolved, min, max);
  }

  function safeColor(value, fallback) {
    const raw = String(value || '').trim();
    return /^#[0-9a-f]{6}$/i.test(raw) ? raw : fallback;
  }

  function vectorSnapshot(values) {
    return numberList(values, [0, 0, 0]).map((value) => Number(Number(value).toFixed(5)));
  }

  function layerAsset(raw, fallbackType) {
    const value = raw && typeof raw === 'object' ? raw : {};
    const type = normalizeType(value.type || value.mediaType || fallbackType || '');
    return {
      type,
      url: String(value.url || value.assetUrl || '').trim(),
      path: String(value.path || value.assetPath || '').trim(),
      format: String(value.format || '').trim().toLowerCase(),
      contentType: String(value.contentType || 'application/octet-stream').trim() || 'application/octet-stream',
      bytes: Number.isFinite(Number(value.bytes)) ? Number(value.bytes) : undefined
    };
  }

  function imageLayersFromValue(value) {
    if (!Array.isArray(value)) return [];
    return value.map((raw, index) => {
      const layer = raw && typeof raw === 'object' ? raw : {};
      const fallbackTransform = {
        position: [0, 0, -0.08 - index * 0.08],
        scale: 0.25,
        rotation: [0, 0, 0]
      };
      return {
        id: String(layer.id || `png-${index}`).trim() || `png-${index}`,
        name: String(layer.name || `PNG Layer ${index + 1}`).trim() || `PNG Layer ${index + 1}`,
        url: String(layer.url || layer.assetUrl || '').trim(),
        path: String(layer.path || layer.assetPath || '').trim(),
        contentType: String(layer.contentType || 'image/png').trim() || 'image/png',
        bytes: Number.isFinite(Number(layer.bytes)) ? Number(layer.bytes) : undefined,
        visible: safeBool(layer.visible, true),
        locked: safeBool(layer.locked, false),
        transform: transformFromRaw(layer.transform, fallbackTransform)
      };
    }).filter((layer) => layer.url);
  }

  function imageLayerSnapshot(layer) {
    return {
      id: String(layer.id || ''),
      name: String(layer.name || 'PNG Layer'),
      url: String(layer.url || ''),
      path: String(layer.path || ''),
      contentType: String(layer.contentType || 'image/png'),
      ...(Number.isFinite(Number(layer.bytes)) ? { bytes: Number(layer.bytes) } : {}),
      visible: layer.visible !== false,
      locked: layer.locked === true,
      transform: transformSnapshot(layer.transform)
    };
  }

  function modelLayersFromValue(value) {
    if (!Array.isArray(value)) return [];
    return value.map((raw, index) => {
      const layer = raw && typeof raw === 'object' ? raw : {};
      const asset = layerAsset(layer, layer.type || layer.mediaType || 'triangle_mesh');
      const fallbackTransform = {
        position: [0, -0.09, -0.03 - index * 0.08],
        scale: DEFAULT_TRANSFORM.scale,
        rotation: DEFAULT_TRANSFORM.rotation
      };
      return {
        id: String(layer.id || `model-${index}`).trim() || `model-${index}`,
        name: String(layer.name || `3D Layer ${index + 1}`).trim() || `3D Layer ${index + 1}`,
        ...asset,
        visible: safeBool(layer.visible, true),
        locked: safeBool(layer.locked, false),
        autoFit: safeBool(layer.autoFit, false),
        transform: transformFromRaw(layer.transform, fallbackTransform)
      };
    }).filter((layer) => layer.url && (supportedMesh(layer) || supportedSplat(layer)));
  }

  function modelLayerSnapshot(layer) {
    return {
      id: String(layer.id || ''),
      name: String(layer.name || '3D Layer'),
      type: normalizeType(layer.type),
      url: String(layer.url || ''),
      path: String(layer.path || ''),
      format: String(layer.format || ''),
      contentType: String(layer.contentType || 'application/octet-stream'),
      ...(Number.isFinite(Number(layer.bytes)) ? { bytes: Number(layer.bytes) } : {}),
      visible: layer.visible !== false,
      locked: layer.locked === true,
      autoFit: layer.autoFit === true,
      transform: transformSnapshot(layer.transform)
    };
  }

  function lightLayersFromValue(value) {
    if (!Array.isArray(value)) return [];
    return value.map((raw, index) => {
      const layer = raw && typeof raw === 'object' ? raw : {};
      const type = String(layer.type || '').trim().toLowerCase() === 'spot' ? 'spot' : 'point';
      const fallbackTransform = {
        position: [0.15 * (index + 1), 0.15, 0.25],
        scale: 0.25,
        rotation: [-0.5, -0.5, 0]
      };
      return {
        id: String(layer.id || `${type}-${index}`).trim() || `${type}-${index}`,
        name: String(layer.name || `${type === 'spot' ? 'Spot' : 'Point'} Light ${index + 1}`).trim(),
        type,
        color: safeColor(layer.color, '#ffffff'),
        intensity: safeNumber(layer.intensity, type === 'spot' ? 1.2 : 1, 0, 20),
        visible: safeBool(layer.visible, true),
        locked: safeBool(layer.locked, false),
        transform: transformFromRaw(layer.transform, fallbackTransform)
      };
    });
  }

  function lightLayerSnapshot(layer) {
    return {
      id: String(layer.id || ''),
      name: String(layer.name || 'Light'),
      type: String(layer.type || 'point'),
      color: safeColor(layer.color, '#ffffff'),
      intensity: Number(Number(layer.intensity).toFixed(3)),
      visible: layer.visible !== false,
      locked: layer.locked === true,
      transform: transformSnapshot(layer.transform)
    };
  }

  function environmentFromValue(value) {
    const raw = value && typeof value === 'object' ? value : {};
    const url = String(raw.url || raw.assetUrl || '').trim();
    if (!url) return {};
    return {
      url,
      path: String(raw.path || raw.assetPath || '').trim(),
      name: String(raw.name || 'Environment').trim() || 'Environment',
      format: String(raw.format || '').trim().toLowerCase(),
      contentType: String(raw.contentType || 'application/octet-stream').trim() || 'application/octet-stream',
      bytes: Number.isFinite(Number(raw.bytes)) ? Number(raw.bytes) : undefined
    };
  }

  function environmentSnapshot(environment) {
    const next = environmentFromValue(environment);
    if (!next.url) return {};
    return {
      url: next.url,
      path: next.path,
      name: next.name,
      format: next.format,
      contentType: next.contentType,
      ...(Number.isFinite(Number(next.bytes)) ? { bytes: Number(next.bytes) } : {})
    };
  }

  function viewerStateFromPayload(payload) {
    const raw = payload && typeof payload.viewer === 'object' ? payload.viewer : {};
    const imageLayers = imageLayersFromValue(raw.imageLayers);
    const modelLayers = modelLayersFromValue(raw.modelLayers);
    const lightLayers = lightLayersFromValue(raw.lightLayers);
    const rawSelected = String(raw.selectedLayerId || '').trim();
    return {
      gridVisible: safeBool(raw.gridVisible, DEFAULT_VIEWER_STATE.gridVisible),
      fogVisible: safeBool(raw.fogVisible, DEFAULT_VIEWER_STATE.fogVisible),
      dartsVisible: safeBool(raw.dartsVisible, DEFAULT_VIEWER_STATE.dartsVisible),
      objectVisible: safeBool(raw.objectVisible, DEFAULT_VIEWER_STATE.objectVisible),
      selectedLayerId: rawSelected ||
        (imageLayers[0] ? imageLayers[0].id : '') ||
        (modelLayers[0] ? modelLayers[0].id : '') ||
        (lightLayers[0] ? lightLayers[0].id : ''),
      imageLayers,
      modelLayers,
      lightLayers,
      fogStrength: safeNumber(raw.fogStrength, DEFAULT_VIEWER_STATE.fogStrength, 0, 1),
      fogDepth: safeNumber(raw.fogDepth, DEFAULT_VIEWER_STATE.fogDepth, 0.5, 40),
      fogColor: safeColor(raw.fogColor, DEFAULT_VIEWER_STATE.fogColor),
      backgroundColor: safeColor(raw.backgroundColor, DEFAULT_VIEWER_STATE.backgroundColor),
      gridColor: safeColor(raw.gridColor, DEFAULT_VIEWER_STATE.gridColor),
      ambientColor: safeColor(raw.ambientColor, DEFAULT_VIEWER_STATE.ambientColor),
      ambientIntensity: safeNumber(raw.ambientIntensity, DEFAULT_VIEWER_STATE.ambientIntensity, 0, 5),
      sunColor: safeColor(raw.sunColor, DEFAULT_VIEWER_STATE.sunColor),
      sunIntensity: safeNumber(raw.sunIntensity, DEFAULT_VIEWER_STATE.sunIntensity, 0, 10),
      sunDirection: numberList(raw.sunDirection, DEFAULT_VIEWER_STATE.sunDirection),
      environment: environmentFromValue(raw.environment),
      environmentLightingEnabled: safeBool(raw.environmentLightingEnabled, DEFAULT_VIEWER_STATE.environmentLightingEnabled),
      autoFitPrimary: safeBool(raw.autoFitPrimary, DEFAULT_VIEWER_STATE.autoFitPrimary),
      autoFitTargetId: String(raw.autoFitTargetId || '').trim(),
      autoFitNonce: Number.isFinite(Number(raw.autoFitNonce)) ? Number(raw.autoFitNonce) : 0,
      trackingSmoothing: safeNumber(raw.trackingSmoothing, DEFAULT_VIEWER_STATE.trackingSmoothing, 0, 1),
      deadZoneX: safeNumber(raw.deadZoneX, DEFAULT_VIEWER_STATE.deadZoneX, 0, 0.2),
      deadZoneY: safeNumber(raw.deadZoneY, DEFAULT_VIEWER_STATE.deadZoneY, 0, 0.2),
      deadZoneZ: safeNumber(raw.deadZoneZ, DEFAULT_VIEWER_STATE.deadZoneZ, 0, 0.4)
    };
  }

  function viewerStateSnapshot(ctx) {
    return {
      gridVisible: ctx.gridPreference === true,
      fogVisible: ctx.fogVisible === true,
      dartsVisible: ctx.dartsVisible === true,
      objectVisible: ctx.objectVisible !== false,
      selectedLayerId: ctx.selectedLayerId || '',
      imageLayers: (ctx.imageLayers || []).map(imageLayerSnapshot),
      modelLayers: (ctx.modelLayers || []).map(modelLayerSnapshot),
      lightLayers: (ctx.lightLayers || []).map(lightLayerSnapshot),
      fogStrength: Number(Number(ctx.fogStrength).toFixed(3)),
      fogDepth: Number(Number(ctx.fogDepth).toFixed(3)),
      fogColor: safeColor(ctx.fogColor, DEFAULT_VIEWER_STATE.fogColor),
      backgroundColor: safeColor(ctx.backgroundColor, DEFAULT_VIEWER_STATE.backgroundColor),
      gridColor: safeColor(ctx.gridColor, DEFAULT_VIEWER_STATE.gridColor),
      ambientColor: safeColor(ctx.ambientColor, DEFAULT_VIEWER_STATE.ambientColor),
      ambientIntensity: Number(Number(ctx.ambientIntensity).toFixed(3)),
      sunColor: safeColor(ctx.sunColor, DEFAULT_VIEWER_STATE.sunColor),
      sunIntensity: Number(Number(ctx.sunIntensity).toFixed(3)),
      sunDirection: vectorSnapshot(ctx.sunDirection),
      environment: environmentSnapshot(ctx.environment),
      environmentLightingEnabled: ctx.environmentLightingEnabled === true,
      autoFitPrimary: ctx.autoFitPrimary === true,
      autoFitTargetId: ctx.autoFitTargetId || '',
      autoFitNonce: Number.isFinite(Number(ctx.autoFitNonce)) ? Number(ctx.autoFitNonce) : 0,
      trackingSmoothing: Number(Number(ctx.trackingSmoothing).toFixed(3)),
      deadZoneX: Number(Number(ctx.deadZoneX).toFixed(3)),
      deadZoneY: Number(Number(ctx.deadZoneY).toFixed(3)),
      deadZoneZ: Number(Number(ctx.deadZoneZ).toFixed(3))
    };
  }

  function hasImageLayers(payload) {
    const state = viewerStateFromPayload(payload);
    return state.imageLayers.length > 0;
  }

  function hasModelLayers(payload) {
    const state = viewerStateFromPayload(payload);
    return state.modelLayers.length > 0;
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
      this.smoothedPose = defaultHeadPose();
      this.hasPose = false;
      this.smoothingAmount = DEFAULT_VIEWER_STATE.trackingSmoothing;
      this.deadZoneX = DEFAULT_VIEWER_STATE.deadZoneX;
      this.deadZoneY = DEFAULT_VIEWER_STATE.deadZoneY;
      this.deadZoneZ = DEFAULT_VIEWER_STATE.deadZoneZ;
    }

    updateSettings(settings) {
      const next = settings && typeof settings === 'object' ? settings : {};
      this.smoothingAmount = safeNumber(next.trackingSmoothing, this.smoothingAmount, 0, 0.95);
      this.deadZoneX = safeNumber(next.deadZoneX, this.deadZoneX, 0, 0.2);
      this.deadZoneY = safeNumber(next.deadZoneY, this.deadZoneY, 0, 0.2);
      this.deadZoneZ = safeNumber(next.deadZoneZ, this.deadZoneZ, 0, 0.4);
    }

    eyeCenter(face, centerIndex, irisIndexes, fallbackIndexes) {
      const center = face[centerIndex];
      if (center) return center;
      const iris = irisIndexes.map((index) => face[index]).filter(Boolean);
      const points = iris.length ? iris : fallbackIndexes.map((index) => face[index]).filter(Boolean);
      if (!points.length) return null;
      return points.reduce(
        (sum, point) => ({
          x: sum.x + point.x / points.length,
          y: sum.y + point.y / points.length
        }),
        { x: 0, y: 0 }
      );
    }

    extractHeadPoseFromLandmarks(landmarks) {
      if (!landmarks || landmarks.length === 0) return null;
      const firstFace = landmarks[0];
      if (!firstFace || firstFace.length < 468) return null;

      const rightEyePupil = this.eyeCenter(firstFace, 468, [469, 470, 471, 472], [33, 133]);
      const leftEyePupil = this.eyeCenter(firstFace, 473, [474, 475, 476, 477], [362, 263]);
      const noseTip = firstFace[1];
      const leftEyeInner = firstFace[133];
      const rightEyeInner = firstFace[362];
      const leftEyeOuter = firstFace[33];
      const rightEyeOuter = firstFace[263];
      if (!leftEyePupil || !rightEyePupil || !leftEyeInner || !rightEyeInner || !noseTip || !leftEyeOuter || !rightEyeOuter) {
        return null;
      }

      const faceX = (leftEyePupil.x + rightEyePupil.x + noseTip.x) / 3;
      const faceY = (leftEyePupil.y + rightEyePupil.y + noseTip.y) / 3;
      const interOcularDist = Math.hypot(
        leftEyePupil.x - rightEyePupil.x,
        leftEyePupil.y - rightEyePupil.y
      );
      const eyeWidth = Math.hypot(
        rightEyeOuter.x - leftEyeOuter.x,
        rightEyeOuter.y - leftEyeOuter.y
      );
      const depthProxy = (interOcularDist + eyeWidth * 0.5) / (this.baseInterOcularDistance * 1.5);
      const clamped = {
        x: clamp(faceX, 0.2, 0.8),
        y: clamp(faceY, 0.2, 0.8),
        z: clamp(depthProxy, 0.5, 2),
        eyes: {
          left: {
            x: clamp(leftEyePupil.x, 0.05, 0.95),
            y: clamp(leftEyePupil.y, 0.05, 0.95)
          },
          right: {
            x: clamp(rightEyePupil.x, 0.05, 0.95),
            y: clamp(rightEyePupil.y, 0.05, 0.95)
          }
        }
      };
      if (!this.hasPose) {
        this.smoothedPose = cloneHeadPose(clamped);
        this.hasPose = true;
        return cloneHeadPose(this.smoothedPose);
      }
      const alpha = clamp(1 - this.smoothingAmount, 0.05, 1);
      const applyValue = (current, target, deadZone) => {
        const delta = target - current;
        if (Math.abs(delta) <= deadZone) return current;
        return current + alpha * delta;
      };
      this.smoothedPose = cloneHeadPose(this.smoothedPose);
      this.smoothedPose.x = applyValue(this.smoothedPose.x, clamped.x, this.deadZoneX);
      this.smoothedPose.y = applyValue(this.smoothedPose.y, clamped.y, this.deadZoneY);
      this.smoothedPose.z = applyValue(this.smoothedPose.z, clamped.z, this.deadZoneZ);
      for (const eye of ['left', 'right']) {
        this.smoothedPose.eyes[eye].x = applyValue(
          this.smoothedPose.eyes[eye].x,
          clamped.eyes[eye].x,
          this.deadZoneX
        );
        this.smoothedPose.eyes[eye].y = applyValue(
          this.smoothedPose.eyes[eye].y,
          clamped.eyes[eye].y,
          this.deadZoneY
        );
      }
      return cloneHeadPose(this.smoothedPose);
    }

    reset() {
      this.smoothedPose = defaultHeadPose();
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
      const calibratedWidth = this.calibration.screenWidthCm * worldScale;
      const calibratedHeight = this.calibration.screenHeightCm * worldScale;
      const pixelAspect = this.calibration.pixelWidth > 0 && this.calibration.pixelHeight > 0
        ? this.calibration.pixelWidth / this.calibration.pixelHeight
        : 0;
      this.screenWidthWorld = calibratedWidth;
      this.screenHeightWorld = pixelAspect > 0
        ? calibratedWidth / pixelAspect
        : calibratedHeight;
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
      const worldPosition = this.headPoseToWorldPosition(headPose || defaultHeadPose());
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
    lastPose: defaultHeadPose(),
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

    activeTrackingSettings() {
      for (const ctx of viewers.values()) {
        if (ctx.trackingEnabled && !ctx.disposed) {
          return {
            trackingSmoothing: ctx.trackingSmoothing,
            deadZoneX: ctx.deadZoneX,
            deadZoneY: ctx.deadZoneY,
            deadZoneZ: ctx.deadZoneZ
          };
        }
      }
      return DEFAULT_VIEWER_STATE;
    },

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
      this.video.width = 320;
      this.video.height = 240;
      this.video.style.cssText = 'position:fixed;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;pointer-events:none;';
      if (!this.video.parentNode) document.body.appendChild(this.video);

      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          width: { ideal: 320, max: 640 },
          height: { ideal: 240, max: 480 },
          frameRate: { ideal: 60, max: 60 },
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
        selfieMode: false,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.65
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
      this.poseTracker.updateSettings(this.activeTrackingSettings());
      const pose = this.poseTracker.extractHeadPoseFromLandmarks(landmarks);
      this.lastPose = cloneHeadPose(pose || this.lastPose || defaultHeadPose());
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
          if (ctx.trackingEnabled) ctx.headPose = defaultHeadPose();
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
      this.showSpatialViewButton = options.showSpatialViewButton === true;
      this.spatialEye = normalizeSpatialEye(options.spatialEye);
      this.viewerState = viewerStateFromPayload(payload);
      this.previewVisible = false;
      this.gridPreference = this.viewerState.gridVisible;
      this.gridVisible = true;
      this.fogVisible = this.viewerState.fogVisible;
      this.dartsVisible = this.viewerState.dartsVisible;
      this.objectVisible = this.viewerState.objectVisible;
      this.imageLayers = this.viewerState.imageLayers.map((layer) => ({
        ...layer,
        transform: transformFromRaw(layer.transform, {
          position: [0, 0, -0.08],
          scale: 0.25,
          rotation: [0, 0, 0]
        })
      }));
      this.modelLayers = this.viewerState.modelLayers.map((layer) => ({
        ...layer,
        transform: transformFromRaw(layer.transform, DEFAULT_TRANSFORM)
      }));
      this.lightLayers = this.viewerState.lightLayers.map((layer) => ({
        ...layer,
        transform: transformFromRaw(layer.transform, {
          position: [0.15, 0.15, 0.25],
          scale: 0.25,
          rotation: [-0.5, -0.5, 0]
        })
      }));
      this.selectedLayerId = this.viewerState.selectedLayerId || (this.imageLayers[0] ? this.imageLayers[0].id : '');
      if (!this.selectedLayerId && this.modelLayers[0]) this.selectedLayerId = this.modelLayers[0].id;
      if (!this.selectedLayerId && this.lightLayers[0]) this.selectedLayerId = this.lightLayers[0].id;
      this.fogStrength = this.viewerState.fogStrength;
      this.fogDepth = this.viewerState.fogDepth;
      this.fogColor = this.viewerState.fogColor;
      this.backgroundColor = this.viewerState.backgroundColor;
      this.gridColor = this.viewerState.gridColor;
      this.ambientColor = this.viewerState.ambientColor;
      this.ambientIntensity = this.viewerState.ambientIntensity;
      this.sunColor = this.viewerState.sunColor;
      this.sunIntensity = this.viewerState.sunIntensity;
      this.sunDirection = numberList(this.viewerState.sunDirection, DEFAULT_VIEWER_STATE.sunDirection);
      this.environment = environmentFromValue(this.viewerState.environment);
      this.environmentLightingEnabled = this.viewerState.environmentLightingEnabled;
      this.environmentTexture = null;
      this.environmentPmrem = null;
      this.environmentLoadKey = '';
      this.autoFitPrimary = this.viewerState.autoFitPrimary;
      this.autoFitTargetId = this.viewerState.autoFitTargetId;
      this.autoFitNonce = this.viewerState.autoFitNonce;
      this.lastAppliedAutoFitNonce = 0;
      this.trackingSmoothing = this.viewerState.trackingSmoothing;
      this.deadZoneX = this.viewerState.deadZoneX;
      this.deadZoneY = this.viewerState.deadZoneY;
      this.deadZoneZ = this.viewerState.deadZoneZ;
      this.debugMode = false;
      this.headPose = defaultHeadPose();
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
      this.imageLayerObjects = [];
      this.imageLayerPromises = [];
      this.imageLayerGroup = null;
      this.modelLayerObjects = new Map();
      this.modelLayerPromises = [];
      this.lightLayerObjects = new Map();
      this.animationMixers = [];
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
      this.scene.background = new this.THREE.Color(this.backgroundColor);
      this.fog = new this.THREE.Fog(this.fogColor, 0.6, 1.6);
      this.scene.fog = this.fog;
      this.camera = new this.THREE.PerspectiveCamera(75, 1, 0.05, 1000);
      this.camera.position.z = 5;
      this.clock = new this.THREE.Clock();
      const calibration = {
        ...getCalibration(),
        pixelWidth: Math.max(1, this.root.clientWidth),
        pixelHeight: Math.max(1, this.root.clientHeight)
      };
      this.offAxisCamera = new OffAxisCamera(this.THREE, this.camera, calibration);
      this.renderer = new this.THREE.WebGLRenderer({ antialias: true, alpha: false });
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1));
      this.renderer.setSize(Math.max(1, this.root.clientWidth), Math.max(1, this.root.clientHeight), false);
      this.renderer.outputColorSpace = this.THREE.SRGBColorSpace;
      this.renderer.domElement.className = 'dx-render-canvas';
      this.root.appendChild(this.renderer.domElement);
      this.pmremGenerator = new this.THREE.PMREMGenerator(this.renderer);

      if (this.modules.spark && this.modules.spark.SparkRenderer) {
        this.scene.add(new this.modules.spark.SparkRenderer({ renderer: this.renderer }));
      }
      this.applySceneBackground();
      this.addLights();
      this.createWireframeRoom();
      this.createDarts();
      this.createImageLayers();
      this.createLightLayers();
      this.createDebugHelpers();
      this.buildChrome();
      this.installContextLossHandler();
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(this.root);
      this.resize();
      this.resumeRender();
      this.ensureTracking();
      this.applyEnvironment();
      notifyViewerStateChanged(this, true);
      notifyTransformChanged(this, true);
      await this.loadAsset();
    }

    addLights() {
      this.ambientLight = new this.THREE.AmbientLight(this.ambientColor, this.ambientIntensity);
      this.sunLight = new this.THREE.DirectionalLight(this.sunColor, this.sunIntensity);
      this.scene.add(this.ambientLight);
      this.scene.add(this.sunLight);
      this.applySceneLighting();
    }

    applySceneBackground() {
      if (!this.scene) return;
      if (this.environmentTexture) {
        this.scene.background = this.environmentTexture;
      } else {
        this.scene.background = new this.THREE.Color(this.backgroundColor);
      }
      if (this.root) this.root.style.background = this.backgroundColor;
    }

    applySceneLighting() {
      if (this.ambientLight) {
        this.ambientLight.color.set(this.ambientColor);
        this.ambientLight.intensity = this.ambientIntensity;
      }
      if (this.sunLight) {
        this.sunLight.color.set(this.sunColor);
        this.sunLight.intensity = this.sunIntensity;
        const direction = numberList(this.sunDirection, DEFAULT_VIEWER_STATE.sunDirection);
        const length = Math.hypot(direction[0], direction[1], direction[2]) || 1;
        this.sunLight.position.set(direction[0] / length, direction[1] / length, direction[2] / length);
      }
      if (this.scene) {
        this.scene.environment = this.environmentLightingEnabled
          ? (this.environmentPmrem || this.environmentTexture || null)
          : null;
      }
    }

    async loadEnvironmentTexture(environment) {
      const env = environmentFromValue(environment);
      if (!env.url || !this.modules.EXRLoader) return null;
      const key = `${env.url}|environment|${env.format || 'exr'}`;
      const cached = textureCache.get(key);
      if (cached) return cached;
      const loader = new this.modules.EXRLoader();
      const promise = loader.loadAsync(env.url).then((texture) => {
        texture.mapping = this.THREE.EquirectangularReflectionMapping;
        texture.userData = texture.userData || {};
        texture.userData.deepxCachedTexture = true;
        return texture;
      });
      textureCache.set(key, promise);
      return promise;
    }

    async applyEnvironment() {
      const env = environmentFromValue(this.environment);
      const key = env.url ? `${env.url}|${env.format || 'exr'}` : '';
      if (key === this.environmentLoadKey) {
        this.applySceneBackground();
        this.applySceneLighting();
        return;
      }
      this.environmentLoadKey = key;
      this.environmentTexture = null;
      if (this.environmentPmrem && typeof this.environmentPmrem.dispose === 'function') {
        try { this.environmentPmrem.dispose(); } catch (_) {}
      }
      this.environmentPmrem = null;
      if (!env.url) {
        this.applySceneBackground();
        this.applySceneLighting();
        return;
      }
      try {
        const texture = await this.loadEnvironmentTexture(env);
        if (this.disposed || key !== this.environmentLoadKey) return;
        this.environmentTexture = texture;
        if (this.pmremGenerator) {
          const pmrem = this.pmremGenerator.fromEquirectangular(texture);
          this.environmentPmrem = pmrem && pmrem.texture ? pmrem.texture : null;
        }
        this.applySceneBackground();
        this.applySceneLighting();
      } catch (error) {
        console.warn('Unable to load EXR environment:', error);
        if (key === this.environmentLoadKey) {
          this.environmentTexture = null;
          this.environmentPmrem = null;
          this.applySceneBackground();
          this.applySceneLighting();
        }
      }
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
      if (!this.asset.url || (!supportedMesh(this.asset) && !supportedSplat(this.asset))) {
        await Promise.allSettled([this.waitForImageLayers(), this.loadModelLayers()]);
        if (this.disposed) return;
        this.assetLoaded = true;
        this.applyObjectVisibility();
        this.applyAutoFitRequest();
        this.setGridVisible(this.gridPreference, { notify: false, preference: false });
        if (this.controlsOpen) this.refreshControlPanel();
        notifyViewerStateChanged(this, true);
        notifyLoadState(this.elementId, 'ready', 1, this.imageLayers.length ? 'Image layers ready' : 'Scene ready');
        return;
      }
      this.updateLoading('Loading 3D asset');
      try {
        this.object = supportedMesh(this.asset)
          ? await this.addTriangleMesh(this.asset, 'Loading 3D mesh')
          : await this.addGaussianSplat(this.asset, 'Loading 3D asset');
        await this.loadModelLayers();
        if (this.disposed) return;
        this.assetLoaded = true;
        this.applyTransform();
        if (this.autoFitPrimary === true) {
          if (this.autoFitPrimaryObject(true)) this.autoFitPrimary = false;
        }
        this.applyModelLayerTransforms();
        this.applyObjectVisibility();
        this.updateModelBounds();
        this.computeScaleRange();
        this.applyAutoFitRequest();
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

    async loadModelLayers() {
      this.modelLayerPromises = this.modelLayers.map((layer) => this.loadModelLayer(layer));
      await Promise.allSettled(this.modelLayerPromises);
    }

    async loadModelLayer(layer) {
      if (!layer || !layer.url) return null;
      const existing = this.modelLayerObjects.get(layer.id);
      if (existing) return existing;
      try {
        const object = supportedMesh(layer)
          ? await this.addTriangleMesh(layer, `Loading ${layer.name}`)
          : await this.addGaussianSplat(layer, `Loading ${layer.name}`);
        if (this.disposed) return null;
        object.userData = object.userData || {};
        object.userData.deepxModelLayerId = layer.id;
        this.modelLayerObjects.set(layer.id, object);
        this.applyModelLayerTransform(layer);
        if (layer.autoFit === true) {
          if (this.autoFitModelLayer(layer, true)) layer.autoFit = false;
        }
        this.applyAutoFitRequest();
        this.applyObjectVisibility();
        return object;
      } catch (error) {
        console.warn('Unable to load 3D layer:', error);
        return null;
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

    async addTriangleMesh(asset, label) {
      const source = asset || this.asset;
      const key = `${assetCacheKey(source)}|gltf`;
      let entry = assetCache.get(key);
      if (!entry) {
        entry = {};
        assetCache.set(key, entry);
      }
      if (!entry.gltf) {
        if (!entry.promise) {
          entry.promise = this.loadGltfForCache(source, key, label || 'Loading 3D mesh');
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
      this.playAnimations(object, entry.gltf.animations);
      return object;
    }

    async loadGltfForCache(asset, key, label) {
      const loader = new this.modules.GLTFLoader();
      let dracoLoader = null;
      if (this.modules.DRACOLoader) {
        dracoLoader = new this.modules.DRACOLoader();
        dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.6/');
        dracoLoader.setDecoderConfig({ type: 'js' });
        loader.setDRACOLoader(dracoLoader);
      }
      let loadUrl = asset.url;
      if (assetLooksLike(asset, 'glb')) {
        loadUrl = await this.fetchObjectUrl(asset.url, label || 'Loading 3D mesh', `${assetCacheKey(asset)}|blob`);
      } else {
        this.updateLoading(label || 'Loading 3D mesh');
      }
      try {
        const gltf = await loader.loadAsync(loadUrl, (event) => {
          if (event && Number.isFinite(event.total) && event.total > 0) {
            this.updateLoading(label || 'Loading 3D mesh', event.loaded / event.total);
          }
        });
        assetCache.set(key, { gltf });
        return gltf;
      } finally {
        if (dracoLoader) dracoLoader.dispose();
      }
    }

    playAnimations(object, clips) {
      if (!object || !Array.isArray(clips) || !clips.length) return;
      const mixer = new this.THREE.AnimationMixer(object);
      for (const clip of clips) {
        try { mixer.clipAction(clip).play(); } catch (_) {}
      }
      this.animationMixers.push(mixer);
    }

    markSharedAsset(object) {
      object.traverse((node) => {
        node.userData = node.userData || {};
        node.userData.deepxSharedAsset = true;
      });
    }

    async addGaussianSplat(asset, label) {
      const source = asset || this.asset;
      const spark = this.modules.spark;
      if (!spark) throw new Error('Spark module failed to load.');
      const Candidate =
        spark.SplatMesh || spark.SparkSplatMesh || spark.GaussianSplatMesh || spark.SplatObject;
      if (!Candidate) throw new Error('Spark loaded, but no supported splat mesh export was found.');
      const loadUrl = await this.fetchObjectUrl(source.url, label || 'Loading 3D asset', `${assetCacheKey(source)}|blob`);
      let object;
      try {
        object = new Candidate({ url: loadUrl, fileType: source.format || undefined });
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
      const thickness = Math.max(roomHeight, roomWidth) / 900;
      const wallMaterial = new this.THREE.MeshStandardMaterial({
        color: this.gridColor || DEFAULT_VIEWER_STATE.gridColor,
        transparent: true,
        opacity: WII_ROOM.gridOpacity,
        depthTest: true,
        depthWrite: true,
        fog: true,
        roughness: 0.82,
        metalness: 0
      });
      const createGridWall = (width, height, includeEdges) => {
        const group = new this.THREE.Group();
        for (let i = 0; i <= gridDivisions; i++) {
          if (!includeEdges && (i === 0 || i === gridDivisions)) continue;
          const t = i / gridDivisions;
          const x = -width / 2 + t * width;
          const y = -height / 2 + t * height;
          const vertical = new this.THREE.Mesh(
            new this.THREE.BoxGeometry(thickness, height, thickness),
            wallMaterial
          );
          vertical.position.x = x;
          const horizontal = new this.THREE.Mesh(
            new this.THREE.BoxGeometry(width, thickness, thickness),
            wallMaterial
          );
          horizontal.position.y = y;
          vertical.receiveShadow = true;
          horizontal.receiveShadow = true;
          group.add(vertical, horizontal);
        }
        return group;
      };
      const backWall = createGridWall(roomWidth, roomHeight, false);
      backWall.position.z = -roomDepth;
      const leftWall = createGridWall(roomDepth, roomHeight, false);
      leftWall.rotation.y = Math.PI / 2;
      leftWall.position.x = -roomWidth / 2;
      leftWall.position.z = -roomDepth / 2;
      const rightWall = createGridWall(roomDepth, roomHeight, false);
      rightWall.rotation.y = -Math.PI / 2;
      rightWall.position.x = roomWidth / 2;
      rightWall.position.z = -roomDepth / 2;
      const floor = createGridWall(roomWidth, roomDepth, false);
      floor.rotation.x = Math.PI / 2;
      floor.position.y = -roomHeight / 2;
      floor.position.z = -roomDepth / 2;
      const ceiling = createGridWall(roomWidth, roomDepth, false);
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
        this.disposeObject(obj);
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

    createImageLayers() {
      this.removeImageLayers();
      const group = new this.THREE.Group();
      group.visible = this.objectVisible;
      this.imageLayerGroup = group;
      this.scene.add(group);
      this.imageLayerObjects = [];
      this.imageLayerPromises = [];
      for (const layer of this.imageLayers) {
        const geometry = new this.THREE.PlaneGeometry(1, 1);
        const material = new this.THREE.MeshBasicMaterial({
          color: 0xffffff,
          transparent: true,
          alphaTest: 0.01,
          depthTest: true,
          depthWrite: false,
          side: this.THREE.DoubleSide,
          fog: true
        });
        const mesh = new this.THREE.Mesh(geometry, material);
        mesh.userData.deepxImageLayerId = layer.id;
        mesh.userData.deepxImageLayerAspect = 1;
        mesh.visible = layer.visible !== false;
        group.add(mesh);
        this.imageLayerObjects.push(mesh);
        this.applyImageLayerTransform(layer);
        const promise = this.loadTexture(layer.url)
          .then((texture) => {
            if (this.disposed) return;
            material.map = texture;
            const image = texture.image || {};
            const width = Number(image.width) || 1;
            const height = Number(image.height) || 1;
            mesh.userData.deepxImageLayerAspect = width / Math.max(height, 1);
            material.needsUpdate = true;
            this.applyImageLayerTransform(layer);
            if (layer.autoFit === true) {
              if (this.autoFitImageLayer(layer, true)) layer.autoFit = false;
            }
            this.applyAutoFitRequest();
          })
          .catch((error) => console.warn('Unable to load PNG layer:', error));
        this.imageLayerPromises.push(promise);
      }
    }

    async waitForImageLayers() {
      if (!this.imageLayerPromises || !this.imageLayerPromises.length) return;
      await Promise.allSettled(this.imageLayerPromises);
    }

    removeImageLayers() {
      if (this.imageLayerGroup) {
        this.scene.remove(this.imageLayerGroup);
        this.disposeObject(this.imageLayerGroup);
      }
      this.imageLayerGroup = null;
      this.imageLayerObjects = [];
    }

    selectedImageLayer() {
      if (!this.selectedLayerId) return null;
      return this.imageLayers.find((layer) => layer.id === this.selectedLayerId) || null;
    }

    imageLayerMesh(id) {
      return this.imageLayerObjects.find((mesh) => mesh.userData && mesh.userData.deepxImageLayerId === id) || null;
    }

    applyImageLayerTransform(layer) {
      const mesh = layer ? this.imageLayerMesh(layer.id) : null;
      if (!mesh) return;
      const transform = layer.transform;
      const aspect = Number(mesh.userData.deepxImageLayerAspect) || 1;
      mesh.position.set(transform.position[0], transform.position[1], transform.position[2]);
      mesh.rotation.set(transform.rotation[0], transform.rotation[1], transform.rotation[2]);
      mesh.scale.set(transform.scale * aspect, transform.scale, transform.scale);
      mesh.visible = layer.visible !== false;
    }

    applyImageLayerTransforms() {
      for (const layer of this.imageLayers) this.applyImageLayerTransform(layer);
    }

    selectedModelLayer() {
      if (!this.selectedLayerId) return null;
      return this.modelLayers.find((layer) => layer.id === this.selectedLayerId) || null;
    }

    modelLayerObject(id) {
      return this.modelLayerObjects.get(id) || null;
    }

    applyModelLayerTransform(layer) {
      const object = layer ? this.modelLayerObject(layer.id) : null;
      if (!object) return;
      const transform = layer.transform;
      object.position.set(transform.position[0], transform.position[1], transform.position[2]);
      object.scale.set(transform.scale, transform.scale, transform.scale);
      object.rotation.set(transform.rotation[0], transform.rotation[1], transform.rotation[2]);
      object.visible = this.objectVisible && layer.visible !== false;
    }

    applyModelLayerTransforms() {
      for (const layer of this.modelLayers) this.applyModelLayerTransform(layer);
    }

    finiteBox(box) {
      if (!box || typeof box.isEmpty !== 'function' || box.isEmpty()) return false;
      const values = [
        box.min.x, box.min.y, box.min.z,
        box.max.x, box.max.y, box.max.z
      ];
      return values.every((value) => Number.isFinite(value));
    }

    fitObjectTransformToGrid(object, transform, applyTransform) {
      if (!object || !transform || typeof applyTransform !== 'function') return false;
      const screenDims = this.offAxisCamera.getScreenDimensions();
      applyTransform();
      object.updateMatrixWorld(true);
      const box = new this.THREE.Box3().setFromObject(object);
      if (!this.finiteBox(box)) {
        transform.position = [0, 0, -screenDims.height * 0.72];
        transform.scale = clamp(transform.scale || DEFAULT_TRANSFORM.scale, 0.001, 100);
        applyTransform();
        return true;
      }
      const size = new this.THREE.Vector3();
      box.getSize(size);
      const fitWidth = screenDims.width * 0.58;
      const fitHeight = screenDims.height * 0.58;
      const fitDepth = screenDims.height * 2.5;
      const factors = [
        size.x > 1e-6 ? fitWidth / size.x : Number.POSITIVE_INFINITY,
        size.y > 1e-6 ? fitHeight / size.y : Number.POSITIVE_INFINITY,
        size.z > 1e-6 ? fitDepth / size.z : Number.POSITIVE_INFINITY
      ].filter((value) => Number.isFinite(value) && value > 0);
      const factor = factors.length ? Math.min(...factors) : 1;
      transform.scale = clamp((transform.scale || DEFAULT_TRANSFORM.scale) * factor, 0.001, 100);
      applyTransform();
      object.updateMatrixWorld(true);
      const fittedBox = new this.THREE.Box3().setFromObject(object);
      if (!this.finiteBox(fittedBox)) return true;
      const center = new this.THREE.Vector3();
      fittedBox.getCenter(center);
      const targetZ = -screenDims.height * 0.72;
      transform.position = [
        Number((transform.position[0] - center.x).toFixed(5)),
        Number((transform.position[1] - center.y).toFixed(5)),
        Number((transform.position[2] + targetZ - center.z).toFixed(5))
      ];
      applyTransform();
      return true;
    }

    autoFitPrimaryObject(force) {
      if (!this.object) return false;
      if (!force && this.selectedLayerId) return false;
      const fitted = this.fitObjectTransformToGrid(
        this.object,
        this.transform,
        () => this.applyTransform()
      );
      if (fitted) {
        this.updateModelBounds();
        this.computeScaleRange();
        notifyTransformChanged(this, true);
      }
      return fitted;
    }

    autoFitModelLayer(layer, force) {
      if (!layer || (!force && layer.locked === true)) return false;
      const object = this.modelLayerObject(layer.id);
      if (!object) return false;
      const fitted = this.fitObjectTransformToGrid(
        object,
        layer.transform,
        () => this.applyModelLayerTransform(layer)
      );
      if (fitted) {
        this.computeScaleRange();
        notifyViewerStateChanged(this, true);
      }
      return fitted;
    }

    autoFitImageLayer(layer, force) {
      if (!layer || (!force && layer.locked === true)) return false;
      const object = this.imageLayerMesh(layer.id);
      if (!object) return false;
      const fitted = this.fitObjectTransformToGrid(
        object,
        layer.transform,
        () => this.applyImageLayerTransform(layer)
      );
      if (fitted) {
        this.computeScaleRange();
        notifyViewerStateChanged(this, true);
      }
      return fitted;
    }

    applyAutoFitRequest() {
      if (!Number.isFinite(Number(this.autoFitNonce)) || this.autoFitNonce <= 0) return;
      if (this.autoFitNonce === this.lastAppliedAutoFitNonce) return;
      const targetId = String(this.autoFitTargetId || '').trim();
      let fitted = false;
      if (!targetId) {
        fitted = this.autoFitPrimaryObject(true);
      } else {
        const modelLayer = this.modelLayers.find((layer) => layer.id === targetId);
        const imageLayer = this.imageLayers.find((layer) => layer.id === targetId);
        if (modelLayer) fitted = this.autoFitModelLayer(modelLayer, false);
        if (imageLayer) fitted = this.autoFitImageLayer(imageLayer, false);
      }
      if (fitted) {
        this.lastAppliedAutoFitNonce = this.autoFitNonce;
        this.autoFitPrimary = false;
        notifyViewerStateChanged(this, true);
        if (this.controlsOpen) this.refreshControlPanel();
      }
    }

    removeModelLayers() {
      for (const object of this.modelLayerObjects.values()) {
        this.scene.remove(object);
        this.disposeObject(object);
      }
      this.modelLayerObjects.clear();
      this.modelLayerPromises = [];
    }

    syncModelLayers(nextLayers) {
      const nextIds = new Set(nextLayers.map((layer) => layer.id));
      for (const [id, object] of this.modelLayerObjects.entries()) {
        if (!nextIds.has(id)) {
          this.scene.remove(object);
          this.disposeObject(object);
          this.modelLayerObjects.delete(id);
        }
      }
      this.modelLayers = nextLayers;
      for (const layer of this.modelLayers) {
        if (this.modelLayerObjects.has(layer.id)) {
          this.applyModelLayerTransform(layer);
        } else {
          this.loadModelLayer(layer);
        }
      }
    }

    createLightLayers() {
      this.removeLightLayers();
      for (const layer of this.lightLayers) this.addLightLayerObject(layer);
      this.applyObjectVisibility();
    }

    addLightLayer(type) {
      const normalizedType = type === 'spot' ? 'spot' : 'point';
      const id = `${normalizedType}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
      const layer = {
        id,
        name: `${normalizedType === 'spot' ? 'Spot' : 'Point'} Light ${this.lightLayers.length + 1}`,
        type: normalizedType,
        color: '#ffffff',
        intensity: normalizedType === 'spot' ? 1.2 : 1,
        visible: true,
        locked: false,
        transform: {
          position: [0.18, 0.16, 0.28],
          scale: 0.25,
          rotation: [-0.55, -0.45, 0]
        }
      };
      this.lightLayers.push(layer);
      this.selectedLayerId = id;
      this.addLightLayerObject(layer);
      this.applyObjectVisibility();
      notifyViewerStateChanged(this);
      this.refreshControlPanel();
    }

    addLightLayerObject(layer) {
      let light;
      let target = null;
      if (layer.type === 'spot') {
        light = new this.THREE.SpotLight(layer.color, layer.intensity, 0, Math.PI / 5, 0.35, 1);
        target = new this.THREE.Object3D();
        light.target = target;
        this.scene.add(target);
      } else {
        light = new this.THREE.PointLight(layer.color, layer.intensity, 0, 1);
      }
      light.userData = light.userData || {};
      light.userData.deepxLightLayerId = layer.id;
      this.scene.add(light);
      this.lightLayerObjects.set(layer.id, { light, target });
      this.applyLightLayerTransform(layer);
    }

    selectedLightLayer() {
      if (!this.selectedLayerId) return null;
      return this.lightLayers.find((layer) => layer.id === this.selectedLayerId) || null;
    }

    selectedEditableLayer() {
      return this.selectedImageLayer() || this.selectedModelLayer() || this.selectedLightLayer();
    }

    selectedLayerLocked() {
      const layer = this.selectedEditableLayer();
      return !!(layer && layer.locked === true);
    }

    lightLayerObject(id) {
      return this.lightLayerObjects.get(id) || null;
    }

    applyLightLayerTransform(layer) {
      const entry = layer ? this.lightLayerObject(layer.id) : null;
      if (!entry || !entry.light) return;
      const transform = layer.transform;
      entry.light.position.set(transform.position[0], transform.position[1], transform.position[2]);
      entry.light.color.set(layer.color);
      entry.light.intensity = layer.intensity;
      entry.light.visible = layer.visible !== false;
      const distance = Math.max(0, transform.scale * 20);
      entry.light.distance = distance;
      if (layer.type === 'spot') {
        entry.light.angle = clamp(transform.scale, 0.03, Math.PI / 2);
        const direction = new this.THREE.Vector3(0, 0, -1).applyEuler(
          new this.THREE.Euler(transform.rotation[0], transform.rotation[1], transform.rotation[2])
        );
        if (entry.target) {
          entry.target.position.set(
            transform.position[0] + direction.x,
            transform.position[1] + direction.y,
            transform.position[2] + direction.z
          );
          entry.target.updateMatrixWorld();
          entry.target.visible = layer.visible !== false;
        }
      }
    }

    applyLightLayerTransforms() {
      for (const layer of this.lightLayers) this.applyLightLayerTransform(layer);
    }

    removeLightLayers() {
      for (const entry of this.lightLayerObjects.values()) {
        if (entry.light) {
          this.scene.remove(entry.light);
          this.disposeObject(entry.light);
        }
        if (entry.target) this.scene.remove(entry.target);
      }
      this.lightLayerObjects.clear();
    }

    syncLightLayers(nextLayers) {
      const nextIds = new Set(nextLayers.map((layer) => layer.id));
      for (const [id, entry] of this.lightLayerObjects.entries()) {
        if (!nextIds.has(id)) {
          if (entry.light) {
            this.scene.remove(entry.light);
            this.disposeObject(entry.light);
          }
          if (entry.target) this.scene.remove(entry.target);
          this.lightLayerObjects.delete(id);
        }
      }
      this.lightLayers = nextLayers;
      for (const layer of this.lightLayers) {
        if (this.lightLayerObjects.has(layer.id)) {
          this.applyLightLayerTransform(layer);
        } else {
          this.addLightLayerObject(layer);
        }
      }
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

    activeImageLayerTransform() {
      const layer = this.selectedImageLayer();
      return layer ? layer.transform : null;
    }

    activeModelLayerTransform() {
      const layer = this.selectedModelLayer();
      return layer ? layer.transform : null;
    }

    activeLightLayerTransform() {
      const layer = this.selectedLightLayer();
      return layer ? layer.transform : null;
    }

    activeTransform() {
      return this.activeImageLayerTransform() ||
        this.activeModelLayerTransform() ||
        this.activeLightLayerTransform() ||
        this.transform;
    }

    computeScaleRange() {
      const lightTransform = this.activeLightLayerTransform();
      if (lightTransform) {
        const current = Math.max(Number(lightTransform.scale) || 0.25, 0.001);
        this.scaleRange = {
          min: clamp(Math.min(0.001, current / 20), 0.001, 100),
          max: clamp(Math.max(2, current * 20), 0.001, 100)
        };
        return this.scaleRange;
      }
      const layerTransform = this.activeImageLayerTransform();
      if (layerTransform) {
        const current = Math.max(Number(layerTransform.scale) || 0.25, 0.001);
        this.scaleRange = {
          min: clamp(Math.min(0.001, current / 20), 0.001, 100),
          max: clamp(Math.max(2, current * 20), 0.001, 100)
        };
        return this.scaleRange;
      }
      const modelTransform = this.activeModelLayerTransform();
      if (modelTransform) {
        const current = Math.max(Number(modelTransform.scale) || DEFAULT_TRANSFORM.scale, 0.001);
        this.scaleRange = {
          min: clamp(Math.min(0.001, current / 20), 0.001, 100),
          max: clamp(Math.max(2, current * 20), 0.001, 100)
        };
        return this.scaleRange;
      }
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
      this.trackingControls = document.createElement('div');
      this.trackingControls.className = 'dx-tracking-controls';
      this.statsPanel = document.createElement('div');
      this.statsPanel.className = 'dx-camera-stats';
      this.previewVideo = document.createElement('video');
      this.previewVideo.autoplay = true;
      this.previewVideo.muted = true;
      this.previewVideo.playsInline = true;
      this.previewCanvas = document.createElement('canvas');
      this.previewCanvas.width = 320;
      this.previewCanvas.height = 240;
      this.buildTrackingControls();
      this.preview.appendChild(this.trackingControls);
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
      body.appendChild(this.makeSceneControls());
      body.appendChild(this.makeAddLightControls());
      if (this.imageLayers.length || this.modelLayers.length || this.lightLayers.length) {
        body.appendChild(this.makeLayerSelector());
      }
      const active = this.activeTransform();
      body.appendChild(this.makeRange('Position X', active.position[0], -1, 1, 0.001, (value) => this.setPositionAxis(0, value)));
      body.appendChild(this.makeRange('Position Y', active.position[1], -1, 1, 0.001, (value) => this.setPositionAxis(1, value)));
      body.appendChild(this.makeRange('Position Z', active.position[2], -2, 1, 0.001, (value) => this.setPositionAxis(2, value)));
      const scaleGroup = document.createElement('div');
      scaleGroup.className = 'dx-control-group';
      this.computeScaleRange();
      scaleGroup.appendChild(this.makeLogRange('Scale', active.scale, this.scaleRange.min, this.scaleRange.max, (value) => this.setScale(value)));
      body.appendChild(scaleGroup);
      const rotationGroup = document.createElement('div');
      rotationGroup.className = 'dx-control-group';
      const formatDegrees = (value) => `${(value * 180 / Math.PI).toFixed(1)}deg`;
      rotationGroup.appendChild(this.makeRange('Rotation X', active.rotation[0], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(0, value), formatDegrees));
      rotationGroup.appendChild(this.makeRange('Rotation Y', active.rotation[1], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(1, value), formatDegrees));
      rotationGroup.appendChild(this.makeRange('Rotation Z', active.rotation[2], -Math.PI, Math.PI, 0.001, (value) => this.setRotationAxis(2, value), formatDegrees));
      body.appendChild(rotationGroup);
      const selectedLight = this.selectedLightLayer();
      if (selectedLight) {
        const lightGroup = document.createElement('div');
        lightGroup.className = 'dx-control-group';
        lightGroup.appendChild(this.makeRange('Light Intensity', selectedLight.intensity, 0, 20, 0.001, (value) => this.setSelectedLightIntensity(value)));
        lightGroup.appendChild(this.makeColorControl('Light Color', selectedLight.color, (value) => this.setSelectedLightColor(value)));
        body.appendChild(lightGroup);
      }
      panel.appendChild(body);
      this.modelPanel.appendChild(panel);
    }

    makeSceneControls() {
      const group = document.createElement('div');
      group.className = 'dx-control-group';
      group.appendChild(this.makeRange('Fog Strength', this.fogStrength, 0, 1, 0.001, (value) => this.setSceneSetting('fogStrength', value)));
      group.appendChild(this.makeRange('Fog Length', this.fogDepth, 0.5, 40, 0.001, (value) => this.setSceneSetting('fogDepth', value)));
      group.appendChild(this.makeRange('Ambient Light', this.ambientIntensity, 0, 5, 0.001, (value) => this.setSceneSetting('ambientIntensity', value)));
      group.appendChild(this.makeColorControl('Ambient Color', this.ambientColor, (value) => this.setSceneSetting('ambientColor', value)));
      group.appendChild(this.makeRange('Sun Light', this.sunIntensity, 0, 10, 0.001, (value) => this.setSceneSetting('sunIntensity', value)));
      group.appendChild(this.makeColorControl('Sun Color', this.sunColor, (value) => this.setSceneSetting('sunColor', value)));
      group.appendChild(this.makeRange('Sun Dir X', this.sunDirection[0], -2, 2, 0.001, (value) => this.setSunDirectionAxis(0, value)));
      group.appendChild(this.makeRange('Sun Dir Y', this.sunDirection[1], -2, 2, 0.001, (value) => this.setSunDirectionAxis(1, value)));
      group.appendChild(this.makeRange('Sun Dir Z', this.sunDirection[2], -2, 2, 0.001, (value) => this.setSunDirectionAxis(2, value)));
      return group;
    }

    makeAddLightControls() {
      const row = document.createElement('div');
      row.className = 'dx-control-row';
      row.append(
        this.makeButton('+ POINT', 'Add point light', () => this.addLightLayer('point')),
        this.makeButton('+ SPOT', 'Add spot light', () => this.addLightLayer('spot'))
      );
      return row;
    }

    makeLayerSelector() {
      const wrap = document.createElement('div');
      wrap.className = 'dx-control';
      const label = document.createElement('label');
      label.textContent = 'Selected Object';
      const select = document.createElement('select');
      select.className = 'dx-layer-select';
      const canSelectObject = !!this.object || !!this.asset.url;
      if (canSelectObject) {
        const option = document.createElement('option');
        option.value = '__object__';
        option.textContent = '3D Object';
        select.appendChild(option);
      }
      for (const layer of this.modelLayers) {
        const option = document.createElement('option');
        option.value = layer.id;
        option.textContent = `3D: ${layer.name}`;
        select.appendChild(option);
      }
      for (const layer of this.imageLayers) {
        const option = document.createElement('option');
        option.value = layer.id;
        option.textContent = `PNG: ${layer.name}`;
        select.appendChild(option);
      }
      for (const layer of this.lightLayers) {
        const option = document.createElement('option');
        option.value = layer.id;
        option.textContent = `${layer.type === 'spot' ? 'Spot' : 'Point'}: ${layer.name}`;
        select.appendChild(option);
      }
      if (!canSelectObject && !this.selectedImageLayer() && !this.selectedModelLayer() && !this.selectedLightLayer()) {
        this.selectedLayerId =
          (this.modelLayers[0] && this.modelLayers[0].id) ||
          (this.imageLayers[0] && this.imageLayers[0].id) ||
          (this.lightLayers[0] && this.lightLayers[0].id) ||
          '';
      }
      select.value = (this.selectedImageLayer() || this.selectedModelLayer() || this.selectedLightLayer())
        ? this.selectedLayerId
        : '__object__';
      select.addEventListener('change', () => {
        this.selectedLayerId = select.value === '__object__' ? '' : select.value;
        notifyViewerStateChanged(this);
        this.refreshControlPanel();
      });
      wrap.append(label, select);
      return wrap;
    }

    buildTrackingControls() {
      if (!this.trackingControls) return;
      this.trackingControls.innerHTML = '';
      this.trackingControls.append(
        this.makeTrackingRange('Smoothing', this.trackingSmoothing, 0, 0.95, 0.001, (value) => this.setTrackingSettings({ trackingSmoothing: value }, true)),
        this.makeTrackingRange('Dead X', this.deadZoneX, 0, 0.2, 0.001, (value) => this.setTrackingSettings({ deadZoneX: value }, true)),
        this.makeTrackingRange('Dead Y', this.deadZoneY, 0, 0.2, 0.001, (value) => this.setTrackingSettings({ deadZoneY: value }, true)),
        this.makeTrackingRange('Dead Z', this.deadZoneZ, 0, 0.4, 0.001, (value) => this.setTrackingSettings({ deadZoneZ: value }, true))
      );
    }

    makeTrackingRange(label, value, min, max, step, onInput) {
      const wrap = document.createElement('label');
      wrap.className = 'dx-tracking-control';
      const text = document.createElement('span');
      text.textContent = label;
      const input = document.createElement('input');
      input.type = 'range';
      input.min = String(min);
      input.max = String(max);
      input.step = String(step);
      input.value = String(clamp(value, min, max));
      const output = document.createElement('span');
      output.className = 'dx-tracking-value';
      const updateOutput = (next) => {
        output.textContent = Number(next).toFixed(3);
      };
      updateOutput(value);
      input.addEventListener('input', () => {
        const next = Number(input.value);
        updateOutput(next);
        onInput(next);
      });
      wrap.append(text, input, output);
      return wrap;
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

    makeLogRange(label, value, min, max, onInput) {
      const safeMin = Math.max(0.001, Number(min) || 0.001);
      const safeMax = Math.max(safeMin * 1.001, Number(max) || safeMin * 1.001);
      const ratio = safeMax / safeMin;
      const wrap = document.createElement('div');
      wrap.className = 'dx-control';
      const text = document.createElement('label');
      const renderValue = (next) => {
        text.textContent = `${label}: ${Number(next).toFixed(4)}`;
      };
      const toSlider = (next) => {
        const clamped = clamp(Number(next) || safeMin, safeMin, safeMax);
        return clamp(Math.log(clamped / safeMin) / Math.log(ratio), 0, 1);
      };
      const fromSlider = (next) => {
        const scaled = safeMin * Math.pow(ratio, clamp(Number(next) || 0, 0, 1));
        return clamp(Number(scaled.toFixed(5)), safeMin, safeMax);
      };
      const input = document.createElement('input');
      input.type = 'range';
      input.min = '0';
      input.max = '1';
      input.step = '0.001';
      input.value = String(toSlider(value));
      renderValue(clamp(Number(value) || safeMin, safeMin, safeMax));
      input.addEventListener('input', () => {
        const next = fromSlider(input.value);
        renderValue(next);
        onInput(next);
      });
      wrap.appendChild(text);
      wrap.appendChild(input);
      return wrap;
    }

    makeColorControl(label, value, onInput) {
      const wrap = document.createElement('label');
      wrap.className = 'dx-color-control';
      const text = document.createElement('span');
      text.textContent = `${label}: ${safeColor(value, '#ffffff')}`;
      const input = document.createElement('input');
      input.type = 'color';
      input.value = safeColor(value, '#ffffff');
      input.addEventListener('input', () => {
        const next = safeColor(input.value, '#ffffff');
        text.textContent = `${label}: ${next}`;
        onInput(next);
      });
      wrap.append(text, input);
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
      const preview = this.makeButton('CAM', 'Toggle camera preview', () => {
        this.setPreviewVisible(!this.previewVisible);
        preview.classList.toggle('is-active', this.previewVisible);
      });
      const reset = this.makeButton('RST', 'Reset model transform', () => this.resetTransform());
      const spatial = this.makeButton('Spatial View', 'Open spatial view', () => this.requestSpatialView());
      spatial.classList.add('dx-spatial-button');
      this.gridButton = grid;
      this.dartsButton = darts;
      this.objectButton = object;
      this.previewButton = preview;
      if (this.showSpatialViewButton) buttons.append(spatial);
      buttons.append(fullscreen, settings, debug, grid, darts, object, preview, reset);
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

    requestSpatialView() {
      window.parent.postMessage({
        type: 'deepx-off-axis-spatial-view-requested',
        elementId: this.elementId
      }, '*');
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
      this.applyImageLayerTransforms();
      this.applyModelLayerTransforms();
      this.applyLightLayerTransforms();
      this.applySceneLighting();
      this.updateFog();
      this.setGridVisible(this.gridVisible, { notify: false, preference: false });
      this.setDartsVisible(this.dartsVisible, false);
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

    setFogVisible(visible, notify) {
      this.fogVisible = visible === true;
      this.updateFog();
      if (notify) notifyViewerStateChanged(this);
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
      if (this.imageLayerGroup) {
        this.imageLayerGroup.visible = this.objectVisible;
        for (const layer of this.imageLayers) this.applyImageLayerTransform(layer);
      }
      for (const layer of this.modelLayers) {
        const object = this.modelLayerObject(layer.id);
        if (object) object.visible = this.objectVisible && layer.visible !== false;
      }
    }

    setSceneSetting(key, value) {
      if (key === 'fogStrength') this.fogStrength = safeNumber(value, this.fogStrength, 0, 1);
      if (key === 'fogDepth') this.fogDepth = safeNumber(value, this.fogDepth, 0.5, 40);
      if (key === 'fogColor') this.fogColor = safeColor(value, this.fogColor);
      if (key === 'backgroundColor') this.backgroundColor = safeColor(value, this.backgroundColor);
      if (key === 'gridColor') this.gridColor = safeColor(value, this.gridColor);
      if (key === 'ambientIntensity') this.ambientIntensity = safeNumber(value, this.ambientIntensity, 0, 5);
      if (key === 'ambientColor') this.ambientColor = safeColor(value, this.ambientColor);
      if (key === 'sunIntensity') this.sunIntensity = safeNumber(value, this.sunIntensity, 0, 10);
      if (key === 'sunColor') this.sunColor = safeColor(value, this.sunColor);
      if (key === 'environmentLightingEnabled') this.environmentLightingEnabled = value === true;
      if (key === 'environment') this.environment = environmentFromValue(value);
      if (key === 'gridColor') this.createWireframeRoom();
      this.applySceneBackground();
      this.applySceneLighting();
      this.updateFog();
      if (key === 'environment') this.applyEnvironment();
      notifyViewerStateChanged(this);
    }

    setSunDirectionAxis(index, value) {
      this.sunDirection[index] = safeNumber(value, this.sunDirection[index], -2, 2);
      this.applySceneLighting();
      notifyViewerStateChanged(this);
    }

    setViewerState(state, notify) {
      const next = {
        ...DEFAULT_VIEWER_STATE,
        ...(state && typeof state === 'object' ? state : {})
      };
      this.gridPreference = safeBool(next.gridVisible, DEFAULT_VIEWER_STATE.gridVisible);
      this.fogVisible = safeBool(next.fogVisible, DEFAULT_VIEWER_STATE.fogVisible);
      const shouldShowGrid = this.assetLoaded ? this.gridPreference : (this.gridPreference || !this.assetLoaded);
      this.setGridVisible(shouldShowGrid, { notify: false, preference: false });
      this.setDartsVisible(safeBool(next.dartsVisible, DEFAULT_VIEWER_STATE.dartsVisible), false);
      this.setObjectVisible(safeBool(next.objectVisible, DEFAULT_VIEWER_STATE.objectVisible), false);
      const incomingLayers = imageLayersFromValue(next.imageLayers);
      const oldLayerKey = JSON.stringify((this.imageLayers || []).map(imageLayerSnapshot));
      const newLayerKey = JSON.stringify(incomingLayers.map(imageLayerSnapshot));
      if (oldLayerKey !== newLayerKey) {
        this.imageLayers = incomingLayers;
        this.selectedLayerId = String(next.selectedLayerId || '').trim() ||
          (this.imageLayers[0] ? this.imageLayers[0].id : '') ||
          (this.modelLayers[0] ? this.modelLayers[0].id : '') ||
          (this.lightLayers[0] ? this.lightLayers[0].id : '');
        this.createImageLayers();
        this.applyObjectVisibility();
        if (this.controlsOpen) this.refreshControlPanel();
      } else {
        this.selectedLayerId = String(next.selectedLayerId || '').trim();
      }
      const incomingModels = modelLayersFromValue(next.modelLayers);
      const oldModelKey = JSON.stringify((this.modelLayers || []).map(modelLayerSnapshot));
      const newModelKey = JSON.stringify(incomingModels.map(modelLayerSnapshot));
      if (oldModelKey !== newModelKey) {
        this.syncModelLayers(incomingModels);
        this.applyObjectVisibility();
        if (this.controlsOpen) this.refreshControlPanel();
      }
      const incomingLights = lightLayersFromValue(next.lightLayers);
      const oldLightKey = JSON.stringify((this.lightLayers || []).map(lightLayerSnapshot));
      const newLightKey = JSON.stringify(incomingLights.map(lightLayerSnapshot));
      if (oldLightKey !== newLightKey) {
        this.syncLightLayers(incomingLights);
        if (this.controlsOpen) this.refreshControlPanel();
      }
      this.fogStrength = safeNumber(next.fogStrength, DEFAULT_VIEWER_STATE.fogStrength, 0, 1);
      this.fogDepth = safeNumber(next.fogDepth, DEFAULT_VIEWER_STATE.fogDepth, 0.5, 40);
      this.fogColor = safeColor(next.fogColor, DEFAULT_VIEWER_STATE.fogColor);
      const nextBackgroundColor = safeColor(next.backgroundColor, DEFAULT_VIEWER_STATE.backgroundColor);
      const nextGridColor = safeColor(next.gridColor, DEFAULT_VIEWER_STATE.gridColor);
      const gridColorChanged = nextGridColor !== this.gridColor;
      this.backgroundColor = nextBackgroundColor;
      this.gridColor = nextGridColor;
      this.ambientColor = safeColor(next.ambientColor, DEFAULT_VIEWER_STATE.ambientColor);
      this.ambientIntensity = safeNumber(next.ambientIntensity, DEFAULT_VIEWER_STATE.ambientIntensity, 0, 5);
      this.sunColor = safeColor(next.sunColor, DEFAULT_VIEWER_STATE.sunColor);
      this.sunIntensity = safeNumber(next.sunIntensity, DEFAULT_VIEWER_STATE.sunIntensity, 0, 10);
      this.sunDirection = numberList(next.sunDirection, DEFAULT_VIEWER_STATE.sunDirection);
      this.environment = environmentFromValue(next.environment);
      this.environmentLightingEnabled = safeBool(next.environmentLightingEnabled, DEFAULT_VIEWER_STATE.environmentLightingEnabled);
      this.autoFitPrimary = safeBool(next.autoFitPrimary, DEFAULT_VIEWER_STATE.autoFitPrimary);
      this.autoFitTargetId = String(next.autoFitTargetId || '').trim();
      this.autoFitNonce = Number.isFinite(Number(next.autoFitNonce)) ? Number(next.autoFitNonce) : 0;
      if (gridColorChanged) this.createWireframeRoom();
      this.applySceneBackground();
      this.applySceneLighting();
      this.updateFog();
      this.applyEnvironment();
      if (this.autoFitPrimary === true && this.object) {
        if (this.autoFitPrimaryObject(true)) this.autoFitPrimary = false;
      }
      this.applyAutoFitRequest();
      this.setTrackingSettings({
        trackingSmoothing: safeNumber(next.trackingSmoothing, DEFAULT_VIEWER_STATE.trackingSmoothing, 0, 1),
        deadZoneX: safeNumber(next.deadZoneX, DEFAULT_VIEWER_STATE.deadZoneX, 0, 0.2),
        deadZoneY: safeNumber(next.deadZoneY, DEFAULT_VIEWER_STATE.deadZoneY, 0, 0.2),
        deadZoneZ: safeNumber(next.deadZoneZ, DEFAULT_VIEWER_STATE.deadZoneZ, 0, 0.4)
      }, false);
      if (notify) notifyViewerStateChanged(this);
    }

    setTrackingSettings(settings, notify) {
      const next = settings && typeof settings === 'object' ? settings : {};
      if (Object.prototype.hasOwnProperty.call(next, 'trackingSmoothing')) {
        this.trackingSmoothing = safeNumber(next.trackingSmoothing, this.trackingSmoothing, 0, 0.95);
      }
      if (Object.prototype.hasOwnProperty.call(next, 'deadZoneX')) {
        this.deadZoneX = safeNumber(next.deadZoneX, this.deadZoneX, 0, 0.2);
      }
      if (Object.prototype.hasOwnProperty.call(next, 'deadZoneY')) {
        this.deadZoneY = safeNumber(next.deadZoneY, this.deadZoneY, 0, 0.2);
      }
      if (Object.prototype.hasOwnProperty.call(next, 'deadZoneZ')) {
        this.deadZoneZ = safeNumber(next.deadZoneZ, this.deadZoneZ, 0, 0.4);
      }
      faceTracker.poseTracker.updateSettings({
        trackingSmoothing: this.trackingSmoothing,
        deadZoneX: this.deadZoneX,
        deadZoneY: this.deadZoneY,
        deadZoneZ: this.deadZoneZ
      });
      if (!notify) this.buildTrackingControls();
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
      const pose = this.headPose || defaultHeadPose();
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

    setSelectedLightIntensity(value) {
      const layer = this.selectedLightLayer();
      if (!layer) return;
      if (layer.locked === true) return;
      layer.intensity = safeNumber(value, layer.intensity, 0, 20);
      this.applyLightLayerTransform(layer);
      notifyViewerStateChanged(this);
    }

    setSelectedLightColor(value) {
      const layer = this.selectedLightLayer();
      if (!layer) return;
      if (layer.locked === true) return;
      layer.color = safeColor(value, layer.color);
      this.applyLightLayerTransform(layer);
      notifyViewerStateChanged(this);
    }

    setPositionAxis(index, value) {
      const layer = this.selectedImageLayer();
      if (layer) {
        if (layer.locked === true) return;
        layer.transform.position[index] = value;
        this.applyImageLayerTransform(layer);
        notifyViewerStateChanged(this);
        return;
      }
      const modelLayer = this.selectedModelLayer();
      if (modelLayer) {
        if (modelLayer.locked === true) return;
        modelLayer.transform.position[index] = value;
        this.applyModelLayerTransform(modelLayer);
        notifyViewerStateChanged(this);
        return;
      }
      const lightLayer = this.selectedLightLayer();
      if (lightLayer) {
        if (lightLayer.locked === true) return;
        lightLayer.transform.position[index] = value;
        this.applyLightLayerTransform(lightLayer);
        notifyViewerStateChanged(this);
        return;
      }
      this.transform.position[index] = value;
      this.applyTransform();
      notifyTransformChanged(this);
    }

    setRotationAxis(index, value) {
      const layer = this.selectedImageLayer();
      if (layer) {
        if (layer.locked === true) return;
        layer.transform.rotation[index] = value;
        this.applyImageLayerTransform(layer);
        notifyViewerStateChanged(this);
        return;
      }
      const modelLayer = this.selectedModelLayer();
      if (modelLayer) {
        if (modelLayer.locked === true) return;
        modelLayer.transform.rotation[index] = value;
        this.applyModelLayerTransform(modelLayer);
        notifyViewerStateChanged(this);
        return;
      }
      const lightLayer = this.selectedLightLayer();
      if (lightLayer) {
        if (lightLayer.locked === true) return;
        lightLayer.transform.rotation[index] = value;
        this.applyLightLayerTransform(lightLayer);
        notifyViewerStateChanged(this);
        return;
      }
      this.transform.rotation[index] = value;
      this.applyTransform();
      notifyTransformChanged(this);
    }

    setScale(value) {
      const nextScale = Number(value);
      if (!Number.isFinite(nextScale)) return;
      value = clamp(nextScale, 0.001, 100);
      const layer = this.selectedImageLayer();
      if (layer) {
        if (layer.locked === true) return;
        layer.transform.scale = value;
        this.applyImageLayerTransform(layer);
        this.computeScaleRange();
        notifyViewerStateChanged(this);
        return;
      }
      const modelLayer = this.selectedModelLayer();
      if (modelLayer) {
        if (modelLayer.locked === true) return;
        modelLayer.transform.scale = value;
        this.applyModelLayerTransform(modelLayer);
        this.computeScaleRange();
        notifyViewerStateChanged(this);
        return;
      }
      const lightLayer = this.selectedLightLayer();
      if (lightLayer) {
        if (lightLayer.locked === true) return;
        lightLayer.transform.scale = value;
        this.applyLightLayerTransform(lightLayer);
        this.computeScaleRange();
        notifyViewerStateChanged(this);
        return;
      }
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
      this.headPose = cloneHeadPose(headPose);
      this.updateOffAxisCamera();
    }

    activeCameraPose(basePose) {
      const pose = cloneHeadPose(basePose);
      if (!this.spatialEye) return pose;
      const eye = pose.eyes && pose.eyes[this.spatialEye];
      if (!eye) return pose;
      return {
        x: eye.x,
        y: eye.y,
        z: pose.z
      };
    }

    updateOffAxisCamera() {
      const pose = this.activeCameraPose(
        this.trackingEnabled ? this.headPose : defaultHeadPose()
      );
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
      if (!this.scene || !this.fog) return;
      if (!this.fogVisible || this.fogStrength <= 0) {
        this.scene.fog = null;
        return;
      }
      this.scene.fog = this.fog;
      this.fog.color.set(this.fogColor || DEFAULT_VIEWER_STATE.fogColor);
      const screenDims = this.offAxisCamera.getScreenDimensions();
      const headZ = this.worldHeadPosition ? this.worldHeadPosition.z : this.camera.position.z;
      const start = Math.max(0.001, headZ - screenDims.height * WII_ROOM.fogReachTowardViewer);
      const strength = clamp(this.fogStrength, 0.001, 1);
      this.fog.near = start;
      this.fog.far = start + (screenDims.height * this.fogDepth) / strength;
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
      const delta = this.lastFrameAt ? (now - this.lastFrameAt) / 1000 : 0;
      this.lastFrameAt = now;
      for (const mixer of this.animationMixers) {
        try { mixer.update(delta); } catch (_) {}
      }
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
      this.applyImageLayerTransforms();
      this.applyModelLayerTransforms();
      this.applyLightLayerTransforms();
      this.applySceneLighting();
      this.updateFog();
      this.setGridVisible(this.gridVisible, { notify: false, preference: false });
      this.setDartsVisible(this.dartsVisible, false);
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
      if (this.environmentPmrem && typeof this.environmentPmrem.dispose === 'function') {
        try { this.environmentPmrem.dispose(); } catch (_) {}
      }
      if (this.pmremGenerator && typeof this.pmremGenerator.dispose === 'function') {
        try { this.pmremGenerator.dispose(); } catch (_) {}
      }
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
    const imageLayerScene = hasImageLayers(payload);
    const modelLayerScene = hasModelLayers(payload);
    const layeredScene = imageLayerScene || modelLayerScene;
    if (!asset.url && !layeredScene) {
      notifyLoadState(elementId, 'missing', null, missingLabel(asset));
      setMessage(root, missingLabel(asset));
      return;
    }
    if (asset.url && !supportedMesh(asset) && !supportedSplat(asset) && !layeredScene) {
      notifyLoadState(elementId, 'missing', null, missingLabel(asset));
      setMessage(root, missingLabel(asset));
      return;
    }
    setMessage(root, layeredScene && !asset.url ? 'Loading scene layers...' : 'Loading 3D asset...');
    notifyLoadState(
      elementId,
      'loading',
      null,
      layeredScene && !asset.url ? 'Loading scene layers' : 'Loading 3D asset'
    );
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
