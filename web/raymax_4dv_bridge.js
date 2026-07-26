(function () {
  'use strict';

  /* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   *  RayMax 4DV Bridge â€” manages 4DV.ai iframe player
   *  instances inside Flutter HtmlElementView containers.
   *
   *  Exposes  window.RayMax4DVPlayer  with the same shape
   *  the Dart side already uses for RayMaxOffAxisViewer.
   * â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  const instances = new Map();

  /* â”€â”€ constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  const BASE_URL = 'https://www.4dv.ai/assets';

  const DEMO_ASSETS = Object.freeze([
    { id: 'rocket',  label: 'Rocket Launch' },
  ]);

  const DEFAULT_PARAMS = Object.freeze({
    nowheel: '',
    lang: 'en',
  });

  /* â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function buildSrc(assetName, extraParams) {
    const url = new URL(`${BASE_URL}/${encodeURIComponent(assetName)}`);
    const merged = { ...DEFAULT_PARAMS, ...(extraParams || {}) };
    for (const [key, value] of Object.entries(merged)) {
      if (value === '' || value === true) {
        url.searchParams.set(key, '');
      } else if (value !== false && value != null) {
        url.searchParams.set(key, String(value));
      }
    }
    return url.toString();
  }

  function notify(elementId, status, progress, label) {
    window.postMessage({
      type: 'raymax-4dv-load-state',
      elementId: elementId,
      status: status,
      progress: progress,
      label: label || '',
    }, '*');
  }

  function setMessage(root, text) {
    let el = root.querySelector('.dx-4dv-msg');
    if (!el) {
      el = document.createElement('div');
      el.className = 'dx-4dv-msg';
      el.style.cssText =
        'position:absolute;inset:0;display:grid;place-items:center;' +
        'color:#999;font:600 13px/1.4 system-ui,sans-serif;text-align:center;' +
        'padding:20px;pointer-events:none;z-index:2;';
      root.appendChild(el);
    }
    el.textContent = text;
    el.style.display = text ? 'grid' : 'none';
  }

  function clearMessage(root) {
    const el = root.querySelector('.dx-4dv-msg');
    if (el) el.style.display = 'none';
  }

  /* â”€â”€ inject global styles (once) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  (function injectStyles() {
    if (document.getElementById('raymax-4dv-style')) return;
    const style = document.createElement('style');
    style.id = 'raymax-4dv-style';
    style.textContent = `
      .dx-4dv-root {
        position: relative;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #000;
      }
      .dx-4dv-root iframe {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        border: 0;
        background: #000;
      }
      .dx-4dv-root .dx-4dv-overlay {
        position: absolute;
        inset: 0;
        z-index: 10;
        display: flex;
        align-items: flex-end;
        justify-content: flex-start;
        padding: 12px;
        pointer-events: none;
        opacity: 0;
        transition: opacity 180ms ease;
      }
      .dx-4dv-root:hover .dx-4dv-overlay,
      .dx-4dv-root:focus-within .dx-4dv-overlay {
        opacity: 1;
      }
      .dx-4dv-overlay .dx-4dv-badge {
        pointer-events: auto;
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 5px 10px;
        border-radius: 6px;
        background: rgba(0,0,0,0.65);
        backdrop-filter: blur(8px);
        font: 600 11px/1 system-ui, sans-serif;
        color: rgba(255,255,255,0.85);
        letter-spacing: 0.02em;
        user-select: none;
      }
      .dx-4dv-badge .dx-4dv-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #22c55e;
        animation: dx-4dv-pulse 1.8s infinite;
      }
      @keyframes dx-4dv-pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.4; }
      }
      .dx-4dv-selector {
        position: absolute;
        top: 12px;
        right: 12px;
        z-index: 15;
        pointer-events: auto;
        opacity: 0;
        transition: opacity 180ms ease;
      }
      .dx-4dv-root:hover .dx-4dv-selector,
      .dx-4dv-root:focus-within .dx-4dv-selector {
        opacity: 1;
      }
      .dx-4dv-selector select {
        padding: 5px 8px;
        border-radius: 6px;
        border: 1px solid rgba(255,255,255,0.2);
        background: rgba(0,0,0,0.7);
        backdrop-filter: blur(8px);
        color: #fff;
        font: 600 11px/1 system-ui, sans-serif;
        cursor: pointer;
        outline: none;
      }
      .dx-4dv-selector select:hover {
        background: rgba(0,0,0,0.85);
      }
      .dx-4dv-selector select option {
        background: #1a1a1a;
        color: #fff;
      }
    `;
    document.head.appendChild(style);
  })();

  /* â”€â”€ mount â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function mount(elementId, configJson) {
    dispose(elementId);

    const root = document.getElementById(elementId);
    if (!root) return;

    const config = parseJson(configJson);
    const assetName = config.asset || config.assetName || 'rocket';
    const params = config.params || {};
    const showSelector = config.showSelector !== false;
    const showBadge = config.showBadge !== false;

    const token = Symbol('mount');
    root.__raymax4dvMountToken = token;

    // Set up root
    root.innerHTML = '';
    root.classList.add('dx-4dv-root');

    notify(elementId, 'loading', null, 'Loading 4D playerâ€¦');
    setMessage(root, 'Loading 4D playerâ€¦');

    // Create iframe
    const iframe = document.createElement('iframe');
    iframe.allow = 'xr-spatial-tracking; gyroscope; accelerometer; autoplay; fullscreen';
    iframe.allowFullscreen = true;
    iframe.loading = 'lazy';
    iframe.style.opacity = '0';
    iframe.style.transition = 'opacity 400ms ease';

    iframe.src = buildSrc(assetName, params);

    iframe.addEventListener('load', function onLoad() {
      if (root.__raymax4dvMountToken !== token) return;
      iframe.style.opacity = '1';
      clearMessage(root);
      notify(elementId, 'ready', 1, '4D player ready');
    });

    iframe.addEventListener('error', function onError() {
      if (root.__raymax4dvMountToken !== token) return;
      setMessage(root, 'Unable to load 4D player.');
      notify(elementId, 'error', null, 'Unable to load 4D player.');
    });

    root.appendChild(iframe);

    // Overlay badge
    if (showBadge) {
      const overlay = document.createElement('div');
      overlay.className = 'dx-4dv-overlay';
      overlay.innerHTML =
        '<div class="dx-4dv-badge">' +
        '<span class="dx-4dv-dot"></span>' +
        '<span>4D Â· Gaussian Splatting</span>' +
        '</div>';
      root.appendChild(overlay);
    }

    // Demo asset selector
    if (showSelector && DEMO_ASSETS.length > 1) {
      const selectorWrap = document.createElement('div');
      selectorWrap.className = 'dx-4dv-selector';
      const select = document.createElement('select');
      for (const demo of DEMO_ASSETS) {
        const opt = document.createElement('option');
        opt.value = demo.id;
        opt.textContent = demo.label;
        if (demo.id === assetName) opt.selected = true;
        select.appendChild(opt);
      }
      select.addEventListener('change', function () {
        setAsset(elementId, select.value);
      });
      selectorWrap.appendChild(select);
      root.appendChild(selectorWrap);
    }

    // Store instance
    instances.set(elementId, {
      root: root,
      iframe: iframe,
      assetName: assetName,
      token: token,
    });
  }

  /* â”€â”€ setAsset â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function setAsset(elementId, assetName, extraParams) {
    const inst = instances.get(elementId);
    if (!inst) return;

    inst.assetName = assetName;
    inst.iframe.style.opacity = '0';
    setMessage(inst.root, 'Loading 4D playerâ€¦');
    notify(elementId, 'loading', null, 'Switching to ' + assetName);

    inst.iframe.src = buildSrc(assetName, extraParams || {});
  }

  /* â”€â”€ dispose â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function dispose(elementId) {
    const inst = instances.get(elementId);
    if (!inst) {
      const root = document.getElementById(elementId);
      if (root) root.innerHTML = '';
      return;
    }
    inst.token = null;
    if (inst.iframe && inst.iframe.parentNode) {
      inst.iframe.parentNode.removeChild(inst.iframe);
    }
    instances.delete(elementId);
    const root = document.getElementById(elementId);
    if (root) root.innerHTML = '';
  }

  /* â”€â”€ resize â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function resize(elementId) {
    const inst = instances.get(elementId);
    if (!inst) return false;
    // iframes resize automatically with CSS â€” no-op but keeps API parity
    return true;
  }

  /* â”€â”€ isAlive â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function isAlive(elementId) {
    const inst = instances.get(elementId);
    if (!inst || !inst.iframe) return false;
    return inst.iframe.isConnected === true;
  }

  /* â”€â”€ getAsset â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function getAsset(elementId) {
    const inst = instances.get(elementId);
    return inst ? inst.assetName : null;
  }

  /* â”€â”€ getDemoAssets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function getDemoAssets() {
    return DEMO_ASSETS.map(function (a) { return { id: a.id, label: a.label }; });
  }

  /* â”€â”€ JSON parse helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  function parseJson(value) {
    if (!value) return {};
    if (typeof value === 'object') return value;
    try { return JSON.parse(value); } catch (e) { return {}; }
  }

  /* â”€â”€ public API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

  window.RayMax4DVPlayer = {
    mount: mount,
    dispose: dispose,
    resize: resize,
    isAlive: isAlive,
    setAsset: setAsset,
    getAsset: getAsset,
    getDemoAssets: getDemoAssets,
  };
})();
