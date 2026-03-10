// lib/engine3d.dart
import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';

import 'models/preset_payload_v2.dart';
import 'services/app_repository.dart';
import 'services/tracking_service.dart';

class Engine3DPage extends StatefulWidget {
  const Engine3DPage({
    super.key,
    this.initialPresetPayload,
    this.cleanView = false,
    this.embedded = false,
    this.embeddedStudio = false,
    this.persistPresets = true,
    this.disableAudio = false,
    this.externalHeadPose,
    this.onPresetSaved,
    this.onLivePayloadChanged,
    this.useGlobalTracking = true,
    this.pointerPassthrough = false,
    this.reanchorToken = 0,
    this.studioSurface = false,
  });

  final Map<String, dynamic>? initialPresetPayload;
  final bool cleanView;
  final bool embedded;
  final bool embeddedStudio;
  final bool persistPresets;
  final bool disableAudio;
  final Map<String, double>? externalHeadPose;
  final void Function(String name, Map<String, dynamic> payload)? onPresetSaved;
  final ValueChanged<Map<String, dynamic>>? onLivePayloadChanged;
  final bool useGlobalTracking;
  final bool pointerPassthrough;
  final int reanchorToken;
  final bool studioSurface;

  @override
  State<Engine3DPage> createState() => _Engine3DPageState();
}

