// web/tracker.js
// --- GLOBAL VARIABLES ---
let eyesClosed = false;
let closedCount = 0;
let anchorFace = { x: 0, y: 0, z: 0 };
let currentFace = { x: 0, y: 0, z: 0 };
let currentThreeDCamera = { x: 0, y: 0, z: 0 };
let smoothedRel = { x: 0, y: 0, z: 0 };
let anchorYaw = 0, anchorPitch = 0;
let anchorHand = { x: 0.5, y: 0.5 };
let isCapturing = false;
let cameraSvc = null;
let localStream = null;
let currentVideoSize = 0;
let inferenceRaf = 0;
let inferenceGeneration = 0;
let inferenceInFlight = false;
let lastInferenceTime = 0;
let configuredFaceSignature = '';
let configuredHandSignature = '';
let handsReadyPromise = null;
let handsHealthy = true;
let handsRetryAt = 0;
let lastHudDrawTime = 0;
let lastOverlayDrawTime = 0;
let overlayDrawRaf = 0;
let lastHoverHitTestTime = 0;
let cachedHoveredElement = null;
const tCanvas = document.getElementById('ui-text-canvas');
const tCtx = tCanvas.getContext('2d');
const cursor = document.getElementById('white-cursor');
const cursorWidth = 26;
const cursorHeight = 31;
const cursorHotspotX = 4;
const cursorHotspotY = 3;
let targetX = window.innerWidth / 2;
let targetY = window.innerHeight / 2;
let smoothX = targetX;
let smoothY = targetY;
let currentHeadYaw = 0, currentHeadPitch = 0;
let currentHeadYawNorm = 0, currentHeadPitchNorm = 0;
let currentIrisYaw = 0, currentIrisPitch = 0;
let currentDx = 0, currentDy = 0;
let currentHandIndexX = 0.5, currentHandIndexY = 0.5;
let currentHandDx = 0, currentHandDy = 0;
let currentAvgYawRatio = 0, currentAvgPitchRatio = 0;
let fps = 0;
let frameCount = 0;
let lastFpsTime = performance.now();
let latency = 0;
let transferLat = 0;
let isMouseTracking = false;
let prevTracking = false;
let mouseX = window.innerWidth / 2;
let mouseY = window.innerHeight / 2;
let mouseWheelZ = 0;
const wheelSens = 0.0005;
let isPaused = false;
let cursorPausedByRealMouse = false;
let coeffX = [];
let coeffY = [];
let isIrisCalibrated = false;
let tempCoeffX = [];
let tempCoeffY = [];
let calibrationData = [];
const calDot = document.getElementById('cal-dot');
const calibrationPoints = [
    {x: 0, y: 0},
    {x: 0.5, y: 0},
    {x: 1, y: 0},
    {x: 0, y: 0.5},
    {x: 0.5, y: 0.5},
    {x: 1, y: 0.5},
    {x: 0, y: 1},
    {x: 0.5, y: 1},
    {x: 1, y: 1}
];
let leftClosed = false;
let rightClosed = false;
let isWinking = false;
let isPinching = false;
let winkStartTime = 0;
let winkEndTime = 0;
let effectiveWinkStart = 0;
let dragging = false;
let dragTarget = null;
let prevWinking = false;
let winkDownSent = false;
let unwinkStartTime = 0;
let isDebouncingUnwink = false;
let currentLeftEAR = 0;
let currentRightEAR = 0;
let prevHoveredElement = null;
let potentialDragTarget = null;
let hoverRedStart = 0;
let isHoverRed = false;
let potentialClickTarget = null;
let hoverBlueStart = 0;
let isHoverBlue = false;
let hasHand = false;
let handLm = null;
let faceLm = null;
let activeTracker = 'face';
let frameCounter = 0;
const checkInterval = 5;
let prevCenterX = window.innerWidth / 2;
let prevCenterY = window.innerHeight / 2;
let lastPinchTrueTime = 0;
let peer = null;
let conn = null;
let isClient = false;
let isRemote = false;
let perfMode = 'medium';
let currentMode = 'head';
let lastHandDataTime = 0;
let sendIris = true;
let sendNose = true;
let sendYawPitch = true;
let sendFingertips = true;
let sendFullFace = false;
let sendFullHand = false;
let sendAll = true;
let sendNone = false;
let batteryLevel = 'N/A';
let batteryRate = 0.00;
let prevBatteryLevel = null;
let prevBatteryTime = Date.now();
let faceMesh = null;
let hands = null;
let startTime = 0;
let prevHeadYaw = 0;
let prevHeadPitch = 0;
let prevHandIndexX = 0.5;
let prevHandIndexY = 0.5;
let prevTime = performance.now();
let lastTargetX = window.innerWidth / 2;
let lastTargetY = window.innerHeight / 2;
let dt = 0;
let headCursorAcceleration = 1;
let handCursorSpeed = 500;
let handCursorAcceleration = 6;
let autoHandFrameCounter = 0;
let currentPinchDistance = 1;
let winkCalibration = null;
let pinchCalibration = null;
let winkRecordStage = 'idle';
let pinchRecordStage = 'idle';
let uiVisible = false;
let realMouseResumeTimer = null;
let realCursorHideTimer = null;
let pageActive = true;
let lastParentHoverX = Number.NaN;
let lastParentHoverY = Number.NaN;
let parentHoverClickable = false;
let parentHoverDraggable = false;
const REAL_MOUSE_IDLE_DELAY_MS = 1500;
const HEAD_CURSOR_MIN_SPEED = 1;
const HEAD_CURSOR_MAX_SPEED = 80;
const MEDIAPIPE_FACE_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4';
const MEDIAPIPE_HANDS_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/hands@0.4';
const PEER_JS_URL = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
const scriptLoadPromises = new Map();
let handsResultsAttached = false;
let handFrameFailures = 0;
const HAND_FRAME_FAILURE_COOLDOWN_MS = 1200;
const HAND_TRACKER_RECREATE_FAILURES = 3;
const HAND_TRACKER_RECREATE_COOLDOWN_MS = 3000;
const elementCache = new Map();
const numericSettingCache = new Map();
const performanceProfiles = {
    low: { width: 160, height: 160, intervalMs: 1000 / 15 },
    medium: { width: 320, height: 320, intervalMs: 1000 / 24 },
    high: { width: 480, height: 480, intervalMs: 1000 / 30 }
};
const parentPointerTarget = {
    __deepxParentPointerTarget: true,
    tagName: 'PARENT',
    classList: { contains: () => false },
    dispatchEvent: () => true
};
let lastWinkTime = 0;
let lastPinchTime = 0;
let doubleClickThreshold = 600;
let doubleDragThreshold = 300;
let lastDoubleDragTime = 0;
const inputSmooth = 0.7;
function el(id) {
    if (!elementCache.has(id)) {
        elementCache.set(id, document.getElementById(id));
    }
    return elementCache.get(id);
}
function numericSetting(id, fallback = 0) {
    const node = el(id);
    if (!node) return fallback;
    const raw = node.value;
    const cached = numericSettingCache.get(id);
    if (cached && cached.raw === raw) return cached.value;
    const parsed = Number.parseFloat(raw);
    const value = Number.isFinite(parsed) ? parsed : fallback;
    numericSettingCache.set(id, { raw, value });
    return value;
}
function trackingEnabled() {
    return !!el('tracking-toggle')?.checked;
}
function showCursorEnabled() {
    return !!el('show-cursor')?.checked;
}
function cursorFunctional() {
    return trackingEnabled() && showCursorEnabled() && !cursorPausedByRealMouse && pageActive;
}
function setTrackerCursorVisible(visible) {
    cursor.style.display = visible ? 'block' : 'none';
}
function setRealCursorHidden(hidden) {
    document.body.classList.toggle('cursor-hidden', hidden);
}
function resetTrackerInteractionState() {
    potentialClickTarget = null;
    potentialDragTarget = null;
    isHoverBlue = false;
    isHoverRed = false;
    dragging = false;
    dragTarget = null;
    winkDownSent = false;
    parentHoverClickable = false;
    parentHoverDraggable = false;
    cursor.dataset.state = 'idle';
}
function scheduleRealCursorHide() {
    if (realCursorHideTimer) clearTimeout(realCursorHideTimer);
    if (!trackingEnabled() || !showCursorEnabled()) {
        setRealCursorHidden(false);
        return;
    }
    realCursorHideTimer = setTimeout(() => {
        if (trackingEnabled() && showCursorEnabled()) {
            setRealCursorHidden(true);
        }
    }, REAL_MOUSE_IDLE_DELAY_MS);
}
function setShowCursorEnabled(enabled) {
    const toggle = el('show-cursor');
    if (!toggle) return;
    toggle.checked = enabled;
    localStorage.setItem('show-cursor', String(enabled));
    if (!enabled) {
        setTrackerCursorVisible(false);
        setRealCursorHidden(false);
        resetTrackerInteractionState();
        sendTrackerState();
        return;
    }
    scheduleRealCursorHide();
    if (cursorFunctional()) setTrackerCursorVisible(true);
    sendTrackerState();
}
function setTrackingEnabled(enabled) {
    const toggle = el('tracking-toggle');
    if (!toggle || toggle.checked === enabled) return;
    toggle.checked = enabled;
    toggle.dispatchEvent(new Event('change', { bubbles: true }));
}
function toggleTrackingEnabled() {
    setTrackingEnabled(!trackingEnabled());
}
function toggleCursorFunction() {
    setShowCursorEnabled(!showCursorEnabled());
}
function isTypingTarget(target) {
    const elem = target && target.nodeType === Node.ELEMENT_NODE
        ? target
        : target?.parentElement;
    if (!elem) return false;
    const tag = elem.tagName?.toLowerCase();
    return tag === 'input'
        || tag === 'textarea'
        || tag === 'select'
        || elem.isContentEditable === true;
}
function isAutoMode() {
    return currentMode === 'auto' || el('cursor-mode')?.value === 'auto';
}
function cursorControlMode() {
    const mode = el('cursor-mode')?.value || currentMode;
    if (mode === 'auto') return activeTracker === 'hand' && hasHand ? 'hand' : 'head';
    return mode;
}
function currentPerformanceProfile() {
    return performanceProfiles[perfMode] || performanceProfiles.medium;
}
function clearHandState() {
    hasHand = false;
    handLm = null;
    isPinching = false;
    currentHandDx = 0;
    currentHandDy = 0;
}
function shouldDrawTrackerOverlay() {
    if (!uiVisible) return false;
    const now = performance.now();
    if (now - lastOverlayDrawTime < 33) return false;
    lastOverlayDrawTime = performance.now();
    return true;
}
function closeHandsTracker(reason) {
    if (reason) console.warn('Recreating MediaPipe Hands after repeated failures:', reason);
    handsHealthy = false;
    handsRetryAt = performance.now() + HAND_TRACKER_RECREATE_COOLDOWN_MS;
    const tracker = hands;
    hands = null;
    handsReadyPromise = null;
    handsResultsAttached = false;
    configuredHandSignature = '';
    clearHandState();
    if (tracker && typeof tracker.close === 'function') {
        try {
            tracker.close();
        } catch (_) {}
    }
}
function handleHandsFrameFailure(error) {
    handFrameFailures++;
    handsRetryAt = performance.now() + HAND_FRAME_FAILURE_COOLDOWN_MS;
    clearHandState();
    if (handFrameFailures >= HAND_TRACKER_RECREATE_FAILURES) {
        handFrameFailures = 0;
        closeHandsTracker(error);
        return;
    }
    if (error) console.warn('Skipping MediaPipe Hands temporarily after frame failure:', error);
}
function loadScriptOnce(src, globalName) {
    if (globalName && window[globalName]) return Promise.resolve();
    if (scriptLoadPromises.has(src)) return scriptLoadPromises.get(src);

    const existing = Array.from(document.scripts).find(script => script.src === src);
    if (existing && existing.dataset.loaded === 'true') return Promise.resolve();

    const promise = new Promise((resolve, reject) => {
        const script = existing || document.createElement('script');
        script.src = src;
        script.async = true;
        script.onload = () => {
            script.dataset.loaded = 'true';
            resolve();
        };
        script.onerror = () => {
            scriptLoadPromises.delete(src);
            reject(new Error(`Failed to load ${src}`));
        };
        if (!existing) document.body.appendChild(script);
    });
    scriptLoadPromises.set(src, promise);
    return promise;
}
async function ensurePeerJsLoaded() {
    await loadScriptOnce(PEER_JS_URL, 'Peer');
}
async function ensureHandsReady() {
    if (performance.now() < handsRetryAt) return null;
    if (hands) return hands;
    if (handsReadyPromise) return handsReadyPromise;
    handsHealthy = true;
    handsReadyPromise = (async () => {
        await loadScriptOnce(`${MEDIAPIPE_HANDS_BASE}/hands.js`, 'Hands');
        const tracker = new Hands({locateFile: (file) => `${MEDIAPIPE_HANDS_BASE}/${file}`});
        hands = tracker;
        handsResultsAttached = false;
        configuredHandSignature = '';
        setupHandsResults(tracker);
        return tracker;
    })().catch((error) => {
        closeHandsTracker(error);
        return null;
    }).finally(() => {
        handsReadyPromise = null;
    });
    return handsReadyPromise;
}
async function init() {
    const urlParams = new URLSearchParams(window.parent.location.search);
    const mode = urlParams.get('mode');
    const remotePeerId = urlParams.get('peer');
    isClient = (mode === 'client');
    faceMesh = new FaceMesh({locateFile: (file) => `${MEDIAPIPE_FACE_BASE}/${file}`});
    setupDraggablePanel();
    setupTrackerEvents();
    setupOnResults();
    if (isClient) {
        document.getElementById('tracker-panel').style.display = 'none';
        document.getElementById('toggle-btns').style.display = 'none';
        document.getElementById('white-cursor').style.display = 'none';
        document.getElementById('ui-video-box').style.top = '10px';
        document.getElementById('ui-video-box').style.left = '10px';
        document.getElementById('ui-video-box').style.transform = 'none';
        document.getElementById('ui-video-box').style.width = '240px';
        document.getElementById('ui-video-box').style.height = '240px';
        document.getElementById('face-dots-overlay').style.display = 'none';
        document.getElementById('client-panel').style.display = 'block';
        document.getElementById('stop-connection-client').style.display = 'none';
        await ensurePeerJsLoaded();
        peer = new Peer();
        peer.on('open', (id) => {
            connectToHost(remotePeerId);
        });
        document.getElementById('perf-mode-client').onchange = async (e) => {
            perfMode = e.target.value;
            localStorage.setItem('perf-mode', perfMode);
            await updatePerformanceSettings();
        };
        document.getElementById('perf-mode-client').value = 'medium';
        document.getElementById('send-iris').onchange = (e) => sendIris = e.target.checked;
        document.getElementById('send-nose').onchange = (e) => sendNose = e.target.checked;
        document.getElementById('send-yaw-pitch').onchange = (e) => sendYawPitch = e.target.checked;
        document.getElementById('send-fingertips').onchange = (e) => sendFingertips = e.target.checked;
        document.getElementById('send-full-face').onchange = (e) => sendFullFace = e.target.checked;
        document.getElementById('send-full-hand').onchange = (e) => sendFullHand = e.target.checked;
        document.getElementById('send-all').onchange = (e) => {
            sendAll = e.target.checked;
            if (sendAll) {
                document.getElementById('send-iris').checked = true;
                document.getElementById('send-nose').checked = true;
                document.getElementById('send-yaw-pitch').checked = true;
                document.getElementById('send-fingertips').checked = true;
                document.getElementById('send-full-face').checked = true;
                document.getElementById('send-full-hand').checked = true;
                document.getElementById('send-none').checked = false;
                sendIris = true; sendNose = true; sendYawPitch = true; sendFingertips = true; sendFullFace = true; sendFullHand = true; sendNone = false;
            }
        };
        document.getElementById('send-none').onchange = (e) => {
            sendNone = e.target.checked;
            if (sendNone) {
                document.getElementById('send-iris').checked = false;
                document.getElementById('send-nose').checked = false;
                document.getElementById('send-yaw-pitch').checked = false;
                document.getElementById('send-fingertips').checked = false;
                document.getElementById('send-full-face').checked = false;
                document.getElementById('send-full-hand').checked = false;
                document.getElementById('send-all').checked = false;
                sendIris = false; sendNose = false; sendYawPitch = false; sendFingertips = false; sendFullFace = false; sendFullHand = false; sendAll = false;
            }
        };
        document.getElementById('stop-connection-client').onclick = () => {
            if (conn) conn.close();
            if (peer) peer.destroy();
            peer = null;
            conn = null;
        };
        document.getElementById('full-screen-client').onchange = (e) => {
            if (e.target.checked) {
                document.documentElement.requestFullscreen();
            } else {
                if (document.fullscreenElement) {
                    document.exitFullscreen();
                }
            }
        };
        setInterval(async () => {
            if ('getBattery' in navigator) {
                const battery = await navigator.getBattery();
                const currentLevel = battery.level * 100;
                const deltaTime = (Date.now() - prevBatteryTime) / 60000;
                if (deltaTime > 0 && prevBatteryLevel !== null) {
                    batteryRate = (currentLevel - prevBatteryLevel) / deltaTime;
                }
                prevBatteryLevel = currentLevel;
                prevBatteryTime = Date.now();
                document.getElementById('bat-level').innerText = currentLevel.toFixed(0);
                document.getElementById('bat-rate').innerText = batteryRate.toFixed(2);
            }
        }, 60000);
        if ('getBattery' in navigator) {
            navigator.getBattery().then(battery => {
                prevBatteryLevel = battery.level * 100;
            });
        }
    } else {
        document.getElementById('client-panel').style.display = 'none';
        document.getElementById('perf-mode-host').onchange = async (e) => {
            perfMode = e.target.value;
            localStorage.setItem('perf-mode', perfMode);
            await updatePerformanceSettings();
        };
        document.getElementById('input-source').onchange = async (e) => {
            isRemote = (e.target.value === 'remote');
            if (isRemote) {
                await stopLocalTrackingCamera();
                const s = document.getElementById('webcam-small').srcObject;
                if (s) s.getTracks().forEach(t => t.stop());
                document.getElementById('webcam-small').srcObject = null;
                document.getElementById('ui-video-box').style.display = 'block';
                document.getElementById('webcam-small').style.display = 'none';
                document.getElementById('face-dots-overlay').style.display = 'block';
                const qrDiv = document.createElement('div');
                qrDiv.id = 'qr-code';
                qrDiv.style.width = '100%';
                qrDiv.style.height = '100%';
                qrDiv.style.display = 'flex';
                qrDiv.style.alignItems = 'center';
                qrDiv.style.justifyContent = 'center';
                qrDiv.style.background = 'white';
                const qrImg = document.createElement('img');
                qrDiv.appendChild(qrImg);
                document.getElementById('ui-video-box').appendChild(qrDiv);
                const reconnectMsg = document.createElement('div');
                reconnectMsg.id = 'reconnect-msg';
                reconnectMsg.style.display = 'none';
                reconnectMsg.innerText = 'Waiting for reconnection...';
                reconnectMsg.style.color = '#fff';
                document.getElementById('ui-video-box').appendChild(reconnectMsg);
                let hostPeerId = localStorage.getItem('hostPeerId');
                await ensurePeerJsLoaded();
                peer = new Peer(hostPeerId || undefined);
                peer.on('open', (id) => {
                    localStorage.setItem('hostPeerId', id);
                    const baseUrl = window.parent.location.origin + window.parent.location.pathname;
                    const url = `${baseUrl}?mode=client&peer=${id}`;
                    qrImg.src = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(url)}`;
                    if (hostPeerId) {
                        qrDiv.style.display = 'none';
                        reconnectMsg.style.display = 'block';
                    }
                });
                peer.on('error', (err) => {
                    if (err.type === 'unavailable-id') {
                        localStorage.removeItem('hostPeerId');
                        peer.destroy();
                        peer = new Peer();
                    }
                });
                peer.on('connection', (c) => {
                    conn = c;
                    conn.on('open', () => {
                        console.log('Remote device connected');
                        const qr = document.getElementById('qr-code');
                        if (qr) qr.remove();
                        const msg = document.getElementById('reconnect-msg');
                        if (msg) msg.remove();
                        document.getElementById('ui-video-box').style.display = 'block';
                    });
                    conn.on('data', (data) => {
                        const now = Date.now();
                        if (data.type === 'face' || data.type === 'hand') {
                            latency = data.mpLatency;
                            transferLat = now - data.timestamp;
                        }
                        if (data.type === 'face') {
                            if (!isAutoMode() || performance.now() - lastHandDataTime > 350) {
                                hasHand = false;
                                activeTracker = 'face';
                            }
                            if (data.partial) {
                                if (data.partial.iris) {
                                    currentDx = data.partial.iris.dx;
                                    currentDy = data.partial.iris.dy;
                                    currentIrisYaw = currentDx * -200;
                                    currentIrisPitch = currentDy * 400;
                                    currentAvgYawRatio = currentDx + 0.5;
                                    currentAvgPitchRatio = currentDy + 0.5;
                                }
                                if (data.partial.nose) {
                                    currentFace.x = data.partial.nose.x;
                                    currentFace.y = data.partial.nose.y;
                                }
                                if (data.partial.camera3d) {
                                    currentThreeDCamera.x = Number(data.partial.camera3d.x) || 0;
                                    currentThreeDCamera.y = Number(data.partial.camera3d.y) || 0;
                                    currentThreeDCamera.z = Number(data.partial.camera3d.z) || 0;
                                    postHeadPoseSnapshot();
                                }
                                if (data.partial.yawPitch) {
                                    currentHeadYaw = data.partial.yawPitch.yaw;
                                    currentHeadPitch = data.partial.yawPitch.pitch;
                                    currentHeadYawNorm = currentHeadYaw / 60;
                                    currentHeadPitchNorm = currentHeadPitch / 40;
                                }
                                if (data.partial.ear) {
                                    currentLeftEAR = data.partial.ear.left;
                                    currentRightEAR = data.partial.ear.right;
                                    updateWinkStateFromEAR();
                                }
                                if (data.partial.z) {
                                    currentFace.z = data.partial.z;
                                }
                            }
                            if (data.drawLm) {
                                let lmArray = [];
                                for (let pt of data.drawLm) {
                                    lmArray[pt.i] = {x: pt.x, y: pt.y, z: pt.z};
                                }
                                faceLm = lmArray;
                                scheduleTrackerOverlayDraw();
                                if (!data.partial && data.drawLm.length >= FILTERED_INDICES.length) {
                                    processFace(lmArray);
                                }
                            }
                        } else if (data.type === 'hand') {
                            hasHand = true;
                            activeTracker = 'hand';
                            lastHandDataTime = performance.now();
                            if (data.partial) {
                                if (data.partial.fingertips) {
                                    const index = data.partial.fingertips.index;
                                    const thumb = data.partial.fingertips.thumb;
                                    const deadZoneHandX = numericSetting('dz-hx', 0);
                                    const deadZoneHandY = numericSetting('dz-hand-y', 0);
                                    let rawIndexX = index.x;
                                    let rawIndexY = index.y;
                                    let deltaX = rawIndexX - currentHandIndexX;
                                    let adjustedX = rawIndexX;
                                    if (Math.abs(deltaX) <= deadZoneHandX) {
                                        adjustedX = currentHandIndexX;
                                    } else {
                                        adjustedX = currentHandIndexX + (Math.abs(deltaX) - deadZoneHandX) * Math.sign(deltaX);
                                    }
                                    currentHandIndexX = currentHandIndexX * inputSmooth + adjustedX * (1 - inputSmooth);
                                    let deltaY = rawIndexY - currentHandIndexY;
                                    let adjustedY = rawIndexY;
                                    if (Math.abs(deltaY) <= deadZoneHandY) {
                                        adjustedY = currentHandIndexY;
                                    } else {
                                        adjustedY = currentHandIndexY + (Math.abs(deltaY) - deadZoneHandY) * Math.sign(deltaY);
                                    }
                                    currentHandIndexY = currentHandIndexY * inputSmooth + adjustedY * (1 - inputSmooth);
                                    currentHandDx = currentHandIndexX - anchorHand.x;
                                    currentHandDy = currentHandIndexY - anchorHand.y;
                                    const pinchDist = Math.hypot(thumb.x - index.x, thumb.y - index.y, thumb.z - index.z);
                                    currentPinchDistance = pinchDist;
                                    isPinching = pinchDist <= calibratedPinchThreshold();
                                }
                            }
                            if (data.drawLm) {
                                let lmArray = [];
                                for (let pt of data.drawLm) {
                                    lmArray[pt.i] = {x: pt.x, y: pt.y, z: pt.z};
                                }
                                if (data.drawLm.length >= 21) {
                                    handLm = lmArray;
                                }
                                scheduleTrackerOverlayDraw();
                                if (!data.partial && data.drawLm.length === 21) {
                                    processHand(lmArray);
                                }
                            }
                        } else if (data.type === 'pong') {
                            transferLat = (now - data.time) / 2;
                        }
                    });
                    conn.on('close', () => {
                        setTimeout(() => {
                            if (peer && !peer.destroyed) {
                                conn = peer.connect(remotePeerId);
                            }
                        }, 1000);
                    });
                });
                setInterval(() => {
                    if (conn && conn.open) {
                        conn.send({type: 'ping', time: Date.now()});
                    }
                }, 50);
            } else {
                document.getElementById('ui-video-box').style.display = 'block';
                document.getElementById('webcam-small').style.display = 'block';
                document.getElementById('face-dots-overlay').style.display = 'block';
                const qr = document.getElementById('qr-code');
                if (qr) qr.remove();
                const msg = document.getElementById('reconnect-msg');
                if (msg) msg.remove();
                if (peer) peer.destroy();
                peer = null;
                conn = null;
                if (document.getElementById('tracking-toggle').checked) {
                    document.getElementById('tracking-toggle').dispatchEvent(new Event('change'));
                }
            }
        };
        document.getElementById('cursor-mode').onchange = async (e) => {
            const mode = e.target.value;
            currentMode = mode;
            if (conn && conn.open) conn.send({type: 'set_mode', mode: mode});
            if (mode !== 'hand' && mode !== 'auto') {
                activeTracker = 'face';
                hasHand = false;
            }
            localStorage.setItem('cursor-mode', mode);
            if (document.getElementById('tracking-toggle').checked) {
                await updatePerformanceSettings();
            }
        };
        document.getElementById('stop-connection').onclick = () => {
            if (conn) conn.close();
            if (peer) peer.destroy();
            localStorage.removeItem('hostPeerId');
            peer = null;
            conn = null;
            location.reload();
        };
        document.getElementById('perf-mode-host').value = 'medium';
        document.getElementById('full-screen-host').onchange = (e) => {
            if (e.target.checked) {
                document.documentElement.requestFullscreen();
            } else {
                if (document.fullscreenElement) {
                    document.exitFullscreen();
                }
            }
        };
    }
    frameUpdate();
    loadSettings();
    syncClientSendSettingsFromControls();
    loadGestureCalibration();
    currentMode = document.getElementById('cursor-mode').value;
    perfMode = isClient ? document.getElementById('perf-mode-client').value : document.getElementById('perf-mode-host').value;
    isMouseTracking = !!el('mouse-tracking')?.checked;
    if (document.getElementById('tracking-toggle').checked) {
        await updatePerformanceSettings();
    }
    document.addEventListener('fullscreenchange', () => {
        const isFull = !!document.fullscreenElement;
        const fsCheckbox = isClient ? document.getElementById('full-screen-client') : document.getElementById('full-screen-host');
        if (fsCheckbox) fsCheckbox.checked = isFull;
    });
    setTrackerUiVisible(uiVisible);
}
function connectToHost(remotePeerId) {
    conn = peer.connect(remotePeerId);
    conn.on('open', () => {
        console.log('Connected to host');
    });
    conn.on('close', () => {
        setTimeout(() => {
            if (peer && !peer.destroyed) {
                connectToHost(remotePeerId);
            }
        }, 1000);
    });
    conn.on('data', async (data) => {
        if (data.type === 'set_mode') {
            currentMode = data.mode;
            if (document.getElementById('tracking-toggle').checked) {
                await updatePerformanceSettings();
            }
        } else if (data.type === 'ping') {
            conn.send({type: 'pong', time: data.time});
        }
    });
}
function clearTrackerOverlay() {
    const overlay = document.getElementById('face-dots-overlay');
    const oCtx = overlay.getContext('2d');
    oCtx.clearRect(0, 0, overlay.width, overlay.height);
}
function connectorEndpoints(connector) {
    if (Array.isArray(connector)) return [connector[0], connector[1]];
    return [connector?.start, connector?.end];
}
function drawFaceConnectors(oCtx, landmarks, connectors, style) {
    if (typeof drawConnectors !== 'function' || typeof connectors === 'undefined') return;
    const filtered = Array.from(connectors).filter((connector) => {
        const [start, end] = connectorEndpoints(connector);
        return landmarks?.[start] && landmarks?.[end];
    });
    if (filtered.length) drawConnectors(oCtx, landmarks, filtered, style);
}
function faceMeshConnectors(name) {
    return typeof globalThis[name] === 'undefined' ? undefined : globalThis[name];
}
function drawFaceDots(drawLm) {
    clearTrackerOverlay();
    if (!drawLm) return;
    const overlay = document.getElementById('face-dots-overlay');
    const oCtx = overlay.getContext('2d');
    if (typeof drawConnectors === 'function') {
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_TESSELATION'), { color: '#C0C0C070', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_RIGHT_EYE'), { color: '#FF3030', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_RIGHT_EYEBROW'), { color: '#FF3030', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_RIGHT_IRIS'), { color: '#FF3030', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_LEFT_EYE'), { color: '#30FF30', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_LEFT_EYEBROW'), { color: '#30FF30', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_LEFT_IRIS'), { color: '#30FF30', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_FACE_OVAL'), { color: '#E0E0E0', lineWidth: 1 });
        drawFaceConnectors(oCtx, drawLm, faceMeshConnectors('FACEMESH_LIPS'), { color: '#E0E0E0', lineWidth: 1 });
        return;
    }
}
function scheduleTrackerOverlayDraw(force = false) {
    if (!uiVisible) return;
    const now = performance.now();
    if (!force && now - lastOverlayDrawTime < 33) return;
    if (overlayDrawRaf) return;
    overlayDrawRaf = requestAnimationFrame(() => {
        overlayDrawRaf = 0;
        if (!uiVisible) return;
        lastOverlayDrawTime = performance.now();
        const mode = cursorControlMode();
        if ((mode === 'hand' || activeTracker === 'hand') && hasHand && handLm) {
            drawHandDots(handLm);
            return;
        }
        if (faceLm) {
            drawFaceDots(faceLm);
            return;
        }
        clearTrackerOverlay();
    });
}
function drawHandDots(lmArray) {
    const overlay = document.getElementById('face-dots-overlay');
    const oCtx = overlay.getContext('2d');
    const vidSize = overlay.width;
    const scaleFactor = vidSize / 240;
    const dotSize = 1.5 * scaleFactor;
    const lineWidth = 1 * scaleFactor;
    oCtx.clearRect(0, 0, overlay.width, overlay.height);
    oCtx.fillStyle = '#F00';
    oCtx.strokeStyle = isRemote ? '#3c3c3c' : '#141414';
    oCtx.lineWidth = lineWidth;
    if (lmArray.length === 21) {
        const connections = [
            [0, 1, 2, 3, 4],
            [0, 5, 6, 7, 8],
            [0, 9, 10, 11, 12],
            [0, 13, 14, 15, 16],
            [0, 17, 18, 19, 20]
        ];
        for (let conn of connections) {
            oCtx.beginPath();
            for (let idx of conn) {
                const p = lmArray[idx];
                if (p) {
                    if (idx === conn[0]) {
                        oCtx.moveTo(p.x * overlay.width, p.y * overlay.height);
                    } else {
                        oCtx.lineTo(p.x * overlay.width, p.y * overlay.height);
                    }
                }
            }
            oCtx.stroke();
        }
    }
    for (let i = 0; i < lmArray.length; i++) {
        const p = lmArray[i];
        if (p) {
            oCtx.beginPath();
            oCtx.arc(p.x * overlay.width, p.y * overlay.height, dotSize, 0, Math.PI * 2);
            oCtx.fill();
        }
    }
}
async function updatePerformanceSettings() {
    if (!pageActive) return;
    const generation = ++inferenceGeneration;
    const profile = currentPerformanceProfile();
    const refineLandmarks = true;
    const minDetectionConfidence = perfMode === 'low' ? 0.5 : 0.3;
    const minTrackingConfidence = minDetectionConfidence;
    const faceSignature = [
        refineLandmarks,
        minDetectionConfidence,
        minTrackingConfidence
    ].join('|');
    if (faceMesh && configuredFaceSignature !== faceSignature) {
        faceMesh.setOptions({
            refineLandmarks,
            maxNumFaces: 1,
            minDetectionConfidence,
            minTrackingConfidence
        });
        configuredFaceSignature = faceSignature;
    }
    if (currentMode === 'hand' || isAutoMode()) {
        const handTracker = await ensureHandsReady();
        if (generation !== inferenceGeneration) return;
        const handDetectionConfidence = isAutoMode() ? 0.75 : 0.3;
        const handTrackingConfidence = isAutoMode() ? 0.70 : 0.3;
        const handSignature = `0|1|${handDetectionConfidence}|${handTrackingConfidence}`;
        if (handTracker && configuredHandSignature !== handSignature) {
            handTracker.setOptions({
                modelComplexity: 0,
                maxNumHands: 1,
                minDetectionConfidence: handDetectionConfidence,
                minTrackingConfidence: handTrackingConfidence
            });
            configuredHandSignature = handSignature;
        }
    }
    const overlay = el('face-dots-overlay');
    overlay.width = profile.width;
    overlay.height = profile.height;
    if (!isRemote && trackingEnabled()) {
        await ensureLocalTrackingCamera(profile, generation);
        startInferenceLoop();
    } else {
        await stopLocalTrackingCamera();
    }
}
async function ensureLocalTrackingCamera(profile, generation) {
    const video = el('webcam-small');
    if (!video || !navigator.mediaDevices?.getUserMedia) return;
    if (localStream && currentVideoSize === profile.width) {
        if (video.srcObject !== localStream) video.srcObject = localStream;
        if (video.paused) {
            try {
                await video.play();
            } catch (_) {}
        }
        return;
    }
    await stopLocalTrackingCamera({ keepLoop: true });
    if (generation !== inferenceGeneration || !trackingEnabled() || isRemote) return;
    try {
        localStream = await navigator.mediaDevices.getUserMedia({
            audio: false,
            video: {
                width: { ideal: profile.width },
                height: { ideal: profile.height },
                facingMode: 'user'
            }
        });
    } catch (error) {
        console.warn('Unable to acquire tracker camera:', error);
        return;
    }
    if (generation !== inferenceGeneration || !trackingEnabled() || isRemote) {
        localStream.getTracks().forEach(track => track.stop());
        localStream = null;
        return;
    }
    currentVideoSize = profile.width;
    video.srcObject = localStream;
    video.muted = true;
    video.playsInline = true;
    try {
        await video.play();
    } catch (error) {
        console.warn('Unable to start tracker video stream:', error);
    }
}
function startInferenceLoop() {
    if (inferenceRaf) return;
    inferenceRaf = requestAnimationFrame(runInferenceLoop);
}
function stopInferenceLoop() {
    if (!inferenceRaf) return;
    cancelAnimationFrame(inferenceRaf);
    inferenceRaf = 0;
}
function runInferenceLoop(now) {
    inferenceRaf = 0;
    if (!pageActive || isRemote || !trackingEnabled()) return;
    const profile = currentPerformanceProfile();
    if (!inferenceInFlight && now - lastInferenceTime >= profile.intervalMs) {
        const generation = inferenceGeneration;
        const video = el('webcam-small');
        if (video && video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
            lastInferenceTime = now;
            inferenceInFlight = true;
            startTime = performance.now();
            const mode = currentMode;
            const run = mode === 'hand'
                ? sendHandFrame(video, generation)
                : (mode === 'auto'
                    ? sendAutoFrame(video, generation)
                    : sendFaceFrame(video, generation));
            run.catch(error => {
                if (mode === 'hand' || mode === 'auto') {
                    handleHandsFrameFailure(error);
                } else {
                    console.warn('Face tracking frame failed:', error);
                }
            }).finally(() => {
                if (generation === inferenceGeneration) {
                    frameCounter++;
                }
                inferenceInFlight = false;
            });
        }
    }
    inferenceRaf = requestAnimationFrame(runInferenceLoop);
}
async function sendFaceFrame(video, generation) {
    if (!faceMesh || generation !== inferenceGeneration) return;
    await faceMesh.send({ image: video });
}
async function sendAutoFrame(video, generation) {
    await sendFaceFrame(video, generation);
    if (generation !== inferenceGeneration) return;
    autoHandFrameCounter++;
    await sendHandFrame(video, generation);
}
async function sendHandFrame(video, generation) {
    const handTracker = await ensureHandsReady();
    if (!handTracker || generation !== inferenceGeneration) return;
    await handTracker.send({ image: video });
}
function setupDraggablePanel() {
    const panel = document.getElementById('tracker-panel');
    const title = document.querySelector('#tracker-panel .section-title');
    let isDragging = false;
    let holdTimer = null;
    let startX, startY;
    panel.style.left = '10px';
    panel.style.top = '260px';
    function clientPoint(event) {
        if (event.touches && event.touches.length) return event.touches[0];
        if (event.changedTouches && event.changedTouches.length) return event.changedTouches[0];
        return event;
    }
    function startDrag(event) {
        const point = clientPoint(event);
        isDragging = true;
        startX = point.clientX - panel.offsetLeft;
        startY = point.clientY - panel.offsetTop;
        title.classList.add('fake-hover');
    }
    function cancelHold() {
        if (holdTimer) clearTimeout(holdTimer);
        holdTimer = null;
    }
    function beginHold(event) {
        cancelHold();
        holdTimer = setTimeout(() => startDrag(event), 320);
    }
    function movePanel(event) {
        if (!isDragging) return;
        const point = clientPoint(event);
        let newLeft = point.clientX - startX;
        let newTop = point.clientY - startY;
        newLeft = Math.max(0, Math.min(window.innerWidth - panel.offsetWidth, newLeft));
        newTop = Math.max(0, Math.min(window.innerHeight - panel.offsetHeight, newTop));
        panel.style.left = `${newLeft}px`;
        panel.style.top = `${newTop}px`;
        event.preventDefault();
    }
    function endDrag() {
        cancelHold();
        isDragging = false;
        title.classList.remove('fake-hover');
    }
    title.addEventListener('mousedown', beginHold);
    title.addEventListener('touchstart', beginHold, {passive: true});
    document.addEventListener('mousemove', movePanel);
    document.addEventListener('touchmove', movePanel, {passive: false});
    document.addEventListener('mouseup', endDrag);
    document.addEventListener('touchend', endDrag);
    document.addEventListener('touchcancel', endDrag);
}
function loadSettings() {
    document.querySelectorAll('input[type=range], input[type=number], input[type=checkbox], select').forEach(el => {
        const val = localStorage.getItem(el.id);
        if (val !== null) {
            if (el.type === 'checkbox') {
                el.checked = val === 'true';
            } else {
                el.value = val;
            }
            if (el.oninput) el.oninput({target: el});
        }
    });
}
function syncClientSendSettingsFromControls() {
    if (!isClient) return;
    const sendAllToggle = el('send-all');
    const sendNoneToggle = el('send-none');
    const ids = ['send-iris', 'send-nose', 'send-yaw-pitch', 'send-fingertips', 'send-full-face', 'send-full-hand'];
    if (sendAllToggle?.checked) {
        ids.forEach(id => {
            const node = el(id);
            if (node) node.checked = true;
        });
        if (sendNoneToggle) sendNoneToggle.checked = false;
    } else if (sendNoneToggle?.checked) {
        ids.forEach(id => {
            const node = el(id);
            if (node) node.checked = false;
        });
    }
    sendIris = !!el('send-iris')?.checked;
    sendNose = !!el('send-nose')?.checked;
    sendYawPitch = !!el('send-yaw-pitch')?.checked;
    sendFingertips = !!el('send-fingertips')?.checked;
    sendFullFace = !!el('send-full-face')?.checked;
    sendFullHand = !!el('send-full-hand')?.checked;
    sendAll = !!sendAllToggle?.checked;
    sendNone = !!sendNoneToggle?.checked;
}
function dist(p1, p2) {
    return Math.hypot(p1.x - p2.x, p1.y - p2.y, (p1.z || 0) - (p2.z || 0));
}
function getEAR(lm, isLeft) {
    const points = isLeft ? [362, 263, 386, 374, 385, 380] : [33, 133, 159, 145, 158, 153];
    const d1 = dist(lm[points[2]], lm[points[3]]);
    const d2 = dist(lm[points[4]], lm[points[5]]);
    const horiz = dist(lm[points[0]], lm[points[1]]);
    return (d1 + d2) / (2 * horiz);
}
function loadGestureCalibration() {
    try {
        const winkRaw = localStorage.getItem('wink-calibration-v1');
        winkCalibration = winkRaw ? JSON.parse(winkRaw) : null;
    } catch (_) {
        winkCalibration = null;
    }
    try {
        const pinchRaw = localStorage.getItem('pinch-calibration-v1');
        pinchCalibration = pinchRaw ? JSON.parse(pinchRaw) : null;
    } catch (_) {
        pinchCalibration = null;
    }
    updateGestureStatus();
}
function saveWinkCalibration() {
    if (winkCalibration) {
        localStorage.setItem('wink-calibration-v1', JSON.stringify(winkCalibration));
    } else {
        localStorage.removeItem('wink-calibration-v1');
    }
    updateGestureStatus();
}
function savePinchCalibration() {
    if (pinchCalibration) {
        localStorage.setItem('pinch-calibration-v1', JSON.stringify(pinchCalibration));
    } else {
        localStorage.removeItem('pinch-calibration-v1');
    }
    updateGestureStatus();
}
function updateGestureStatus() {
    const winkStatus = el('wink-record-status');
    const pinchStatus = el('pinch-record-status');
    const winkButton = el('record-wink');
    const pinchButton = el('record-pinch');
    if (winkStatus) {
        if (winkRecordStage === 'left') {
            winkStatus.innerText = 'Wink your left eye, keep it held, then click Winked.';
        } else if (winkRecordStage === 'right') {
            winkStatus.innerText = 'Now wink your right eye, keep it held, then click Winked.';
        } else if (winkCalibration?.left && winkCalibration?.right) {
            winkStatus.innerText = `Recorded. L ${winkCalibration.left.closed.toFixed(3)} / R ${winkCalibration.right.closed.toFixed(3)}`;
        } else {
            winkStatus.innerText = 'Use defaults or record both eyes for best results.';
        }
    }
    if (pinchStatus) {
        if (pinchRecordStage === 'pinching') {
            pinchStatus.innerText = 'Pinch thumb and index together, keep holding, then click Pinched.';
        } else if (pinchCalibration?.threshold) {
            pinchStatus.innerText = `Recorded threshold ${pinchCalibration.threshold.toFixed(3)}.`;
        } else {
            pinchStatus.innerText = 'Use default pinch distance or record your own.';
        }
    }
    if (winkButton) winkButton.innerText = winkRecordStage === 'idle' ? 'Record Wink' : 'Winked';
    if (pinchButton) pinchButton.innerText = pinchRecordStage === 'idle' ? 'Record Pinch' : 'Pinched';
}
function fallbackWinkThresholds() {
    return {
        leftClosed: 0.18,
        leftOpen: 0.25,
        rightClosed: 0.18,
        rightOpen: 0.25
    };
}
function winkThresholds() {
    if (winkCalibration?.left && winkCalibration?.right) {
        return {
            leftClosed: winkCalibration.left.closed,
            leftOpen: winkCalibration.right.otherOpen,
            rightClosed: winkCalibration.right.closed,
            rightOpen: winkCalibration.left.otherOpen
        };
    }
    return fallbackWinkThresholds();
}
function updateWinkStateFromEAR() {
    const thresholds = winkThresholds();
    leftClosed = currentLeftEAR <= thresholds.leftClosed;
    rightClosed = currentRightEAR <= thresholds.rightClosed;
    const leftOpen = currentLeftEAR >= thresholds.leftOpen * 0.88;
    const rightOpen = currentRightEAR >= thresholds.rightOpen * 0.88;
    const leftWink = leftClosed && rightOpen;
    const rightWink = rightClosed && leftOpen;
    isWinking = leftWink || rightWink;
    const blinkClosed = Math.min(thresholds.leftClosed, thresholds.rightClosed);
    const avgEAR = (currentLeftEAR + currentRightEAR) / 2;
    if (avgEAR < blinkClosed) {
        closedCount++;
    } else {
        closedCount = 0;
    }
    eyesClosed = closedCount > 5;
}
function calibratedPinchThreshold() {
    return pinchCalibration?.threshold || 0.05;
}
function hasReadableEarSample() {
    return Number.isFinite(currentLeftEAR)
        && Number.isFinite(currentRightEAR)
        && currentLeftEAR > 0.04
        && currentRightEAR > 0.04;
}
function recordCurrentWinkStage() {
    if (winkRecordStage === 'idle') {
        winkCalibration = { left: null, right: null, recordedAt: Date.now() };
        winkRecordStage = 'left';
        updateGestureStatus();
        return;
    }
    if (!hasReadableEarSample()) {
        const winkStatus = el('wink-record-status');
        if (winkStatus) winkStatus.innerText = 'Face sample is not ready yet.';
        return;
    }
    if (winkRecordStage === 'left') {
        winkCalibration.left = {
            closed: currentLeftEAR,
            otherOpen: currentRightEAR,
            recordedAt: Date.now()
        };
        winkRecordStage = 'right';
        updateGestureStatus();
        return;
    }
    if (winkRecordStage === 'right') {
        winkCalibration.right = {
            closed: currentRightEAR,
            otherOpen: currentLeftEAR,
            recordedAt: Date.now()
        };
        winkRecordStage = 'idle';
        saveWinkCalibration();
    }
}
function recordCurrentPinchStage() {
    if (pinchRecordStage === 'idle') {
        pinchRecordStage = 'pinching';
        updateGestureStatus();
        return;
    }
    if (!hasHand || !Number.isFinite(currentPinchDistance) || currentPinchDistance <= 0 || currentPinchDistance > 0.5) {
        const pinchStatus = el('pinch-record-status');
        if (pinchStatus) pinchStatus.innerText = 'Hand pinch sample is not ready yet.';
        return;
    }
    pinchCalibration = {
        threshold: Number.isFinite(currentPinchDistance) ? currentPinchDistance : 0.05,
        recordedAt: Date.now()
    };
    pinchRecordStage = 'idle';
    savePinchCalibration();
}
function setUnifiedCursorValue(id, value, decimals = 3) {
    const input = el(id);
    const num = el(`${id}-num`);
    const display = el(`${id}-val`);
    if (input) input.value = value;
    if (num) num.value = Number(value).toFixed(decimals);
    if (display) display.innerText = Number(value).toFixed(decimals);
    localStorage.setItem(id, String(value));
}
function transpose(mat) {
    return mat[0].map((_, colIndex) => mat.map(row => row[colIndex]));
}
function matMul(a, b) {
    return a.map(row => transpose(b).map(col => row.reduce((sum, val, i) => sum + val * col[i], 0)));
}
function gaussianElimination(a) {
    let n = a.length;
    let aa = a.map(row => [...row]);
    for (let i = 0; i < n; i++) {
        let max = i;
        for (let k = i + 1; k < n; k++) {
            if (Math.abs(aa[k][i]) > Math.abs(aa[max][i])) {
                max = k;
            }
        }
        [aa[i], aa[max]] = [aa[max], aa[i]];
        for (let k = i + 1; k < n; k++) {
            let c = -aa[k][i] / aa[i][i];
            for (let j = i; j < n + 1; j++) {
                if (i === j) {
                    aa[k][j] = 0;
                } else {
                    aa[k][j] += c * aa[i][j];
                }
            }
        }
    }
    let x = new Array(n).fill(0);
    for (let i = n - 1; i >= 0; i--) {
        x[i] = aa[i][n] / aa[i][i];
        for (let k = i - 1; k >= 0; k--) {
            aa[k][n] -= aa[k][i] * x[i];
        }
    }
    return x;
}
function isDraggableElement(elem) {
    if (!elem) return false;
    if (elem.closest('#tracker-panel .section-title')) return true;
    if (elem.tagName === 'INPUT' && elem.type === 'range') return true;
    return false;
}
function isClickableElement(elem) {
    if (!elem) return false;
    const tag = elem.tagName.toLowerCase();
    if (tag === 'button' || tag === 'a' || tag === 'select') return true;
    if (tag === 'input') {
        const type = elem.type.toLowerCase();
        return type === 'button' || type === 'submit' || type === 'checkbox' || type === 'radio' || type === 'text' || type === 'number' || type === 'range' || type === 'color' || type === 'file';
    }
    return false;
}
function hoverStateForElement(elem) {
    return {
        draggable: isDraggableElement(elem),
        clickable: isClickableElement(elem)
    };
}
function cursorStateFromHover() {
    if (dragging || isWinking) return dragging ? 'dragging' : 'active';
    const draggable = uiVisible ? isHoverRed : parentHoverDraggable;
    const clickable = uiVisible ? isHoverBlue : parentHoverClickable;
    if (draggable && clickable) return 'both-hover';
    if (draggable) return 'drag-hover';
    if (clickable) return 'click-hover';
    return 'idle';
}
function isParentPointerTarget(elem) {
    return !!(elem && elem.__deepxParentPointerTarget);
}
function getTrackerEventTarget(x, y) {
    return uiVisible ? document.elementFromPoint(x, y) : parentPointerTarget;
}
function postParentPointer(action, x, y, options = {}) {
    if (window.parent === window) return;
    window.parent.postMessage({
        type: 'deepx-tracker-pointer',
        action,
        x,
        y,
        button: options.button ?? 0,
        buttons: options.buttons ?? 0
    }, '*');
}
function postParentHoverMove(x, y, options = {}, force = false) {
    const dx = Math.abs(x - lastParentHoverX);
    const dy = Math.abs(y - lastParentHoverY);
    if (!force && Number.isFinite(dx) && Number.isFinite(dy) && dx < 0.75 && dy < 0.75) {
        return;
    }
    lastParentHoverX = x;
    lastParentHoverY = y;
    postParentPointer('mousemove', x, y, options);
}
function dispatchTrackerMouseEvent(targetElem, eventName, x, y, options = {}) {
    if (!targetElem) return;
    if (isParentPointerTarget(targetElem)) {
        postParentPointer(eventName, x, y, options);
        return;
    }
    const mouseEvent = new MouseEvent(eventName, {
        bubbles: true,
        cancelable: true,
        view: window,
        clientX: x,
        clientY: y,
        button: options.button ?? 0,
        buttons: options.buttons ?? 0
    });
    targetElem.dispatchEvent(mouseEvent);
}
function dispatchTrackerFocusAndClick(elem, x, y) {
    if (!elem) return;
    if (isParentPointerTarget(elem)) {
        postParentPointer('focus', x, y);
        postParentPointer('click', x, y);
        return;
    }
    const focusEvent = new FocusEvent('focus', {
        bubbles: true,
        cancelable: true,
        view: window
    });
    elem.dispatchEvent(focusEvent);
    const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: window,
        clientX: x,
        clientY: y
    });
    elem.dispatchEvent(clickEvent);
    if (elem.tagName === 'SELECT') {
        const inputEvent = new InputEvent('input', {
            bubbles: true,
            cancelable: true
        });
        elem.dispatchEvent(inputEvent);
        const changeEvent = new Event('change', {
            bubbles: true,
            cancelable: true
        });
        elem.dispatchEvent(changeEvent);
    }
}
function sendTrackerState() {
    document.body.classList.toggle('tracker-ui-hidden', !uiVisible);
    if (window.parent !== window) {
        window.parent.postMessage({
            type: 'deepx-tracker-state',
            uiVisible,
            linkActive: trackingEnabled(),
            showCursor: showCursorEnabled(),
            cursorAllowed: trackingEnabled() && showCursorEnabled() && pageActive,
            cursorEnabled: cursorFunctional()
        }, '*');
    }
}
function setTrackerUiVisible(visible) {
    uiVisible = visible;
    const display = uiVisible ? 'block' : 'none';
    document.getElementById('tracker-panel').style.display = display;
    document.getElementById('ui-video-box').style.display = display;
    document.getElementById('client-panel').style.display = (isClient && uiVisible) ? 'block' : 'none';
    document.getElementById('toggle-btns').style.display = display;
    document.getElementById('ui-text-canvas').style.display = display;
    document.getElementById('timer-overlay').style.display = 'none';
    document.getElementById('cal-dot').style.display = 'none';
    sendTrackerState();
}
function resumeTrackerAfterRealMouse() {
    cursorPausedByRealMouse = false;
    targetX = mouseX;
    targetY = mouseY;
    smoothX = mouseX;
    smoothY = mouseY;
    prevCenterX = mouseX;
    prevCenterY = mouseY;
    prevHeadYaw = currentHeadYaw;
    prevHeadPitch = currentHeadPitch;
    prevHandIndexX = currentHandIndexX;
    prevHandIndexY = currentHandIndexY;
    if (trackingEnabled() && showCursorEnabled()) {
        setTrackerCursorVisible(true);
        scheduleRealCursorHide();
    }
    if (!uiVisible) postParentHoverMove(mouseX, mouseY, {buttons: 0}, true);
}
function handleRealMouseActivity(x, y, deltaY = 0) {
    if (typeof x === 'number') mouseX = x;
    if (typeof y === 'number') mouseY = y;
    if (deltaY && isMouseTracking) mouseWheelZ += deltaY * wheelSens;
    cursorPausedByRealMouse = true;
    setTrackerCursorVisible(false);
    setRealCursorHidden(false);
    if (realCursorHideTimer) clearTimeout(realCursorHideTimer);
    if (realMouseResumeTimer) clearTimeout(realMouseResumeTimer);
    realMouseResumeTimer = setTimeout(resumeTrackerAfterRealMouse, REAL_MOUSE_IDLE_DELAY_MS);
}
async function stopLocalTrackingCamera(options = {}) {
    if (!options.keepLoop) inferenceGeneration++;
    if (!options.keepLoop) stopInferenceLoop();
    if (cameraSvc) {
        try {
            await cameraSvc.stop();
        } catch (_) {}
        cameraSvc = null;
    }
    const video = el('webcam-small');
    const stream = localStream || (video ? video.srcObject : null);
    if (stream && stream.getTracks) {
        stream.getTracks().forEach(track => track.stop());
    }
    localStream = null;
    currentVideoSize = 0;
    if (video) video.srcObject = null;
}
async function restartLocalTrackingCamera() {
    if (isRemote) return;
    if (!trackingEnabled()) return;
    await updatePerformanceSettings();
}
function handlePageVisibility() {
    pageActive = !document.hidden;
    if (!pageActive) {
        setTrackerCursorVisible(false);
        setRealCursorHidden(false);
        stopLocalTrackingCamera();
        return;
    }
    restartLocalTrackingCamera();
    if (trackingEnabled() && showCursorEnabled()) {
        setTrackerCursorVisible(cursorFunctional());
        scheduleRealCursorHide();
    }
}
function postHeadPoseSnapshot({
    x = currentThreeDCamera.x,
    y = currentThreeDCamera.y,
    z = currentThreeDCamera.z,
    yaw = currentHeadYaw,
    pitch = currentHeadPitch,
    yawNorm = currentHeadYawNorm,
    pitchNorm = currentHeadPitchNorm
} = {}) {
    const payload = {
        type: 'deepx-head-pose',
        x,
        y,
        z,
        yaw,
        pitch,
        yawNorm,
        pitchNorm,
        cameraSpeed: numericSetting('three-d-camera-speed', 1),
        timestamp: performance.now()
    };
    try {
        window.parent?.postMessage(payload, '*');
    } catch (_) {}
}
function landmarkOffset(point) {
    if (!point) return { x: 0, y: 0 };
    return { x: (point.x - 0.5) * 2, y: (point.y - 0.5) * 2 };
}
function averageLandmarks(lm, indices) {
    let x = 0;
    let y = 0;
    let count = 0;
    for (const index of indices) {
        const point = lm[index];
        if (!point) continue;
        x += point.x;
        y += point.y;
        count++;
    }
    if (!count) return { x: 0, y: 0 };
    return { x: (x / count - 0.5) * 2, y: (y / count - 0.5) * 2 };
}
function rawThreeDCameraSignal(lm, rawFaceX, rawFaceY, rawFaceZ, rawHeadYaw, rawHeadPitch) {
    const source = el('three-d-camera-source')?.value || 'nose';
    let xy;
    if (source === 'left-eye') {
        xy = averageLandmarks(lm, [33, 133, 159, 145, 160, 144, 158, 153]);
    } else if (source === 'right-eye') {
        xy = averageLandmarks(lm, [362, 263, 386, 374, 385, 380, 387, 373]);
    } else if (source === 'eye-center') {
        xy = averageLandmarks(lm, [33, 133, 159, 145, 362, 263, 386, 374]);
    } else if (source === 'head-yaw-pitch') {
        xy = { x: rawHeadYaw / 60, y: rawHeadPitch / 40 };
    } else if (source === 'biased-eye') {
        const eyes = averageLandmarks(lm, [33, 133, 159, 145, 362, 263, 386, 374]);
        xy = {
            x: eyes.x + currentDx * 1.8,
            y: eyes.y + currentDy * 1.8
        };
    } else {
        xy = { x: rawFaceX, y: rawFaceY };
    }
    return {
        x: Math.max(-3, Math.min(3, xy.x)),
        y: Math.max(-3, Math.min(3, xy.y)),
        z: rawFaceZ
    };
}
function filterThreeDCameraAxis(axis, rawValue) {
    const previous = Number(currentThreeDCamera[axis]) || 0;
    const deadZone = numericSetting(`three-d-camera-dz-${axis}`, 0.01);
    const smoothing = Math.max(0, Math.min(0.98, numericSetting(`three-d-camera-smooth-${axis}`, 0.7)));
    const delta = rawValue - previous;
    const adjusted = Math.abs(delta) <= deadZone
        ? previous
        : previous + (Math.abs(delta) - deadZone) * Math.sign(delta);
    return previous * smoothing + adjusted * (1 - smoothing);
}
function updateThreeDCameraSignal(raw) {
    currentThreeDCamera = {
        x: filterThreeDCameraAxis('x', raw.x),
        y: filterThreeDCameraAxis('y', raw.y),
        z: filterThreeDCameraAxis('z', raw.z)
    };
}
function processFace(lm) {
    let rawHeadYaw = ((lm[1].x - lm[234].x) / (lm[454].x - lm[234].x) - 0.5) * -120;
    let rawHeadPitch = ((lm[1].y - lm[10].y) / (lm[152].y - lm[10].y) - 0.5) * 80;
    const rawFaceX = (lm[1].x - 0.5) * 2;
    const rawFaceY = (lm[1].y - 0.5) * 2;
    const rawFaceZ = Math.sqrt(Math.pow(lm[33].x - lm[263].x, 2) + Math.pow(lm[33].y - lm[263].y, 2));
    const deadZoneHeadYaw = numericSetting('dz-head-yaw', 0);
    const deadZoneHeadPitch = numericSetting('dz-hp', 0);
    let adjustedHeadYaw = rawHeadYaw;
    let deltaYaw = rawHeadYaw - currentHeadYaw;
    if (Math.abs(deltaYaw) <= deadZoneHeadYaw) {
        adjustedHeadYaw = currentHeadYaw;
    } else {
        adjustedHeadYaw = currentHeadYaw + (Math.abs(deltaYaw) - deadZoneHeadYaw) * Math.sign(deltaYaw);
    }
    currentHeadYaw = currentHeadYaw * inputSmooth + adjustedHeadYaw * (1 - inputSmooth);
    let adjustedHeadPitch = rawHeadPitch;
    let deltaPitch = rawHeadPitch - currentHeadPitch;
    if (Math.abs(deltaPitch) <= deadZoneHeadPitch) {
        adjustedHeadPitch = currentHeadPitch;
    } else {
        adjustedHeadPitch = currentHeadPitch + (Math.abs(deltaPitch) - deadZoneHeadPitch) * Math.sign(deltaPitch);
    }
    currentHeadPitch = currentHeadPitch * inputSmooth + adjustedHeadPitch * (1 - inputSmooth);
    currentHeadYawNorm = currentHeadYaw / 60;
    currentHeadPitchNorm = currentHeadPitch / 40;
    let useIris = lm[468] && lm[473] && lm[33] && lm[133] && lm[159] && lm[145] && lm[158] && lm[153] && lm[362] && lm[263] && lm[386] && lm[374] && lm[385] && lm[380];
    if (useIris) {
        const leftYawRatio = (lm[468].x - lm[33].x) / (lm[133].x - lm[33].x);
        const rightYawRatio = (lm[473].x - lm[362].x) / (lm[263].x - lm[362].x);
        const avgYawRatio = (leftYawRatio + rightYawRatio) / 2;
        const leftPitchRatio = (lm[468].y - lm[159].y) / (lm[145].y - lm[159].y);
        const rightPitchRatio = (lm[473].y - lm[386].y) / (lm[374].y - lm[386].y);
        const avgPitchRatio = (leftPitchRatio + rightPitchRatio) / 2;
        const deadZoneIrisX = numericSetting('dz-ix', 0);
        const deadZoneIrisY = numericSetting('dz-iy', 0);
        let rawDx = avgYawRatio - 0.5;
        let adjustedDx = rawDx;
        let deltaDx = rawDx - currentDx;
        if (Math.abs(deltaDx) <= deadZoneIrisX) {
            adjustedDx = currentDx;
        } else {
            adjustedDx = currentDx + (Math.abs(deltaDx) - deadZoneIrisX) * Math.sign(deltaDx);
        }
        currentDx = adjustedDx;
        let rawDy = avgPitchRatio - 0.5;
        let adjustedDy = rawDy;
        let deltaDy = rawDy - currentDy;
        if (Math.abs(deltaDy) <= deadZoneIrisY) {
            adjustedDy = currentDy;
        } else {
            adjustedDy = currentDy + (Math.abs(deltaDy) - deadZoneIrisY) * Math.sign(deltaDy);
        }
        currentDy = adjustedDy;
        currentIrisYaw = currentDx * -200;
        currentIrisPitch = currentDy * 400;
        currentAvgYawRatio = currentDx + 0.5;
        currentAvgPitchRatio = currentDy + 0.5;
    } else {
        currentDx = 0;
        currentDy = 0;
        currentIrisYaw = 0;
        currentIrisPitch = 0;
        currentAvgYawRatio = 0.5;
        currentAvgPitchRatio = 0.5;
    }
    currentFace.x = rawFaceX;
    currentFace.y = rawFaceY;
    currentFace.z = rawFaceZ;
    updateThreeDCameraSignal(
        rawThreeDCameraSignal(lm, rawFaceX, rawFaceY, rawFaceZ, rawHeadYaw, rawHeadPitch)
    );
    currentLeftEAR = getEAR(lm, true);
    currentRightEAR = getEAR(lm, false);
    updateWinkStateFromEAR();
    postHeadPoseSnapshot({
        x: currentThreeDCamera.x,
        y: currentThreeDCamera.y,
        z: currentThreeDCamera.z,
        yaw: rawHeadYaw,
        pitch: rawHeadPitch,
        yawNorm: rawHeadYaw / 60,
        pitchNorm: rawHeadPitch / 40
    });
    updateTrackerTargets(lm);
}
function processHand(lm) {
    let rawIndexX = lm[8].x;
    let rawIndexY = lm[8].y;
    const deadZoneHandX = numericSetting('dz-hx', 0);
    const deadZoneHandY = numericSetting('dz-hand-y', 0);
    let deltaX = rawIndexX - currentHandIndexX;
    let adjustedX = rawIndexX;
    if (Math.abs(deltaX) <= deadZoneHandX) {
        adjustedX = currentHandIndexX;
    } else {
        adjustedX = currentHandIndexX + (Math.abs(deltaX) - deadZoneHandX) * Math.sign(deltaX);
    }
    currentHandIndexX = currentHandIndexX * inputSmooth + adjustedX * (1 - inputSmooth);
    let deltaY = rawIndexY - currentHandIndexY;
    let adjustedY = rawIndexY;
    if (Math.abs(deltaY) <= deadZoneHandY) {
        adjustedY = currentHandIndexY;
    } else {
        adjustedY = currentHandIndexY + (Math.abs(deltaY) - deadZoneHandY) * Math.sign(deltaY);
    }
    currentHandIndexY = currentHandIndexY * inputSmooth + adjustedY * (1 - inputSmooth);
    currentHandDx = currentHandIndexX - anchorHand.x;
    currentHandDy = currentHandIndexY - anchorHand.y;
    const pinchDist = Math.hypot(lm[4].x - lm[8].x, lm[4].y - lm[8].y, lm[4].z - lm[8].z);
    currentPinchDistance = pinchDist;
    isPinching = pinchDist <= calibratedPinchThreshold();
}
function setupOnResults() {
    faceMesh.onResults((results) => {
        latency = performance.now() - startTime;
        if (isClient) {
            if (results.multiFaceLandmarks && results.multiFaceLandmarks[0] && !sendNone) {
                if (currentMode !== 'hand' || !hasHand) {
                    const lm = results.multiFaceLandmarks[0];
                    processFace(lm);
                    let sendData = {type: 'face', timestamp: Date.now(), mpLatency: latency};
                    let partial = {};
                    let drawLmList = [];
                    if (sendIris) {
                        partial.iris = {dx: currentDx, dy: currentDy};
                        IRIS_INDICES.forEach(i => drawLmList.push({i, x: lm[i].x, y: lm[i].y, z: lm[i].z}));
                    }
                    if (sendNose) {
                        partial.nose = {x: currentFace.x, y: currentFace.y};
                        drawLmList.push({i: 1, x: lm[1].x, y: lm[1].y, z: lm[1].z});
                    }
                    partial.camera3d = {...currentThreeDCamera};
                    if (sendYawPitch) {
                        partial.yawPitch = {yaw: currentHeadYaw, pitch: currentHeadPitch};
                        YAW_PITCH_INDICES.forEach(i => drawLmList.push({i, x: lm[i].x, y: lm[i].y, z: lm[i].z}));
                    }
                    if (sendFullFace) {
                        lm.forEach((point, i) => {
                            if (point) drawLmList.push({i, x: point.x, y: point.y, z: point.z});
                        });
                    }
                    partial.ear = {left: currentLeftEAR, right: currentRightEAR};
                    partial.z = currentFace.z;
                    if (Object.keys(partial).length > 0) sendData.partial = partial;
                    if (drawLmList.length > 0) sendData.drawLm = drawLmList;
                    if (conn && conn.open) conn.send(sendData);
                }
            }
            return;
        } else {
            if (currentMode === 'hand') return;
            if (!document.getElementById('tracking-toggle').checked) { setTrackerCursorVisible(false); return; }
            setTrackerCursorVisible(cursorFunctional());
            if (results.multiFaceLandmarks && results.multiFaceLandmarks[0]) {
                faceLm = results.multiFaceLandmarks[0];
                processFace(faceLm);
                if (!isAutoMode() || activeTracker === 'face') {
                    scheduleTrackerOverlayDraw();
                }
            } else {
                faceLm = null;
                scheduleTrackerOverlayDraw(true);
            }
        }
    });
}
function isValidHandCandidate(lm, handedness) {
    if (!Array.isArray(lm) || lm.length < 21) return false;
    const score = handedness?.score ?? handedness?.[0]?.score ?? 1;
    if (isAutoMode() && Number.isFinite(score) && score < 0.75) return false;
    let inBounds = 0;
    let minX = 1, maxX = 0, minY = 1, maxY = 0;
    for (const p of lm) {
        if (!p || !Number.isFinite(p.x) || !Number.isFinite(p.y)) return false;
        if (p.x >= -0.05 && p.x <= 1.05 && p.y >= -0.05 && p.y <= 1.05) inBounds++;
        minX = Math.min(minX, p.x);
        maxX = Math.max(maxX, p.x);
        minY = Math.min(minY, p.y);
        maxY = Math.max(maxY, p.y);
    }
    if (inBounds < 18) return false;
    const bboxW = maxX - minX;
    const bboxH = maxY - minY;
    if (bboxW < 0.055 || bboxH < 0.055) return false;
    const palmWidth = dist(lm[5], lm[17]);
    const palmLength = dist(lm[0], lm[9]);
    const indexLength = dist(lm[5], lm[8]);
    if (palmWidth < 0.025 || palmLength < 0.035 || indexLength < 0.025) return false;
    if (Math.max(bboxW, bboxH) / Math.max(0.001, Math.min(bboxW, bboxH)) > 8) return false;
    return true;
}
function setupHandsResults(tracker = hands) {
    if (!tracker || handsResultsAttached) return;
    handsResultsAttached = true;
    tracker.onResults((results) => {
        if (tracker !== hands) return;
        latency = performance.now() - startTime;
        if (isClient) {
            hasHand = results.multiHandLandmarks && results.multiHandLandmarks.length > 0 &&
                isValidHandCandidate(results.multiHandLandmarks[0], results.multiHandedness?.[0]);
            if ((currentMode === 'hand' || currentMode === 'auto') && hasHand && !sendNone) {
                const lm = results.multiHandLandmarks[0];
                processHand(lm);
                let sendData = {type: 'hand', timestamp: Date.now(), mpLatency: latency};
                let partial = {};
                let drawLmList = [];
                if (sendFingertips) {
                    partial.fingertips = {index: lm[8], thumb: lm[4]};
                    drawLmList.push({i: 4, x: lm[4].x, y: lm[4].y, z: lm[4].z});
                    drawLmList.push({i: 8, x: lm[8].x, y: lm[8].y, z: lm[8].z});
                }
                if (sendFullHand) {
                    for (let i = 0; i < 21; i++) {
                        drawLmList.push({i, x: lm[i].x, y: lm[i].y, z: lm[i].z});
                    }
                }
                if (Object.keys(partial).length > 0) sendData.partial = partial;
                if (drawLmList.length > 0) sendData.drawLm = drawLmList;
                if (conn && conn.open) conn.send(sendData);
            }
            return;
        } else {
            if (tracker !== hands || !(currentMode === 'hand' || isAutoMode()) || !trackingEnabled()) {
                clearHandState();
                return;
            }
            const lm = results.multiHandLandmarks && results.multiHandLandmarks.length > 0
                ? results.multiHandLandmarks[0]
                : null;
            const validHand = lm && isValidHandCandidate(lm, results.multiHandedness?.[0]);
            if (validHand) {
                hasHand = true;
                handLm = lm;
                if (activeTracker !== 'hand') {
                    activeTracker = 'hand';
                }
                processHand(handLm);
                scheduleTrackerOverlayDraw();
                lastHandDataTime = performance.now();
                handFrameFailures = 0;
            } else {
                if (!isAutoMode() || performance.now() - lastHandDataTime > 350) {
                    clearHandState();
                    activeTracker = 'face';
                }
                scheduleTrackerOverlayDraw(true);
            }
        }
    });
}
function updateTrackerTargets(lm) {
    const s = numericSetting('s-sens', 100) / 100;
    let rawRelX = currentFace.x - anchorFace.x;
    let rawRelY = currentFace.y - anchorFace.y;
    let rawRelZ = anchorFace.z - currentFace.z;
    let finalRelX = rawRelX;
    let finalRelY = rawRelY;
    let finalRelZ = rawRelZ;
    if (isMouseTracking) {
        smoothedRel.x = finalRelX;
        smoothedRel.y = finalRelY;
        smoothedRel.z = finalRelZ;
    } else {
        smoothedRel.x = smoothedRel.x * s + finalRelX * (1 - s);
        smoothedRel.y = smoothedRel.y * s + finalRelY * (1 - s);
        smoothedRel.z = smoothedRel.z * s + finalRelZ * (1 - s);
    }
}
function toggleUI() {
    setTrackerUiVisible(!uiVisible);
}
function frameUpdate() {
    const now = performance.now();
    dt = now - prevTime;
    prevTime = now;
    if (now - lastFpsTime >= 1000) {
        fps = (frameCounter / ((now - lastFpsTime) / 1000)).toFixed(1);
        frameCounter = 0;
        lastFpsTime = now;
        if (isClient) {
            document.getElementById('fps-span').innerText = fps;
            document.getElementById('lat-span').innerText = latency.toFixed(0);
        }
    }
    if ((currentMode === 'hand' || isAutoMode()) && (now - lastHandDataTime > 350)) {
        clearHandState();
        if (isAutoMode()) {
            activeTracker = 'face';
            scheduleTrackerOverlayDraw();
        }
    }
    const cursorIsFunctional = cursorFunctional();
    if (cursorIsFunctional) {
        const mode = cursorControlMode();
        const isHead = mode === 'head';
        let rawRelYaw, rawRelPitch;
        if (mode === 'hand') {
            if (hasHand) {
                const deltaX = currentHandIndexX - prevHandIndexX;
                const deltaY = currentHandIndexY - prevHandIndexY;
                const frameDt = Math.max(dt / 1000, 0.001);
                const velocity = Math.hypot(deltaX, deltaY) / frameDt;
                const speed = numericSetting('hand-cursor-speed', handCursorSpeed);
                const accelSetting = numericSetting('hand-cursor-accel', handCursorAcceleration);
                const accel = 1 + Math.min(1, velocity / 0.8) * accelSetting;
                let cursorDeltaX = deltaX * speed * accel * -1;
                let cursorDeltaY = deltaY * speed * accel;
                targetX += cursorDeltaX;
                targetY += cursorDeltaY;
                targetX = Math.max(0, Math.min(window.innerWidth, targetX));
                targetY = Math.max(0, Math.min(window.innerHeight, targetY));
                prevHandIndexX = currentHandIndexX;
                prevHandIndexY = currentHandIndexY;
            } else {
                prevHeadYaw = currentHeadYaw;
                prevHeadPitch = currentHeadPitch;
                prevHandIndexX = currentHandIndexX;
                prevHandIndexY = currentHandIndexY;
                isWinking = false;
            }
        } else if (isHead) {
            const deltaYaw = currentHeadYaw - prevHeadYaw;
            const deltaPitch = currentHeadPitch - prevHeadPitch;
            const frameDt = Math.max(dt / 1000, 0.001);
            const velocity = Math.hypot(deltaYaw, deltaPitch) / frameDt;
            const accelSetting = numericSetting('head-cursor-accel', headCursorAcceleration);
            const threshold = 400 / Math.max(0.001, accelSetting);
            const t = Math.max(0, Math.min(1, velocity / threshold));
            const eased = t * t * (3 - 2 * t);
            const speed = HEAD_CURSOR_MIN_SPEED + (HEAD_CURSOR_MAX_SPEED - HEAD_CURSOR_MIN_SPEED) * eased;
            let cursorDeltaX = deltaYaw * speed * 0.45;
            let cursorDeltaY = deltaPitch * speed * 0.45;
            targetX += cursorDeltaX;
            targetY += cursorDeltaY;
            targetX = Math.max(0, Math.min(window.innerWidth, targetX));
            targetY = Math.max(0, Math.min(window.innerHeight, targetY));
            prevHeadYaw = currentHeadYaw;
            prevHeadPitch = currentHeadPitch;
        } else {
            if (isIrisCalibrated) {
                const dx = currentDx;
                const dy = currentDy;
                const yaw = currentHeadYawNorm;
                const pitch = currentHeadPitchNorm;
                targetX = coeffX[0] + coeffX[1]*dx + coeffX[2]*dy + coeffX[3]*yaw + coeffX[4]*pitch + coeffX[5]*dx*dx + coeffX[6]*dx*dy + coeffX[7]*dy*dy;
                targetY = coeffY[0] + coeffY[1]*dx + coeffY[2]*dy + coeffY[3]*yaw + coeffY[4]*pitch + coeffY[5]*dx*dx + coeffY[6]*dx*dy + coeffY[7]*dy*dy;
                targetX = Math.max(0, Math.min(window.innerWidth, targetX));
                targetY = Math.max(0, Math.min(window.innerHeight, targetY));
            } else {
                const scale = 1.0;
                rawRelYaw = currentIrisYaw;
                rawRelPitch = currentIrisPitch;
                targetX = (window.innerWidth / 2) + (rawRelYaw * scale * 4);
                targetY = (window.innerHeight / 2) + (rawRelPitch * scale * 4);
            }
            prevHeadYaw = currentHeadYaw;
            prevHeadPitch = currentHeadPitch;
        }
        const sFactor = numericSetting('s-sens', 100) / 100;
        smoothX = (smoothX * sFactor) + (targetX * (1 - sFactor));
        smoothY = (smoothY * sFactor) + (targetY * (1 - sFactor));
        const centerX = smoothX;
        const centerY = smoothY;
        const finalX = Math.max(0, Math.min(window.innerWidth - cursorWidth, centerX - cursorHotspotX));
        const finalY = Math.max(0, Math.min(window.innerHeight - cursorHeight, centerY - cursorHotspotY));
        cursor.style.transform = `translate3d(${finalX}px, ${finalY}px, 0)`;
    } else {
        setTrackerCursorVisible(false);
        prevHeadYaw = currentHeadYaw;
        prevHeadPitch = currentHeadPitch;
        prevHandIndexX = currentHandIndexX;
        prevHandIndexY = currentHandIndexY;
    }
    if (isMouseTracking) {
        currentFace.x = (mouseX / window.innerWidth - 0.5) * 2;
        currentFace.y = (mouseY / window.innerHeight - 0.5) * 2;
        currentFace.z = anchorFace.z - mouseWheelZ;
        updateThreeDCameraSignal({
            x: currentFace.x,
            y: currentFace.y,
            z: currentFace.z
        });
        postHeadPoseSnapshot();
        updateTrackerTargets();
        if (tCanvas.style.display !== 'none' && now - lastHudDrawTime >= 100) {
            lastHudDrawTime = now;
            if(tCanvas.width !== window.innerWidth) { tCanvas.width = window.innerWidth; tCanvas.height = window.innerHeight; }
            drawMouseHUD();
        }
    } else if (!document.getElementById('tracking-toggle').checked) {
        tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
    } else {
        if (tCanvas.style.display !== 'none' && now - lastHudDrawTime >= 100) {
            lastHudDrawTime = now;
            if(tCanvas.width !== window.innerWidth) { tCanvas.width = window.innerWidth; tCanvas.height = window.innerHeight; }
            drawHUD();
        }
    }
    if (!cursorIsFunctional) {
        if (prevHoveredElement) {
            prevHoveredElement.classList.remove('fake-hover');
            prevHoveredElement = null;
        }
        potentialClickTarget = null;
        potentialDragTarget = null;
        isHoverRed = false;
        isHoverBlue = false;
        prevWinking = false;
        requestAnimationFrame(frameUpdate);
        return;
    }
    const centerX = smoothX;
    const centerY = smoothY;
    const deltaX = Math.abs(centerX - prevCenterX);
    const deltaY = Math.abs(centerY - prevCenterY);
    const isMoving = (deltaX > 2 || deltaY > 2);
    prevCenterX = centerX;
    prevCenterY = centerY;
    let hoveredElement = null;
    if (!uiVisible) {
        postParentHoverMove(centerX, centerY, {buttons: dragging ? 1 : 0});
        if (prevHoveredElement) {
            prevHoveredElement.classList.remove('fake-hover');
            dispatchTrackerMouseEvent(prevHoveredElement, 'mouseout', centerX, centerY);
            prevHoveredElement = null;
        }
        potentialClickTarget = null;
        potentialDragTarget = null;
        isHoverRed = false;
        isHoverBlue = false;
    } else {
        const shouldHitTest = isMoving || !cachedHoveredElement || now - lastHoverHitTestTime >= 100;
        if (shouldHitTest) {
            lastHoverHitTestTime = now;
            cachedHoveredElement = document.elementFromPoint(centerX, centerY);
        }
        hoveredElement = cachedHoveredElement;
        if (shouldHitTest && hoveredElement !== prevHoveredElement) {
            if (prevHoveredElement) {
                prevHoveredElement.classList.remove('fake-hover');
                dispatchTrackerMouseEvent(prevHoveredElement, 'mouseout', centerX, centerY);
            }
            if (hoveredElement) {
                hoveredElement.classList.add('fake-hover');
                dispatchTrackerMouseEvent(hoveredElement, 'mouseover', centerX, centerY);
                const state = hoverStateForElement(hoveredElement);
                if (state.draggable) {
                    potentialDragTarget = hoveredElement;
                    hoverRedStart = now;
                    isHoverRed = true;
                } else {
                    potentialDragTarget = null;
                    isHoverRed = false;
                }
                if (state.clickable) {
                    potentialClickTarget = hoveredElement;
                    hoverBlueStart = now;
                    isHoverBlue = true;
                } else {
                    potentialClickTarget = null;
                    isHoverBlue = false;
                }
            }
            prevHoveredElement = hoveredElement;
        }
    }
    if (isHoverRed && (now - hoverRedStart > 2000)) {
        isHoverRed = false;
        potentialDragTarget = null;
    }
    if (isHoverBlue && (now - hoverBlueStart > 1000)) {
        isHoverBlue = false;
        potentialClickTarget = null;
    }
    const mode = cursorControlMode();
    if (mode === 'hand' && hasHand) {
        if (isPinching) {
            lastPinchTime = now;
            lastPinchTrueTime = now;
            isWinking = true;
        } else {
            const timeSince = now - lastPinchTrueTime;
            if (timeSince < 500 && isMoving) {
                isWinking = true;
            } else {
                isWinking = false;
            }
        }
    }
    cursor.dataset.state = cursorStateFromHover();
    if (isWinking && !prevWinking) {
        if (now - lastDoubleDragTime < doubleDragThreshold && isHoverRed && !dragging) {
            let targetElem = getTrackerEventTarget(centerX, centerY);
            if (potentialDragTarget && isHoverRed) {
                targetElem = potentialDragTarget;
            }
            if (targetElem) {
                const panel = document.getElementById('tracker-panel');
                if (targetElem.classList.contains('section-title') && potentialDragTarget && hoveredElement !== potentialDragTarget) {
                    panel.style.left = `${centerX - (panel.offsetWidth / 2)}px`;
                    panel.style.top = `${centerY}px`;
                }
                dispatchTrackerMouseEvent(targetElem, 'mousedown', centerX, centerY, {buttons: 1});
                dragTarget = targetElem;
                winkDownSent = true;
                dragging = true;
                potentialDragTarget = null;
                isHoverRed = false;
            }
        } else if (dragging) {
            if (dragTarget) {
                dispatchTrackerMouseEvent(dragTarget, 'mouseup', centerX, centerY);
            }
            dragging = false;
            dragTarget = null;
            winkDownSent = false;
        }
        lastWinkTime = now;
        lastDoubleDragTime = now;
    }
    if (isWinking) {
        if (isDebouncingUnwink) {
            isDebouncingUnwink = false;
            winkStartTime = now - (now - unwinkStartTime);
        }
        if (!prevWinking) {
            winkStartTime = now;
            if (now - winkEndTime < 100) {
                effectiveWinkStart = now - (winkEndTime - effectiveWinkStart);
            } else {
                effectiveWinkStart = now;
            }
            winkDownSent = false;
        }
        const winkDuration = now - effectiveWinkStart;
        if (winkDuration > 1000 && !winkDownSent) {
            let targetElem = getTrackerEventTarget(centerX, centerY);
            if (potentialDragTarget && isHoverRed) {
                targetElem = potentialDragTarget;
            }
            if (targetElem) {
                const panel = document.getElementById('tracker-panel');
                if (targetElem.classList.contains('section-title') && potentialDragTarget && hoveredElement !== potentialDragTarget) {
                    panel.style.left = `${centerX - (panel.offsetWidth / 2)}px`;
                    panel.style.top = `${centerY}px`;
                }
                dispatchTrackerMouseEvent(targetElem, 'mousedown', centerX, centerY, {buttons: 1});
                dragTarget = targetElem;
                winkDownSent = true;
                dragging = true;
                potentialDragTarget = null;
                isHoverRed = false;
            }
        }
    } else {
        if (prevWinking) {
            winkEndTime = now;
            const winkDuration = winkEndTime - effectiveWinkStart;
            if (winkDuration < 1000) {
                let elem = getTrackerEventTarget(centerX, centerY);
                if (potentialClickTarget && isHoverBlue) {
                    elem = potentialClickTarget;
                }
                dispatchTrackerFocusAndClick(elem, centerX, centerY);
                potentialClickTarget = null;
                isHoverBlue = false;
            } else if (dragging && !isDebouncingUnwink) {
                if (mode === 'hand' && hasHand) {
                    if (dragTarget) {
                        dispatchTrackerMouseEvent(dragTarget, 'mouseup', centerX, centerY);
                    }
                    dragging = false;
                    dragTarget = null;
                    winkDownSent = false;
                } else {
                    unwinkStartTime = now;
                    isDebouncingUnwink = true;
                }
            }
        }
        if (isDebouncingUnwink && (now - unwinkStartTime > 1000)) {
            if (dragTarget) {
                dispatchTrackerMouseEvent(dragTarget, 'mouseup', centerX, centerY);
            }
            dragging = false;
            dragTarget = null;
            isDebouncingUnwink = false;
            winkDownSent = false;
        }
    }
    prevWinking = isWinking || isDebouncingUnwink;
    if (dragging && dragTarget) {
        dispatchTrackerMouseEvent(dragTarget, 'mousemove', centerX, centerY, {buttons: 1});
    }
    requestAnimationFrame(frameUpdate);
}
function drawHUD() {
    tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
    let stats = [
        `Neural Link: Active`,
        `Depth Z: ${currentFace.z.toFixed(3)}`,
        `X Offset: ${(currentFace.x - anchorFace.x).toFixed(3)}`,
        `Y Offset: ${(currentFace.y - anchorFace.y).toFixed(3)}`,
        `3D Cam X: ${currentThreeDCamera.x.toFixed(3)} Y: ${currentThreeDCamera.y.toFixed(3)} Z: ${currentThreeDCamera.z.toFixed(3)}`,
        `Raw Iris X: ${currentAvgYawRatio.toFixed(3)} Y: ${currentAvgPitchRatio.toFixed(3)}`,
        `Rel Iris X: ${currentDx.toFixed(3)} Y: ${currentDy.toFixed(3)}`,
        `Head Yaw: ${currentHeadYaw.toFixed(2)} Pitch: ${currentHeadPitch.toFixed(2)}`,
        `L EAR: ${currentLeftEAR.toFixed(3)} (Closed: ${leftClosed ? 'Yes' : 'No'})`,
        `R EAR: ${currentRightEAR.toFixed(3)} (Closed: ${rightClosed ? 'Yes' : 'No'})`,
        `Cursor X: ${targetX.toFixed(1)} Y: ${targetY.toFixed(1)}`,
        `FPS: ${fps}`,
        `Track Lat: ${latency.toFixed(0)}ms`,
        `Transfer Lat: ${transferLat.toFixed(0)}ms`,
        `Wink: ${isWinking ? 'Yes' : 'No'}`,
        `Hold State: ${dragging ? 'Yes' : 'No'}`
    ];
    if (hasHand) {
        stats.push(`Hand Detected: Yes`);
        stats.push(`Index Tip X: ${currentHandIndexX.toFixed(3)} Y: ${currentHandIndexY.toFixed(3)}`);
        stats.push(`Rel Hand X: ${currentHandDx.toFixed(3)} Y: ${currentHandDy.toFixed(3)}`);
        stats.push(`Pinch: ${isPinching ? 'Yes' : 'No'}`);
    }
    tCtx.fillStyle = 'rgba(18,18,18,0.8)';
    tCtx.fillRect(260, 10, 200, stats.length * 15 + 20);
    tCtx.strokeStyle = '#333';
    tCtx.strokeRect(260, 10, 200, stats.length * 15 + 20);
    tCtx.fillStyle = '#e0e0e0';
    tCtx.font = '10px Poppins';
    stats.forEach((s, i) => tCtx.fillText(s, 275, 35 + (i * 15)));
}
function drawMouseHUD() {
    tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
    const z = anchorFace.z - mouseWheelZ;
    const stats = [
        `Mouse Tracking: Active`,
        `Depth Z: ${z.toFixed(3)}`,
        `X Offset: ${(currentFace.x - anchorFace.x).toFixed(3)}`,
        `Y Offset: ${(currentFace.y - anchorFace.y).toFixed(3)}`,
        `3D Cam X: ${currentThreeDCamera.x.toFixed(3)} Y: ${currentThreeDCamera.y.toFixed(3)} Z: ${currentThreeDCamera.z.toFixed(3)}`,
        `Cursor X: ${targetX.toFixed(1)} Y: ${targetY.toFixed(1)}`,
        `FPS: ${fps}`
    ];
    tCtx.fillStyle = 'rgba(18,18,18,0.8)';
    tCtx.fillRect(260, 10, 200, stats.length * 15 + 20);
    tCtx.strokeStyle = '#333';
    tCtx.strokeRect(260, 10, 200, stats.length * 15 + 20);
    tCtx.fillStyle = '#e0e0e0';
    tCtx.font = '10px Poppins';
    stats.forEach((s, i) => tCtx.fillText(s, 275, 35 + (i * 15)));
}
function setupTrackerEvents() {
    document.getElementById('toggle-tracker-ui').onclick = toggleUI;
    document.getElementById('tracker-hide-ui').onclick = () => setTrackerUiVisible(false);
    const trackingToggle = el('tracking-toggle');
    if (trackingToggle) {
        trackingToggle.onchange = async (e) => {
            localStorage.setItem('tracking-toggle', String(e.target.checked));
            if (e.target.checked) {
                await updatePerformanceSettings();
                if (cursorFunctional()) setTrackerCursorVisible(true);
                scheduleRealCursorHide();
            } else {
                await stopLocalTrackingCamera();
                setTrackerCursorVisible(false);
                setRealCursorHidden(false);
                resetTrackerInteractionState();
                tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
            }
            sendTrackerState();
        };
    }
    const showCursorToggle = el('show-cursor');
    if (showCursorToggle) {
        showCursorToggle.onchange = (e) => {
            setShowCursorEnabled(e.target.checked);
        };
    }
    const mouseTrackingToggle = el('mouse-tracking');
    if (mouseTrackingToggle) {
        mouseTrackingToggle.onchange = (e) => {
            isMouseTracking = e.target.checked;
            localStorage.setItem('mouse-tracking', String(e.target.checked));
        };
    }
    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || typeof data !== 'object') return;
        if (data.type === 'deepx-tracker-command') {
            if (data.command === 'show-ui') setTrackerUiVisible(true);
            if (data.command === 'hide-ui') setTrackerUiVisible(false);
            if (data.command === 'toggle-ui') toggleUI();
            if (data.command === 'toggle-link') toggleTrackingEnabled();
            if (data.command === 'toggle-cursor') toggleCursorFunction();
            if (data.command === 'set-link-active') setTrackingEnabled(data.active === true);
            if (data.command === 'set-cursor-active') setShowCursorEnabled(data.active === true);
        }
        if (data.type === 'deepx-parent-real-mouse') {
            handleRealMouseActivity(data.x, data.y, data.deltaY || 0);
        }
        if (data.type === 'deepx-parent-hover-state') {
            parentHoverClickable = data.clickable === true;
            parentHoverDraggable = data.draggable === true;
        }
    });
    document.addEventListener('dblclick', (e) => {
        if (!uiVisible) toggleUI();
    });
    document.getElementById('btn-calibrate').onclick = async () => {
        const mode = cursorControlMode();
        const overlay = document.getElementById('timer-overlay');
        const label = document.getElementById('timer-label');
        const count = document.getElementById('timer-count');
        overlay.style.display = 'block';
        calibrationData = [];
        if (mode === 'head' || mode === 'hand') {
            label.innerText = mode === 'head' ? 'CENTER EYES' : 'CENTER INDEX FINGER';
            for(let i=3; i>0; i--) { count.innerText = i; await new Promise(r => setTimeout(r, 1000)); }
            label.innerText = 'SYNCING...';
            isCapturing = true;
            let samplesCursor = [];
            let samplesCam = [];
            let samplesHand = [];
            const interval = setInterval(() => {
                if (mode === 'head' || !hasHand) {
                    samplesCursor.push({
                        y: currentHeadYaw,
                        p: currentHeadPitch
                    });
                    samplesCam.push({
                        x: currentFace.x,
                        y: currentFace.y,
                        z: currentFace.z
                    });
                } else if (hasHand) {
                    samplesHand.push({
                        x: currentHandIndexX,
                        y: currentHandIndexY
                    });
                }
            }, 50);
            for(let i=5; i>0; i--) { count.innerText = i; await new Promise(r => setTimeout(r, 1000)); }
            clearInterval(interval);
            isCapturing = false;
            if (mode === 'hand') {
                if (samplesHand.length > 0) {
                    anchorHand.x = samplesHand.reduce((a, b) => a + b.x, 0) / samplesHand.length;
                    anchorHand.y = samplesHand.reduce((a, b) => a + b.y, 0) / samplesHand.length;
                } else {
                    alert('No hand detected during calibration.');
                }
            } else {
                if (samplesCursor.length > 0) {
                    anchorYaw = samplesCursor.reduce((a, b) => a + b.y, 0) / samplesCursor.length;
                    anchorPitch = samplesCursor.reduce((a, b) => a + b.p, 0) / samplesCursor.length;
                }
                if (samplesCam.length > 0) {
                    anchorFace.x = samplesCam.reduce((a, b) => a + b.x, 0) / samplesCam.length;
                    anchorFace.y = samplesCam.reduce((a, b) => a + b.y, 0) / samplesCam.length;
                    anchorFace.z = samplesCam.reduce((a, b) => a + b.z, 0) / samplesCam.length;
                }
            }
            targetX = window.innerWidth / 2;
            targetY = window.innerHeight / 2;
            smoothX = targetX;
            smoothY = targetY;
        } else {
            label.innerText = 'PREPARE TO CALIBRATE';
            for(let i=3; i>0; i--) { count.innerText = i; await new Promise(r => setTimeout(r, 1000)); }
            const w = window.innerWidth;
            const h = window.innerHeight;
            calDot.style.display = 'block';
            for (let i = 0; i < calibrationPoints.length; i++) {
                const p = calibrationPoints[i];
                calDot.style.left = (w * p.x) + 'px';
                calDot.style.top = (h * p.y) + 'px';
                label.innerText = 'LOOK AT DOT';
                for(let j=3; j>0; j--) { count.innerText = j; await new Promise(r => setTimeout(r, 1000)); }
                label.innerText = 'SAMPLING...';
                count.innerText = '';
                isCapturing = true;
                let samples = [];
                const startSample = performance.now();
                while (performance.now() - startSample < 2000) {
                    await new Promise(r => setTimeout(r, 50));
                    if (!eyesClosed) {
                        samples.push({dx: currentDx, dy: currentDy, yaw: currentHeadYawNorm, pitch: currentHeadPitchNorm});
                    }
                    if (calibrationData.length >= 8) {
                        const dx = currentDx;
                        const dy = currentDy;
                        const yaw = currentHeadYawNorm;
                        const pitch = currentHeadPitchNorm;
                        targetX = tempCoeffX[0] + tempCoeffX[1]*dx + tempCoeffX[2]*dy + tempCoeffX[3]*yaw + tempCoeffX[4]*pitch + tempCoeffX[5]*dx*dx + tempCoeffX[6]*dx*dy + tempCoeffX[7]*dy*dy;
                        targetY = tempCoeffY[0] + tempCoeffY[1]*dx + tempCoeffY[2]*dy + tempCoeffY[3]*yaw + tempCoeffY[4]*pitch + tempCoeffY[5]*dx*dx + tempCoeffY[6]*dx*dy + tempCoeffY[7]*dy*dy;
                        targetX = Math.max(0, Math.min(window.innerWidth, targetX));
                        targetY = Math.max(0, Math.min(window.innerHeight, targetY));
                    }
                }
                isCapturing = false;
                if (samples.length > 0) {
                    const avgDx = samples.reduce((sum, s) => sum + s.dx, 0) / samples.length;
                    const avgDy = samples.reduce((sum, s) => sum + s.dy, 0) / samples.length;
                    const avgYaw = samples.reduce((sum, s) => sum + s.yaw, 0) / samples.length;
                    const avgPitch = samples.reduce((sum, s) => sum + s.pitch, 0) / samples.length;
                    calibrationData.push({dx: avgDx, dy: avgDy, yaw: avgYaw, pitch: avgPitch, screenX: w * p.x, screenY: h * p.y});
                } else {
                    alert('No valid samples for this point. Retry calibration.');
                    overlay.style.display = 'none';
                    calDot.style.display = 'none';
                    return;
                }
                if (calibrationData.length >= 8) {
                    const A = calibrationData.map(d => [1, d.dx, d.dy, d.yaw, d.pitch, d.dx*d.dx, d.dx*d.dy, d.dy*d.dy]);
                    const At = transpose(A);
                    const AtA = matMul(At, A);
                    for (let k = 0; k < AtA.length; k++) {
                        AtA[k][k] += 0.001;
                    }
                    const Xt = calibrationData.map(d => [d.screenX]);
                    const Yt = calibrationData.map(d => [d.screenY]);
                    const AtX = matMul(At, Xt);
                    const AtY = matMul(At, Yt);
                    const augX = AtA.map((row, k) => [...row, AtX[k][0]]);
                    const augY = AtA.map((row, k) => [...row, AtY[k][0]]);
                    tempCoeffX = gaussianElimination(augX);
                    tempCoeffY = gaussianElimination(augY);
                }
            }
            calDot.style.display = 'none';
            const A = calibrationData.map(d => [1, d.dx, d.dy, d.yaw, d.pitch, d.dx*d.dx, d.dx*d.dy, d.dy*d.dy]);
            const At = transpose(A);
            const AtA = matMul(At, A);
            for (let k = 0; k < AtA.length; k++) {
                AtA[k][k] += 0.001;
            }
            const Xt = calibrationData.map(d => [d.screenX]);
            const Yt = calibrationData.map(d => [d.screenY]);
            const AtX = matMul(At, Xt);
            const AtY = matMul(At, Yt);
            const augX = AtA.map((row, k) => [...row, AtX[k][0]]);
            const augY = AtA.map((row, k) => [...row, AtY[k][0]]);
            coeffX = gaussianElimination(augX);
            coeffY = gaussianElimination(augY);
            isIrisCalibrated = true;
        }
        overlay.style.display = 'none';
    };
    document.getElementById('head-cursor-accel').oninput = (e) => {
        headCursorAcceleration = parseFloat(e.target.value);
        document.getElementById('head-cursor-accel-val').innerText = headCursorAcceleration.toFixed(3);
        localStorage.setItem('head-cursor-accel', e.target.value);
    };
    document.getElementById('hand-cursor-speed').oninput = (e) => {
        handCursorSpeed = parseFloat(e.target.value);
        document.getElementById('hand-cursor-speed-val').innerText = handCursorSpeed.toFixed(0);
        localStorage.setItem('hand-cursor-speed', e.target.value);
    };
    document.getElementById('hand-cursor-accel').oninput = (e) => {
        handCursorAcceleration = parseFloat(e.target.value);
        document.getElementById('hand-cursor-accel-val').innerText = handCursorAcceleration.toFixed(3);
        localStorage.setItem('hand-cursor-accel', e.target.value);
    };
    document.getElementById('three-d-camera-speed').oninput = (e) => {
        document.getElementById('three-d-camera-speed-val').innerText = parseFloat(e.target.value).toFixed(3);
        localStorage.setItem('three-d-camera-speed', e.target.value);
    };
    document.getElementById('three-d-camera-source').onchange = (e) => {
        localStorage.setItem('three-d-camera-source', e.target.value);
    };
    document.getElementById('s-sens').oninput = (e) => { document.getElementById('s-val').innerText = e.target.value + '%'; localStorage.setItem('s-sens', e.target.value); };
    document.getElementById('dz-ix').oninput = (e) => { document.getElementById('dz-ix-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-ix', e.target.value); };
    document.getElementById('dz-iy').oninput = (e) => { document.getElementById('dz-iy-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-iy', e.target.value); };
    document.getElementById('dz-head-yaw').oninput = (e) => { document.getElementById('dz-head-yaw-val').innerText = parseFloat(e.target.value).toFixed(1); localStorage.setItem('dz-head-yaw', e.target.value); };
    document.getElementById('dz-hp').oninput = (e) => { document.getElementById('dz-hp-val').innerText = parseFloat(e.target.value).toFixed(1); localStorage.setItem('dz-hp', e.target.value); };
    document.getElementById('dz-hx').oninput = (e) => { document.getElementById('dz-hx-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-hx', e.target.value); };
    document.getElementById('dz-hand-y').oninput = (e) => { document.getElementById('dz-hand-y-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-hand-y', e.target.value); };
    document.getElementById('record-wink').onclick = recordCurrentWinkStage;
    document.getElementById('reset-wink').onclick = () => {
        winkCalibration = null;
        winkRecordStage = 'idle';
        saveWinkCalibration();
    };
    document.getElementById('record-pinch').onclick = recordCurrentPinchStage;
    document.getElementById('reset-pinch').onclick = () => {
        pinchCalibration = null;
        pinchRecordStage = 'idle';
        savePinchCalibration();
    };
    ['head-cursor-accel', 'three-d-camera-speed', 'hand-cursor-speed', 'hand-cursor-accel'].forEach(id => {
        const range = document.getElementById(id);
        const num = document.getElementById(id + '-num');
        if (num) {
            num.oninput = (e) => {
                range.value = e.target.value;
                document.getElementById(id + '-val').innerText = parseFloat(e.target.value).toFixed(3);
                localStorage.setItem(id, e.target.value);
                window[id.replace(/-/g, '')] = parseFloat(e.target.value);
            };
        }
    });
    document.querySelectorAll('input[type=range]').forEach(setupSlider);
    const cameraSource = document.getElementById('three-d-camera-source');
    const savedCameraSource = localStorage.getItem('three-d-camera-source');
    if (cameraSource && savedCameraSource) {
        const hasOption = Array.from(cameraSource.options)
            .some(option => option.value === savedCameraSource);
        if (hasOption) cameraSource.value = savedCameraSource;
    }
    window.addEventListener('keydown', (e) => {
        if (isTypingTarget(e.target)) return;
        if (e.code === 'Space') {
            toggleTrackingEnabled();
            e.preventDefault();
        } else if (e.code === 'KeyC') {
            toggleCursorFunction();
            e.preventDefault();
        }
    });
    sendTrackerState();
}
function setupSlider(slider) {
    if (!slider) return;
    const id = slider.id;
    const num = document.getElementById(`${id}-num`);
    if (!num) return;
    const valDisplay = document.getElementById(`${id}-val`)
        || document.getElementById(`${id.replace(/-[^-]+$/, '')}-val`)
        || document.getElementById(`v-${id}`);
    const originalOnInput = slider.oninput || (() => {});
    const precision = id.endsWith('cursor-speed')
        ? 0
        : (id.includes('dz-head') || id.includes('dz-hp') ? 1 : 3);
    const displayText = (value) => id === 's-sens'
        ? `${Number(value).toFixed(0)}%`
        : Number(value).toFixed(precision);
    const syncUi = (value) => {
        const parsed = Number.parseFloat(value);
        if (!Number.isFinite(parsed)) return;
        num.value = parsed.toFixed(3);
        if (valDisplay) valDisplay.innerText = displayText(parsed);
    };
    slider.oninput = (e) => {
        originalOnInput(e);
        syncUi(slider.value);
        localStorage.setItem(id, slider.value);
    };
    num.oninput = (e) => {
        const parsed = Number.parseFloat(e.target.value);
        if (!Number.isFinite(parsed)) return;
        slider.value = parsed;
        originalOnInput({target: slider});
        syncUi(slider.value);
        localStorage.setItem(id, slider.value);
    };
    const minus = document.getElementById(`${id}-minus`);
    const plus = document.getElementById(`${id}-plus`);
    let holdTimer;
    let holdInterval;
    function startHold(dir) {
        clearTimeout(holdTimer);
        clearInterval(holdInterval);
        const range = parseFloat(slider.max) - parseFloat(slider.min);
        let incAmount = range > 100 ? 0.01 : 0.001;
        let stepVal = incAmount * dir;
        function inc() {
            let newVal = parseFloat(slider.value) + stepVal;
            newVal = Math.min(parseFloat(slider.max), Math.max(parseFloat(slider.min), newVal));
            slider.value = newVal;
            originalOnInput({target: slider});
            syncUi(slider.value);
            localStorage.setItem(id, slider.value);
        }
        inc();
        holdTimer = setTimeout(() => {
            holdInterval = setInterval(inc, 50);
        }, 400);
    }
    function stopHold() {
        clearTimeout(holdTimer);
        clearInterval(holdInterval);
    }
    if (minus) {
        minus.onmousedown = () => startHold(-1);
        minus.onmouseup = stopHold;
        minus.onmouseleave = stopHold;
    }
    if (plus) {
        plus.onmousedown = () => startHold(1);
        plus.onmouseup = stopHold;
        plus.onmouseleave = stopHold;
    }
}
const MESH_SILHOUETTE = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109];
const MESH_EYELASHES = [33, 160, 158, 133, 153, 144, 362, 385, 387, 263, 373, 380];
const MESH_IRIS = [468, 469, 470, 471, 472, 473, 474, 475, 476, 477];
const MESH_EYEBROWS = [70, 63, 105, 66, 107, 336, 296, 334, 293, 300];
const MESH_LIPS = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 375, 321, 405, 314, 17, 84, 181, 91, 146];
const MESH_NOSE = [168, 6, 197, 195, 5, 4, 1, 19, 94, 2, 98, 97, 326, 327];
const FILTERED_INDICES = [...MESH_SILHOUETTE, ...MESH_EYELASHES, ...MESH_IRIS, ...MESH_EYEBROWS, ...MESH_LIPS, ...MESH_NOSE];
const IRIS_INDICES = [33, 133, 159, 145, 158, 153, 362, 263, 386, 374, 385, 380, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477];
const YAW_PITCH_INDICES = [1, 10, 152, 234, 454];
init();
window.addEventListener('resize', () => {
    if(tCanvas.width !== window.innerWidth) { tCanvas.width = window.innerWidth; tCanvas.height = window.innerHeight; }
    if (isIrisCalibrated) {
        isIrisCalibrated = false;
        alert('Screen resized. Please recalibrate for iris mode.');
    }
});
document.addEventListener('visibilitychange', handlePageVisibility);
window.addEventListener('pagehide', () => {
    pageActive = false;
    stopLocalTrackingCamera();
});
window.addEventListener('pageshow', () => {
    if (!document.hidden) {
        pageActive = true;
        restartLocalTrackingCamera();
    }
});
window.addEventListener('beforeunload', () => {
    pageActive = false;
    stopLocalTrackingCamera();
});
window.addEventListener('mousemove', (e) => {
    if (e.isTrusted) {
        handleRealMouseActivity(e.clientX, e.clientY);
        return;
    }
    mouseX = e.clientX;
    mouseY = e.clientY;
});
window.addEventListener('mousedown', (e) => {
    if (e.isTrusted) handleRealMouseActivity(e.clientX, e.clientY);
});
window.addEventListener('mouseup', (e) => {
    if (e.isTrusted) handleRealMouseActivity(e.clientX, e.clientY);
});
window.addEventListener('wheel', (e) => {
    if (e.isTrusted) {
        handleRealMouseActivity(mouseX, mouseY, e.deltaY);
    } else if (isMouseTracking) {
        mouseWheelZ += e.deltaY * wheelSens;
    }
});
