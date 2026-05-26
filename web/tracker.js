// web/tracker.js
// --- GLOBAL VARIABLES ---
let eyesClosed = false;
let closedCount = 0;
let anchorFace = { x: 0, y: 0, z: 0 };
let currentFace = { x: 0, y: 0, z: 0 };
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
let lastHoverHitTestTime = 0;
let cachedHoveredElement = null;
const tCanvas = document.getElementById('ui-text-canvas');
const tCtx = tCanvas.getContext('2d');
const cursor = document.getElementById('white-cursor');
const cursorSize = 16;
const halfSize = cursorSize / 2;
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
let headSlowX = 0.1;
let headFastX = 1.0;
let headTransX = 5.0;
let headSlowY = 0.1;
let headFastY = 1.0;
let headTransY = 5.0;
let handSlowX = 1.0;
let handFastX = 10.0;
let handTransX = 0.001;
let handSlowY = 1.0;
let handFastY = 10.0;
let handTransY = 0.001;
let uiVisible = false;
let realMouseResumeTimer = null;
let pageActive = true;
let lastParentHoverX = Number.NaN;
let lastParentHoverY = Number.NaN;
const MEDIAPIPE_FACE_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4';
const MEDIAPIPE_HANDS_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/hands@0.4';
const PEER_JS_URL = 'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js';
const scriptLoadPromises = new Map();
let handsResultsAttached = false;
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
let doubleClickThreshold = 600; // Changed to 600ms
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
    const now = performance.now();
    if (!uiVisible || now - lastOverlayDrawTime < 100) return false;
    lastOverlayDrawTime = now;
    return true;
}
function resetHandsTracker(reason) {
    if (reason) console.warn('Resetting MediaPipe Hands after failure:', reason);
    handsHealthy = false;
    handsRetryAt = performance.now() + 2000;
    const tracker = hands;
    hands = null;
    handsReadyPromise = null;
    handsResultsAttached = false;
    clearHandState();
    if (tracker && typeof tracker.close === 'function') {
        try {
            tracker.close();
        } catch (_) {}
    }
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
    if (hands && handsHealthy) return hands;
    if (handsReadyPromise) return handsReadyPromise;
    if (performance.now() < handsRetryAt) return null;
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
        resetHandsTracker(error);
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
                            hasHand = false;
                            activeTracker = 'face';
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
                                if (data.partial.yawPitch) {
                                    currentHeadYaw = data.partial.yawPitch.yaw;
                                    currentHeadPitch = data.partial.yawPitch.pitch;
                                    currentHeadYawNorm = currentHeadYaw / 60;
                                    currentHeadPitchNorm = currentHeadPitch / 40;
                                }
                                if (data.partial.ear) {
                                    currentLeftEAR = data.partial.ear.left;
                                    currentRightEAR = data.partial.ear.right;
                                    const leftClosedThresh = numericSetting('left-closed-thresh', 0.16);
                                    const leftOpenThresh = numericSetting('left-open-thresh', 0.22);
                                    const rightClosedThresh = numericSetting('right-closed-thresh', 0.16);
                                    const rightOpenThresh = numericSetting('right-open-thresh', 0.22);
                                    leftClosed = currentLeftEAR < leftClosedThresh;
                                    rightClosed = currentRightEAR < rightClosedThresh;
                                    const leftWink = leftClosed && (currentRightEAR > rightOpenThresh);
                                    const rightWink = rightClosed && (currentLeftEAR > leftOpenThresh);
                                    isWinking = leftWink || rightWink;
                                    const avgEAR = (currentLeftEAR + currentRightEAR) / 2;
                                    if (avgEAR < 0.18) {
                                        closedCount++;
                                    } else {
                                        closedCount = 0;
                                    }
                                    eyesClosed = closedCount > 5;
                                }
                                if (data.partial.z) {
                                    currentFace.z = data.partial.z;
                                }
                            }
                            if (data.drawLm) {
                                let drawLmObj = {};
                                for (let pt of data.drawLm) {
                                    drawLmObj[pt.i] = {x: pt.x, y: pt.y, z: pt.z};
                                }
                                if (shouldDrawTrackerOverlay()) drawFaceDots(drawLmObj);
                                if (!data.partial && data.drawLm.length >= FILTERED_INDICES.length) {
                                    let lmArray = [];
                                    for (let pt of data.drawLm) {
                                        lmArray[pt.i] = {x: pt.x, y: pt.y, z: pt.z};
                                    }
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
                                    const pinchThresh = numericSetting('pinch-thresh', 0.05);
                                    const pinchDist = Math.hypot(thumb.x - index.x, thumb.y - index.y, thumb.z - index.z);
                                    isPinching = pinchDist < pinchThresh;
                                }
                            }
                            if (data.drawLm) {
                                let lmArray = [];
                                for (let pt of data.drawLm) {
                                    lmArray[pt.i] = {x: pt.x, y: pt.y, z: pt.z};
                                }
                                if (shouldDrawTrackerOverlay()) drawHandDots(lmArray);
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
            if (mode !== 'hand') {
                activeTracker = 'face';
                hasHand = false;
            }
            localStorage.setItem('cursor-mode', mode);
            // Adjust sensitivity when switching mode
            const hSensInput = document.getElementById('h-sens');
            const vSensInput = document.getElementById('v-sens');
            if (mode === 'hand') {
                hSensInput.value = 500;
                vSensInput.value = 500;
                document.getElementById('h-val').innerText = '500';
                document.getElementById('v-val').innerText = '500';
                handTransX = 10;
                handTransY = 10;
                document.getElementById('hand-trans-x').value = 10;
                document.getElementById('hand-trans-y').value = 10;
                document.getElementById('hand-trans-x-val').innerText = '10.000';
                document.getElementById('hand-trans-y-val').innerText = '10.000';
            } else {
                hSensInput.value = 100;
                vSensInput.value = 100;
                document.getElementById('h-val').innerText = '100';
                document.getElementById('v-val').innerText = '100';
            }
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
function drawFaceDots(drawLm) {
    const overlay = document.getElementById('face-dots-overlay');
    const oCtx = overlay.getContext('2d');
    const vidSize = overlay.width;
    const scaleFactor = vidSize / 240;
    const dotSize = 0.5 * scaleFactor;
    oCtx.clearRect(0, 0, overlay.width, overlay.height);
    oCtx.fillStyle = isRemote ? '#FFF' : '#000';
    for (let idx in drawLm) {
        const p = drawLm[idx];
        if (p) {
            oCtx.beginPath();
            oCtx.arc(p.x * overlay.width, p.y * overlay.height, dotSize, 0, Math.PI * 2);
            oCtx.fill();
        }
    }
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
    const refineLandmarks = currentMode === 'iris';
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
    if (currentMode === 'hand') {
        const handTracker = await ensureHandsReady();
        if (generation !== inferenceGeneration) return;
        const handSignature = '0|1|0.3|0.3';
        if (handTracker && configuredHandSignature !== handSignature) {
            handTracker.setOptions({
                modelComplexity: 0,
                maxNumHands: 1,
                minDetectionConfidence: 0.3,
                minTrackingConfidence: 0.3
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
    if (!isPaused && !inferenceInFlight && now - lastInferenceTime >= profile.intervalMs) {
        const generation = inferenceGeneration;
        const video = el('webcam-small');
        if (video && video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
            lastInferenceTime = now;
            inferenceInFlight = true;
            startTime = performance.now();
            const mode = currentMode;
            const run = mode === 'hand'
                ? sendHandFrame(video, generation)
                : sendFaceFrame(video, generation);
            run.catch(error => {
                if (mode === 'hand') {
                    resetHandsTracker(error);
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
async function sendHandFrame(video, generation) {
    const handTracker = await ensureHandsReady();
    if (!handTracker || generation !== inferenceGeneration) return;
    await handTracker.send({ image: video });
}
function setupDraggablePanel() {
    const panel = document.getElementById('tracker-panel');
    const title = document.querySelector('#tracker-panel .section-title');
    let isDragging = false;
    let startX, startY;
    panel.style.left = '10px';
    panel.style.top = '260px';
    title.addEventListener('mousedown', (e) => {
        isDragging = true;
        startX = e.clientX - panel.offsetLeft;
        startY = e.clientY - panel.offsetTop;
        e.preventDefault();
    });
    document.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        let newLeft = e.clientX - startX;
        let newTop = e.clientY - startY;
        newLeft = Math.max(0, Math.min(window.innerWidth - panel.offsetWidth, newLeft));
        newTop = Math.max(0, Math.min(window.innerHeight - panel.offsetHeight, newTop));
        panel.style.left = `${newLeft}px`;
        panel.style.top = `${newTop}px`;
    });
    document.addEventListener('mouseup', () => {
        isDragging = false;
    });
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
            uiVisible
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
    isPaused = false;
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
    if (document.getElementById('tracking-toggle').checked && document.getElementById('show-cursor').checked) {
        cursor.style.display = 'block';
    }
    if (!uiVisible) postParentHoverMove(mouseX, mouseY, {buttons: 0}, true);
}
function handleRealMouseActivity(x, y, deltaY = 0) {
    if (typeof x === 'number') mouseX = x;
    if (typeof y === 'number') mouseY = y;
    if (deltaY && isMouseTracking) mouseWheelZ += deltaY * wheelSens;
    isPaused = true;
    cursor.style.display = 'none';
    if (realMouseResumeTimer) clearTimeout(realMouseResumeTimer);
    realMouseResumeTimer = setTimeout(resumeTrackerAfterRealMouse, 80);
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
        cursor.style.display = 'none';
        stopLocalTrackingCamera();
        return;
    }
    restartLocalTrackingCamera();
    if (document.getElementById('tracking-toggle').checked && document.getElementById('show-cursor').checked) {
        cursor.style.display = 'block';
    }
}
function processFace(lm) {
    let rawHeadYaw = ((lm[1].x - lm[234].x) / (lm[454].x - lm[234].x) - 0.5) * -120;
    let rawHeadPitch = ((lm[1].y - lm[10].y) / (lm[152].y - lm[10].y) - 0.5) * 80;
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
    currentFace.x = (lm[1].x - 0.5) * 2;
    currentFace.y = (lm[1].y - 0.5) * 2;
    currentFace.z = Math.sqrt(Math.pow(lm[33].x - lm[263].x, 2) + Math.pow(lm[33].y - lm[263].y, 2));
    currentLeftEAR = getEAR(lm, true);
    currentRightEAR = getEAR(lm, false);
    const leftClosedThresh = numericSetting('left-closed-thresh', 0.16);
    const leftOpenThresh = numericSetting('left-open-thresh', 0.22);
    const rightClosedThresh = numericSetting('right-closed-thresh', 0.16);
    const rightOpenThresh = numericSetting('right-open-thresh', 0.22);
    leftClosed = currentLeftEAR < leftClosedThresh;
    rightClosed = currentRightEAR < rightClosedThresh;
    const leftWink = leftClosed && (currentRightEAR > rightOpenThresh);
    const rightWink = rightClosed && (currentLeftEAR > leftOpenThresh);
    isWinking = leftWink || rightWink;
    const avgEAR = (currentLeftEAR + currentRightEAR) / 2;
    if (avgEAR < 0.18) {
        closedCount++;
    } else {
        closedCount = 0;
    }
    eyesClosed = closedCount > 5;
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
    const pinchThresh = numericSetting('pinch-thresh', 0.05);
    const pinchDist = Math.hypot(lm[4].x - lm[8].x, lm[4].y - lm[8].y, lm[4].z - lm[8].z);
    isPinching = pinchDist < pinchThresh;
}
function setupOnResults() {
    const oCtx = document.getElementById('face-dots-overlay').getContext('2d');
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
                    if (sendYawPitch) {
                        partial.yawPitch = {yaw: currentHeadYaw, pitch: currentHeadPitch};
                        YAW_PITCH_INDICES.forEach(i => drawLmList.push({i, x: lm[i].x, y: lm[i].y, z: lm[i].z}));
                    }
                    if (sendFullFace) {
                        FILTERED_INDICES.forEach(i => drawLmList.push({i, x: lm[i].x, y: lm[i].y, z: lm[i].z}));
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
            if (currentMode === 'hand' || activeTracker !== 'face') return;
            if (!document.getElementById('tracking-toggle').checked) { cursor.style.display = 'none'; return; }
            cursor.style.display = (!isPaused && document.getElementById('show-cursor').checked) ? 'block' : 'none';
            const drawOverlay = shouldDrawTrackerOverlay();
            if (results.multiFaceLandmarks && results.multiFaceLandmarks[0]) {
                faceLm = results.multiFaceLandmarks[0];
                processFace(faceLm);
                if (drawOverlay) drawFaceDots(faceLm);
            } else {
                faceLm = null;
                if (drawOverlay) {
                    const overlay = el('face-dots-overlay');
                    oCtx.clearRect(0, 0, overlay.width, overlay.height);
                }
            }
        }
    });
}
function setupHandsResults(tracker = hands) {
    if (!tracker || handsResultsAttached) return;
    handsResultsAttached = true;
    const oCtx = document.getElementById('face-dots-overlay').getContext('2d');
    tracker.onResults((results) => {
        if (tracker !== hands) return;
        latency = performance.now() - startTime;
        if (isClient) {
            hasHand = results.multiHandLandmarks && results.multiHandLandmarks.length > 0;
            if (currentMode === 'hand' && hasHand && !sendNone) {
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
            if (tracker !== hands || currentMode !== 'hand' || !trackingEnabled()) {
                clearHandState();
                return;
            }
            const drawOverlay = shouldDrawTrackerOverlay();
            if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
                hasHand = true;
                handLm = results.multiHandLandmarks[0];
                if (activeTracker !== 'hand') {
                    activeTracker = 'hand';
                }
                processHand(handLm);
                if (drawOverlay) drawHandDots(handLm);
                lastHandDataTime = performance.now();
            } else {
                clearHandState();
                if (drawOverlay) {
                    const overlay = el('face-dots-overlay');
                    oCtx.clearRect(0, 0, overlay.width, overlay.height);
                }
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
    frameCount++;
    const now = performance.now();
    dt = now - prevTime;
    prevTime = now;
    if (now - lastFpsTime >= 1000) {
        fps = (frameCount / ((now - lastFpsTime) / 1000)).toFixed(1);
        frameCount = 0;
        lastFpsTime = now;
        if (isClient) {
            document.getElementById('fps-span').innerText = fps;
            document.getElementById('lat-span').innerText = latency.toFixed(0);
        }
    }
    if (currentMode === 'hand' && (now - lastHandDataTime > 1000)) {
        clearHandState();
    }
    if (isPaused) {
        requestAnimationFrame(frameUpdate);
        return;
    }
    if (document.getElementById('tracking-toggle').checked && !isPaused) {
        const mode = document.getElementById('cursor-mode').value;
        const isHead = mode === 'head';
        let rawRelYaw, rawRelPitch;
        if (mode === 'hand') {
            if (hasHand) {
                const deltaX = currentHandIndexX - prevHandIndexX;
                const deltaY = currentHandIndexY - prevHandIndexY;
                const velX = deltaX / (dt / 1000);
                const velY = deltaY / (dt / 1000);
                const speedX = Math.abs(velX);
                const speedY = Math.abs(velY);
                const baseSensH = numericSetting('h-sens', 100);
                const baseSensV = numericSetting('v-sens', 100);
                const baseThresholdX = 0.05;
                const baseThresholdY = 0.05;
                const thresholdX = baseThresholdX / handTransX;
                const thresholdY = baseThresholdY / handTransY;
                let accelX = handSlowX;
                if (speedX > thresholdX) {
                    const normalizedX = (speedX - thresholdX) / (0.8 - thresholdX);
                    accelX = handSlowX + (handFastX - handSlowX) * Math.pow(normalizedX, 1.5);
                }
                let accelY = handSlowY;
                if (speedY > thresholdY) {
                    const normalizedY = (speedY - thresholdY) / (0.8 - thresholdY);
                    accelY = handSlowY + (handFastY - handSlowY) * Math.pow(normalizedY, 1.5);
                }
                let cursorDeltaX = deltaX * baseSensH * accelX * -1;
                let cursorDeltaY = deltaY * baseSensV * accelY;
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
            const velYaw = deltaYaw / (dt / 1000);
            const velPitch = deltaPitch / (dt / 1000);
            const speedX = Math.abs(velYaw);
            const speedY = Math.abs(velPitch);
            const baseSensH = numericSetting('h-sens', 100);
            const baseSensV = numericSetting('v-sens', 100);
            const baseThresholdX = 5;
            const baseThresholdY = 3;
            const thresholdX = baseThresholdX / headTransX;
            const thresholdY = baseThresholdY / headTransY;
            let accelX = headSlowX;
            if (speedX > thresholdX) {
                const normalizedX = (speedX - thresholdX) / (90 - thresholdX);
                accelX = headSlowX + (headFastX - headSlowX) * Math.pow(normalizedX, 1.5);
            }
            let accelY = headSlowY;
            if (speedY > thresholdY) {
                const normalizedY = (speedY - thresholdY) / (30 - thresholdY);
                accelY = headSlowY + (headFastY - headSlowY) * Math.pow(normalizedY, 1.5);
            }
            let cursorDeltaX = deltaYaw * baseSensH * accelX * 2.5;
            let cursorDeltaY = deltaPitch * baseSensV * accelY * 2.5;
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
                targetX = (window.innerWidth / 2) + (rawRelYaw * scale * (numericSetting('h-sens', 100) / 10));
                targetY = (window.innerHeight / 2) + (rawRelPitch * scale * (numericSetting('v-sens', 100) / 10));
            }
            prevHeadYaw = currentHeadYaw;
            prevHeadPitch = currentHeadPitch;
        }
        const sFactor = numericSetting('s-sens', 100) / 100;
        smoothX = (smoothX * sFactor) + (targetX * (1 - sFactor));
        smoothY = (smoothY * sFactor) + (targetY * (1 - sFactor));
        const centerX = smoothX;
        const centerY = smoothY;
        const finalX = Math.max(0, Math.min(window.innerWidth - cursorSize, centerX - halfSize));
        const finalY = Math.max(0, Math.min(window.innerHeight - cursorSize, centerY - halfSize));
        cursor.style.transform = `translate3d(${finalX}px, ${finalY}px, 0)`;
    }
    if (isMouseTracking && !isPaused) {
        currentFace.x = (mouseX / window.innerWidth - 0.5) * 2;
        currentFace.y = (mouseY / window.innerHeight - 0.5) * 2;
        currentFace.z = anchorFace.z - mouseWheelZ;
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
                if (isDraggableElement(hoveredElement)) {
                    potentialDragTarget = hoveredElement;
                    hoverRedStart = now;
                    isHoverRed = true;
                    isHoverBlue = false;
                    potentialClickTarget = null;
                } else if (!isHoverRed && isClickableElement(hoveredElement)) {
                    potentialClickTarget = hoveredElement;
                    hoverBlueStart = now;
                    isHoverBlue = true;
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
    let cursorColor = 'white';
    if (dragging) {
        cursorColor = 'yellow';
    } else if (isHoverRed) {
        cursorColor = 'red';
    } else if (isHoverBlue) {
        cursorColor = 'blue';
    } else if (isWinking) {
        cursorColor = 'green';
    }
    cursor.style.backgroundColor = cursorColor;
    const mode = document.getElementById('cursor-mode').value;
    if (mode === 'hand' && hasHand) {
        if (isPinching) {
            if (now - lastPinchTime < doubleClickThreshold) {
                if (!uiVisible) toggleUI();
            }
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
    if (isWinking && !prevWinking) {
        if (now - lastWinkTime < doubleClickThreshold) {
            if (!uiVisible) toggleUI();
        }
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
                if (showCursorEnabled() && !isPaused) cursor.style.display = 'block';
            } else {
                await stopLocalTrackingCamera();
                cursor.style.display = 'none';
                tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
            }
        };
    }
    const showCursorToggle = el('show-cursor');
    if (showCursorToggle) {
        showCursorToggle.onchange = (e) => {
            localStorage.setItem('show-cursor', String(e.target.checked));
            cursor.style.display = e.target.checked && trackingEnabled() && !isPaused
                ? 'block'
                : 'none';
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
        }
        if (data.type === 'deepx-parent-real-mouse') {
            handleRealMouseActivity(data.x, data.y, data.deltaY || 0);
        }
    });
    document.addEventListener('dblclick', (e) => {
        if (!uiVisible) toggleUI();
    });
    document.getElementById('btn-calibrate').onclick = async () => {
        const mode = document.getElementById('cursor-mode').value;
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
    document.getElementById('h-sens').oninput = (e) => { document.getElementById('h-val').innerText = e.target.value; localStorage.setItem('h-sens', e.target.value); };
    document.getElementById('v-sens').oninput = (e) => { document.getElementById('v-val').innerText = e.target.value; localStorage.setItem('v-sens', e.target.value); };
    document.getElementById('s-sens').oninput = (e) => { document.getElementById('s-val').innerText = e.target.value + '%'; localStorage.setItem('s-sens', e.target.value); };
    document.getElementById('dz-ix').oninput = (e) => { document.getElementById('dz-ix-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-ix', e.target.value); };
    document.getElementById('dz-iy').oninput = (e) => { document.getElementById('dz-iy-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-iy', e.target.value); };
    document.getElementById('dz-head-yaw').oninput = (e) => { document.getElementById('dz-head-yaw-val').innerText = parseFloat(e.target.value).toFixed(1); localStorage.setItem('dz-head-yaw', e.target.value); };
    document.getElementById('dz-hp').oninput = (e) => { document.getElementById('dz-hp-val').innerText = parseFloat(e.target.value).toFixed(1); localStorage.setItem('dz-hp', e.target.value); };
    document.getElementById('dz-hx').oninput = (e) => { document.getElementById('dz-hx-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-hx', e.target.value); };
    document.getElementById('dz-hand-y').oninput = (e) => { document.getElementById('dz-hand-y-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('dz-hand-y', e.target.value); };
    document.getElementById('left-closed-thresh').oninput = (e) => { document.getElementById('lct-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('left-closed-thresh', e.target.value); };
    document.getElementById('left-open-thresh').oninput = (e) => { document.getElementById('lot-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('left-open-thresh', e.target.value); };
    document.getElementById('right-closed-thresh').oninput = (e) => { document.getElementById('rct-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('right-closed-thresh', e.target.value); };
    document.getElementById('right-open-thresh').oninput = (e) => { document.getElementById('rot-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('right-open-thresh', e.target.value); };
    document.getElementById('pinch-thresh').oninput = (e) => { document.getElementById('pt-val').innerText = parseFloat(e.target.value).toFixed(3); localStorage.setItem('pinch-thresh', e.target.value); };
    // Head acceleration sliders
    document.getElementById('head-slow-x').oninput = (e) => {
        headSlowX = parseFloat(e.target.value);
        document.getElementById('head-slow-x-val').innerText = headSlowX.toFixed(3);
        localStorage.setItem('head-slow-x', e.target.value);
    };
    document.getElementById('head-fast-x').oninput = (e) => {
        headFastX = parseFloat(e.target.value);
        document.getElementById('head-fast-x-val').innerText = headFastX.toFixed(3);
        localStorage.setItem('head-fast-x', e.target.value);
    };
    document.getElementById('head-trans-x').oninput = (e) => {
        headTransX = parseFloat(e.target.value);
        document.getElementById('head-trans-x-val').innerText = headTransX.toFixed(3);
        localStorage.setItem('head-trans-x', e.target.value);
    };
    document.getElementById('head-slow-y').oninput = (e) => {
        headSlowY = parseFloat(e.target.value);
        document.getElementById('head-slow-y-val').innerText = headSlowY.toFixed(3);
        localStorage.setItem('head-slow-y', e.target.value);
    };
    document.getElementById('head-fast-y').oninput = (e) => {
        headFastY = parseFloat(e.target.value);
        document.getElementById('head-fast-y-val').innerText = headFastY.toFixed(3);
        localStorage.setItem('head-fast-y', e.target.value);
    };
    document.getElementById('head-trans-y').oninput = (e) => {
        headTransY = parseFloat(e.target.value);
        document.getElementById('head-trans-y-val').innerText = headTransY.toFixed(3);
        localStorage.setItem('head-trans-y', e.target.value);
    };
    // Hand acceleration sliders
    document.getElementById('hand-slow-x').oninput = (e) => {
        handSlowX = parseFloat(e.target.value);
        document.getElementById('hand-slow-x-val').innerText = handSlowX.toFixed(3);
        localStorage.setItem('hand-slow-x', e.target.value);
    };
    document.getElementById('hand-fast-x').oninput = (e) => {
        handFastX = parseFloat(e.target.value);
        document.getElementById('hand-fast-x-val').innerText = handFastX.toFixed(3);
        localStorage.setItem('hand-fast-x', e.target.value);
    };
    document.getElementById('hand-trans-x').oninput = (e) => {
        handTransX = parseFloat(e.target.value);
        document.getElementById('hand-trans-x-val').innerText = handTransX.toFixed(3);
        localStorage.setItem('hand-trans-x', e.target.value);
    };
    document.getElementById('hand-slow-y').oninput = (e) => {
        handSlowY = parseFloat(e.target.value);
        document.getElementById('hand-slow-y-val').innerText = handSlowY.toFixed(3);
        localStorage.setItem('hand-slow-y', e.target.value);
    };
    document.getElementById('hand-fast-y').oninput = (e) => {
        handFastY = parseFloat(e.target.value);
        document.getElementById('hand-fast-y-val').innerText = handFastY.toFixed(3);
        localStorage.setItem('hand-fast-y', e.target.value);
    };
    document.getElementById('hand-trans-y').oninput = (e) => {
        handTransY = parseFloat(e.target.value);
        document.getElementById('hand-trans-y-val').innerText = handTransY.toFixed(3);
        localStorage.setItem('hand-trans-y', e.target.value);
    };
    // Number inputs for acceleration sliders (sync with range)
    ['head-slow-x', 'head-fast-x', 'head-trans-x', 'head-slow-y', 'head-fast-y', 'head-trans-y',
     'hand-slow-x', 'hand-fast-x', 'hand-trans-x', 'hand-slow-y', 'hand-fast-y', 'hand-trans-y'].forEach(id => {
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
    window.addEventListener('keydown', (e) => {
        if (e.code === 'Space') {
            isPaused = !isPaused;
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
    const valDisplay = document.getElementById(`${id.replace(/-[^-]+$/, '')}-val`) || document.getElementById(`v-${id}`);
    const originalOnInput = slider.oninput || (() => {});
    slider.oninput = (e) => {
        originalOnInput(e);
        const val = parseFloat(slider.value);
        num.value = val.toFixed(3);
        if (valDisplay) valDisplay.innerText = val.toFixed(id.includes('dz-head') || id.includes('dz-hp') ? 1 : 3);
        localStorage.setItem(id, slider.value);
    };
    num.oninput = (e) => {
        slider.value = parseFloat(e.target.value);
        const displayVal = parseFloat(e.target.value);
        if (valDisplay) valDisplay.innerText = displayVal.toFixed(id.includes('dz-head') || id.includes('dz-hp') ? 1 : 3);
        originalOnInput({target: slider});
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
            const displayVal = newVal;
            num.value = displayVal.toFixed(3);
            if (valDisplay) valDisplay.innerText = displayVal.toFixed(id.includes('dz-head') || id.includes('dz-hp') ? 1 : 3);
            originalOnInput({target: slider});
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
