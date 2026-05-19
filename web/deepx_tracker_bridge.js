(function () {
  const pointerId = 97231;
  let trackerUiVisible = true;
  let lastHoverTarget = null;
  let pendingRealMouse = null;
  let realMouseForwardScheduled = false;

  function trackerFrame() {
    return document.getElementById('deepx-tracker-frame');
  }

  function setFrameInteractive(interactive) {
    const frame = trackerFrame();
    if (!frame) return;
    frame.style.pointerEvents = interactive ? 'auto' : 'none';
  }

  function targetAt(x, y) {
    const frame = trackerFrame();
    if (frame) frame.style.pointerEvents = 'none';
    const target = document.elementFromPoint(x, y) || document.body;
    if (frame) frame.style.pointerEvents = trackerUiVisible ? 'auto' : 'none';
    return target;
  }

  function pointerInit(x, y, options) {
    return {
      bubbles: true,
      cancelable: true,
      composed: true,
      clientX: x,
      clientY: y,
      screenX: x,
      screenY: y,
      button: options.button || 0,
      buttons: options.buttons || 0,
      pointerId,
      pointerType: 'mouse',
      isPrimary: true,
      view: window
    };
  }

  function mouseInit(x, y, options) {
    return {
      bubbles: true,
      cancelable: true,
      composed: true,
      clientX: x,
      clientY: y,
      screenX: x,
      screenY: y,
      button: options.button || 0,
      buttons: options.buttons || 0,
      view: window
    };
  }

  function dispatchPointer(target, type, x, y, options) {
    if (!target) return;
    if (window.PointerEvent) {
      target.dispatchEvent(new PointerEvent(type, pointerInit(x, y, options)));
    }
  }

  function dispatchMouse(target, type, x, y, options) {
    if (!target) return;
    target.dispatchEvent(new MouseEvent(type, mouseInit(x, y, options)));
  }

  function dispatchBoth(target, pointerType, mouseType, x, y, options) {
    dispatchPointer(target, pointerType, x, y, options);
    dispatchMouse(target, mouseType, x, y, options);
  }

  function updateHover(target, x, y, options) {
    if (target === lastHoverTarget) return;
    if (lastHoverTarget) {
      dispatchBoth(lastHoverTarget, 'pointerout', 'mouseout', x, y, options);
    }
    if (target) {
      dispatchBoth(target, 'pointerover', 'mouseover', x, y, options);
    }
    lastHoverTarget = target;
  }

  function focusTarget(target) {
    if (!target || typeof target.focus !== 'function') return;
    try {
      target.focus({preventScroll: true});
    } catch (_) {
      target.focus();
    }
  }

  function handleTrackerPointer(data) {
    const x = Number(data.x);
    const y = Number(data.y);
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;

    const options = {
      button: Number(data.button) || 0,
      buttons: Number(data.buttons) || 0
    };
    const target = targetAt(x, y);
    const action = data.action;

    if (action === 'mousemove') {
      updateHover(target, x, y, options);
      dispatchBoth(target, 'pointermove', 'mousemove', x, y, options);
      return;
    }

    if (action === 'mousedown') {
      updateHover(target, x, y, {...options, buttons: 1});
      dispatchBoth(target, 'pointerdown', 'mousedown', x, y, {
        ...options,
        buttons: 1
      });
      return;
    }

    if (action === 'mouseup') {
      dispatchBoth(target, 'pointerup', 'mouseup', x, y, {
        ...options,
        buttons: 0
      });
      return;
    }

    if (action === 'focus') {
      focusTarget(target);
      return;
    }

    if (action === 'click') {
      updateHover(target, x, y, options);
      focusTarget(target);
      dispatchBoth(target, 'pointerdown', 'mousedown', x, y, {
        ...options,
        buttons: 1
      });
      dispatchBoth(target, 'pointerup', 'mouseup', x, y, {
        ...options,
        buttons: 0
      });
      dispatchMouse(target, 'click', x, y, options);
    }
  }

  function forwardRealMouse(action, event) {
    if (!event.isTrusted || trackerUiVisible) return;
    const frame = trackerFrame();
    if (!frame || !frame.contentWindow) return;
    pendingRealMouse = {
      type: 'deepx-parent-real-mouse',
      action,
      x: event.clientX,
      y: event.clientY,
      deltaY: event.deltaY || 0
    };
    if (realMouseForwardScheduled) return;
    realMouseForwardScheduled = true;
    requestAnimationFrame(() => {
      realMouseForwardScheduled = false;
      const next = pendingRealMouse;
      pendingRealMouse = null;
      if (!next) return;
      const nextFrame = trackerFrame();
      if (!nextFrame || !nextFrame.contentWindow) return;
      nextFrame.contentWindow.postMessage(next, '*');
    });
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') return;

    if (data.type === 'deepx-tracker-state') {
      trackerUiVisible = !!data.uiVisible;
      setFrameInteractive(trackerUiVisible);
      window.postMessage(JSON.stringify({
        type: 'deepx-tracker-state',
        uiVisible: trackerUiVisible
      }), window.location.origin);
      return;
    }

    if (data.type === 'deepx-tracker-pointer') {
      handleTrackerPointer(data);
    }
  });

  window.addEventListener('mousemove', (event) => {
    forwardRealMouse('mousemove', event);
  }, {capture: true, passive: true});

  window.addEventListener('mousedown', (event) => {
    forwardRealMouse('mousedown', event);
  }, {capture: true, passive: true});

  window.addEventListener('mouseup', (event) => {
    forwardRealMouse('mouseup', event);
  }, {capture: true, passive: true});

  window.addEventListener('wheel', (event) => {
    forwardRealMouse('wheel', event);
  }, {capture: true, passive: true});
})();
