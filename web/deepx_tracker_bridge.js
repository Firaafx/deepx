(function () {
  const pointerId = 97231;
  let trackerUiVisible = true;
  let pendingRealMouse = null;
  let realMouseForwardScheduled = false;
  let pendingTrackerMove = null;
  let trackerMoveScheduled = false;
  let lastHoverTarget = null;
  let trackerCursorAllowed = false;
  let realCursorHideTimer = null;
  const realMouseIdleDelayMs = 1500;

  const style = document.createElement('style');
  style.textContent = 'html.deepx-real-cursor-hidden, html.deepx-real-cursor-hidden * { cursor: none !important; }';
  document.head.appendChild(style);

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

  function setRealCursorHidden(hidden) {
    document.documentElement.classList.toggle('deepx-real-cursor-hidden', hidden);
  }

  function scheduleRealCursorHide() {
    if (realCursorHideTimer) clearTimeout(realCursorHideTimer);
    if (!trackerCursorAllowed) {
      setRealCursorHidden(false);
      return;
    }
    realCursorHideTimer = setTimeout(() => {
      if (trackerCursorAllowed) setRealCursorHidden(true);
    }, realMouseIdleDelayMs);
  }

  function trackerWindow() {
    const frame = trackerFrame();
    return frame && frame.contentWindow ? frame.contentWindow : null;
  }

  function postTrackerCommand(command, extra) {
    const target = trackerWindow();
    if (!target) return;
    target.postMessage({
      type: 'deepx-tracker-command',
      command,
      ...(extra || {})
    }, '*');
  }

  function isTypingTarget(target) {
    const elem = target && target.nodeType === Node.ELEMENT_NODE
      ? target
      : target && target.parentElement;
    if (!elem) return false;
    const tag = elem.tagName && elem.tagName.toLowerCase();
    return tag === 'input'
      || tag === 'textarea'
      || tag === 'select'
      || elem.isContentEditable === true;
  }

  function closestTarget(target, selector) {
    if (!target || typeof target.closest !== 'function') return null;
    try {
      return target.closest(selector);
    } catch (_) {
      return null;
    }
  }

  function classifyTarget(target) {
    if (!target || target === document.body || target === document.documentElement) {
      return {clickable: false, draggable: false};
    }
    const clickable = !!closestTarget(
      target,
      'a[href],button,input,select,textarea,[role="button"],[role="link"],[tabindex]:not([tabindex="-1"]),[onclick],[data-clickable="true"]'
    );
    const draggable = !!closestTarget(
      target,
      '[draggable="true"],[data-draggable="true"],[data-drag-handle="true"],[role="slider"],input[type="range"],.drag-handle,.draggable'
    );
    return {clickable, draggable};
  }

  function postHoverState(target) {
    const frameWindow = trackerWindow();
    if (!frameWindow) return;
    frameWindow.postMessage({
      type: 'deepx-parent-hover-state',
      ...classifyTarget(target)
    }, '*');
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
      postHoverState(target);
      updateSyntheticHover(target, x, y, options);
      dispatchPointer(target, 'pointermove', x, y, options);
      return;
    }

    if (action === 'mousedown') {
      postHoverState(target);
      dispatchBoth(target, 'pointerdown', 'mousedown', x, y, {
        ...options,
        buttons: 1
      });
      return;
    }

    if (action === 'mouseup') {
      postHoverState(target);
      dispatchBoth(target, 'pointerup', 'mouseup', x, y, {
        ...options,
        buttons: 0
      });
      return;
    }

    if (action === 'focus') {
      postHoverState(target);
      focusTarget(target);
      return;
    }

    if (action === 'click') {
      postHoverState(target);
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
    setRealCursorHidden(false);
    scheduleRealCursorHide();
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
      trackerCursorAllowed = data.cursorAllowed === true;
      setFrameInteractive(trackerUiVisible);
      scheduleRealCursorHide();
      window.postMessage(JSON.stringify({
        type: 'deepx-tracker-state',
        uiVisible: trackerUiVisible,
        linkActive: data.linkActive === true,
        showCursor: data.showCursor === true,
        cursorEnabled: data.cursorEnabled === true
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

  window.addEventListener('keydown', (event) => {
    if (isTypingTarget(event.target)) return;
    if (event.code === 'Space') {
      postTrackerCommand('toggle-link');
      event.preventDefault();
    } else if (event.code === 'KeyC') {
      postTrackerCommand('toggle-cursor');
      setRealCursorHidden(false);
      event.preventDefault();
    }
  }, {capture: true});

  window.addEventListener('pagehide', () => {
    setRealCursorHidden(false);
  });
})();
