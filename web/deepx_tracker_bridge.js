(function () {
  const pointerId = 97231;
  let trackerUiVisible = true;
  let pendingRealMouse = null;
  let realMouseForwardScheduled = false;
  let pendingTrackerMove = null;
  let trackerMoveScheduled = false;
  let lastHoverTarget = null;

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
    if (!trackerUiVisible) {
      return document.elementFromPoint(x, y) || document.body;
    }
    if (frame) frame.style.pointerEvents = 'none';
    const target = document.elementFromPoint(x, y) || document.body;
    if (frame) frame.style.pointerEvents = 'auto';
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
      relatedTarget: options.relatedTarget || null,
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
      relatedTarget: options.relatedTarget || null,
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

  function updateSyntheticHover(target, x, y, options) {
    if (target === lastHoverTarget) return;

    const previous = lastHoverTarget && lastHoverTarget.isConnected ? lastHoverTarget : null;
    const next = target && target.isConnected ? target : document.body;

    if (previous) {
      const outOptions = {...options, relatedTarget: next};
      dispatchPointer(previous, 'pointerout', x, y, outOptions);
      dispatchMouse(previous, 'mouseout', x, y, outOptions);
    }

    if (next) {
      const overOptions = {...options, relatedTarget: previous};
      dispatchPointer(next, 'pointerover', x, y, overOptions);
      dispatchMouse(next, 'mouseover', x, y, overOptions);
    }

    lastHoverTarget = next;
  }

  function focusTarget(target) {
    if (!target || typeof target.focus !== 'function') return;
    try {
      target.focus({preventScroll: true});
    } catch (_) {
      target.focus();
    }
  }

  function handleTrackerPointerNow(data) {
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
      updateSyntheticHover(target, x, y, options);
      dispatchPointer(target, 'pointermove', x, y, options);
      return;
    }

    if (action === 'mousedown') {
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

  function handleTrackerPointer(data) {
    if (data.action !== 'mousemove') {
      handleTrackerPointerNow(data);
      return;
    }
    pendingTrackerMove = data;
    if (trackerMoveScheduled) return;
    trackerMoveScheduled = true;
    requestAnimationFrame(() => {
      trackerMoveScheduled = false;
      const next = pendingTrackerMove;
      pendingTrackerMove = null;
      if (next) handleTrackerPointerNow(next);
    });
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
