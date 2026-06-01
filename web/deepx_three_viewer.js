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

  function payloadAsset(payload) {
    const media = payload && typeof payload.media === 'object' ? payload.media : payload;
    return {
      type: String(media.type || payload.media_type || payload.mediaType || 'image'),
      url: String(media.url || media.assetUrl || ''),
      format: String(media.format || '').toLowerCase()
    };
  }

  function numberList(value, fallback) {
    if (!Array.isArray(value) || value.length < 3) return fallback.slice();
    return [Number(value[0]) || 0, Number(value[1]) || 0, Number(value[2]) || 0];
  }

  function cameraConfig(payload) {
    const camera = payload && typeof payload.camera === 'object' ? payload.camera : {};
    return {
      position: numberList(camera.initialPosition, [0, 0, 3]),
      target: numberList(camera.initialTarget, [0, 0, 0]),
      fov: Number(camera.fov) || 45,
      custom: Array.isArray(camera.initialPosition) || Array.isArray(camera.initialTarget)
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
    return 'No 3DGS';
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

  function setBaseCamera(ctx, position, target, fov) {
    const THREE = ctx.modules.three;
    ctx.basePosition = new THREE.Vector3(position[0], position[1], position[2]);
    ctx.baseTarget = new THREE.Vector3(target[0], target[1], target[2]);
    ctx.camera.fov = fov;
    ctx.camera.position.copy(ctx.basePosition);
    ctx.camera.lookAt(ctx.baseTarget);
    ctx.camera.updateProjectionMatrix();
  }

  function cameraSnapshot(ctx) {
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
      fov: Number(ctx.camera.fov.toFixed(3))
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

  function autoFitObject(ctx, object) {
    if (!object || ctx.hasCustomCamera) return;
    const THREE = ctx.modules.three;
    const box = new THREE.Box3().setFromObject(object);
    if (box.isEmpty()) return;
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z, 0.1);
    const fov = ctx.camera.fov * Math.PI / 180;
    let distance = Math.abs(maxDim / (2 * Math.tan(fov / 2)));
    distance *= 1.35;
    setBaseCamera(
      ctx,
      [center.x, center.y, center.z + distance],
      [center.x, center.y, center.z],
      ctx.camera.fov
    );
  }

  function recenter(ctx) {
    ctx.center = { ...ctx.head };
    ctx.camera.position.copy(ctx.basePosition);
    ctx.camera.lookAt(ctx.baseTarget);
  }

  function applyHeadCamera(ctx) {
    if (ctx.editable) {
      ctx.camera.position.copy(ctx.basePosition);
      ctx.camera.lookAt(ctx.baseTarget);
      return;
    }
    const THREE = ctx.modules.three;
    const head = ctx.head || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const center = ctx.center || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
    const x = clamp((head.x - center.x) * 0.9 + ((head.yaw || 0) - (center.yaw || 0)) / 90, -0.9, 0.9);
    const y = clamp((head.y - center.y) * -0.7 + ((head.pitch || 0) - (center.pitch || 0)) / 70, -0.7, 0.7);
    const z = clamp(((center.z || head.z || 0) - (head.z || 0)) * 2.5, -0.9, 0.9);
    const offset = new THREE.Vector3(x, y, z);
    ctx.camera.position.copy(ctx.basePosition).add(offset);
    ctx.camera.lookAt(ctx.baseTarget);
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
    if (!ctx.editable) return;
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
      spherical.phi = Math.max(0.08, Math.min(Math.PI - 0.08, spherical.phi - dy * 0.006));
      offset.setFromSpherical(spherical);
      ctx.basePosition.copy(ctx.baseTarget).add(offset);
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
      notifyCameraChanged(ctx);
    }

    canvas.addEventListener('pointerdown', (event) => {
      dragging = true;
      mode = event.button === 2 || event.shiftKey ? 'pan' : 'orbit';
      lastX = event.clientX;
      lastY = event.clientY;
      canvas.setPointerCapture(event.pointerId);
      event.preventDefault();
    });
    canvas.addEventListener('pointermove', (event) => {
      if (!dragging) return;
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
    });
    canvas.addEventListener('pointerup', (event) => {
      dragging = false;
      try {
        canvas.releasePointerCapture(event.pointerId);
      } catch (_) {}
    });
    canvas.addEventListener('contextmenu', (event) => event.preventDefault());
    canvas.addEventListener('wheel', (event) => {
      const direction = event.deltaY > 0 ? 1 : -1;
      const factor = direction > 0 ? 1.12 : 0.88;
      const offset = ctx.basePosition.clone().sub(ctx.baseTarget).multiplyScalar(factor);
      ctx.basePosition.copy(ctx.baseTarget).add(offset);
      notifyCameraChanged(ctx);
      event.preventDefault();
    }, { passive: false });
  }

  async function mount(elementId, payloadJson, optionsJson) {
    const root = document.getElementById(elementId);
    if (!root) return;
    dispose(elementId);
    let payload = {};
    let options = {};
    try {
      payload = JSON.parse(payloadJson || '{}');
    } catch (_) {}
    try {
      options = JSON.parse(optionsJson || '{}');
    } catch (_) {}
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
        editable: options.editable === true,
        hasCustomCamera: config.custom,
        head: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        center: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        disposed: false,
        resizeObserver: null,
        raf: 0
      };
      setBaseCamera(ctx, config.position, config.target, config.fov);
      viewers.set(elementId, ctx);
      const object = supportedMesh(asset)
        ? await addTriangleMesh(ctx, asset)
        : await addGaussianSplat(ctx, asset);
      autoFitObject(ctx, object);
      resize(ctx);
      installPointerControls(ctx);
      ctx.resizeObserver = new ResizeObserver(() => resize(ctx));
      ctx.resizeObserver.observe(root);
      animate(ctx);
      notifyCameraChanged(ctx);
    } catch (error) {
      console.error(error);
      setMessage(root, error && error.message ? error.message : 'Unable to load 3D asset.');
    }
  }

  function dispose(elementId) {
    const ctx = viewers.get(elementId);
    if (!ctx) return;
    ctx.disposed = true;
    if (ctx.raf) cancelAnimationFrame(ctx.raf);
    if (ctx.resizeObserver) ctx.resizeObserver.disconnect();
    if (ctx.renderer) ctx.renderer.dispose();
    viewers.delete(elementId);
  }

  function recenterViewer(elementId) {
    const ctx = viewers.get(elementId);
    if (ctx) recenter(ctx);
  }

  function getCamera(elementId) {
    const ctx = viewers.get(elementId);
    return ctx ? cameraSnapshot(ctx) : null;
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

  window.DeepXThreeViewer = { mount, dispose, recenter: recenterViewer, getCamera };
})();
