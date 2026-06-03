(function () {
  const viewers = new Map();
  let modulePromise = null;

  function loadModules() {
    if (!modulePromise) {
      modulePromise = Promise.all([
        import('https://esm.sh/three@0.180.0'),
        import('https://esm.sh/three@0.180.0/examples/jsm/loaders/GLTFLoader.js'),
        import('https://esm.sh/@sparkjsdev/spark@2.1.0?deps=three@0.180.0').catch(() => null)
      ]).then(([three, gltf, spark]) => ({ three, GLTFLoader: gltf.GLTFLoader, spark }));
    }
    return modulePromise;
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

  function numberList(value, fallback) {
    if (!Array.isArray(value) || value.length < 3) return fallback.slice();
    return [
      Number.isFinite(Number(value[0])) ? Number(value[0]) : fallback[0],
      Number.isFinite(Number(value[1])) ? Number(value[1]) : fallback[1],
      Number.isFinite(Number(value[2])) ? Number(value[2]) : fallback[2]
    ];
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function degToRad(value) {
    return Number(value || 0) * Math.PI / 180;
  }

  function radToDeg(value) {
    return value * 180 / Math.PI;
  }

  function safeRotation(value) {
    const raw = value && typeof value === 'object' ? value : {};
    return {
      yaw: Number.isFinite(Number(raw.yaw)) ? Number(raw.yaw) : 0,
      pitch: Number.isFinite(Number(raw.pitch)) ? Number(raw.pitch) : 0,
      roll: Number.isFinite(Number(raw.roll)) ? Number(raw.roll) : 0
    };
  }

  function positionFromRotation(THREE, target, rotation, distance) {
    const yaw = degToRad(rotation.yaw);
    const pitch = degToRad(rotation.pitch);
    const cosPitch = Math.cos(pitch);
    const offset = new THREE.Vector3(
      Math.sin(yaw) * cosPitch * distance,
      Math.sin(pitch) * distance,
      Math.cos(yaw) * cosPitch * distance
    );
    return target.clone().add(offset);
  }

  function rotationFromPosition(position, target) {
    const dx = position.x - target.x;
    const dy = position.y - target.y;
    const dz = position.z - target.z;
    const distance = Math.max(0.0001, Math.sqrt(dx * dx + dy * dy + dz * dz));
    return {
      yaw: radToDeg(Math.atan2(dx, dz)),
      pitch: radToDeg(Math.asin(clamp(dy / distance, -1, 1))),
      roll: 0
    };
  }

  function cameraConfig(payload) {
    const camera = payload && typeof payload.camera === 'object' ? payload.camera : {};
    const position = numberList(camera.initialPosition, [0, 0, 3]);
    const target = numberList(camera.initialTarget, [0, 0, 0]);
    const fov = clamp(Number(camera.fov) || 45, 10, 100);
    const distance = Math.max(0.01, Number(camera.distance) || Math.hypot(
      position[0] - target[0],
      position[1] - target[1],
      position[2] - target[2]
    ) || 3);
    return {
      position,
      target,
      rotationDegrees: safeRotation(camera.rotationDegrees),
      fov,
      distance,
      custom: Array.isArray(camera.initialPosition)
        || Array.isArray(camera.initialTarget)
        || !!camera.rotationDegrees
        || Number.isFinite(Number(camera.distance))
    };
  }

  function setMessage(root, text) {
    root.innerHTML = '';
    const node = document.createElement('div');
    node.textContent = text;
    node.style.cssText = [
      'height:100%',
      'display:grid',
      'place-items:center',
      'color:#fff',
      'text-align:center',
      'padding:16px',
      'box-sizing:border-box',
      'font:600 14px system-ui,sans-serif',
      'background:#050505'
    ].join(';');
    root.appendChild(node);
  }

  function supportedMesh(asset) {
    return asset.type === 'triangle_mesh' || asset.format === 'glb' || asset.format === 'gltf';
  }

  function supportedSplat(asset) {
    return asset.type === 'gaussian_splat' || ['ply', 'splat', 'ksplat'].includes(asset.format);
  }

  function missingLabel(asset) {
    if (asset.type === 'triangle_mesh' || asset.format === 'glb' || asset.format === 'gltf') {
      return 'No 3D mesh';
    }
    if (asset.type === 'gaussian_splat' || ['ply', 'splat', 'ksplat'].includes(asset.format)) {
      return 'No 3DGS';
    }
    return 'No 3D';
  }

  async function addGaussianSplat(ctx, asset) {
    const spark = ctx.modules.spark;
    if (!spark) throw new Error('Spark module failed to load.');
    const Candidate =
      spark.SplatMesh || spark.SparkSplatMesh || spark.GaussianSplatMesh || spark.SplatObject;
    if (!Candidate) {
      throw new Error('Spark loaded, but no supported splat mesh export was found.');
    }
    let object;
    try {
      object = new Candidate({ url: asset.url });
    } catch (_) {
      object = new Candidate(asset.url);
    }
    ctx.scene.add(object);
    return object;
  }

  async function addTriangleMesh(ctx, asset) {
    const loader = new ctx.modules.GLTFLoader();
    const gltf = await loader.loadAsync(asset.url);
    const root = gltf.scene;
    root.traverse((node) => {
      if (node.isMesh) {
        node.castShadow = true;
        node.receiveShadow = true;
      }
    });
    ctx.scene.add(root);
    return root;
  }

  function syncRotationFromBase(ctx, keepRoll = true) {
    const computed = rotationFromPosition(ctx.basePosition, ctx.baseTarget);
    ctx.rotationDegrees = {
      yaw: computed.yaw,
      pitch: computed.pitch,
      roll: keepRoll ? (ctx.rotationDegrees?.roll || 0) : 0
    };
    ctx.distance = ctx.basePosition.distanceTo(ctx.baseTarget);
  }

  function applyCameraTransform(ctx, position, target, fov, rotationDegrees, distance) {
    const THREE = ctx.modules.three;
    const targetVec = new THREE.Vector3(target[0], target[1], target[2]);
    const rotation = safeRotation(rotationDegrees);
    const useRotationPosition = rotationDegrees
      && Number.isFinite(Number(distance))
      && (!Array.isArray(position) || position.length < 3);
    const positionVec = useRotationPosition
      ? positionFromRotation(THREE, targetVec, rotation, Number(distance))
      : new THREE.Vector3(position[0], position[1], position[2]);

    ctx.basePosition = positionVec;
    ctx.baseTarget = targetVec;
    ctx.camera.fov = clamp(Number(fov) || 45, 10, 100);
    ctx.rotationDegrees = rotationDegrees ? rotation : rotationFromPosition(positionVec, targetVec);
    ctx.distance = Math.max(0.01, Number(distance) || positionVec.distanceTo(targetVec) || 3);
    renderBaseCamera(ctx);
  }

  function renderBaseCamera(ctx, headOffset) {
    const offset = headOffset || new ctx.modules.three.Vector3(0, 0, 0);
    ctx.camera.up.set(0, 1, 0);
    ctx.camera.position.copy(ctx.basePosition).add(offset);
    ctx.camera.lookAt(ctx.baseTarget);
    const roll = degToRad(ctx.rotationDegrees?.roll || 0);
    if (roll) ctx.camera.rotateZ(roll);
    ctx.camera.updateProjectionMatrix();
  }

  function setBaseCamera(ctx, position, target, fov, rotationDegrees, distance) {
    applyCameraTransform(ctx, position, target, fov, rotationDegrees, distance);
  }

  function cameraSnapshot(ctx) {
    syncRotationFromBase(ctx);
    return {
      initialPosition: [
        Number(ctx.basePosition.x.toFixed(5)),
        Number(ctx.basePosition.y.toFixed(5)),
        Number(ctx.basePosition.z.toFixed(5))
      ],
      initialTarget: [
        Number(ctx.baseTarget.x.toFixed(5)),
        Number(ctx.baseTarget.y.toFixed(5)),
        Number(ctx.baseTarget.z.toFixed(5))
      ],
      rotationDegrees: {
        yaw: Number((ctx.rotationDegrees?.yaw || 0).toFixed(3)),
        pitch: Number((ctx.rotationDegrees?.pitch || 0).toFixed(3)),
        roll: Number((ctx.rotationDegrees?.roll || 0).toFixed(3))
      },
      fov: Number(ctx.camera.fov.toFixed(3)),
      distance: Number((ctx.distance || ctx.basePosition.distanceTo(ctx.baseTarget)).toFixed(5))
    };
  }

  function notifyCameraChanged(ctx) {
    if (!ctx.editable) return;
    window.postMessage(JSON.stringify({
      type: 'deepx-three-camera-changed',
      elementId: ctx.elementId,
      camera: cameraSnapshot(ctx)
    }), window.location.origin);
  }

  function autoFitObject(ctx, object, force = false) {
    if (!object || (!force && ctx.hasCustomCamera)) return;
    const THREE = ctx.modules.three;
    const box = new THREE.Box3().setFromObject(object);
    if (box.isEmpty()) return;
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z, 0.1);
    const fov = ctx.camera.fov * Math.PI / 180;
    let distance = Math.abs(maxDim / (2 * Math.tan(fov / 2)));
    distance = Math.max(distance * 1.45, 0.35);
    setBaseCamera(
      ctx,
      [center.x, center.y, center.z + distance],
      [center.x, center.y, center.z],
      ctx.camera.fov,
      { yaw: 0, pitch: 0, roll: ctx.rotationDegrees?.roll || 0 },
      distance
    );
    ctx.hasCustomCamera = true;
    notifyCameraChanged(ctx);
  }

  function recenter(ctx) {
    ctx.center = { ...ctx.head };
    renderBaseCamera(ctx);
  }

  function applyHeadCamera(ctx) {
    if (ctx.editable) {
      renderBaseCamera(ctx);
      return;
    }
    const THREE = ctx.modules.three;
    const head = ctx.head || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const center = ctx.center || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const x = clamp((head.x - center.x) * 0.9 + ((head.yaw || 0) - (center.yaw || 0)) / 90, -0.9, 0.9);
    const y = clamp((head.y - center.y) * -0.7 + ((head.pitch || 0) - (center.pitch || 0)) / 70, -0.7, 0.7);
    const z = clamp(((center.z || head.z || 0) - (head.z || 0)) * 2.5, -0.9, 0.9);
    renderBaseCamera(ctx, new THREE.Vector3(x, y, z));
  }

  function animate(ctx) {
    if (ctx.disposed) return;
    ctx.raf = requestAnimationFrame(() => animate(ctx));
    applyHeadCamera(ctx);
    ctx.renderer.render(ctx.scene, ctx.camera);
  }

  function resize(ctx) {
    const width = Math.max(1, ctx.root.clientWidth);
    const height = Math.max(1, ctx.root.clientHeight);
    ctx.camera.aspect = width / height;
    ctx.camera.updateProjectionMatrix();
    ctx.renderer.setSize(width, height, false);
  }

  function installPointerControls(ctx) {
    const THREE = ctx.modules.three;
    const canvas = ctx.renderer.domElement;
    let dragging = false;
    let mode = 'orbit';
    let lastX = 0;
    let lastY = 0;

    function orbit(dx, dy) {
      const offset = ctx.basePosition.clone().sub(ctx.baseTarget);
      const spherical = new THREE.Spherical().setFromVector3(offset);
      spherical.theta -= dx * 0.006;
      spherical.phi = clamp(spherical.phi - dy * 0.006, 0.08, Math.PI - 0.08);
      offset.setFromSpherical(spherical);
      ctx.basePosition.copy(ctx.baseTarget).add(offset);
      syncRotationFromBase(ctx);
      renderBaseCamera(ctx);
      notifyCameraChanged(ctx);
    }

    function pan(dx, dy) {
      const distance = ctx.basePosition.distanceTo(ctx.baseTarget);
      const scale = distance * 0.0018;
      const forward = ctx.baseTarget.clone().sub(ctx.basePosition).normalize();
      const right = new THREE.Vector3().crossVectors(forward, ctx.camera.up).normalize();
      const up = new THREE.Vector3().crossVectors(right, forward).normalize();
      const move = right.multiplyScalar(-dx * scale).add(up.multiplyScalar(dy * scale));
      ctx.basePosition.add(move);
      ctx.baseTarget.add(move);
      renderBaseCamera(ctx);
      notifyCameraChanged(ctx);
    }

    function onPointerDown(event) {
      if (!ctx.editable) return;
      dragging = true;
      mode = event.button === 2 || event.shiftKey ? 'pan' : 'orbit';
      lastX = event.clientX;
      lastY = event.clientY;
      canvas.setPointerCapture(event.pointerId);
      event.preventDefault();
    }

    function onPointerMove(event) {
      if (!dragging || !ctx.editable) return;
      const dx = event.clientX - lastX;
      const dy = event.clientY - lastY;
      lastX = event.clientX;
      lastY = event.clientY;
      if (mode === 'pan') {
        pan(dx, dy);
      } else {
        orbit(dx, dy);
      }
      event.preventDefault();
    }

    function onPointerUp(event) {
      dragging = false;
      try {
        canvas.releasePointerCapture(event.pointerId);
      } catch (_) {}
    }

    function onWheel(event) {
      if (!ctx.editable) return;
      const factor = event.deltaY > 0 ? 1.12 : 0.88;
      const offset = ctx.basePosition.clone().sub(ctx.baseTarget).multiplyScalar(factor);
      ctx.basePosition.copy(ctx.baseTarget).add(offset);
      syncRotationFromBase(ctx);
      renderBaseCamera(ctx);
      notifyCameraChanged(ctx);
      event.preventDefault();
    }

    function onContextMenu(event) {
      if (ctx.editable) event.preventDefault();
    }

    canvas.addEventListener('pointerdown', onPointerDown);
    canvas.addEventListener('pointermove', onPointerMove);
    canvas.addEventListener('pointerup', onPointerUp);
    canvas.addEventListener('pointerleave', onPointerUp);
    canvas.addEventListener('contextmenu', onContextMenu);
    canvas.addEventListener('wheel', onWheel, { passive: false });
    ctx.cleanup.push(() => canvas.removeEventListener('pointerdown', onPointerDown));
    ctx.cleanup.push(() => canvas.removeEventListener('pointermove', onPointerMove));
    ctx.cleanup.push(() => canvas.removeEventListener('pointerup', onPointerUp));
    ctx.cleanup.push(() => canvas.removeEventListener('pointerleave', onPointerUp));
    ctx.cleanup.push(() => canvas.removeEventListener('contextmenu', onContextMenu));
    ctx.cleanup.push(() => canvas.removeEventListener('wheel', onWheel));
  }

  async function mount(elementId, payloadJson, optionsJson) {
    const root = document.getElementById(elementId);
    if (!root) return;
    const token = (root.__deepxThreeMountToken || 0) + 1;
    root.__deepxThreeMountToken = token;
    dispose(elementId, { keepRootMessage: true });

    const payload = parseJson(payloadJson);
    const options = parseJson(optionsJson);
    const asset = payloadAsset(payload);
    if (!asset.url) {
      setMessage(root, missingLabel(asset));
      return;
    }
    if (!supportedMesh(asset) && !supportedSplat(asset)) {
      setMessage(root, missingLabel(asset));
      return;
    }
    setMessage(root, 'Loading 3D asset...');
    try {
      const modules = await loadModules();
      if (root.__deepxThreeMountToken !== token) return;
      const THREE = modules.three;
      root.innerHTML = '';
      const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      root.appendChild(renderer.domElement);
      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0x050505);
      if (modules.spark && modules.spark.SparkRenderer) {
        scene.add(new modules.spark.SparkRenderer({ renderer }));
      }
      const config = cameraConfig(payload);
      const camera = new THREE.PerspectiveCamera(config.fov, 1, 0.01, 5000);
      scene.add(new THREE.HemisphereLight(0xffffff, 0x222244, 2.2));
      const key = new THREE.DirectionalLight(0xffffff, 2);
      key.position.set(2, 4, 5);
      scene.add(key);
      const ctx = {
        elementId,
        root,
        modules,
        renderer,
        scene,
        camera,
        object: null,
        editable: options.editable === true,
        hasCustomCamera: config.custom,
        head: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        center: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        disposed: false,
        resizeObserver: null,
        raf: 0,
        cleanup: []
      };
      setBaseCamera(
        ctx,
        config.position,
        config.target,
        config.fov,
        config.rotationDegrees,
        config.distance
      );
      viewers.set(elementId, ctx);
      const object = supportedMesh(asset)
        ? await addTriangleMesh(ctx, asset)
        : await addGaussianSplat(ctx, asset);
      if (root.__deepxThreeMountToken !== token || ctx.disposed) {
        disposeObject(object);
        return;
      }
      ctx.object = object;
      autoFitObject(ctx, object, false);
      resize(ctx);
      installPointerControls(ctx);
      ctx.resizeObserver = new ResizeObserver(() => resize(ctx));
      ctx.resizeObserver.observe(root);
      animate(ctx);
      notifyCameraChanged(ctx);
    } catch (error) {
      console.error(error);
      if (root.__deepxThreeMountToken === token) {
        setMessage(root, error && error.message ? error.message : 'Unable to load 3D asset.');
      }
    }
  }

  function disposeMaterial(material) {
    if (!material) return;
    for (const key of Object.keys(material)) {
      const value = material[key];
      if (value && value.isTexture && typeof value.dispose === 'function') {
        value.dispose();
      }
    }
    if (typeof material.dispose === 'function') material.dispose();
  }

  function disposeObject(object) {
    if (!object) return;
    if (typeof object.dispose === 'function') {
      try {
        object.dispose();
      } catch (_) {}
    }
    if (typeof object.traverse === 'function') {
      object.traverse((node) => {
        if (node.geometry && typeof node.geometry.dispose === 'function') {
          node.geometry.dispose();
        }
        if (Array.isArray(node.material)) {
          node.material.forEach(disposeMaterial);
        } else {
          disposeMaterial(node.material);
        }
      });
    }
  }

  function dispose(elementId, options = {}) {
    const ctx = viewers.get(elementId);
    if (!ctx) {
      if (!options.keepRootMessage) {
        const root = document.getElementById(elementId);
        if (root) root.innerHTML = '';
      }
      return;
    }
    ctx.disposed = true;
    if (ctx.raf) cancelAnimationFrame(ctx.raf);
    if (ctx.resizeObserver) ctx.resizeObserver.disconnect();
    for (const cleanup of ctx.cleanup || []) {
      try {
        cleanup();
      } catch (_) {}
    }
    disposeObject(ctx.scene);
    if (ctx.renderer) {
      try {
        ctx.renderer.renderLists?.dispose?.();
      } catch (_) {}
      try {
        ctx.renderer.dispose();
      } catch (_) {}
      try {
        ctx.renderer.forceContextLoss?.();
      } catch (_) {}
    }
    viewers.delete(elementId);
    if (!options.keepRootMessage && ctx.root) ctx.root.innerHTML = '';
  }

  function recenterViewer(elementId) {
    const ctx = viewers.get(elementId);
    if (ctx) recenter(ctx);
  }

  function setEditable(elementId, editable) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    ctx.editable = editable === true;
    renderBaseCamera(ctx);
  }

  function setCamera(elementId, cameraJson) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    const camera = parseJson(cameraJson);
    const current = cameraSnapshot(ctx);
    const position = Array.isArray(camera.initialPosition)
      ? numberList(camera.initialPosition, current.initialPosition)
      : current.initialPosition;
    const target = Array.isArray(camera.initialTarget)
      ? numberList(camera.initialTarget, current.initialTarget)
      : current.initialTarget;
    const rotationDegrees = camera.rotationDegrees && typeof camera.rotationDegrees === 'object'
      ? safeRotation(camera.rotationDegrees)
      : current.rotationDegrees;
    const fov = Number.isFinite(Number(camera.fov)) ? Number(camera.fov) : current.fov;
    const distance = Number.isFinite(Number(camera.distance)) ? Number(camera.distance) : current.distance;
    setBaseCamera(ctx, position, target, fov, rotationDegrees, distance);
  }

  function getCamera(elementId) {
    const ctx = viewers.get(elementId);
    return ctx ? cameraSnapshot(ctx) : null;
  }

  function autoFit(elementId) {
    const ctx = viewers.get(elementId);
    if (ctx && ctx.object) autoFitObject(ctx, ctx.object, true);
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.type !== 'deepx-head-pose') return;
    for (const ctx of viewers.values()) {
      ctx.head = {
        x: Number(data.x) || 0,
        y: Number(data.y) || 0,
        z: Number(data.z) || 0,
        yaw: Number(data.yaw) || 0,
        pitch: Number(data.pitch) || 0
      };
      if (!ctx.centeredOnce) {
        ctx.centeredOnce = true;
        recenter(ctx);
      }
    }
  });

  window.DeepXThreeViewer = {
    mount,
    dispose,
    setEditable,
    setCamera,
    getCamera,
    recenter: recenterViewer,
    autoFit
  };
})();
