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

  function setMessage(root, text) {
    root.innerHTML = '';
    const node = document.createElement('div');
    node.textContent = text;
    node.style.cssText = [
      'height:100%',
      'display:grid',
      'place-items:center',
      'color:#fff',
      'font:600 14px system-ui,sans-serif',
      'background:#050505'
    ].join(';');
    root.appendChild(node);
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
  }

  function recenter(ctx) {
    ctx.center = { ...ctx.head };
  }

  function applyHeadCamera(ctx) {
    const head = ctx.head || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const center = ctx.center || { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 };
    const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
    const x = clamp((head.x - center.x) * 0.9 + ((head.yaw || 0) - (center.yaw || 0)) / 90, -0.9, 0.9);
    const y = clamp((head.y - center.y) * -0.7 + ((head.pitch || 0) - (center.pitch || 0)) / 70, -0.7, 0.7);
    const z = clamp(((center.z || head.z || 0) - (head.z || 0)) * 2.5, -0.9, 0.9);
    ctx.camera.position.set(x, y, 3 + z);
    ctx.camera.lookAt(0, 0, 0);
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

  async function mount(elementId, payloadJson) {
    const root = document.getElementById(elementId);
    if (!root) return;
    dispose(elementId);
    let payload = {};
    try {
      payload = JSON.parse(payloadJson || '{}');
    } catch (_) {}
    const asset = payloadAsset(payload);
    if (!asset.url) {
      setMessage(root, '3D asset is missing.');
      return;
    }
    setMessage(root, 'Loading 3D scene...');
    try {
      const modules = await loadModules();
      const THREE = modules.three;
      root.innerHTML = '';
      const renderer = new THREE.WebGLRenderer({ antialias: false, alpha: false });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      root.appendChild(renderer.domElement);
      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0x050505);
      if (modules.spark && modules.spark.SparkRenderer) {
        scene.add(new modules.spark.SparkRenderer({ renderer }));
      }
      const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 200);
      camera.position.set(0, 0, 3);
      scene.add(new THREE.HemisphereLight(0xffffff, 0x222244, 2.2));
      const key = new THREE.DirectionalLight(0xffffff, 2);
      key.position.set(2, 4, 5);
      scene.add(key);
      const ctx = {
        root,
        modules,
        renderer,
        scene,
        camera,
        head: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        center: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0 },
        disposed: false,
        resizeObserver: null,
        raf: 0
      };
      viewers.set(elementId, ctx);
      if (asset.type === 'triangle_mesh' || asset.format === 'glb' || asset.format === 'gltf') {
        await addTriangleMesh(ctx, asset);
      } else {
        await addGaussianSplat(ctx, asset);
      }
      resize(ctx);
      ctx.resizeObserver = new ResizeObserver(() => resize(ctx));
      ctx.resizeObserver.observe(root);
      animate(ctx);
    } catch (error) {
      console.error(error);
      setMessage(root, error && error.message ? error.message : 'Unable to load 3D scene.');
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

  window.DeepXThreeViewer = { mount, dispose, recenter: recenterViewer };
})();