class _Engine3DPageState extends State<Engine3DPage> {
  late String viewID;
  late String trackerViewID;
  late String _engineFrameElementId;
  late String _trackerFrameElementId;
  late String _bridgeChannel;
  web.HTMLIFrameElement? _engineIframe;
  web.HTMLIFrameElement? _trackerIframe;
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController.broadcast();
  StreamSubscription? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _trackingDataSubscription;
  VoidCallback? _globalTrackingListener;
  bool showTracker = false;
  String? currentPresetName;
  final Map<String, Map<String, dynamic>> presets = {};
  final AppRepository _repository = AppRepository.instance;
  Map<String, dynamic> _modeState = <String, dynamic>{};
  Timer? _saveDebounce;
  bool _iframeReady = false;
  TextEditingController presetNameController = TextEditingController();
  double headX = 0, headY = 0, yaw = 0, pitch = 0, zValue = 0.2;
  double deadZoneX = 0.0,
      deadZoneY = 0.0,
      deadZoneZ = 0.0,
      deadZoneYaw = 0.0,
      deadZonePitch = 0.0;
  bool manualMode = false;
  @override
  void initState() {
    super.initState();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int nowUs = DateTime.now().microsecondsSinceEpoch;
    viewID = 'cyber-engine-$nowMs';
    trackerViewID = 'cyber-tracker-3d-$nowMs';
    _engineFrameElementId = 'engine-iframe-$nowMs';
    _trackerFrameElementId = 'engine-tracker-iframe-$nowMs';
    _bridgeChannel = 'engine-bridge-$nowUs';
    _bootstrap();
    String content = r'''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { margin: 0; background: __BODY_BG__; overflow: hidden; }
        #canvas-container { width: 100vw; height: 100vh; position: absolute; inset: 0; }
    </style>
</head>
<body>
    <div id="canvas-container"></div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
    <script type="importmap">
    {
        "imports": {
            "three": "https://unpkg.com/three@0.160.0/build/three.module.js",
            "three/addons/": "https://unpkg.com/three@0.160.0/examples/jsm/"
        }
    }
    </script>
    <script type="module">
        import * as THREE from 'three';
        import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
        import { RGBELoader } from 'three/addons/loaders/RGBELoader.js';
        import { EXRLoader } from 'three/addons/loaders/EXRLoader.js';
        import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
        import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
        import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
        import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
        import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
        const CLEAN_VIEW = __CLEAN_VIEW__;
        const HIDE_PANEL = __HIDE_PANEL__;
        const STUDIO_SURFACE = __STUDIO_SURFACE__;
        const AUDIO_ENABLED = __AUDIO_ENABLED__;
        const BRIDGE_CHANNEL = '__BRIDGE_CHANNEL__';
        // --- GLOBAL VARIABLES ---
        let scene, camera, renderer, bloomComposer, finalComposer, clock;
        let currentModels = [];
        let modelNames = [];
        let mixers = [];
        let selectedModelIndex = -1;
        let sun, ambientLight, bloomPass;
        let dynamicLights = [];
        let spatialAudios = [];
        let audioCtx = new AudioContext();
        let convolver;
        let bloomLayer = new THREE.Layers(); bloomLayer.set(1);
        let darkMaterial = new THREE.MeshBasicMaterial({ color: 'black' });
        let materialsBackup = {};
        let skyTex = null;
        let envTex = null;
        let fps = 0;
        let frameCount = 0;
        let lastFpsTime = performance.now();
        let isPlaying = false;
        let activeCount = 0;
        const tempVec = new THREE.Vector3();
        const forwardVec = new THREE.Vector3();
        const irZipUrl = 'https://housefast.github.io/test/audio/impulse_responses/air/windows_ir_pack/W1 Bright chamber.wav';
        const irFileName = 'W1 Bright chamber.wav';
        let persistedSettings = {};
        let headX = 0, headY = 0, yaw = 0, pitch = 0, zValue = 0.2;
        let anchorHeadX = 0, anchorHeadY = 0, anchorZ = 0.2, anchorYaw = 0, anchorPitch = 0;
        let deadZoneX = 0.0, deadZoneY = 0.0, deadZoneZ = 0.0, deadZoneYaw = 0.0, deadZonePitch = 0.0;
        let manualMode = false;
        let showTracker = false;
        let useGlobalTracking = false;
        let cameraMode = 'orbit';
        let presets = {};
        let currentPreset = null;
        let disposed = false;
        let mouseDragActive = false;
        let mouseLastX = 0;
        let mouseLastY = 0;
        let mouseYawOffset = 0;
        let mousePitchOffset = 0;
        let mouseZoomOffset = 0;
        let shadowQualityValue = '512';
        let snapshotRevision = 0;
        function emitToParent(payload) {
            window.parent.postMessage(JSON.stringify({ ...payload, channel: BRIDGE_CHANNEL }), '*');
        }
        function getStore(key) {
            return Object.prototype.hasOwnProperty.call(persistedSettings, key) ? persistedSettings[key] : null;
        }
        function setStore(key, value) {
            persistedSettings[key] = String(value);
            emitToParent({ type: 'engine_setting', key, value: String(value) });
        }
        function pushStateSnapshot() {
            snapshotRevision += 1;
            emitToParent({
                type: 'engine_snapshot',
                kind: 'full',
                revision: snapshotRevision,
                sceneDelta: getCurrentState(),
                settingsDelta: { ...persistedSettings },
            });
        }
        function applyGlobalTrackingConfig(enabled) {
            useGlobalTracking = !!enabled;
            const trackerInput = document.getElementById('show-tracker');
            if (!trackerInput) return;
            const trackerRow = trackerInput.parentElement;
            if (trackerRow) {
                trackerRow.style.display = useGlobalTracking ? 'none' : 'flex';
            }
            if (useGlobalTracking) {
                showTracker = false;
                trackerInput.checked = false;
                setStore('show-tracker', false);
            }
        }
        function disposeEngine() {
            if (disposed) return;
            disposed = true;
            try {
                if (renderer) {
                    renderer.setAnimationLoop(null);
                    renderer.dispose();
                }
            } catch (_) {}
            try {
                if (audioCtx && audioCtx.state !== 'closed') {
                    audioCtx.close();
                }
            } catch (_) {}
            emitToParent({ type: 'engine_disposed' });
        }
        function setupMouseCameraControls(canvas) {
            if (!canvas) return;
            const canControl = () => !!(STUDIO_SURFACE || HIDE_PANEL || CLEAN_VIEW);
            const stopDrag = (event) => {
                if (!mouseDragActive) return;
                mouseDragActive = false;
                try {
                    if (event && event.pointerId != null && canvas.releasePointerCapture) {
                        canvas.releasePointerCapture(event.pointerId);
                    }
                } catch (_) {}
            };
            canvas.addEventListener('contextmenu', (event) => event.preventDefault());
            canvas.addEventListener('pointerdown', (event) => {
                if (!canControl()) return;
                if (event.button !== 0 && event.button !== 1) return;
                mouseDragActive = true;
                mouseLastX = event.clientX;
                mouseLastY = event.clientY;
                try {
                    if (canvas.setPointerCapture) {
                        canvas.setPointerCapture(event.pointerId);
                    }
                } catch (_) {}
            });
            canvas.addEventListener('pointermove', (event) => {
                if (!mouseDragActive) return;
                const dx = event.clientX - mouseLastX;
                const dy = event.clientY - mouseLastY;
                mouseLastX = event.clientX;
                mouseLastY = event.clientY;
                mouseYawOffset += dx * 0.16;
                mousePitchOffset += dy * 0.12;
                mousePitchOffset = Math.max(-85, Math.min(85, mousePitchOffset));
            });
            canvas.addEventListener('pointerup', stopDrag);
            canvas.addEventListener('pointercancel', stopDrag);
            canvas.addEventListener('pointerleave', stopDrag);
            canvas.addEventListener(
                'wheel',
                (event) => {
                    if (!canControl()) return;
                    event.preventDefault();
                    mouseZoomOffset += event.deltaY * 0.0025;
                    mouseZoomOffset = Math.max(-0.75, Math.min(0.75, mouseZoomOffset));
                },
                { passive: false },
            );
        }
        // Target for orbit mode
        const orbitTarget = new THREE.Vector3(0, 0, 0);
        let initPos = new THREE.Vector3(0, 2, 10);
        let initRot = new THREE.Euler(0, 0, 0, 'YXZ');
        async function init() {
            clock = new THREE.Clock();
            scene = new THREE.Scene();
            camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.copy(initPos);
            camera.setRotationFromEuler(initRot);
            renderer = new THREE.WebGLRenderer({ antialias: true, alpha: CLEAN_VIEW });
            renderer.setPixelRatio(window.devicePixelRatio);
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.toneMapping = THREE.ACESFilmicToneMapping;
            renderer.toneMappingExposure = 1.2;
            renderer.shadowMap.enabled = true;
            renderer.shadowMap.type = THREE.PCFSoftShadowMap;
            if (CLEAN_VIEW) {
                renderer.setClearColor(0x000000, 0);
                document.body.style.background = 'transparent';
            } else {
                renderer.setClearColor(0x000000, 1);
            }
            renderer.setAnimationLoop(animate);
            document.getElementById('canvas-container').appendChild(renderer.domElement);
            setupMouseCameraControls(renderer.domElement);
            ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
            scene.add(ambientLight);
            sun = new THREE.DirectionalLight(0xffffff, 2);
            sun.position.set(10, 20, 10);
            sun.castShadow = true;
            sun.shadow.mapSize.width = 512;
            sun.shadow.mapSize.height = 512;
            sun.shadow.camera.near = 0.5;
            sun.shadow.camera.far = 500;
            sun.shadow.camera.left = -50;
            sun.shadow.camera.right = 50;
            sun.shadow.camera.top = 50;
            sun.shadow.camera.bottom = -50;
            scene.add(sun);
            // POST PROCESSING
            const renderPass = new RenderPass(scene, camera);
            bloomPass = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 1.0, 0.5, 0.1);
            bloomComposer = new EffectComposer(renderer);
            bloomComposer.renderToScreen = false;
            bloomComposer.addPass(renderPass);
            bloomComposer.addPass(bloomPass);
            const mixPass = new ShaderPass(new THREE.ShaderMaterial({
                uniforms: { baseTexture: { value: null }, bloomTexture: { value: bloomComposer.renderTarget2.texture } },
                vertexShader: `varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
                fragmentShader: `uniform sampler2D baseTexture; uniform sampler2D bloomTexture; varying vec2 vUv; void main() { gl_FragColor = (texture2D(baseTexture, vUv) + vec4(1.0) * texture2D(bloomTexture, vUv)); }`
            }), 'baseTexture');
            finalComposer = new EffectComposer(renderer);
            finalComposer.addPass(renderPass);
            finalComposer.addPass(mixPass);
            finalComposer.addPass(new OutputPass());
            // Audio setup
            if (AUDIO_ENABLED) {
                convolver = audioCtx.createConvolver();
                fetch(irZipUrl).then(res => res.arrayBuffer()).then(buffer => audioCtx.decodeAudioData(buffer)).then(decoded => {
                  convolver.buffer = decoded;
                }).catch(e => console.error('Failed to load IR', e));
            }
            loadSettings();
            window.addEventListener('message', (event) => {
                try {
                    let data = event.data;
                    if (typeof data === 'string') {
                        data = JSON.parse(data);
                    }
                    if (!data || typeof data !== 'object') return;
                    if (data.channel && data.channel !== BRIDGE_CHANNEL) return;
                    if (data.type === 'dispose_engine') {
                        disposeEngine();
                        return;
                    }
                    if (data.type === 'bootstrap_state') {
                        const incomingSettings = data.settings || {};
                        persistedSettings = { ...persistedSettings, ...incomingSettings };
                        presets = data.presets || presets || {};
                        loadSettings();
                        updatePresetSelect();
                        const incomingScene = data.scene || data.sceneState;
                        if (incomingScene) {
                            applyState(incomingScene);
                        } else {
                            pushStateSnapshot();
                        }
                        return;
                    }
                    if (data.type === 'apply_scene_patch') {
                        const patch = data.patch || data.scene || data.sceneState;
                        if (patch) {
                            applyState(patch);
                        } else {
                            pushStateSnapshot();
                        }
                        return;
                    }
                    if (data.type === 'apply_settings_patch') {
                        const patch = data.patch || data.settings || {};
                        persistedSettings = { ...persistedSettings, ...patch };
                        loadSettings();
                        pushStateSnapshot();
                        return;
                    }
                    if (data.type === 'global_tracking_config') {
                        applyGlobalTrackingConfig(data.useGlobal === true);
                        return;
                    }
                    if (data.type === 'snapshot_request') {
                        pushStateSnapshot();
                        return;
                    }
                    if (data.type === 'entity_add' || data.type === 'external_add_model' || data.type === 'external_add_audio') {
                        const entityType = (data.entityType || (data.type === 'external_add_audio' ? 'audio' : 'model')).toString().toLowerCase();
                        if (entityType === 'model') {
                            const modelUrl = data.url || (data.entity && data.entity.url) || '';
                            if (modelUrl) {
                                addModel(modelUrl, data.entity || null).then(() => pushStateSnapshot());
                            }
                            return;
                        }
                        if (entityType === 'audio') {
                            const audioUrl = data.url || (data.entity && data.entity.url) || '';
                            if (audioUrl) {
                                addSpatialAudio(audioUrl, data.entity || null);
                                pushStateSnapshot();
                            }
                            return;
                        }
                        if (entityType === 'light') {
                            addPointLight(data.entity || null);
                            pushStateSnapshot();
                        }
                        return;
                    }
                    if (data.type === 'entity_update' || data.type === 'entity_delete' || data.type === 'entity_reorder') {
                        if (data.scene) {
                            applyState(data.scene);
                            return;
                        }
                        const current = getCurrentState();
                        const listKeyForType = (type) => type === 'model' ? 'models' : (type === 'light' ? 'lights' : 'audios');
                        const token = (data.token || '').toString();
                        const entityType = (data.entityType || (token.includes(':') ? token.split(':')[0] : '')).toString().toLowerCase();
                        const entityId = (data.id || (token.includes(':') ? token.split(':')[1] : '')).toString();
                        if (!entityType || !entityId) {
                            pushStateSnapshot();
                            return;
                        }
                        const listKey = listKeyForType(entityType);
                        const list = Array.isArray(current[listKey]) ? current[listKey].slice() : [];
                        const idx = list.findIndex((item) => item && String(item.id || '') === entityId);
                        if (data.type === 'entity_update' && idx >= 0) {
                            list[idx] = { ...(list[idx] || {}), ...(data.patch || {}) };
                            current[listKey] = list;
                        } else if (data.type === 'entity_delete' && idx >= 0) {
                            list.splice(idx, 1);
                            current[listKey] = list;
                            const removeToken = `${entityType}:${entityId}`;
                            if (Array.isArray(current.renderOrder)) {
                                current.renderOrder = current.renderOrder.filter((t) => t !== removeToken);
                            }
                        } else if (data.type === 'entity_reorder' && Array.isArray(data.order)) {
                            current.renderOrder = data.order.map((item) => String(item));
                        }
                        applyState(current);
                        return;
                    }
                    if (data.type === 'external_set_sky') {
                        if (data.url) {
                            loadEnv(data.url, tex => { skyTex = tex; scene.background = tex; pushStateSnapshot(); });
                        }
                        return;
                    }
                    if (data.type === 'external_set_env') {
                        if (data.url) {
                            loadEnv(data.url, tex => { envTex = tex; scene.environment = tex; pushStateSnapshot(); });
                        }
                        return;
                    }
                    if (data.type === 'reanchor' || data.type === 'external_reanchor') {
                        anchorHeadX = headX;
                        anchorHeadY = headY;
                        anchorZ = zValue;
                        anchorYaw = yaw;
                        anchorPitch = pitch;
                        mouseYawOffset = 0;
                        mousePitchOffset = 0;
                        mouseZoomOffset = 0;
                        return;
                    }
                    if (data.type === 'tracking_patch' && data.head && typeof data.head === 'object') {
                        const nextX = Number(data.head.x);
                        const nextY = Number(data.head.y);
                        const nextZ = Number(data.head.z);
                        const nextYaw = Number(data.head.yaw);
                        const nextPitch = Number(data.head.pitch);
                        if (Number.isFinite(nextX)) headX = nextX;
                        if (Number.isFinite(nextY)) headY = nextY;
                        if (Number.isFinite(nextZ)) zValue = nextZ;
                        if (Number.isFinite(nextYaw)) yaw = nextYaw;
                        if (Number.isFinite(nextPitch)) pitch = nextPitch;
                        return;
                    }
                    if (data.head && typeof data.head === 'object') {
                        const nextX = Number(data.head.x);
                        const nextY = Number(data.head.y);
                        const nextZ = Number(data.head.z);
                        const nextYaw = Number(data.head.yaw);
                        const nextPitch = Number(data.head.pitch);
                        if (Number.isFinite(nextX)) headX = nextX;
                        if (Number.isFinite(nextY)) headY = nextY;
                        if (Number.isFinite(nextZ)) zValue = nextZ;
                        if (Number.isFinite(nextYaw)) yaw = nextYaw;
                        if (Number.isFinite(nextPitch)) pitch = nextPitch;
                    }
                } catch (_) {}
            });
            emitToParent({type: 'engine_ready'});
        }
        function loadSettings() {
            document.querySelectorAll('input[type=range], input[type=number], input[type=text], input[type=checkbox], select').forEach(el => {
                const val = getStore(el.id);
                if (val !== null) {
                    if (el.type === 'checkbox') {
                        el.checked = val === 'true';
                    } else {
                        el.value = val;
                    }
                    if (el.oninput) el.oninput({target: el});
                    if (el.onchange) el.onchange({target: el});
                }
            });
            deadZoneX = parseFloat(getStore('dz-x') || 0.0);
            deadZoneY = parseFloat(getStore('dz-y') || 0.0);
            deadZoneZ = parseFloat(getStore('dz-z') || 0.0);
            deadZoneYaw = parseFloat(getStore('dz-yaw') || 0.0);
            deadZonePitch = parseFloat(getStore('dz-pitch') || 0.0);
            manualMode = getStore('manual-mode') === 'true';
            showTracker = getStore('show-tracker') === 'true';
            if (useGlobalTracking) {
                showTracker = false;
                setStore('show-tracker', false);
            }
            cameraMode = getStore('camera-mode') || 'orbit';
            document.getElementById('manual-controls').style.display = manualMode ? 'block' : 'none';
        }
        function saveSettings() {
            document.querySelectorAll('input[type=range], input[type=number], input[type=checkbox], select').forEach(el => {
                setStore(el.id, el.type === 'checkbox' ? el.checked : el.value);
            });
            pushStateSnapshot();
        }
        function loadEnv(url, cb) {
            if (!url) return;
            const ext = url.split('.').pop().toLowerCase();
            const loader = ext === 'hdr' ? new RGBELoader() : (ext === 'exr' ? new EXRLoader() : null);
            if (!loader) return;
            loader.load(url, tex => {
                tex.mapping = THREE.EquirectangularReflectionMapping;
                cb(tex);
            });
        }
        function updateEnv() {
            scene.background = skyTex;
            scene.environment = envTex;
        }
        function updateShadows(size) {
            sun.shadow.mapSize.set(size, size);
            sun.shadow.map = null;
            dynamicLights.forEach(l => {
                l.light.shadow.mapSize.set(size / 2, size / 2);
                l.light.shadow.map = null;
            });
        }
        // --- MODEL LOADING & TRANSFORMS ---
        function addModel(url, initialState = null) {
            if(!url) return Promise.resolve(null);
            const modelName = url.split('/').pop().replace(/\.[^/.]+$/, "");
            const modelUrlInput = document.getElementById('model-url');
            if (modelUrlInput && 'value' in modelUrlInput) {
                modelUrlInput.value = '';
            }
            return new Promise((resolve, reject) => {
                new GLTFLoader().load(url, (gltf) => {
                    const model = gltf.scene;
                    model.traverse(n => { if(n.isMesh) { n.layers.enable(1); n.castShadow = true; n.receiveShadow = true; } });
                    model.userData.url = url;
                    model.userData.id =
                        (initialState && initialState.id) ||
                        `model_${Date.now()}_${currentModels.length}`;
                    model.userData.windowLayer =
                        (initialState && initialState.windowLayer) || 'inside';
                    if (currentModels.length > 0) {
                        currentModels[0].add(model);
                    } else {
                        scene.add(model);
                    }
                    currentModels.push(model);
                    modelNames.push(modelName);
                    modelAnchors.push({ pos: {x:0, y:0, z:0}, rot: {x:0, y:0, z:0}, sc: 1 });
                    if(gltf.animations.length) {
                        const mixer = new THREE.AnimationMixer(model);
                        gltf.animations.forEach(clip => mixer.clipAction(clip).play());
                        mixers.push(mixer);
                    } else {
                        mixers.push(null);
                    }
                    updateModelList();
                    selectedModelIndex = currentModels.length - 1;
                    loadModelTransformToSliders();
                    resolve(model);
                }, undefined, (error) => {
                    console.error('Failed to load model', error);
                    reject(error);
                });
            });
        }
        let modelAnchors = [];
        function getSelectedModel() {
            return currentModels[selectedModelIndex];
        }
        function getRoot() {
            return currentModels[0] || scene;
        }
        function updateModelTransform() {
            const model = getSelectedModel();
            if(!model) return;
            model.position.set(
                parseFloat(document.getElementById('mPosX').value) / 1000,
                parseFloat(document.getElementById('mPosY').value) / 1000,
                parseFloat(document.getElementById('mPosZ').value) / 1000
            );
            model.rotation.set(
                parseFloat(document.getElementById('mRotX').value) / 1000,
                parseFloat(document.getElementById('mRotY').value) / 1000,
                parseFloat(document.getElementById('mRotZ').value) / 1000
            );
            const s = parseFloat(document.getElementById('mScale').value) / 1000;
            model.scale.set(s, s, s);
            document.getElementById('v-scale').innerText = s.toFixed(1);
        }
        function loadModelTransformToSliders() {
            const model = getSelectedModel();
            if(!model) return;
            document.getElementById('mPosX').value = model.position.x * 1000;
            document.getElementById('mPosX-num').value = model.position.x;
            document.getElementById('mPosY').value = model.position.y * 1000;
            document.getElementById('mPosY-num').value = model.position.y;
            document.getElementById('mPosZ').value = model.position.z * 1000;
            document.getElementById('mPosZ-num').value = model.position.z;
            document.getElementById('mRotX').value = model.rotation.x * 1000;
            document.getElementById('mRotX-num').value = model.rotation.x;
            document.getElementById('mRotY').value = model.rotation.y * 1000;
            document.getElementById('mRotY-num').value = model.rotation.y;
            document.getElementById('mRotZ').value = model.rotation.z * 1000;
            document.getElementById('mRotZ-num').value = model.rotation.z;
            document.getElementById('mScale').value = model.scale.x * 1000;
            document.getElementById('mScale-num').value = model.scale.x;
            document.getElementById('v-scale').innerText = model.scale.x.toFixed(1);
        }
        function updateModelList() {
            const list = document.getElementById('model-list');
            list.innerHTML = '';
            modelNames.forEach((name, i) => {
                const div = document.createElement('div');
                const radio = document.createElement('input');
                radio.type = 'radio';
                radio.name = 'model-select';
                radio.value = i;
                radio.checked = i === selectedModelIndex;
                radio.onchange = (e) => {
                    selectedModelIndex = parseInt(e.target.value);
                    loadModelTransformToSliders();
                    updateHideButton();
                };
                const label = document.createElement('label');
                label.innerText = name;
                div.appendChild(radio);
                div.appendChild(label);
                list.appendChild(div);
            });
        }
        // --- DYNAMIC LIGHT SYSTEM ---
        function addPointLight(initialState = null) {
            const id = (initialState && initialState.id) || Date.now();
            const light = new THREE.PointLight(0xffffff, 10, 50);
            light.position.set(0, 5, 0);
            light.castShadow = true;
            light.shadow.mapSize.width = 512;
            light.shadow.mapSize.height = 512;
            light.shadow.camera.near = 0.1;
            light.shadow.camera.far = 100;
            const root = getRoot();
            root.add(light);
            const helper = new THREE.Mesh(new THREE.SphereGeometry(0.2), new THREE.MeshStandardMaterial({emissive: 0xffffff, emissiveIntensity: 1, toneMapped: false}));
            helper.layers.enable(1);
            root.add(helper);
            const lightData = {
                id,
                light,
                helper,
                modelIndex: currentModels.length > 0 ? 0 : -1,
                windowLayer: (initialState && initialState.windowLayer) || 'inside',
            };
            dynamicLights.push(lightData);
            const card = document.createElement('div');
            card.className = 'light-card';
            card.id = `light-ui-${id}`;
            card.innerHTML = `
                <div class="control-group">
                    <input type="color" id="lc-${id}" value="#ffffff">
                    <div class="slider-wrap">
                        <input type="range" id="li-${id}" min="0" max="100" step="0.001" value="10">
                        <input type="number" id="li-${id}-num" step="0.001" value="10">
                        <button class="btn-inc" id="li-${id}-minus">-</button>
                        <button class="btn-inc" id="li-${id}-plus">+</button>
                    </div>
                </div>
                <div class="control-group">
                    <div class="slider-wrap">
                        <input type="range" id="lx-${id}" min="-20000" max="20000" step="1" value="0">
                        <input type="number" id="lx-${id}-num" step="0.001" value="0">
                        <button class="btn-inc" id="lx-${id}-minus">-</button>
                        <button class="btn-inc" id="lx-${id}-plus">+</button>
                    </div>
                    <div class="slider-wrap">
                        <input type="range" id="ly-${id}" min="-20000" max="20000" step="1" value="5000">
                        <input type="number" id="ly-${id}-num" step="0.001" value="5">
                        <button class="btn-inc" id="ly-${id}-minus">-</button>
                        <button class="btn-inc" id="ly-${id}-plus">+</button>
                    </div>
                    <div class="slider-wrap">
                        <input type="range" id="lz-${id}" min="-20000" max="20000" step="1" value="0">
                        <input type="number" id="lz-${id}-num" step="0.001" value="0">
                        <button class="btn-inc" id="lz-${id}-minus">-</button>
                        <button class="btn-inc" id="lz-${id}-plus">+</button>
                    </div>
                </div>
                <label>Scale <span id="ls-${id}-val" class="val-display">1.0</span></label>
                <div class="slider-wrap">
                    <input type="range" id="ls-${id}" min="0.1" max="10" step="0.01" value="1">
                    <input type="number" id="ls-${id}-num" step="0.01" value="1">
                    <button class="btn-inc" id="ls-${id}-minus">-</button>
                    <button class="btn-inc" id="ls-${id}-plus">+</button>
                </div>
                <div style="display:flex; justify-content:space-between; margin-top:8px;">
                    <label>Ghost Mode</label>
                    <input type="checkbox" id="lg-${id}">
                </div>
                <button class="btn" style="background:linear-gradient(135deg, #ff1744, #b71c1c); color:white;" id="ld-${id}">Remove</button>
            `;
            document.getElementById('lights-container').appendChild(card);
            const up = () => {
                const color = new THREE.Color(document.getElementById(`lc-${id}`).value);
                light.color.copy(color);
                light.intensity = parseFloat(document.getElementById(`li-${id}`).value);
                light.position.set(
                    parseFloat(document.getElementById(`lx-${id}`).value) / 1000,
                    parseFloat(document.getElementById(`ly-${id}`).value) / 1000,
                    parseFloat(document.getElementById(`lz-${id}`).value) / 1000
                );
                const scale = parseFloat(document.getElementById(`ls-${id}`).value);
                helper.scale.set(scale, scale, scale);
                light.distance = 50 * scale;
                helper.position.copy(light.position);
                helper.material.emissive.copy(color);
                helper.material.emissiveIntensity = light.intensity / 10;
                helper.visible = !document.getElementById(`lg-${id}`).checked;
            };
            document.getElementById(`lc-${id}`).oninput = up;
            document.getElementById(`li-${id}`).oninput = up;
            document.getElementById(`lx-${id}`).oninput = up;
            document.getElementById(`ly-${id}`).oninput = up;
            document.getElementById(`lz-${id}`).oninput = up;
            document.getElementById(`ls-${id}`).oninput = up;
            document.getElementById(`lg-${id}`).oninput = up;
            setupSlider(document.getElementById(`li-${id}`));
            setupSlider(document.getElementById(`lx-${id}`));
            setupSlider(document.getElementById(`ly-${id}`));
            setupSlider(document.getElementById(`lz-${id}`));
            setupSlider(document.getElementById(`ls-${id}`));
            document.getElementById(`ld-${id}`).onclick = () => {
                const parent = lightData.modelIndex === 0 ? currentModels[0] : scene;
                if (parent) {
                    parent.remove(light); parent.remove(helper);
                }
                card.remove();
                dynamicLights = dynamicLights.filter(l => l.id !== id);
                pushStateSnapshot();
            };
        }
        // --- SPATIAL AUDIO SYSTEM ---
        function addSpatialAudio(explicitUrl, initialState = null) {
            if (!AUDIO_ENABLED) return;
            const url =
                explicitUrl ||
                (initialState && initialState.url) ||
                prompt('Enter audio URL:');
            if (!url) return;
            const id =
                (initialState && initialState.id) ||
                `audio_${Date.now()}_${spatialAudios.length}`;
            const audio = new Audio(url);
            audio.preload = 'auto';
            audio.load();
            audio.volume = 1;
            audio.muted = false;
            audio.loop = false;
            audio.crossOrigin = "anonymous";
            const source = audioCtx.createMediaElementSource(audio);
            const lowpass = audioCtx.createBiquadFilter();
            lowpass.type = 'lowpass';
            lowpass.frequency.value = 22050;
            const panner = audioCtx.createPanner();
            panner.panningModel = 'HRTF';
            panner.distanceModel = 'inverse';
            panner.refDistance = 1;
            panner.maxDistance = 10000;
            panner.rolloffFactor = 1;
            const dryGain = audioCtx.createGain();
            dryGain.gain.value = 1;
            const wetGain = audioCtx.createGain();
            wetGain.gain.value = 0;
            source.connect(lowpass);
            lowpass.connect(panner);
            panner.connect(dryGain);
            dryGain.connect(audioCtx.destination);
            panner.connect(convolver);
            convolver.connect(wetGain);
            wetGain.connect(audioCtx.destination);
            const root = getRoot();
            const helper = new THREE.Mesh(new THREE.SphereGeometry(0.3), new THREE.MeshStandardMaterial({color: 0x00ff00}));
            helper.layers.enable(1);
            root.add(helper);
            const audioName = url.split('/').pop().replace(/\.[^/.]+$/, "");
            const label = createTextSprite(audioName);
            helper.add(label);
            label.position.set(0, 0.5, 0);
            const audioData = {
                id,
                audio,
                source,
                lowpass,
                panner,
                dryGain,
                wetGain,
                helper,
                label,
                modelIndex: currentModels.length > 0 ? 0 : -1,
                volume: 1,
                windowLayer: (initialState && initialState.windowLayer) || 'inside',
            };
            spatialAudios.push(audioData);
            audio.addEventListener('ended', () => {
                activeCount--;
                if (activeCount === 0 && isPlaying) {
                    syncAudioTimes(0);
                    playAll();
                }
            });
            const card = document.createElement('div');
            card.className = 'light-card';
            card.id = `audio-ui-${id}`;
            card.innerHTML = `
                <label>Volume <span id="av-${id}-val" class="val-display">1.0</span></label>
                <div class="slider-wrap">
                    <input type="range" id="av-${id}" min="0" max="2" step="0.001" value="1">
                    <input type="number" id="av-${id}-num" step="0.001" value="1">
                    <button class="btn-inc" id="av-${id}-minus">-</button>
                    <button class="btn-inc" id="av-${id}-plus">+</button>
                </div>
                <div class="control-group">
                    <div class="slider-wrap">
                        <input type="range" id="ax-${id}" min="-20000" max="20000" step="1" value="0">
                        <input type="number" id="ax-${id}-num" step="0.001" value="0">
                        <button class="btn-inc" id="ax-${id}-minus">-</button>
                        <button class="btn-inc" id="ax-${id}-plus">+</button>
                    </div>
                    <div class="slider-wrap">
                        <input type="range" id="ay-${id}" min="-20000" max="20000" step="1" value="0">
                        <input type="number" id="ay-${id}-num" step="0.001" value="0">
                        <button class="btn-inc" id="ay-${id}-minus">-</button>
                        <button class="btn-inc" id="ay-${id}-plus">+</button>
                    </div>
                    <div class="slider-wrap">
                        <input type="range" id="az-${id}" min="-20000" max="20000" step="1" value="0">
                        <input type="number" id="az-${id}-num" step="0.001" value="0">
                        <button class="btn-inc" id="az-${id}-minus">-</button>
                        <button class="btn-inc" id="az-${id}-plus">+</button>
                    </div>
                </div>
                <div style="display:flex; justify-content:space-between; margin-top:8px;">
                    <label>Ghost Mode</label>
                    <input type="checkbox" id="ag-${id}">
                </div>
                <button class="btn" style="background:linear-gradient(135deg, #ff1744, #b71c1c); color:white;" id="ad-${id}">Remove</button>
            `;
            document.getElementById('audios-container').appendChild(card);
            const up = () => {
                audioData.volume = parseFloat(document.getElementById(`av-${id}`).value);
                dryGain.gain.value = audioData.volume;
                wetGain.gain.value = 0;
                helper.position.set(
                    parseFloat(document.getElementById(`ax-${id}`).value) / 1000,
                    parseFloat(document.getElementById(`ay-${id}`).value) / 1000,
                    parseFloat(document.getElementById(`az-${id}`).value) / 1000
                );
                label.position.set(0, 0.5, 0);
                helper.visible = !document.getElementById(`ag-${id}`).checked;
                label.visible = helper.visible;
            };
            document.getElementById(`av-${id}`).oninput = up;
            document.getElementById(`ax-${id}`).oninput = up;
            document.getElementById(`ay-${id}`).oninput = up;
            document.getElementById(`az-${id}`).oninput = up;
            document.getElementById(`ag-${id}`).oninput = up;
            setupSlider(document.getElementById(`av-${id}`));
            setupSlider(document.getElementById(`ax-${id}`));
            setupSlider(document.getElementById(`ay-${id}`));
            setupSlider(document.getElementById(`az-${id}`));
            if (initialState) {
                if (Number.isFinite(initialState.volume)) {
                    document.getElementById(`av-${id}`).value = initialState.volume;
                }
                if (Array.isArray(initialState.position)) {
                    const px = Number(initialState.position[0]);
                    const py = Number(initialState.position[1]);
                    const pz = Number(initialState.position[2]);
                    if (Number.isFinite(px)) document.getElementById(`ax-${id}`).value = px * 1000;
                    if (Number.isFinite(py)) document.getElementById(`ay-${id}`).value = py * 1000;
                    if (Number.isFinite(pz)) document.getElementById(`az-${id}`).value = pz * 1000;
                }
                document.getElementById(`ag-${id}`).checked = !!initialState.ghost;
                up();
            }
            document.getElementById(`ad-${id}`).onclick = () => {
                const parent = audioData.modelIndex === 0 ? currentModels[0] : scene;
                if (parent) parent.remove(helper);
                audio.pause();
                source.disconnect();
                card.remove();
                spatialAudios = spatialAudios.filter(a => a.id !== id);
                updatePlaybackVisibility();
                pushStateSnapshot();
            };
            updatePlaybackVisibility();
        }
        function createTextSprite(text) {
            const canvas = document.createElement('canvas');
            canvas.width = 256;
            canvas.height = 128;
            const ctx = canvas.getContext('2d');
            ctx.fillStyle = 'white';
            ctx.font = 'bold 40px Poppins';
            ctx.fillText(text, 10, 60);
            const tex = new THREE.CanvasTexture(canvas);
            const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true }));
            sprite.scale.set(2, 1, 1);
            return sprite;
        }
        function updatePlaybackVisibility() {
            document.getElementById('playback-controls').style.display = spatialAudios.length > 0 ? 'flex' : 'none';
        }
        function syncAudioTimes(time) {
            spatialAudios.forEach(a => { a.audio.currentTime = time; });
        }
        async function playAll() {
            await audioCtx.resume();
            activeCount = spatialAudios.length;
            isPlaying = true;
            spatialAudios.forEach(async (a) => {
                if (a.audio.paused) {
                    try {
                        await a.audio.play();
                    } catch (e) {
                        console.error('Playback failed', e);
                    }
                }
            });
        }
        function pauseAll() {
            isPlaying = false;
            spatialAudios.forEach(a => { if (!a.audio.paused) a.audio.pause(); });
        }
        function formatTime(s) {
            const m = Math.floor(s / 60);
            s = Math.floor(s % 60);
            return m + ':' + (s < 10 ? '0' + s : s);
        }
        function updateProgress() {
            if (spatialAudios.length === 0) return;
            let current = 0;
            spatialAudios.forEach(a => {
                if (!a.audio.paused) current = Math.max(current, a.audio.currentTime);
            });
            const maxDuration = Math.max(...spatialAudios.map(a => a.audio.duration || 0));
            if (maxDuration > 0) {
                const prog = document.getElementById('progress');
                prog.value = (current / maxDuration) * 100;
                document.getElementById('timer').innerText = formatTime(current) + ' / ' + formatTime(maxDuration);
            }
        }
        // --- UI & ENGINE EVENTS ---
        function setupEngineEvents() {
            document.getElementById('add-model-btn').onclick = () => {
                addModel(document.getElementById('model-url').value).then(() => pushStateSnapshot());
            };
            ['mPosX','mPosY','mPosZ','mRotX','mRotY','mRotZ','mScale'].forEach(id => {
                document.getElementById(id).oninput = (e) => {
                    updateModelTransform();
                    setStore(id, e.target.value);
                    pushStateSnapshot();
                };
            });
            document.getElementById('hide-model-btn').onclick = () => {
                const model = getSelectedModel();
                if (model) {
                    model.visible = !model.visible;
                    updateHideButton();
                    pushStateSnapshot();
                }
            };
            document.getElementById('delete-model-btn').onclick = () => {
                if (currentModels.length === 0) return;
                if (selectedModelIndex === 0 && currentModels.length > 1) {
                    alert('Cannot delete root model if children exist.');
                    return;
                }
                const model = getSelectedModel();
                model.parent.remove(model);
                currentModels.splice(selectedModelIndex, 1);
                modelNames.splice(selectedModelIndex, 1);
                modelAnchors.splice(selectedModelIndex, 1);
                mixers.splice(selectedModelIndex, 1);
                if (selectedModelIndex >= currentModels.length) selectedModelIndex = currentModels.length - 1;
                updateModelList();
                loadModelTransformToSliders();
                updateHideButton();
                pushStateSnapshot();
            };
            function updateHideButton() {
                const btn = document.getElementById('hide-model-btn');
                const model = getSelectedModel();
                btn.innerText = model && model.visible ? 'Hide' : 'Show';
            }
            document.getElementById('add-light-btn').onclick = () => {
                addPointLight();
                pushStateSnapshot();
            };
            document.getElementById('add-audio-btn').onclick = () => {
                addSpatialAudio();
                pushStateSnapshot();
            };
            document.getElementById('capture-anchor').onclick = () => {
                const model = getSelectedModel();
                modelAnchors[selectedModelIndex] = {
                    pos: { x: model.position.x, y: model.position.y, z: model.position.z },
                    rot: { x: model.rotation.x, y: model.rotation.y, z: model.rotation.z },
                    sc: model.scale.x
                };
                alert("Model anchor saved.");
            };
            document.getElementById('restore-anchor').onclick = () => {
                const anchor = modelAnchors[selectedModelIndex];
                document.getElementById('mPosX').value = anchor.pos.x * 1000;
                document.getElementById('mPosY').value = anchor.pos.y * 1000;
                document.getElementById('mPosZ').value = anchor.pos.z * 1000;
                document.getElementById('mRotX').value = anchor.rot.x * 1000;
                document.getElementById('mRotY').value = anchor.rot.y * 1000;
                document.getElementById('mRotZ').value = anchor.rot.z * 1000;
                document.getElementById('mScale').value = anchor.sc * 1000;
                updateModelTransform();
                pushStateSnapshot();
            };
            document.getElementById('sunIntensity').oninput = (e) => { sun.intensity = e.target.value; document.getElementById('v-sun').innerText = e.target.value; setStore('sunIntensity', e.target.value); pushStateSnapshot(); };
            document.getElementById('ambLight').oninput = (e) => { ambientLight.intensity = e.target.value; document.getElementById('v-amb').innerText = e.target.value; setStore('ambLight', e.target.value); pushStateSnapshot(); };
            document.getElementById('bloomIntensity').oninput = (e) => { bloomPass.strength = e.target.value; document.getElementById('v-bi').innerText = e.target.value; setStore('bloomIntensity', e.target.value); pushStateSnapshot(); };
            document.getElementById('shadowQuality').onchange = (e) => {
                const size = parseInt(e.target.value);
                updateShadows(size);
                setStore('shadowQuality', e.target.value);
                pushStateSnapshot();
            };
            document.getElementById('shadowSoftness').oninput = (e) => {
                const softness = parseFloat(e.target.value);
                document.getElementById('v-shadow-soft').innerText = softness.toFixed(1);
                sun.shadow.radius = softness;
                dynamicLights.forEach(l => l.light.shadow.radius = softness);
                setStore('shadowSoftness', e.target.value);
                pushStateSnapshot();
            };
            document.getElementById('envRot').oninput = (e) => { scene.backgroundRotation.y = e.target.value / 1000; scene.environmentRotation.y = e.target.value / 1000; document.getElementById('v-envRot').innerText = (e.target.value / 1000).toFixed(2); setStore('envRot', e.target.value); pushStateSnapshot(); };
            document.getElementById('sky-btn').onclick = () => {
                const url = document.getElementById('sky-url').value;
                loadEnv(url, tex => { skyTex = tex; scene.background = tex; });
                pushStateSnapshot();
            };
            document.getElementById('sky-clear').onclick = () => { skyTex = null; scene.background = null; pushStateSnapshot(); };
            document.getElementById('env-btn').onclick = () => {
                const url = document.getElementById('env-url').value;
                loadEnv(url, tex => { envTex = tex; scene.environment = tex; });
                pushStateSnapshot();
            };
            document.getElementById('env-clear').onclick = () => { envTex = null; scene.environment = null; pushStateSnapshot(); };
            // Playback controls
            const playPause = document.getElementById('play-pause');
            playPause.onclick = () => {
                if (playPause.innerText === 'Play') {
                    playAll();
                    playPause.innerText = 'Pause';
                } else {
                    pauseAll();
                    playPause.innerText = 'Play';
                }
            };
            document.getElementById('restart').onclick = () => {
                syncAudioTimes(0);
                if (playPause.innerText === 'Pause') playAll();
            };
            document.getElementById('progress').oninput = (e) => {
                if (spatialAudios.length > 0) {
                    const maxDuration = Math.max(...spatialAudios.map(a => a.audio.duration || 0));
                    const time = (e.target.value / 100) * maxDuration;
                    syncAudioTimes(time);
                }
            };
            // Initial camera sliders
            ['initPosX','initPosY','initPosZ','initRotX','initRotY','initRotZ'].forEach(id => {
                document.getElementById(id).oninput = (e) => {
                    const val = parseFloat(e.target.value) / 1000;
                    if (id === 'initPosX') initPos.x = val;
                    if (id === 'initPosY') initPos.y = val;
                    if (id === 'initPosZ') initPos.z = val;
                    if (id === 'initRotX') initRot.x = val;
                    if (id === 'initRotY') initRot.y = val;
                    if (id === 'initRotZ') initRot.z = val;
                    camera.position.copy(initPos);
                    camera.setRotationFromEuler(initRot);
                    setStore(id, e.target.value);
                    pushStateSnapshot();
                };
            });
            // Tracking settings
            document.getElementById('camera-mode').onchange = (e) => {
                cameraMode = e.target.value;
                setStore('camera-mode', cameraMode);
                saveSettings();
            };
            document.getElementById('manual-mode').onchange = (e) => {
                manualMode = e.target.checked;
                document.getElementById('manual-controls').style.display = manualMode ? 'block' : 'none';
                setStore('manual-mode', manualMode);
                saveSettings();
            };
            document.getElementById('show-tracker').onchange = (e) => {
                showTracker = e.target.checked;
                emitToParent({type: 'toggle_tracker', show: showTracker});
                setStore('show-tracker', showTracker);
                saveSettings();
            };
            ['dz-x', 'dz-y', 'dz-z', 'dz-yaw', 'dz-pitch'].forEach(id => {
                document.getElementById(id).oninput = (e) => {
                    const value = parseFloat(e.target.value);
                    if (id === 'dz-x') deadZoneX = value;
                    if (id === 'dz-y') deadZoneY = value;
                    if (id === 'dz-z') deadZoneZ = value;
                    if (id === 'dz-yaw') deadZoneYaw = value;
                    if (id === 'dz-pitch') deadZonePitch = value;
                    document.getElementById(id + '-val').innerText = e.target.value;
                    setStore(id, e.target.value);
                    emitToParent({
                        type: 'deadzone_update',
                        deadZoneX, deadZoneY, deadZoneZ, deadZoneYaw, deadZonePitch
                    });
                };
            });
            document.getElementById('anchor-center').onclick = () => {
                anchorHeadX = headX;
                anchorHeadY = headY;
                anchorZ = zValue;
                anchorYaw = yaw;
                anchorPitch = pitch;
                alert('Anchored current tracking to initial camera position.');
            };
            ['head-x', 'head-y', 'z-value', 'yaw', 'pitch'].forEach(id => {
                document.getElementById(id).oninput = (e) => {
                    window[id.replace('-', '')] = parseFloat(e.target.value);
                    document.getElementById(id + '-val').innerText = e.target.value;
                };
            });
            document.getElementById('switch-2d').onclick = () => {
                emitToParent({type: 'switch_2d'});
            };
            // Preset
            document.getElementById('save-preset-btn').onclick = () => {
                const name = document.getElementById('preset-name').value.trim();
                if (name) {
                    const state = getCurrentState();
                    presets[name] = state;
                    emitToParent({
                        type: 'save_preset',
                        name,
                        state
                    });
                    updatePresetSelect();
                    document.getElementById('preset-name').value = '';
                }
            };
            document.getElementById('load-preset-btn').onclick = () => {
                const name = document.getElementById('preset-select').value;
                if (name) {
                    if (presets[name]) {
                        applyState(presets[name]);
                    } else {
                        emitToParent({
                            type: 'load_preset_request',
                            name
                        });
                    }
                }
            };
            // Setup sliders
            document.querySelectorAll('input[type=range]').forEach(setupSlider);
        }
        function getCurrentState() {
            return {
                models: currentModels.map((m, i) => ({
                    id: m.userData.id || `model_${i}`,
                    windowLayer: m.userData.windowLayer || 'inside',
                    name: modelNames[i],
                    url: m.userData.url,
                    position: m.position.toArray(),
                    rotation: m.rotation.toArray(),
                    scale: m.scale.toArray(),
                    visible: m.visible
                })),
                lights: dynamicLights.map(l => ({
                    id: l.id,
                    windowLayer: l.windowLayer || 'inside',
                    color: l.light.color.getHexString(),
                    intensity: l.light.intensity,
                    position: l.light.position.toArray(),
                    scale: l.helper.scale.x,
                    ghost: !l.helper.visible
                })),
                audios: spatialAudios.map(a => ({
                    id: a.id,
                    windowLayer: a.windowLayer || 'inside',
                    url: a.audio.src,
                    volume: a.volume,
                    position: a.helper.position.toArray(),
                    ghost: !a.helper.visible
                })),
                renderOrder: [
                    ...currentModels.map((m, i) => 'model:' + (m.userData.id || ('model_' + i))),
                    ...dynamicLights.map((l) => `light:${l.id}`),
                    ...spatialAudios.map((a) => `audio:${a.id}`),
                ],
                sunIntensity: sun.intensity,
                ambLight: ambientLight.intensity,
                bloomIntensity: bloomPass.strength,
                shadowQuality: document.getElementById('shadowQuality').value,
                shadowSoftness: sun.shadow.radius,
                skyUrl: skyTex ? skyTex.source.data.currentSrc : null,
                envUrl: envTex ? envTex.source.data.currentSrc : null,
                envRot: scene.backgroundRotation.y,
                initPos: initPos.toArray(),
                initRot: initRot.toArray()
            };
        }
        async function applyState(state) {
            if (!state) return;
            // Clear current scene
            while (currentModels.length > 0) {
                const model = currentModels.pop();
                model.parent.remove(model);
            }
            modelNames = [];
            mixers = [];
            modelAnchors = [];
            dynamicLights.forEach(l => l.light.parent.remove(l.light));
            dynamicLights = [];
            spatialAudios.forEach(a => a.helper.parent.remove(a.helper));
            spatialAudios = [];
            document.getElementById('lights-container').innerHTML = '';
            document.getElementById('audios-container').innerHTML = '';
            const models = Array.isArray(state.models) ? state.models : [];
            const lights = Array.isArray(state.lights) ? state.lights : [];
            const audios = Array.isArray(state.audios) ? state.audios : [];
            // Load models
            for (const m of models) {
                const model = await addModel(m.url, m);
                if (!model) continue;
                if (Array.isArray(m.position)) model.position.fromArray(m.position);
                if (Array.isArray(m.rotation)) model.rotation.fromArray(m.rotation);
                if (Array.isArray(m.scale)) model.scale.fromArray(m.scale);
                model.visible = (m.visible !== false);
            }
            // Load lights
            lights.forEach((l) => addPointLight(l));
            lights.forEach((l, i) => {
                const lightData = dynamicLights[i];
                if (!lightData) return;
                lightData.windowLayer = l.windowLayer || 'inside';
                lightData.light.color.setHex('0x' + l.color);
                lightData.light.intensity = l.intensity;
                if (Array.isArray(l.position)) {
                    lightData.light.position.fromArray(l.position);
                }
                lightData.helper.scale.setScalar(l.scale);
                lightData.helper.visible = !l.ghost;
            });
            // Load audios
            if (AUDIO_ENABLED) {
                audios.forEach(a => addSpatialAudio(a.url, a));
                audios.forEach((a, i) => {
                    const audioData = spatialAudios[i];
                    if (!audioData) return;
                    audioData.windowLayer = a.windowLayer || 'inside';
                    audioData.volume = a.volume;
                    if (Array.isArray(a.position)) {
                        audioData.helper.position.fromArray(a.position);
                    }
                    audioData.helper.visible = !a.ghost;
                });
            }
            // Load other settings
            if (Number.isFinite(state.sunIntensity)) sun.intensity = state.sunIntensity;
            if (Number.isFinite(state.ambLight)) ambientLight.intensity = state.ambLight;
            if (Number.isFinite(state.bloomIntensity)) bloomPass.strength = state.bloomIntensity;
            if (state.shadowQuality != null) document.getElementById('shadowQuality').value = state.shadowQuality;
            if (Number.isFinite(state.shadowSoftness)) sun.shadow.radius = state.shadowSoftness;
            if (state.skyUrl) loadEnv(state.skyUrl, tex => { skyTex = tex; scene.background = tex; });
            if (state.envUrl) loadEnv(state.envUrl, tex => { envTex = tex; scene.environment = tex; });
            if (Number.isFinite(state.envRot)) scene.backgroundRotation.y = state.envRot;
            if (Array.isArray(state.initPos)) initPos.fromArray(state.initPos);
            if (Array.isArray(state.initRot)) initRot.fromArray(state.initRot);
            camera.position.copy(initPos);
            camera.setRotationFromEuler(initRot);
            updatePlaybackVisibility();
            pushStateSnapshot();
        }
        function updatePresetSelect() {
            const select = document.getElementById('preset-select');
            select.innerHTML = '<option value="">Load Preset</option>';
            Object.keys(presets).forEach(name => {
                const opt = document.createElement('option');
                opt.value = name;
                opt.innerText = name;
                select.appendChild(opt);
            });
        }
        function updateCamera() {
            if (manualMode) {
                headX = parseFloat(document.getElementById('head-x').value);
                headY = parseFloat(document.getElementById('head-y').value);
                zValue = parseFloat(document.getElementById('z-value').value);
                yaw = parseFloat(document.getElementById('yaw').value);
                pitch = parseFloat(document.getElementById('pitch').value);
            }
            const relX = headX - anchorHeadX;
            const relY = headY - anchorHeadY;
            const relZ = zValue - anchorZ;
            const relYaw = yaw - anchorYaw;
            const relPitch = pitch - anchorPitch;
            let effectiveRelX = relX;
            let effectiveRelY = relY;
            let effectiveRelZ = relZ;
            let effectiveRelYaw = relYaw + mouseYawOffset;
            let effectiveRelPitch = relPitch + mousePitchOffset;
            effectiveRelZ += mouseZoomOffset;
            const relEuler = new THREE.Euler(effectiveRelPitch * Math.PI / 180, -effectiveRelYaw * Math.PI / 180, 0, 'YXZ');
            switch (cameraMode) {
                case 'orbit':
                    const phi = (effectiveRelPitch / 90) * Math.PI / 2;
                    const theta = (effectiveRelYaw / 90) * Math.PI * 2;
                    const radius = 10 + effectiveRelZ * 50;
                    camera.position.x = radius * Math.sin(phi) * Math.sin(theta) + orbitTarget.x;
                    camera.position.y = radius * Math.cos(phi) + orbitTarget.y;
                    camera.position.z = radius * Math.sin(phi) * Math.cos(theta) + orbitTarget.z;
                    camera.lookAt(orbitTarget);
                    break;
                case 'fps':
                    camera.position.copy(initPos);
                    const moveSpeed = 0.1;
                    const forward = new THREE.Vector3(0, 0, -1).applyEuler(relEuler);
                    camera.position.add(forward.multiplyScalar(-effectiveRelY * moveSpeed));
                    const right = new THREE.Vector3(1, 0, 0).applyEuler(relEuler);
                    camera.position.add(right.multiplyScalar(effectiveRelX * moveSpeed));
                    camera.position.y += effectiveRelZ * moveSpeed * 10;
                    camera.setRotationFromEuler(initRot);
                    camera.rotateX(relEuler.x);
                    camera.rotateY(relEuler.y);
                    break;
                case 'free':
                    camera.position.copy(initPos);
                    const moveSpeedFree = 0.05;
                    const forwardFree = new THREE.Vector3(0, 0, -1).applyEuler(relEuler);
                    camera.position.add(forwardFree.multiplyScalar(effectiveRelZ * moveSpeedFree * 10));
                    const rightFree = new THREE.Vector3(1, 0, 0).applyEuler(relEuler);
                    camera.position.add(rightFree.multiplyScalar(effectiveRelX * moveSpeedFree));
                    const upFree = new THREE.Vector3(0, 1, 0).applyEuler(relEuler);
                    camera.position.add(upFree.multiplyScalar(-effectiveRelY * moveSpeedFree));
                    camera.setRotationFromEuler(initRot);
                    camera.rotateX(relEuler.x);
                    camera.rotateY(relEuler.y);
                    break;
            }
            camera.updateMatrixWorld(true);
        }
        function animate() {
            if (disposed) return;
            frameCount++;
            const now = performance.now();
            if (now - lastFpsTime >= 1000) {
                fps = (frameCount / ((now - lastFpsTime) / 1000)).toFixed(1);
                frameCount = 0;
                lastFpsTime = now;
                const memoryApi = performance && performance.memory ? performance.memory : null;
                emitToParent({
                    type: 'engine_metrics',
                    fps: Number(fps),
                    latency: 0,
                    memory: memoryApi ? Number(memoryApi.usedJSHeapSize || 0) : null,
                });
            }
            const delta = clock.getDelta();
            mixers.forEach(m => { if(m) m.update(delta); });
            updateCamera();
            // Update audio listener
            audioCtx.listener.positionX.value = camera.position.x;
            audioCtx.listener.positionY.value = camera.position.y;
            audioCtx.listener.positionZ.value = camera.position.z;
            camera.getWorldDirection(forwardVec);
            audioCtx.listener.forwardX.value = -forwardVec.x;
            audioCtx.listener.forwardY.value = -forwardVec.y;
            audioCtx.listener.forwardZ.value = -forwardVec.z;
            audioCtx.listener.upX.value = camera.up.x;
            audioCtx.listener.upY.value = camera.up.y;
            audioCtx.listener.upZ.value = camera.up.z;
            // Update spatial audios
            spatialAudios.forEach(a => {
                a.helper.getWorldPosition(tempVec);
                a.panner.positionX.value = tempVec.x;
                a.panner.positionY.value = tempVec.y;
                a.panner.positionZ.value = tempVec.z;
                const dist = camera.position.distanceTo(tempVec);
                const absorption = Math.pow(10, (-0.005 * dist) / 20);
                a.lowpass.frequency.value = 22050 * absorption;
                a.dryGain.gain.value = a.volume;
                a.wetGain.gain.value = 0;
                a.label.lookAt(camera.position);
            });
            updateProgress();
            // Selective Bloom
            scene.traverse(obj => {
                if(obj.isMesh && !bloomLayer.test(obj.layers)) {
                    materialsBackup[obj.uuid] = obj.material;
                    obj.material = darkMaterial;
                }
            });
            const bgBackup = scene.background;
            scene.background = null;
            bloomComposer.render();
            scene.background = bgBackup;
            scene.traverse(obj => {
                if(materialsBackup[obj.uuid]) {
                    obj.material = materialsBackup[obj.uuid];
                    delete materialsBackup[obj.uuid];
                }
            });
            finalComposer.render();
        }
        function handleResize() {
            if (disposed || !camera || !renderer || !bloomComposer || !finalComposer) return;
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
            bloomComposer.setSize(window.innerWidth, window.innerHeight);
            finalComposer.setSize(window.innerWidth, window.innerHeight);
        }
        function setupSlider(slider) {
            if (!slider) return;
            const id = slider.id;
            const num = document.getElementById(`${id}-num`);
            if (!num) return;
            const valDisplay = document.getElementById(`${id}-val`) || document.getElementById(`v-${id}`);
            const originalOnInput = slider.oninput || (() => {});
            slider.oninput = (e) => {
                originalOnInput(e);
                const val = parseFloat(slider.value);
                num.value = val.toFixed(3);
                if (valDisplay) valDisplay.innerText = val.toFixed(id.includes('dz-head') || id.includes('dz-hp') ? 1 : 3);
                setStore(id, slider.value);
                if (!id.startsWith('head-') && id !== 'z-value' && id !== 'yaw' && id !== 'pitch') {
                    pushStateSnapshot();
                }
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
        // Renderer-only bridge overrides.
        function applyGlobalTrackingConfig(enabled) {
            useGlobalTracking = !!enabled;
            if (useGlobalTracking) {
                showTracker = false;
                persistedSettings['show-tracker'] = 'false';
            }
        }
        function _readStoredNumber(key, fallback) {
            const raw = getStore(key);
            if (raw === null || raw === undefined) return fallback;
            const next = Number(raw);
            return Number.isFinite(next) ? next : fallback;
        }
        function loadSettings() {
            cameraMode = (getStore('camera-mode') || cameraMode || 'orbit').toString();
            manualMode = getStore('manual-mode') === 'true';
            showTracker = getStore('show-tracker') === 'true';
            deadZoneX = _readStoredNumber('dz-x', deadZoneX);
            deadZoneY = _readStoredNumber('dz-y', deadZoneY);
            deadZoneZ = _readStoredNumber('dz-z', deadZoneZ);
            deadZoneYaw = _readStoredNumber('dz-yaw', deadZoneYaw);
            deadZonePitch = _readStoredNumber('dz-pitch', deadZonePitch);
            headX = _readStoredNumber('head-x', headX);
            headY = _readStoredNumber('head-y', headY);
            zValue = _readStoredNumber('z-value', zValue);
            yaw = _readStoredNumber('yaw', yaw);
            pitch = _readStoredNumber('pitch', pitch);
            sun.intensity = _readStoredNumber('sunIntensity', sun.intensity);
            ambientLight.intensity = _readStoredNumber('ambLight', ambientLight.intensity);
            bloomPass.strength = _readStoredNumber('bloomIntensity', bloomPass.strength);
            sun.shadow.radius = _readStoredNumber('shadowSoftness', sun.shadow.radius);
            shadowQualityValue = String(getStore('shadowQuality') || shadowQualityValue || '512');
            const parsedShadowQuality = Number.parseInt(shadowQualityValue, 10);
            if (Number.isFinite(parsedShadowQuality) && parsedShadowQuality > 0) {
                updateShadows(parsedShadowQuality);
            }
            const envRotStored = _readStoredNumber('envRot', scene.backgroundRotation?.y || 0);
            scene.backgroundRotation.y = envRotStored;
            scene.environmentRotation.y = envRotStored;
            if (useGlobalTracking) {
                showTracker = false;
                persistedSettings['show-tracker'] = 'false';
            }
        }
        function saveSettings() {
            pushStateSnapshot();
        }
        function setupEngineEvents() {}
        function setupSlider(_) {}
        function updateModelTransform() {}
        function loadModelTransformToSliders() {}
        function updateModelList() {}
        function updatePresetSelect() {}
        function updatePlaybackVisibility() {}
        function updateProgress() {}
        function addPointLight(initialState = null) {
            const id =
                (initialState && initialState.id) ||
                `light_${Date.now()}_${dynamicLights.length}`;
            const colorHex = ((initialState && initialState.color) || 'ffffff').toString().replace('#', '');
            const intensity = Number(initialState && initialState.intensity);
            const scale = Number(initialState && initialState.scale);
            const light = new THREE.PointLight(
                Number.parseInt(colorHex, 16),
                Number.isFinite(intensity) ? intensity : 10,
                100
            );
            if (Array.isArray(initialState && initialState.position)) {
                const position = initialState.position;
                light.position.set(
                    Number(position[0]) || 0,
                    Number(position[1]) || 5,
                    Number(position[2]) || 0
                );
            } else {
                light.position.set(0, 5, 0);
            }
            light.castShadow = true;
            const helper = new THREE.Mesh(
                new THREE.SphereGeometry(0.35),
                new THREE.MeshStandardMaterial({
                    color: light.color,
                    emissive: light.color,
                    emissiveIntensity: 0.5,
                }),
            );
            helper.layers.enable(1);
            helper.position.copy(light.position);
            helper.scale.setScalar(Number.isFinite(scale) ? scale : 1);
            helper.visible = !(initialState && initialState.ghost === true);
            const root = getRoot();
            (root || scene).add(light);
            (root || scene).add(helper);
            dynamicLights.push({
                id,
                light,
                helper,
                modelIndex: currentModels.length > 0 ? 0 : -1,
                windowLayer: (initialState && initialState.windowLayer) || 'inside',
            });
            return dynamicLights[dynamicLights.length - 1];
        }
        function addSpatialAudio(explicitUrl, initialState = null) {
            if (!AUDIO_ENABLED) return null;
            const url =
                explicitUrl ||
                (initialState && initialState.url) ||
                '';
            if (!url) return null;
            const id =
                (initialState && initialState.id) ||
                `audio_${Date.now()}_${spatialAudios.length}`;
            const audio = new Audio(url);
            audio.preload = 'auto';
            audio.crossOrigin = 'anonymous';
            const source = audioCtx.createMediaElementSource(audio);
            const lowpass = audioCtx.createBiquadFilter();
            lowpass.type = 'lowpass';
            lowpass.frequency.value = 22050;
            const panner = audioCtx.createPanner();
            panner.panningModel = 'HRTF';
            panner.distanceModel = 'inverse';
            panner.refDistance = 1;
            panner.maxDistance = 10000;
            panner.rolloffFactor = 1;
            const dryGain = audioCtx.createGain();
            const wetGain = audioCtx.createGain();
            source.connect(lowpass);
            lowpass.connect(panner);
            panner.connect(dryGain);
            dryGain.connect(audioCtx.destination);
            if (convolver) {
                panner.connect(convolver);
                convolver.connect(wetGain);
                wetGain.connect(audioCtx.destination);
            }
            const helper = new THREE.Mesh(
                new THREE.SphereGeometry(0.3),
                new THREE.MeshStandardMaterial({ color: 0x00ff88 }),
            );
            helper.layers.enable(1);
            if (Array.isArray(initialState && initialState.position)) {
                const position = initialState.position;
                helper.position.set(
                    Number(position[0]) || 0,
                    Number(position[1]) || 0,
                    Number(position[2]) || 0
                );
            } else {
                helper.position.set(0, 0, 0);
            }
            const label = createTextSprite(
                url.split('/').pop().replace(/\.[^/.]+$/, '') || 'audio',
            );
            label.position.set(0, 0.5, 0);
            helper.add(label);
            const root = getRoot();
            (root || scene).add(helper);
            const volume = Number(initialState && initialState.volume);
            const resolvedVolume = Number.isFinite(volume) ? volume : 1;
            dryGain.gain.value = resolvedVolume;
            wetGain.gain.value = 0;
            helper.visible = !(initialState && initialState.ghost === true);
            label.visible = helper.visible;
            const audioData = {
                id,
                audio,
                source,
                lowpass,
                panner,
                dryGain,
                wetGain,
                helper,
                label,
                modelIndex: currentModels.length > 0 ? 0 : -1,
                volume: resolvedVolume,
                windowLayer: (initialState && initialState.windowLayer) || 'inside',
            };
            spatialAudios.push(audioData);
            audio.addEventListener('ended', () => {
                activeCount--;
                if (activeCount === 0 && isPlaying) {
                    syncAudioTimes(0);
                    playAll();
                }
            });
            return audioData;
        }
        function getCurrentState() {
            const skySource = skyTex && skyTex.source && skyTex.source.data ? skyTex.source.data : null;
            const envSource = envTex && envTex.source && envTex.source.data ? envTex.source.data : null;
            return {
                models: currentModels.map((m, i) => ({
                    id: m.userData.id || `model_${i}`,
                    windowLayer: m.userData.windowLayer || 'inside',
                    name: modelNames[i],
                    url: m.userData.url,
                    position: m.position.toArray(),
                    rotation: m.rotation.toArray(),
                    scale: m.scale.toArray(),
                    visible: m.visible
                })),
                lights: dynamicLights.map(l => ({
                    id: l.id,
                    windowLayer: l.windowLayer || 'inside',
                    color: l.light.color.getHexString(),
                    intensity: l.light.intensity,
                    position: l.light.position.toArray(),
                    scale: l.helper.scale.x,
                    ghost: !l.helper.visible
                })),
                audios: spatialAudios.map(a => ({
                    id: a.id,
                    windowLayer: a.windowLayer || 'inside',
                    url: a.audio.src,
                    volume: a.volume,
                    position: a.helper.position.toArray(),
                    ghost: !a.helper.visible
                })),
                renderOrder: [
                    ...currentModels.map((m, i) => 'model:' + (m.userData.id || ('model_' + i))),
                    ...dynamicLights.map((l) => `light:${l.id}`),
                    ...spatialAudios.map((a) => `audio:${a.id}`),
                ],
                sunIntensity: sun.intensity,
                ambLight: ambientLight.intensity,
                bloomIntensity: bloomPass.strength,
                shadowQuality: shadowQualityValue,
                shadowSoftness: sun.shadow.radius,
                skyUrl: skySource ? (skySource.currentSrc || skySource.src || null) : null,
                envUrl: envSource ? (envSource.currentSrc || envSource.src || null) : null,
                envRot: scene.backgroundRotation.y,
                initPos: initPos.toArray(),
                initRot: initRot.toArray()
            };
        }
        async function applyState(state) {
            if (!state) return;
            while (currentModels.length > 0) {
                const model = currentModels.pop();
                if (model && model.parent) model.parent.remove(model);
            }
            modelNames = [];
            mixers = [];
            modelAnchors = [];
            dynamicLights.forEach(l => {
                if (l.light && l.light.parent) l.light.parent.remove(l.light);
                if (l.helper && l.helper.parent) l.helper.parent.remove(l.helper);
            });
            dynamicLights = [];
            spatialAudios.forEach(a => {
                if (a.helper && a.helper.parent) a.helper.parent.remove(a.helper);
                try { a.audio.pause(); } catch (_) {}
                try { a.source.disconnect(); } catch (_) {}
                try { a.lowpass.disconnect(); } catch (_) {}
                try { a.panner.disconnect(); } catch (_) {}
                try { a.dryGain.disconnect(); } catch (_) {}
                try { a.wetGain.disconnect(); } catch (_) {}
            });
            spatialAudios = [];
            const models = Array.isArray(state.models) ? state.models : [];
            const lights = Array.isArray(state.lights) ? state.lights : [];
            const audios = Array.isArray(state.audios) ? state.audios : [];
            for (const m of models) {
                const model = await addModel(m.url, m);
                if (!model) continue;
                if (Array.isArray(m.position)) model.position.fromArray(m.position);
                if (Array.isArray(m.rotation)) model.rotation.fromArray(m.rotation);
                if (Array.isArray(m.scale)) model.scale.fromArray(m.scale);
                model.visible = (m.visible !== false);
            }
            lights.forEach((l) => addPointLight(l));
            if (AUDIO_ENABLED) {
                audios.forEach((a) => addSpatialAudio(a.url, a));
            }
            if (Number.isFinite(state.sunIntensity)) sun.intensity = state.sunIntensity;
            if (Number.isFinite(state.ambLight)) ambientLight.intensity = state.ambLight;
            if (Number.isFinite(state.bloomIntensity)) bloomPass.strength = state.bloomIntensity;
            if (state.shadowQuality != null) {
                shadowQualityValue = String(state.shadowQuality);
                const parsedShadowQuality = Number.parseInt(shadowQualityValue, 10);
                if (Number.isFinite(parsedShadowQuality) && parsedShadowQuality > 0) {
                    updateShadows(parsedShadowQuality);
                }
            }
            if (Number.isFinite(state.shadowSoftness)) sun.shadow.radius = state.shadowSoftness;
            if (state.skyUrl) loadEnv(state.skyUrl, tex => { skyTex = tex; scene.background = tex; });
            if (state.envUrl) loadEnv(state.envUrl, tex => { envTex = tex; scene.environment = tex; });
            if (Number.isFinite(state.envRot)) {
                scene.backgroundRotation.y = state.envRot;
                scene.environmentRotation.y = state.envRot;
            }
            if (Array.isArray(state.initPos)) initPos.fromArray(state.initPos);
            if (Array.isArray(state.initRot)) initRot.fromArray(state.initRot);
            camera.position.copy(initPos);
            camera.setRotationFromEuler(initRot);
            pushStateSnapshot();
        }
        function updateCamera() {
            const relX = headX - anchorHeadX;
            const relY = headY - anchorHeadY;
            const relZ = zValue - anchorZ;
            const relYaw = yaw - anchorYaw;
            const relPitch = pitch - anchorPitch;
            let effectiveRelX = relX;
            let effectiveRelY = relY;
            let effectiveRelZ = relZ;
            let effectiveRelYaw = relYaw + mouseYawOffset;
            let effectiveRelPitch = relPitch + mousePitchOffset;
            effectiveRelZ += mouseZoomOffset;
            const relEuler = new THREE.Euler(effectiveRelPitch * Math.PI / 180, -effectiveRelYaw * Math.PI / 180, 0, 'YXZ');
            switch (cameraMode) {
                case 'orbit':
                    const phi = (effectiveRelPitch / 90) * Math.PI / 2;
                    const theta = (effectiveRelYaw / 90) * Math.PI * 2;
                    const radius = 10 + effectiveRelZ * 50;
                    camera.position.x = radius * Math.sin(phi) * Math.sin(theta) + orbitTarget.x;
                    camera.position.y = radius * Math.cos(phi) + orbitTarget.y;
                    camera.position.z = radius * Math.sin(phi) * Math.cos(theta) + orbitTarget.z;
                    camera.lookAt(orbitTarget);
                    break;
                case 'fps':
                    camera.position.copy(initPos);
                    const moveSpeed = 0.1;
                    const forward = new THREE.Vector3(0, 0, -1).applyEuler(relEuler);
                    camera.position.add(forward.multiplyScalar(-effectiveRelY * moveSpeed));
                    const right = new THREE.Vector3(1, 0, 0).applyEuler(relEuler);
                    camera.position.add(right.multiplyScalar(effectiveRelX * moveSpeed));
                    camera.position.y += effectiveRelZ * moveSpeed * 10;
                    camera.setRotationFromEuler(initRot);
                    camera.rotateX(relEuler.x);
                    camera.rotateY(relEuler.y);
                    break;
                case 'free':
                    camera.position.copy(initPos);
                    const moveSpeedFree = 0.05;
                    const forwardFree = new THREE.Vector3(0, 0, -1).applyEuler(relEuler);
                    camera.position.add(forwardFree.multiplyScalar(effectiveRelZ * moveSpeedFree * 10));
                    const rightFree = new THREE.Vector3(1, 0, 0).applyEuler(relEuler);
                    camera.position.add(rightFree.multiplyScalar(effectiveRelX * moveSpeedFree));
                    const upFree = new THREE.Vector3(0, 1, 0).applyEuler(relEuler);
                    camera.position.add(upFree.multiplyScalar(-effectiveRelY * moveSpeedFree));
                    camera.setRotationFromEuler(initRot);
                    camera.rotateX(relEuler.x);
                    camera.rotateY(relEuler.y);
                    break;
            }
            camera.updateMatrixWorld(true);
        }
        init();
        window.addEventListener('resize', handleResize);
    </script>
</body>
</html>
''';
    content = content
        .replaceAll('__CLEAN_VIEW__', widget.cleanView ? 'true' : 'false')
        .replaceAll('__HIDE_PANEL__', 'true')
        .replaceAll(
            '__STUDIO_SURFACE__', widget.studioSurface ? 'true' : 'false')
        .replaceAll('__AUDIO_ENABLED__', widget.disableAudio ? 'false' : 'true')
        .replaceAll('__BODY_BG__', widget.cleanView ? 'transparent' : '#000')
        .replaceAll('__BRIDGE_CHANNEL__', _bridgeChannel);

    ui_web.platformViewRegistry.registerViewFactory(viewID, (int viewId) {
      final web.HTMLIFrameElement iframe = web.HTMLIFrameElement();
      iframe.id = _engineFrameElementId;
      iframe.width = '100%';
      iframe.height = '100%';
      iframe.srcdoc = content;
      iframe.style.setProperty('border', 'none');
      iframe.style.setProperty('background', 'transparent');
      iframe.style.setProperty(
          'pointer-events', widget.pointerPassthrough ? 'none' : 'auto');
      iframe.allow = 'camera *; microphone *';
      _engineIframe = iframe;
      return iframe;
    });

    if (widget.externalHeadPose == null && !widget.useGlobalTracking) {
      ui_web.platformViewRegistry.registerViewFactory(trackerViewID,
          (int viewId) {
        final web.HTMLIFrameElement iframe = web.HTMLIFrameElement();
        iframe.id = _trackerFrameElementId;
        iframe.setAttribute('width', '100%');
        iframe.setAttribute('height', '100%');
        iframe.src = 'assets/tracker.html?channel=$_bridgeChannel';
        iframe.style.setProperty('border', 'none');
        iframe.style.setProperty('background', 'transparent');
        iframe.allow = 'camera *; microphone *; fullscreen *';
        _trackerIframe = iframe;
        scheduleMicrotask(_postTrackerConfig);
        return iframe;
      });
    }

    _messageSubscription = web.window.onMessage.listen((event) {
      final Map<String, dynamic>? messageData = _extractPayload(event.data);
      if (messageData == null) return;
      if (messageData['channel'] != null &&
          messageData['channel'].toString() != _bridgeChannel) {
        return;
      }
      final bool fromEngine = _isFromEngine(event);
      final bool fromTracker = _isFromTracker(event);
      if (!fromEngine && !fromTracker) return;

      final String? type = messageData['type']?.toString();
      if (fromEngine) {
        if (type == 'toggle_tracker') {
          if (widget.useGlobalTracking) return;
          setState(() {
            showTracker = messageData['show'] == true;
          });
          _postTrackerConfig();
          if (!widget.cleanView) _queueSaveModeState();
          return;
        }
        if (type == 'switch_2d') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/2d');
          return;
        }
        if (type == 'engine_ready') {
          _iframeReady = true;
          _bootstrapEngineState();
          return;
        }
        if (type == 'engine_setting') {
          _onEngineSetting(messageData);
          return;
        }
        if (type == 'engine_snapshot') {
          _onEngineSnapshot(messageData);
          return;
        }
        if (type == 'deadzone_update') {
          _onDeadzoneUpdate(messageData);
          return;
        }
        if (type == 'save_preset') {
          _onSavePresetFromEngine(messageData);
          return;
        }
        if (type == 'load_preset_request') {
          _onLoadPresetRequestFromEngine(messageData);
          return;
        }
      }

      if (fromTracker) {
        if (widget.useGlobalTracking) return;
        if (type == 'hide_tracker') {
          if (showTracker) {
            setState(() => showTracker = false);
            _postTrackerConfig();
          }
          return;
        }
        _dataController.add(messageData);
      }
    });
    _trackingDataSubscription = _dataController.stream.listen((data) {
      if (widget.externalHeadPose != null) return;
      final headMap = _asMap(data['head']);
      if (headMap == null) return;

      if (!manualMode) {
        _applyTrackerDeadZone(headMap);
      } else {
        headX = _toDouble(headMap['x'], headX);
        headY = _toDouble(headMap['y'], headY);
        zValue = _toDouble(headMap['z'], zValue);
        yaw = _toDouble(headMap['yaw'], yaw);
        pitch = _toDouble(headMap['pitch'], pitch);
      }
      _postToEngine(<String, dynamic>{
        'type': 'tracking_patch',
        'head': <String, dynamic>{
          'x': headX,
          'y': headY,
          'z': zValue,
          'yaw': yaw,
          'pitch': pitch,
        },
      });
    });

    if (widget.externalHeadPose == null && widget.useGlobalTracking) {
      _globalTrackingListener = () {
        if (!mounted) return;
        final frame = TrackingService.instance.frameNotifier.value;
        if (!manualMode) {
          _applyTrackerDeadZone(<String, dynamic>{
            'x': frame.headX,
            'y': frame.headY,
            'z': frame.headZ,
            'yaw': frame.yaw,
            'pitch': frame.pitch,
          });
        } else {
          headX = frame.headX;
          headY = frame.headY;
          zValue = frame.headZ;
          yaw = frame.yaw;
          pitch = frame.pitch;
        }
        _postToEngine(<String, dynamic>{
          'type': 'tracking_patch',
          'head': <String, dynamic>{
            'x': headX,
            'y': headY,
            'z': zValue,
            'yaw': yaw,
            'pitch': pitch,
          },
        });
      };
      TrackingService.instance.frameNotifier
          .addListener(_globalTrackingListener!);
    }

    if (widget.externalHeadPose != null) {
      _applyExternalHeadPose(widget.externalHeadPose!);
    }
  }

  @override
  void dispose() {
    debugPrint(
        'Disposing Engine3DPage(cleanView=${widget.cleanView}, embedded=${widget.embedded}, embeddedStudio=${widget.embeddedStudio})');
    _saveDebounce?.cancel();
    _postToEngine(<String, dynamic>{
      'type': 'dispose_engine',
      'channel': _bridgeChannel,
    });
    if (!widget.useGlobalTracking) {
      _postToTracker(<String, dynamic>{
        'type': 'dispose_tracker',
        'channel': _bridgeChannel,
      });
    }
    final listener = _globalTrackingListener;
    if (listener != null) {
      TrackingService.instance.frameNotifier.removeListener(listener);
      _globalTrackingListener = null;
    }
    _messageSubscription?.cancel();
    _trackingDataSubscription?.cancel();
    _dataController.close();
    presetNameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Engine3DPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool externalPayloadChanged = !const DeepCollectionEquality()
        .equals(widget.initialPresetPayload, oldWidget.initialPresetPayload);
    if (externalPayloadChanged) {
      final adapted = _adaptPresetPayload(widget.initialPresetPayload);
      if (adapted != null) {
        _modeState['sceneState'] = adapted.scene;
        final Map<String, dynamic> settings =
            ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
                <String, dynamic>{};
        settings.addAll(adapted.controls);
        _modeState['settings'] = settings;
        _postToEngine(<String, dynamic>{
          'type': 'apply_scene_patch',
          'patch': adapted.scene,
        });
        _postToEngine(<String, dynamic>{
          'type': 'apply_settings_patch',
          'patch': settings,
        });
        widget.onLivePayloadChanged?.call(_buildLivePayloadFromScene(
          adapted.scene,
        ));
      }
    }
    if (widget.externalHeadPose != null) {
      _applyExternalHeadPose(widget.externalHeadPose!);
      return;
    }
    if (widget.useGlobalTracking && !oldWidget.useGlobalTracking) {
      _globalTrackingListener ??= () {
        if (!mounted) return;
        final frame = TrackingService.instance.frameNotifier.value;
        if (!manualMode) {
          _applyTrackerDeadZone(<String, dynamic>{
            'x': frame.headX,
            'y': frame.headY,
            'z': frame.headZ,
            'yaw': frame.yaw,
            'pitch': frame.pitch,
          });
        } else {
          headX = frame.headX;
          headY = frame.headY;
          zValue = frame.headZ;
          yaw = frame.yaw;
          pitch = frame.pitch;
        }
        _postToEngine(<String, dynamic>{
          'type': 'tracking_patch',
          'head': <String, dynamic>{
            'x': headX,
            'y': headY,
            'z': zValue,
            'yaw': yaw,
            'pitch': pitch,
          },
        });
      };
      TrackingService.instance.frameNotifier
          .addListener(_globalTrackingListener!);
    } else if (!widget.useGlobalTracking && oldWidget.useGlobalTracking) {
      final listener = _globalTrackingListener;
      if (listener != null) {
        TrackingService.instance.frameNotifier.removeListener(listener);
        _globalTrackingListener = null;
      }
    }
    if (widget.useGlobalTracking != oldWidget.useGlobalTracking) {
      _postToEngine(<String, dynamic>{
        'type': 'global_tracking_config',
        'useGlobal': widget.useGlobalTracking,
      });
    }
    if (widget.pointerPassthrough != oldWidget.pointerPassthrough) {
      _engineIframe?.style.setProperty(
          'pointer-events', widget.pointerPassthrough ? 'none' : 'auto');
    }
    if (widget.reanchorToken != oldWidget.reanchorToken) {
      _postToEngine(<String, dynamic>{'type': 'reanchor'});
    }
  }

  PresetPayloadV2? _adaptPresetPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return PresetPayloadV2.fromMap(payload, fallbackMode: '3d');
  }

  Future<void> _bootstrap() async {
    if (widget.cleanView) {
      final adapted = _adaptPresetPayload(widget.initialPresetPayload);
      if (adapted != null) {
        _modeState['sceneState'] = adapted.scene;
        _modeState['presetControls'] = adapted.controls;
      }
      return;
    }

    try {
      final modeState = await _repository.fetchModeState('3d');
      if (modeState != null) {
        _modeState = modeState;
        final settings =
            (modeState['settings'] as Map?)?.cast<String, dynamic>();
        deadZoneX = _toDouble(settings?['dz-x'], deadZoneX);
        deadZoneY = _toDouble(settings?['dz-y'], deadZoneY);
        deadZoneZ = _toDouble(settings?['dz-z'], deadZoneZ);
        deadZoneYaw = _toDouble(settings?['dz-yaw'], deadZoneYaw);
        deadZonePitch = _toDouble(settings?['dz-pitch'], deadZonePitch);
        manualMode = settings?['manual-mode']?.toString() == 'true';
        if (!widget.useGlobalTracking) {
          showTracker = settings?['show-tracker']?.toString() == 'true';
        }
      }
    } catch (e) {
      debugPrint('Failed to load 3D mode state: $e');
    }

    final adaptedInitial = _adaptPresetPayload(widget.initialPresetPayload);
    if (adaptedInitial != null) {
      _modeState['sceneState'] = adaptedInitial.scene;
      _modeState['presetControls'] = adaptedInitial.controls;
    }

    if (widget.persistPresets) {
      try {
        final items = await _repository.fetchUserPresets(mode: '3d');
        presets.clear();
        for (final item in items) {
          final adapted =
              PresetPayloadV2.fromMap(item.payload, fallbackMode: '3d');
          presets[item.name] = adapted.scene;
        }
      } catch (e) {
        debugPrint('Failed to load 3D presets: $e');
      }
    }

    _bootstrapEngineState();
    if (mounted) setState(() {});
  }

  void _onEngineSetting(Map<String, dynamic> messageData) {
    final String? key = messageData['key'] as String?;
    if (key == null) return;
    final value = messageData['value'];
    final settings =
        ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
            <String, dynamic>{};
    settings[key] = value;
    _modeState['settings'] = settings;

    if (key == 'manual-mode') {
      manualMode = value.toString() == 'true';
    }
    if (key == 'show-tracker') {
      if (widget.useGlobalTracking) {
        return;
      }
      setState(() => showTracker = value.toString() == 'true');
      _postTrackerConfig();
    }
    if (key == 'dz-x') {
      deadZoneX = double.tryParse(value.toString()) ?? deadZoneX;
    }
    if (key == 'dz-y') {
      deadZoneY = double.tryParse(value.toString()) ?? deadZoneY;
    }
    if (key == 'dz-z') {
      deadZoneZ = double.tryParse(value.toString()) ?? deadZoneZ;
    }
    if (key == 'dz-yaw') {
      deadZoneYaw = double.tryParse(value.toString()) ?? deadZoneYaw;
    }
    if (key == 'dz-pitch') {
      deadZonePitch = double.tryParse(value.toString()) ?? deadZonePitch;
    }
    _queueSaveModeState();
  }

  Map<String, dynamic> _buildLivePayloadFromScene(Map<String, dynamic> scene) {
    final settings =
        ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
            ((_modeState['presetControls'] as Map?)?.cast<String, dynamic>()) ??
            <String, dynamic>{};
    return PresetPayloadV2(
      mode: '3d',
      scene: Map<String, dynamic>.from(scene),
      controls: Map<String, dynamic>.from(settings),
      meta: const <String, dynamic>{
        'editor': 'engine3d',
      },
    ).toMap();
  }

  void _onEngineSnapshot(Map<String, dynamic> messageData) {
    final dynamic state = messageData['sceneDelta'] ?? messageData['state'];
    final dynamic settingsDelta = messageData['settingsDelta'];
    if (settingsDelta is Map || settingsDelta is Map<String, dynamic>) {
      final Map<String, dynamic> patch = settingsDelta is Map<String, dynamic>
          ? Map<String, dynamic>.from(settingsDelta)
          : Map<String, dynamic>.from(settingsDelta as Map);
      final settings =
          ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
              <String, dynamic>{};
      settings.addAll(patch);
      _modeState['settings'] = settings;
      manualMode = settings['manual-mode']?.toString() == 'true';
    }
    if (state is Map<String, dynamic>) {
      _modeState['sceneState'] = state;
      widget.onLivePayloadChanged?.call(_buildLivePayloadFromScene(state));
      _queueSaveModeState();
      return;
    }
    if (state is Map) {
      final mapped = Map<String, dynamic>.from(state);
      _modeState['sceneState'] = mapped;
      widget.onLivePayloadChanged?.call(_buildLivePayloadFromScene(mapped));
      _queueSaveModeState();
    }
  }

  void _onDeadzoneUpdate(Map<String, dynamic> messageData) {
    deadZoneX = _toDouble(messageData['deadZoneX'], deadZoneX);
    deadZoneY = _toDouble(messageData['deadZoneY'], deadZoneY);
    deadZoneZ = _toDouble(messageData['deadZoneZ'], deadZoneZ);
    deadZoneYaw = _toDouble(messageData['deadZoneYaw'], deadZoneYaw);
    deadZonePitch = _toDouble(messageData['deadZonePitch'], deadZonePitch);
    _queueSaveModeState();
  }

  Future<void> _onSavePresetFromEngine(Map<String, dynamic> messageData) async {
    if (widget.cleanView) return;
    final String name = (messageData['name'] ?? '').toString().trim();
    if (name.isEmpty) return;
    final dynamic stateData = messageData['state'];
    if (stateData is! Map) return;
    final Map<String, dynamic> state = stateData is Map<String, dynamic>
        ? stateData
        : Map<String, dynamic>.from(stateData);

    final payload = PresetPayloadV2(
      mode: '3d',
      scene: state,
      controls: ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
          <String, dynamic>{},
      meta: <String, dynamic>{
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'editor': 'engine3d',
      },
    ).toMap();

    if (widget.persistPresets) {
      await _repository.savePreset(mode: '3d', name: name, payload: payload);
    }
    presets[name] = state;
    currentPresetName = name;
    widget.onPresetSaved?.call(name, payload);
    _postToEngine(<String, dynamic>{
      'type': 'apply_settings_patch',
      'patch': _modeState['settings'] ?? <String, dynamic>{},
    });
  }

  void _onLoadPresetRequestFromEngine(Map<String, dynamic> messageData) {
    final String name = (messageData['name'] ?? '').toString();
    if (name.isEmpty) return;
    final preset = presets[name];
    if (preset == null) return;
    _postToEngine(<String, dynamic>{
      'type': 'apply_scene_patch',
      'patch': preset,
    });
  }

  void _applyTrackerDeadZone(Map<String, dynamic> headData) {
    final double rawHeadX = _toDouble(headData['x'], 0.0);
    final double rawHeadY = _toDouble(headData['y'], 0.0);
    final double rawZ = _toDouble(headData['z'], 0.2);
    final double rawYaw = _toDouble(headData['yaw'], 0.0);
    final double rawPitch = _toDouble(headData['pitch'], 0.0);

    final double deltaX = rawHeadX - headX;
    if (deltaX.abs() > deadZoneX) {
      headX += (deltaX.abs() - deadZoneX) * deltaX.sign;
    }
    final double deltaY = rawHeadY - headY;
    if (deltaY.abs() > deadZoneY) {
      headY += (deltaY.abs() - deadZoneY) * deltaY.sign;
    }
    final double deltaZ = rawZ - zValue;
    if (deltaZ.abs() > deadZoneZ) {
      zValue += (deltaZ.abs() - deadZoneZ) * deltaZ.sign;
    }
    final double deltaYaw = rawYaw - yaw;
    if (deltaYaw.abs() > deadZoneYaw) {
      yaw += (deltaYaw.abs() - deadZoneYaw) * deltaYaw.sign;
    }
    final double deltaPitch = rawPitch - pitch;
    if (deltaPitch.abs() > deadZonePitch) {
      pitch += (deltaPitch.abs() - deadZonePitch) * deltaPitch.sign;
    }
    if (mounted) setState(() {});
  }

  void _applyExternalHeadPose(Map<String, double> pose) {
    _applyTrackerDeadZone(<String, dynamic>{
      'x': pose['x'] ?? 0.0,
      'y': pose['y'] ?? 0.0,
      'z': pose['z'] ?? 0.2,
      'yaw': pose['yaw'] ?? 0.0,
      'pitch': pose['pitch'] ?? 0.0,
    });
    _postToEngine(<String, dynamic>{
      'type': 'tracking_patch',
      'head': <String, dynamic>{
        'x': headX,
        'y': headY,
        'z': zValue,
        'yaw': yaw,
        'pitch': pitch,
      },
    });
  }

  void _queueSaveModeState() {
    if (widget.cleanView) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      _repository.upsertModeState(mode: '3d', state: _modeState);
    });
  }

  void _bootstrapEngineState() {
    if (!_iframeReady) return;
    final Map<String, dynamic> settings =
        ((_modeState['settings'] as Map?)?.cast<String, dynamic>()) ??
            <String, dynamic>{};
    if (widget.useGlobalTracking) {
      settings.remove('show-tracker');
    }
    final adaptedInitial = _adaptPresetPayload(widget.initialPresetPayload);
    if (adaptedInitial != null && adaptedInitial.controls.isNotEmpty) {
      settings.addAll(adaptedInitial.controls);
    }
    Map<String, dynamic>? sceneState;
    final dynamic rawScene = adaptedInitial?.scene ?? _modeState['sceneState'];
    if (rawScene is Map<String, dynamic>) sceneState = rawScene;
    if (rawScene is Map) sceneState = Map<String, dynamic>.from(rawScene);

    _postToEngine(<String, dynamic>{
      'type': 'bootstrap_state',
      'settings': settings,
      'presets': presets,
      'scene': sceneState ?? <String, dynamic>{},
    });
    if (sceneState != null) {
      widget.onLivePayloadChanged?.call(_buildLivePayloadFromScene(sceneState));
    }
    _postToEngine(<String, dynamic>{
      'type': 'global_tracking_config',
      'useGlobal': widget.useGlobalTracking,
    });
    _postTrackerConfig();
  }

  void _postToEngine(Map<String, dynamic> message) {
    final element = _engineIframe;
    if (element == null) return;
    final envelope = <String, dynamic>{
      ...message,
      'channel': _bridgeChannel,
    };
    element.contentWindow?.postMessage(jsonEncode(envelope).toJS, '*'.toJS);
  }

  void _postToTracker(Map<String, dynamic> message) {
    final element = _trackerIframe;
    if (element == null) return;
    final envelope = <String, dynamic>{
      ...message,
      'channel': _bridgeChannel,
    };
    element.contentWindow?.postMessage(jsonEncode(envelope).toJS, '*'.toJS);
  }

  void _postTrackerConfig() {
    if (widget.externalHeadPose != null || widget.useGlobalTracking) return;
    _postToTracker(<String, dynamic>{
      'type': 'tracker_config',
      'enabled': true,
      'uiVisible': showTracker,
      'showCursor': showTracker,
      'headless': !showTracker,
    });
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _isFromEngine(web.MessageEvent event) {
    final iframe = _engineIframe;
    if (iframe == null) return false;
    final source = event.source;
    if (source == null) return false;
    return identical(source, iframe.contentWindow) ||
        source == iframe.contentWindow;
  }

  bool _isFromTracker(web.MessageEvent event) {
    final iframe = _trackerIframe;
    if (iframe == null) return false;
    final source = event.source;
    if (source == null) return false;
    return identical(source, iframe.contentWindow) ||
        source == iframe.contentWindow;
  }

  Map<String, dynamic>? _extractPayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is JSString) return _decodePayload(data.toDart);
    if (data is String) return _decodePayload(data);
    return null;
  }

  Map<String, dynamic>? _decodePayload(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: IgnorePointer(
            ignoring: widget.pointerPassthrough,
            child: HtmlElementView(viewType: viewID),
          ),
        ),
        if (!widget.cleanView &&
            widget.externalHeadPose == null &&
            !widget.useGlobalTracking)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !showTracker,
              child: ClipRect(
                child: Opacity(
                  opacity: showTracker ? 1 : 0,
                  child: HtmlElementView(viewType: trackerViewID),
                ),
              ),
            ),
          ),
        if (!widget.cleanView && !widget.embedded)
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/2d');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent),
                  child: const Text(
                    '2D mode',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/feed');
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text(
                    'Feed',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return stack;
    }
    return Scaffold(body: stack);
  }
}
