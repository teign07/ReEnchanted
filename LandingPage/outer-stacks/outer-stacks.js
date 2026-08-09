import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { clone as cloneSkeleton } from "three/addons/utils/SkeletonUtils.js";

const canvas = document.querySelector("#clearing");
const threshold = document.querySelector("#threshold");
const enterButton = document.querySelector("#enter-clearing");
const thresholdNote = document.querySelector("#threshold-note");
const sleeping = document.querySelector("#server-sleeping");
const retryButton = document.querySelector("#retry-connection");
const presence = document.querySelector(".presence");
const presenceCount = document.querySelector("#presence-count");
const memoryLine = document.querySelector("#memory-line");
const heldWord = document.querySelector("#held-word");
const heldWordText = document.querySelector("#held-word-text");
const heldWordTemperament = document.querySelector("#held-word-temperament");
const gatherButton = document.querySelector("#gather-action");
const gatherFill = document.querySelector("#gather-fill");
const gatherTitle = document.querySelector("#gather-title");
const gatherHint = document.querySelector("#gather-hint");
const offerButton = document.querySelector("#offer-action");
const statusWhisper = document.querySelector("#status-whisper");
const touchStick = document.querySelector("#touch-stick");
const touchKnob = document.querySelector("#touch-knob");
const identitySlot = new URLSearchParams(location.search).get("wing") || "default";
const identityStorageKey = `reenchanted.outerStacks.paperwing.${identitySlot}`;

const SERVER_WORLD = Object.freeze({ width: 2200, height: 1400 });
const BASIN = Object.freeze({ x: 1110, y: 690, radius: 126 });
const WORLD_SCALE = 0.01;
const PAPERWING_SCALE = 0.72;
const GATHER_TIME = Object.freeze({
  heavy: 1.65, springy: 0.86, restless: 1.2, settling: 1.05, sharp: 0.72,
  shy: 1.35, rooted: 1.42, bright: 0.72, soft: 1.05, warm: 1.18,
});
const WORD_BEHAVIOR = Object.freeze({
  heavy: "It will not be hurried.",
  springy: "It keeps trying to begin again.",
  restless: "It dislikes staying where it was found.",
  settling: "It is looking for somewhere to belong.",
  sharp: "Mind the edges.",
  shy: "Do not grab. Let it finish hiding.",
  rooted: "It has put down a small grammatical root.",
  bright: "It notices you noticing it.",
  soft: "Come closer without making a point of it.",
  warm: "It is heavier when carried alone.",
});
const HIDE_PATCHES = Object.freeze([
  { x: 440, y: 430, radius: 150 },
  { x: 1740, y: 880, radius: 170 },
  { x: 610, y: 1120, radius: 145 },
]);
const POSE_CLIPS = Object.freeze({
  idle: "Idle", walk: "Walk", run: "Run", skid: "Skid", crouch: "Crouch",
  sleep: "Sleep", offer: "Offer", bow: "Bow", beckon: "Beckon", call: "Call",
  sit: "Crouch", curl: "Sleep", refuse: "Refuse", hide: "Hide",
});

const state = {
  credentials: null,
  connected: false,
  entered: false,
  assetsReady: false,
  snapshot: { players: [], words: [], world: {} },
  local: { x: 570, y: 780, vx: 0, vy: 0, facing: 1, pose: "idle", carriedWord: null, glyph: "" },
  keys: new Set(),
  gatherHeld: false,
  gatherProgress: 0,
  gatheringWordID: null,
  moveSendElapsed: 0,
  heartbeatElapsed: 0,
  stream: null,
  target: null,
  touch: { active: false, id: null, originX: 0, originY: 0, dx: 0, dy: 0 },
  statusTimer: 0,
  audio: null,
  reducedMotion: matchMedia("(prefers-reduced-motion: reduce)").matches,
  avatars: new Map(),
  words: new Map(),
  wordTextures: new Map(),
  particles: [],
  ripples: [],
  lastWorldRevision: -1,
};

let renderer;
let scene;
let camera;
let clock;
let paperwingSource;
let paperwingClips = [];
let worldRoot;
let wordRoot;
let effectRoot;
let basinWater;
let memoryRoots;
let academyGate;
let fireflies;
let fireflyPositions;
const cameraTarget = new THREE.Vector3();
const desiredCamera = new THREE.Vector3();
const desiredLook = new THREE.Vector3();
const tempVector = new THREE.Vector3();
const tempColor = new THREE.Color();

function serverToWorld(x, y, target = new THREE.Vector3()) {
  return target.set(
    (x - SERVER_WORLD.width / 2) * WORLD_SCALE,
    0,
    (y - SERVER_WORLD.height / 2) * WORLD_SCALE,
  );
}

function storedCredentials() {
  try { return JSON.parse(sessionStorage.getItem(identityStorageKey) || "null"); }
  catch { return null; }
}

function storeCredentials(credentials) {
  sessionStorage.setItem(identityStorageKey, JSON.stringify(credentials));
}

async function post(path, body, authenticated = false) {
  const headers = { "Content-Type": "application/json" };
  if (authenticated && state.credentials) {
    headers.Authorization = `Bearer ${state.credentials.token}`;
    headers["X-Player-ID"] = state.credentials.playerId;
  }
  const response = await fetch(path, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw Object.assign(new Error(result.reason || "The Stacks refused."), { status: response.status, result });
  return result;
}

function initThree() {
  if (renderer) return;
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: "high-performance" });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.02;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.setPixelRatio(Math.min(matchMedia("(pointer: coarse)").matches ? 1.25 : 1.5, devicePixelRatio || 1));

  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x080c0b);
  scene.fog = new THREE.FogExp2(0x111a16, 0.035);
  camera = new THREE.PerspectiveCamera(48, innerWidth / innerHeight, 0.1, 100);
  clock = new THREE.Clock();
  worldRoot = new THREE.Group();
  wordRoot = new THREE.Group();
  effectRoot = new THREE.Group();
  scene.add(worldRoot, wordRoot, effectRoot);

  const hemisphere = new THREE.HemisphereLight(0xaac0ab, 0x241810, 1.4);
  const moon = new THREE.DirectionalLight(0xf3dca5, 2.2);
  moon.position.set(-8, 14, 7);
  moon.castShadow = true;
  moon.shadow.mapSize.set(1536, 1536);
  moon.shadow.camera.left = -18;
  moon.shadow.camera.right = 18;
  moon.shadow.camera.top = 14;
  moon.shadow.camera.bottom = -14;
  moon.shadow.bias = -0.0006;
  const mossLight = new THREE.PointLight(0x789878, 16, 25, 2);
  mossLight.position.set(0, 4.5, 0);
  scene.add(hemisphere, moon, mossLight);

  buildClearing();
  resize();
  renderer.setAnimationLoop(frame);
}

function material(color, roughness = 0.8, metalness = 0) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness });
}

function buildClearing() {
  const groundMaterial = new THREE.MeshStandardMaterial({ color: 0x263126, roughness: 0.96 });
  const ground = new THREE.Mesh(new THREE.CircleGeometry(18, 96), groundMaterial);
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  worldRoot.add(ground);

  const under = new THREE.Mesh(new THREE.CylinderGeometry(17.9, 18.5, 0.6, 64), material(0x131914, 1));
  under.position.y = -0.32;
  worldRoot.add(under);

  buildShelfTrees();
  buildBasin();
  buildBramble();
  buildAcademyGate();
  buildLoosePages();
  buildFireflies();
}

function buildShelfTrees() {
  const wood = material(0x2e1c12, 0.88);
  const brass = material(0x8f6a32, 0.4, 0.65);
  const bookMaterials = [0x3c1718, 0x172c24, 0x20203b, 0x5b4022].map((color) => material(color, 0.72));
  const placements = [
    [-10.2, -5.1, 1.12], [-8.4, 5.4, 0.92], [-3.1, -7.1, 0.86], [3.4, -7.2, 1.0],
    [8.8, -5.2, 1.2], [10.0, 1.8, 0.98], [8.1, 6.0, 1.08], [-9.8, 1.5, 1.04],
  ];
  for (const [x, z, scale] of placements) {
    const tree = new THREE.Group();
    tree.position.set(x, 0, z);
    tree.scale.setScalar(scale);
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.62, 6.4, 9), wood);
    trunk.position.y = 3.0;
    trunk.rotation.z = (x + z) * 0.008;
    trunk.castShadow = true;
    tree.add(trunk);
    for (let shelf = 0; shelf < 6; shelf += 1) {
      const angle = shelf * 1.73 + x * 0.1;
      const group = new THREE.Group();
      group.position.set(Math.sin(angle) * 0.15, 0.8 + shelf * 0.9, Math.cos(angle) * 0.15);
      group.rotation.y = angle;
      const board = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.14, 0.68), wood);
      board.castShadow = true;
      group.add(board);
      for (let book = -4; book <= 4; book += 1) {
        const height = 0.38 + ((book + shelf * 2 + 12) % 4) * 0.08;
        const volume = new THREE.Mesh(new THREE.BoxGeometry(0.18, height, 0.42), bookMaterials[(book + shelf + 12) % bookMaterials.length]);
        volume.position.set(book * 0.22, height / 2 + 0.08, -0.01);
        volume.rotation.z = Math.sin(book * 2.1 + shelf) * 0.08;
        volume.castShadow = true;
        group.add(volume);
      }
      tree.add(group);
    }
    const clasp = new THREE.Mesh(new THREE.TorusGeometry(0.66, 0.055, 8, 24), brass);
    clasp.rotation.x = Math.PI / 2;
    clasp.position.y = 2.9;
    tree.add(clasp);
    worldRoot.add(tree);
  }
}

function buildBasin() {
  const group = new THREE.Group();
  group.position.copy(serverToWorld(BASIN.x, BASIN.y));
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.45, 0.16, 10, 64), material(0x604b2b, 0.48, 0.25));
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.12;
  ring.castShadow = true;
  const waterMaterial = new THREE.MeshPhysicalMaterial({
    color: 0x152b29,
    roughness: 0.18,
    metalness: 0.15,
    transmission: 0.12,
    transparent: true,
    opacity: 0.9,
  });
  basinWater = new THREE.Mesh(new THREE.CircleGeometry(1.38, 64), waterMaterial);
  basinWater.rotation.x = -Math.PI / 2;
  basinWater.position.y = 0.08;
  const basinLight = new THREE.PointLight(0x9bc49e, 10, 8, 2);
  basinLight.position.y = 0.6;
  group.add(ring, basinWater, basinLight);
  memoryRoots = new THREE.Group();
  group.add(memoryRoots);
  worldRoot.add(group);
}

function buildBramble() {
  const leafMaterial = material(0x29402d, 0.94);
  const thornMaterial = material(0x503021, 0.84);
  for (const patch of HIDE_PATCHES) {
    const center = serverToWorld(patch.x, patch.y);
    const group = new THREE.Group();
    group.position.copy(center);
    for (let index = 0; index < 19; index += 1) {
      const angle = (index / 19) * Math.PI * 2;
      const radius = 0.45 + (index % 4) * 0.17;
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.04, 0.85, 6), thornMaterial);
      stem.position.set(Math.cos(angle) * radius, 0.35, Math.sin(angle) * radius * 0.66);
      stem.rotation.z = Math.sin(angle) * 0.45;
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.23 + (index % 3) * 0.04, 7, 5), leafMaterial);
      leaf.scale.set(1.6, 0.38, 0.72);
      leaf.position.set(Math.cos(angle) * radius * 1.3, 0.42 + (index % 4) * 0.08, Math.sin(angle) * radius * 0.82);
      group.add(stem, leaf);
    }
    worldRoot.add(group);
  }
}

function buildAcademyGate() {
  academyGate = new THREE.Group();
  academyGate.position.set(7.8, 0, -5.4);
  const stone = material(0x302b26, 0.9);
  const gold = material(0x9a7132, 0.35, 0.7);
  for (const x of [-1.5, 1.5]) {
    const pillar = new THREE.Mesh(new THREE.BoxGeometry(0.55, 4.8, 0.75), stone);
    pillar.position.set(x, 2.4, 0);
    pillar.castShadow = true;
    academyGate.add(pillar);
  }
  const arch = new THREE.Mesh(new THREE.TorusGeometry(1.5, 0.29, 10, 42, Math.PI), stone);
  arch.position.y = 3.75;
  arch.rotation.z = Math.PI;
  academyGate.add(arch);
  for (let x = -1.2; x <= 1.2; x += 0.4) {
    const bar = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 3.8, 6), gold);
    bar.position.set(x, 1.9, 0.05);
    academyGate.add(bar);
  }
  const glow = new THREE.PointLight(0xe0b66e, 18, 9, 2);
  glow.position.set(0, 2.2, -1.0);
  academyGate.add(glow);
  worldRoot.add(academyGate);
}

function buildLoosePages() {
  const page = new THREE.PlaneGeometry(0.36, 0.48);
  const pageMaterial = new THREE.MeshStandardMaterial({ color: 0xaa9163, roughness: 0.92, side: THREE.DoubleSide });
  for (let index = 0; index < 45; index += 1) {
    const mesh = new THREE.Mesh(page, pageMaterial);
    const angle = index * 2.399;
    const radius = 2.8 + (index % 9) * 1.25;
    mesh.position.set(Math.cos(angle) * radius, 0.025, Math.sin(angle) * radius * 0.7);
    mesh.rotation.set(-Math.PI / 2 + Math.sin(index) * 0.08, 0, angle + index * 0.2);
    mesh.receiveShadow = true;
    worldRoot.add(mesh);
  }
}

function buildFireflies() {
  const count = matchMedia("(pointer: coarse)").matches ? 80 : 150;
  fireflyPositions = new Float32Array(count * 3);
  for (let index = 0; index < count; index += 1) {
    const angle = index * 2.399;
    const radius = 3 + (index % 24) * 0.55;
    fireflyPositions[index * 3] = Math.cos(angle) * radius;
    fireflyPositions[index * 3 + 1] = 0.8 + (index % 11) * 0.28;
    fireflyPositions[index * 3 + 2] = Math.sin(angle) * radius * 0.72;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.BufferAttribute(fireflyPositions, 3));
  fireflies = new THREE.Points(geometry, new THREE.PointsMaterial({ color: 0xe4c478, size: 0.055, transparent: true, opacity: 0.62, depthWrite: false }));
  scene.add(fireflies);
}

async function loadAssets() {
  initThree();
  if (state.assetsReady) return;
  const gltf = await new GLTFLoader().loadAsync("./assets/paperwing.glb");
  paperwingSource = gltf.scene;
  paperwingClips = gltf.animations;
  paperwingSource.traverse((object) => {
    if (!object.isMesh) return;
    object.castShadow = true;
    object.receiveShadow = true;
    if (object.material?.name === "Manuscript_Wing") {
      object.material.side = THREE.DoubleSide;
      object.material.transparent = true;
      object.material.depthWrite = false;
    }
  });
  state.assetsReady = true;
}

class PaperwingAvatar {
  constructor(player, local = false) {
    this.id = player.id;
    this.local = local;
    this.root = new THREE.Group();
    this.model = cloneSkeleton(paperwingSource);
    this.model.scale.setScalar(PAPERWING_SCALE);
    this.model.rotation.y = Math.PI;
    this.root.add(this.model);
    this.mixer = new THREE.AnimationMixer(this.model);
    this.actions = new Map();
    for (const clip of paperwingClips) {
      const action = this.mixer.clipAction(clip);
      if (["Idle", "Walk", "Run", "Sleep"].includes(clip.name)) action.setLoop(THREE.LoopRepeat, Infinity);
      else action.setLoop(THREE.LoopOnce, 1).clampWhenFinished = true;
      this.actions.set(clip.name, action);
    }
    this.currentAction = null;
    this.currentClip = "";
    this.glyph = makeTextSprite(player.glyph || "◌", { size: 64, color: local ? "#ffe8ae" : "#d8c79d", glow: true });
    this.glyph.position.set(0, 2.45, 0);
    this.glyph.scale.set(0.75, 0.38, 1);
    this.root.add(this.glyph);
    this.wordSprite = null;
    this.target = serverToWorld(player.x, player.y);
    this.root.position.copy(this.target);
    this.setClip("Idle", 0);
    scene.add(this.root);
  }

  setClip(name, fade = 0.18) {
    if (!name || this.currentClip === name) return;
    const next = this.actions.get(name) || this.actions.get("Idle");
    if (!next) return;
    next.reset().fadeIn(fade).play();
    if (this.currentAction && this.currentAction !== next) this.currentAction.fadeOut(fade);
    this.currentAction = next;
    this.currentClip = name;
  }

  update(player, delta, elapsed) {
    this.target.copy(serverToWorld(player.x, player.y, tempVector));
    if (this.local) this.root.position.copy(this.target);
    else this.root.position.lerp(this.target, 1 - Math.exp(-10 * delta));
    const horizontalSpeed = Math.hypot(player.vx || 0, player.vy || 0);
    if (horizontalSpeed > 20) {
      const desired = Math.atan2(player.vx, player.vy);
      this.root.rotation.y = dampAngle(this.root.rotation.y, desired, 12, delta);
    }
    const gesture = player.gesture && player.gestureUntil > Date.now() ? player.gesture : null;
    const clip = POSE_CLIPS[gesture] || POSE_CLIPS[player.pose] || "Idle";
    this.setClip(clip, clip === "Run" || clip === "Walk" ? 0.12 : 0.2);
    this.mixer.update(delta);
    if (this.currentAction) {
      if (clip === "Run") this.currentAction.timeScale = 1.05 + horizontalSpeed / 1000;
      else if (clip === "Walk") this.currentAction.timeScale = 0.85 + horizontalSpeed / 900;
      else this.currentAction.timeScale = 1;
    }
    this.glyph.material.opacity = 0.72 + Math.sin(elapsed * 1.4 + stableTinyHash(player.id)) * 0.15;
    this.updateWord(player.carriedWord, elapsed);
  }

  updateWord(word, elapsed) {
    if (!word) {
      if (this.wordSprite) this.wordSprite.visible = false;
      return;
    }
    const key = `${word.text}:${word.temperament}`;
    if (!this.wordSprite || this.wordSprite.userData.key !== key) {
      this.wordSprite?.removeFromParent();
      this.wordSprite = makeTextSprite(word.text, { size: word.text.length > 7 ? 40 : 52, color: "#f5d994", glow: true });
      this.wordSprite.userData.key = key;
      this.wordSprite.scale.set(word.text.length > 7 ? 1.2 : 0.92, 0.38, 1);
      this.root.add(this.wordSprite);
    }
    this.wordSprite.visible = true;
    this.wordSprite.position.set(0.72, 1.34 + Math.sin(elapsed * 2.6) * 0.08, 0.18);
  }

  destroy() {
    this.mixer.stopAllAction();
    this.root.removeFromParent();
  }
}

function dampAngle(current, target, speed, delta) {
  let difference = (target - current + Math.PI) % (Math.PI * 2) - Math.PI;
  if (difference < -Math.PI) difference += Math.PI * 2;
  return current + difference * (1 - Math.exp(-speed * delta));
}

function stableTinyHash(value = "") {
  let result = 0;
  for (const character of value) result = (result * 31 + character.charCodeAt(0)) % 1000;
  return result / 113;
}

function makeTextTexture(text, { size = 54, color = "#f1d89c", glow = false } = {}) {
  const cacheKey = `${text}:${size}:${color}:${glow}`;
  if (state.wordTextures.has(cacheKey)) return state.wordTextures.get(cacheKey);
  const textureCanvas = document.createElement("canvas");
  textureCanvas.width = 512;
  textureCanvas.height = 192;
  const ctx = textureCanvas.getContext("2d");
  ctx.clearRect(0, 0, 512, 192);
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = `600 ${size}px Georgia`;
  if (glow) {
    ctx.shadowColor = "rgba(222, 174, 85, .9)";
    ctx.shadowBlur = 22;
  }
  ctx.fillStyle = color;
  ctx.fillText(text, 256, 96);
  const texture = new THREE.CanvasTexture(textureCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  state.wordTextures.set(cacheKey, texture);
  return texture;
}

function makeTextSprite(text, options = {}) {
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({
    map: makeTextTexture(text, options),
    transparent: true,
    depthWrite: false,
    opacity: 1,
  }));
  sprite.center.set(0.5, 0.5);
  return sprite;
}

function temperamentColor(temperament) {
  return {
    heavy: 0xb79b63, springy: 0xf0c36e, restless: 0xaec8a2, settling: 0xd0ae7f,
    sharp: 0xd7b5a8, shy: 0xa5a198, rooted: 0x87a276, bright: 0xffdc86,
    soft: 0xc5b7a1, warm: 0xe5b77f,
  }[temperament] || 0xd9bd80;
}

function createWordObject(word) {
  const group = new THREE.Group();
  group.userData.id = word.id;
  group.userData.phase = word.phase || 0;
  group.userData.temperament = word.temperament;
  const color = temperamentColor(word.temperament);
  const sprite = makeTextSprite(word.text, { size: word.text.length > 7 ? 38 : 52, color: `#${color.toString(16).padStart(6, "0")}`, glow: true });
  sprite.scale.set(word.text.length > 7 ? 1.8 : 1.35, 0.5, 1);
  sprite.position.y = 0.55;
  group.add(sprite);
  const moteGeometry = new THREE.BufferGeometry();
  const positions = new Float32Array(18 * 3);
  for (let index = 0; index < 18; index += 1) {
    positions[index * 3] = (Math.random() - 0.5) * 1.5;
    positions[index * 3 + 1] = Math.random() * 0.9;
    positions[index * 3 + 2] = (Math.random() - 0.5) * 0.5;
  }
  moteGeometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  const motes = new THREE.Points(moteGeometry, new THREE.PointsMaterial({ color, size: 0.055, transparent: true, opacity: 0.66, depthWrite: false }));
  group.add(motes);
  const light = new THREE.PointLight(color, word.temperament === "bright" ? 5 : 2.5, 3.2, 2);
  light.position.y = 0.4;
  group.add(light);
  group.position.copy(serverToWorld(word.x, word.y));
  wordRoot.add(group);
  return group;
}

function updateWordObjects(elapsed) {
  const live = new Set();
  for (const word of state.snapshot.words || []) {
    live.add(word.id);
    let object = state.words.get(word.id);
    if (!object) {
      object = createWordObject(word);
      state.words.set(word.id, object);
    }
    const base = serverToWorld(word.x, word.y, tempVector);
    const phase = elapsed + object.userData.phase;
    let x = base.x;
    let y = 0.16;
    let z = base.z;
    if (word.temperament === "heavy") y += Math.abs(Math.sin(phase * 1.2)) * 0.04;
    else if (word.temperament === "springy") y += Math.abs(Math.sin(phase * 3.6)) * 0.42;
    else if (word.temperament === "restless") { x += Math.cos(phase * 2) * 0.22; z += Math.sin(phase * 2.4) * 0.15; }
    else if (word.temperament === "shy") { x += Math.sin(phase * 0.9) * 0.18; y -= Math.max(0, Math.cos(phase)) * 0.08; }
    else y += Math.sin(phase * 1.6) * 0.08;
    object.position.set(x, y, z);
    object.rotation.y = Math.sin(phase * 0.8) * 0.14;
    const gathering = state.gatheringWordID === word.id && state.gatherHeld;
    object.scale.setScalar(gathering ? 1 + state.gatherProgress * 0.18 : 1);
  }
  for (const [id, object] of state.words.entries()) {
    if (live.has(id)) continue;
    object.removeFromParent();
    state.words.delete(id);
  }
}

function updateMemoryWorld() {
  const world = state.snapshot.world || {};
  if (world.revision === state.lastWorldRevision) return;
  state.lastWorldRevision = world.revision;
  memoryRoots.clear();
  const count = Math.min(12, world.offerings || 0);
  for (let index = 0; index < count; index += 1) {
    const angle = (index / Math.max(1, count)) * Math.PI * 2;
    const root = new THREE.Mesh(
      new THREE.TorusGeometry(1.7 + index * 0.025, 0.025 + (index % 3) * 0.008, 5, 44, Math.PI * 0.42),
      material(index % 3 === 0 ? 0xa8864f : 0x4d5f3e, 0.8),
    );
    root.rotation.set(Math.PI / 2, angle, angle);
    root.position.y = 0.06 + index * 0.003;
    memoryRoots.add(root);
  }
  if (world.offerings >= 3) {
    const door = new THREE.Mesh(new THREE.BoxGeometry(0.7, 1.05, 0.12), material(0x2e2117, 0.74));
    door.position.set(0, 0.58, -1.5);
    door.rotation.x = -0.1;
    memoryRoots.add(door);
  }
}

function syncAvatars(delta, elapsed) {
  const live = new Set();
  for (const remote of state.snapshot.players || []) {
    const local = remote.id === state.credentials?.playerId;
    const player = local ? { ...remote, ...state.local, glyph: remote.glyph || state.local.glyph } : remote;
    live.add(player.id);
    let avatar = state.avatars.get(player.id);
    if (!avatar) {
      avatar = new PaperwingAvatar(player, local);
      state.avatars.set(player.id, avatar);
    }
    avatar.update(player, delta, elapsed);
  }
  for (const [id, avatar] of state.avatars.entries()) {
    if (live.has(id)) continue;
    avatar.destroy();
    state.avatars.delete(id);
  }
}

async function joinClearing() {
  thresholdNote.textContent = "The page is checking whether the shared shelf is awake…";
  enterButton.disabled = true;
  try {
    await loadAssets();
    const previous = storedCredentials();
    const joined = await post("./api/join", previous || {});
    state.credentials = { playerId: joined.playerId, token: joined.token };
    storeCredentials(state.credentials);
    state.local.glyph = joined.glyph;
    acceptSnapshot(joined.snapshot, true);
    openStream();
    threshold.hidden = true;
    sleeping.hidden = true;
    state.entered = true;
    initAudio();
    sound("arrival");
    whisper(`The Labyrinth has marked you ${joined.glyph}.`);
  } catch (error) {
    console.error("The shared clearing did not answer.", error);
    threshold.hidden = true;
    sleeping.hidden = false;
  } finally {
    enterButton.disabled = false;
    thresholdNote.textContent = "No private Pages enter this clearing.";
  }
}

function openStream() {
  state.stream?.abort();
  const stream = new AbortController();
  state.stream = stream;
  void consumeClearingStream(stream);
}

async function consumeClearingStream(controller) {
  try {
    const response = await fetch("./api/stream", {
      headers: {
        Accept: "text/event-stream",
        Authorization: `Bearer ${state.credentials.token}`,
        "X-Player-ID": state.credentials.playerId,
      },
      cache: "no-store",
      signal: controller.signal,
    });
    if (!response.ok || !response.body) throw new Error("stream-refused");
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let pending = "";
    while (!controller.signal.aborted) {
      const { value, done } = await reader.read();
      if (done) break;
      pending += decoder.decode(value, { stream: true });
      let boundary;
      while ((boundary = pending.indexOf("\n\n")) >= 0) {
        const event = pending.slice(0, boundary);
        pending = pending.slice(boundary + 2);
        const data = event.split("\n").find((line) => line.startsWith("data: "))?.slice(6);
        if (!data) continue;
        acceptSnapshot(JSON.parse(data));
        state.connected = true;
        presence.dataset.awake = "true";
      }
    }
  } catch (error) {
    if (controller.signal.aborted) return;
    state.connected = false;
    presence.dataset.awake = "false";
  }
}

function acceptSnapshot(snapshot, initial = false) {
  if (!snapshot) return;
  state.snapshot = snapshot;
  const me = snapshot.players.find((player) => player.id === state.credentials?.playerId);
  if (me) {
    if (initial) Object.assign(state.local, { x: me.x, y: me.y, vx: me.vx, vy: me.vy });
    const oldWord = state.local.carriedWord?.text;
    state.local.carriedWord = me.carriedWord;
    if (!oldWord && me.carriedWord) {
      wordBurst(me.carriedWord, me.x, me.y, 26);
      sound("gather");
      navigator.vibrate?.([12, 25, 18]);
    }
  }
  const others = Math.max(0, snapshot.players.length - 1);
  presenceCount.textContent = others === 0
    ? "You are the only visible Paperwing."
    : others === 1 ? "One other Paperwing is near." : `${others} other Paperwings are near.`;
  memoryLine.textContent = snapshot.world?.memoryLine || "The clearing is thinking.";
  updateWordUI();
}

async function sendAction(action, quiet = false) {
  if (!state.credentials) return null;
  try {
    return await post("./api/action", { action }, true);
  } catch (error) {
    if (!quiet) whisper(error.result?.reason === "word-gone" ? "Another Paperwing reached it first." : "The clearing did not take that action.");
    if (error.status === 401) {
      sessionStorage.removeItem("reenchanted.outerStacks.paperwing");
      state.credentials = null;
    }
    return null;
  }
}

function initAudio() {
  if (state.audio) return;
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (AudioContext) state.audio = new AudioContext();
}

function tone(frequency, duration, gain = 0.035, delay = 0, type = "sine") {
  if (!state.audio) return;
  const oscillator = state.audio.createOscillator();
  const volume = state.audio.createGain();
  const starts = state.audio.currentTime + delay;
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, starts);
  volume.gain.setValueAtTime(0.0001, starts);
  volume.gain.exponentialRampToValueAtTime(gain, starts + 0.02);
  volume.gain.exponentialRampToValueAtTime(0.0001, starts + duration);
  oscillator.connect(volume).connect(state.audio.destination);
  oscillator.start(starts);
  oscillator.stop(starts + duration + 0.04);
}

function sound(kind) {
  if (!state.audio) return;
  if (state.audio.state === "suspended") state.audio.resume();
  if (kind === "gather") {
    tone(280, 0.18, 0.04, 0, "triangle"); tone(420, 0.24, 0.03, 0.08); tone(630, 0.3, 0.018, 0.16);
  } else if (kind === "offer") {
    tone(390, 0.24, 0.035, 0, "triangle"); tone(260, 0.42, 0.025, 0.08);
  } else if (kind === "call") {
    tone(510, 0.22, 0.032); tone(680, 0.32, 0.023, 0.16);
  } else if (kind === "arrival") {
    tone(180, 0.4, 0.025, 0, "triangle"); tone(270, 0.5, 0.02, 0.12);
  }
}

function whisper(message, duration = 2600) {
  clearTimeout(state.statusTimer);
  statusWhisper.textContent = message;
  statusWhisper.dataset.visible = "true";
  state.statusTimer = setTimeout(() => { statusWhisper.dataset.visible = "false"; }, duration);
}

function nearestWord() {
  if (state.local.carriedWord) return null;
  let nearest = null;
  let distance = Infinity;
  for (const word of state.snapshot.words || []) {
    const candidate = Math.hypot(word.x - state.local.x, word.y - state.local.y);
    if (candidate < distance) { nearest = word; distance = candidate; }
  }
  return distance <= 145 ? { word: nearest, distance } : null;
}

function updateWordUI() {
  const carried = state.local.carriedWord;
  heldWord.hidden = !carried;
  offerButton.disabled = !carried;
  if (carried) {
    heldWordText.textContent = carried.text;
    heldWordTemperament.textContent = carried.temperament;
  }
  const nearest = nearestWord();
  gatherButton.disabled = !nearest || Boolean(carried);
  if (carried) {
    gatherTitle.textContent = "Your wings are occupied";
    gatherHint.textContent = "Offer the word before gathering another.";
  } else if (nearest) {
    gatherTitle.textContent = `Gather ${nearest.word.text}`;
    gatherHint.textContent = WORD_BEHAVIOR[nearest.word.temperament] || "Hold still enough to hear it.";
  } else {
    gatherTitle.textContent = "No word near enough";
    gatherHint.textContent = "Move through the bramble and listen.";
  }
}

function setGatherHeld(active) {
  state.gatherHeld = active && !gatherButton.disabled;
  if (!state.gatherHeld) {
    state.gatherProgress = 0;
    state.gatheringWordID = null;
    gatherFill.style.height = "0%";
  }
}

function triggerGesture(gesture) {
  if (!state.entered) return;
  sendAction({ type: "gesture", gesture });
  document.querySelectorAll("[data-gesture]").forEach((button) => {
    button.dataset.active = button.dataset.gesture === gesture ? "true" : "false";
  });
  setTimeout(() => document.querySelectorAll("[data-gesture]").forEach((button) => { button.dataset.active = "false"; }), 1200);
  if (gesture === "call") {
    createRipple(state.local.x, state.local.y, 0xe5c376);
    sound("call");
  }
}

function offerCarriedWord() {
  if (!state.local.carriedWord) return;
  const distance = Math.hypot(state.local.x - BASIN.x, state.local.y - BASIN.y);
  const towardBasin = distance < BASIN.radius + 120;
  const targetX = towardBasin ? BASIN.x : state.local.x + state.local.facing * 92;
  const targetY = towardBasin ? BASIN.y : state.local.y + 38;
  const offered = state.local.carriedWord;
  state.local.pose = "offer";
  sound("offer");
  setTimeout(async () => {
    const result = await sendAction({ type: "drop", x: targetX, y: targetY });
    if (!result?.ok) return;
    wordBurst(offered, targetX, targetY, 24);
    createRipple(targetX, targetY, result.offered ? 0x9bc89f : 0xdfbd77);
    whisper(result.offered
      ? `The basin accepted ${offered.text}.`
      : `${offered.text} has been placed where another creature can choose it.`);
  }, state.reducedMotion ? 0 : 360);
}

function wordBurst(word, x, y, count = 18) {
  if (!effectRoot) return;
  const origin = serverToWorld(x, y);
  const color = temperamentColor(word?.temperament);
  const amount = state.reducedMotion ? Math.ceil(count / 3) : count;
  for (let index = 0; index < amount; index += 1) {
    const mesh = new THREE.Mesh(new THREE.TetrahedronGeometry(0.035 + Math.random() * 0.04), new THREE.MeshBasicMaterial({ color, transparent: true }));
    mesh.position.copy(origin).add(new THREE.Vector3((Math.random() - 0.5) * 0.3, 0.5 + Math.random() * 0.5, (Math.random() - 0.5) * 0.3));
    mesh.userData.velocity = new THREE.Vector3((Math.random() - 0.5) * 2.8, 1.4 + Math.random() * 2.2, (Math.random() - 0.5) * 2.8);
    mesh.userData.life = 0.7 + Math.random() * 0.7;
    mesh.userData.age = 0;
    effectRoot.add(mesh);
    state.particles.push(mesh);
  }
}

function createRipple(x, y, color) {
  if (!effectRoot) return;
  const mesh = new THREE.Mesh(
    new THREE.RingGeometry(0.12, 0.15, 48),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.7, side: THREE.DoubleSide, depthWrite: false }),
  );
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.copy(serverToWorld(x, y));
  mesh.position.y = 0.08;
  mesh.userData.age = 0;
  mesh.userData.life = 1.2;
  effectRoot.add(mesh);
  state.ripples.push(mesh);
}

function inputVector() {
  let x = 0;
  let y = 0;
  if (state.keys.has("KeyA") || state.keys.has("ArrowLeft")) x -= 1;
  if (state.keys.has("KeyD") || state.keys.has("ArrowRight")) x += 1;
  if (state.keys.has("KeyW") || state.keys.has("ArrowUp")) y -= 1;
  if (state.keys.has("KeyS") || state.keys.has("ArrowDown")) y += 1;
  if (state.touch.active) { x += state.touch.dx; y += state.touch.dy; }
  if (state.target) {
    const dx = state.target.x - state.local.x;
    const dy = state.target.y - state.local.y;
    const length = Math.hypot(dx, dy);
    if (length > 18) { x += dx / length; y += dy / length; } else state.target = null;
  }
  const length = Math.hypot(x, y);
  return length > 1 ? { x: x / length, y: y / length } : { x, y };
}

function currentGesture() {
  return state.snapshot.players.find((player) => player.id === state.credentials?.playerId)?.gesture || null;
}

function updateMovement(delta) {
  if (!state.entered) return;
  const input = inputVector();
  const moving = Math.hypot(input.x, input.y) > 0.05;
  const sprinting = state.keys.has("ShiftLeft") || state.keys.has("ShiftRight") || state.touch.active;
  const maximum = sprinting ? 430 : 300;
  const acceleration = moving ? 1120 : 0;
  const drag = moving ? 5.2 : 9.6;
  const previousFacing = state.local.facing;
  state.local.vx += input.x * acceleration * delta;
  state.local.vy += input.y * acceleration * delta;
  const speed = Math.hypot(state.local.vx, state.local.vy);
  if (speed > maximum) {
    state.local.vx = (state.local.vx / speed) * maximum;
    state.local.vy = (state.local.vy / speed) * maximum;
  }
  const damping = Math.exp(-drag * delta);
  state.local.vx *= damping;
  state.local.vy *= damping;
  state.local.x = THREE.MathUtils.clamp(state.local.x + state.local.vx * delta, 70, SERVER_WORLD.width - 70);
  state.local.y = THREE.MathUtils.clamp(state.local.y + state.local.vy * delta, 110, SERVER_WORLD.height - 80);
  if (Math.abs(input.x) > 0.1) state.local.facing = input.x < 0 ? -1 : 1;
  const gesture = currentGesture();
  const nowSpeed = Math.hypot(state.local.vx, state.local.vy);
  if (gesture === "curl") state.local.pose = "sleep";
  else if (gesture === "sit" || gesture === "hide") state.local.pose = "crouch";
  else if (gesture === "offer") state.local.pose = "offer";
  else if (previousFacing !== state.local.facing && nowSpeed > 170) state.local.pose = "skid";
  else if (nowSpeed > 305) state.local.pose = "run";
  else if (nowSpeed > 35) state.local.pose = "walk";
  else state.local.pose = "idle";
}

function updateGathering(delta) {
  const nearest = nearestWord();
  if (!state.gatherHeld || !nearest) {
    if (state.gatherHeld && !nearest) setGatherHeld(false);
    return;
  }
  if (state.gatheringWordID && state.gatheringWordID !== nearest.word.id) state.gatherProgress = 0;
  state.gatheringWordID = nearest.word.id;
  state.gatherProgress = Math.min(1, state.gatherProgress + delta / (GATHER_TIME[nearest.word.temperament] || 1.1));
  gatherFill.style.height = `${Math.round(state.gatherProgress * 100)}%`;
  const object = state.words.get(nearest.word.id);
  const avatar = state.avatars.get(state.credentials?.playerId);
  if (object && avatar && Math.random() < delta * (state.reducedMotion ? 4 : 15)) {
    const particle = new THREE.Mesh(new THREE.TetrahedronGeometry(0.03), new THREE.MeshBasicMaterial({ color: 0xf0d697, transparent: true }));
    particle.position.copy(object.position).add(new THREE.Vector3((Math.random() - 0.5) * 0.4, 0.4 + Math.random() * 0.4, (Math.random() - 0.5) * 0.3));
    particle.userData.target = avatar.root;
    particle.userData.life = 0.55;
    particle.userData.age = 0;
    effectRoot.add(particle);
    state.particles.push(particle);
  }
  if (state.gatherProgress >= 1) {
    setGatherHeld(false);
    sendAction({ type: "pickup", wordId: nearest.word.id });
  }
}

function updateEffects(delta) {
  for (const particle of state.particles) {
    particle.userData.age += delta;
    if (particle.userData.target) {
      const target = particle.userData.target.position.clone();
      target.y += 1.25;
      particle.position.lerp(target, 1 - Math.exp(-8 * delta));
    } else {
      particle.position.addScaledVector(particle.userData.velocity, delta);
      particle.userData.velocity.y -= 3.8 * delta;
    }
    particle.material.opacity = Math.max(0, 1 - particle.userData.age / particle.userData.life);
  }
  state.particles = state.particles.filter((particle) => {
    if (particle.userData.age < particle.userData.life) return true;
    particle.geometry.dispose();
    particle.material.dispose();
    particle.removeFromParent();
    return false;
  });
  for (const ring of state.ripples) {
    ring.userData.age += delta;
    const progress = ring.userData.age / ring.userData.life;
    ring.scale.setScalar(1 + progress * 10);
    ring.material.opacity = Math.max(0, 0.7 * (1 - progress));
  }
  state.ripples = state.ripples.filter((ring) => {
    if (ring.userData.age < ring.userData.life) return true;
    ring.geometry.dispose();
    ring.material.dispose();
    ring.removeFromParent();
    return false;
  });
}

function syncMovement(delta) {
  state.moveSendElapsed += delta;
  state.heartbeatElapsed += delta;
  if (state.moveSendElapsed >= 0.1) {
    state.moveSendElapsed = 0;
    sendAction({
      type: "move", x: Math.round(state.local.x * 10) / 10, y: Math.round(state.local.y * 10) / 10,
      vx: Math.round(state.local.vx), vy: Math.round(state.local.vy), facing: state.local.facing, pose: state.local.pose,
    }, true);
  }
  if (state.heartbeatElapsed >= 6) {
    state.heartbeatElapsed = 0;
    sendAction({ type: "heartbeat" }, true);
  }
}

function updateCamera(delta) {
  const player = serverToWorld(state.local.x, state.local.y, cameraTarget);
  desiredLook.copy(player).add(new THREE.Vector3(0, 0.95, 0));
  desiredCamera.copy(player).add(new THREE.Vector3(0, 7.4, 9.2));
  camera.position.lerp(desiredCamera, 1 - Math.exp(-3.8 * delta));
  camera.userData.look ||= desiredLook.clone();
  camera.userData.look.lerp(desiredLook, 1 - Math.exp(-5.2 * delta));
  camera.lookAt(camera.userData.look);
}

function updateAtmosphere(elapsed) {
  if (basinWater) {
    basinWater.rotation.z = elapsed * 0.025;
    basinWater.material.color.lerp(tempColor.set(state.snapshot.world?.offerings >= 3 ? 0x2e5144 : 0x152b29), 0.03);
  }
  if (fireflies) {
    fireflies.rotation.y = elapsed * 0.018;
    fireflies.material.opacity = 0.48 + Math.sin(elapsed * 0.7) * 0.16;
  }
  if (academyGate) academyGate.rotation.y = Math.sin(elapsed * 0.11) * 0.012;
}

function frame() {
  if (!renderer) return;
  const delta = Math.min(0.04, clock.getDelta());
  const elapsed = clock.elapsedTime;
  updateMovement(delta);
  updateGathering(delta);
  updateEffects(delta);
  updateCamera(delta);
  updateWordUI();
  updateWordObjects(elapsed);
  updateMemoryWorld();
  if (state.assetsReady) syncAvatars(delta, elapsed);
  if (state.entered) syncMovement(delta);
  updateAtmosphere(elapsed);
  renderer.render(scene, camera);
}

function resize() {
  if (!renderer) return;
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight, false);
}

function beginTouchMovement(event) {
  if (event.pointerType !== "touch" || !state.entered || event.clientX > innerWidth * 0.55) return;
  state.touch.active = true;
  state.touch.id = event.pointerId;
  state.touch.originX = event.clientX;
  state.touch.originY = event.clientY;
  touchStick.hidden = false;
  touchStick.style.left = `${event.clientX - 56}px`;
  touchStick.style.top = `${event.clientY - 56}px`;
  touchStick.style.bottom = "auto";
  canvas.setPointerCapture(event.pointerId);
}

function moveTouch(event) {
  if (!state.touch.active || event.pointerId !== state.touch.id) return;
  const dx = event.clientX - state.touch.originX;
  const dy = event.clientY - state.touch.originY;
  const length = Math.hypot(dx, dy);
  const limited = Math.min(42, length);
  const nx = length ? dx / length : 0;
  const ny = length ? dy / length : 0;
  state.touch.dx = nx * Math.min(1, length / 28);
  state.touch.dy = ny * Math.min(1, length / 28);
  touchKnob.style.transform = `translate(calc(-50% + ${nx * limited}px), calc(-50% + ${ny * limited}px))`;
}

function endTouch(event) {
  if (!state.touch.active || event.pointerId !== state.touch.id) return;
  Object.assign(state.touch, { active: false, id: null, dx: 0, dy: 0 });
  touchStick.hidden = true;
  touchKnob.style.transform = "translate(-50%, -50%)";
}

function pointerWorld(event) {
  if (!camera) return null;
  const pointer = new THREE.Vector2((event.clientX / innerWidth) * 2 - 1, -(event.clientY / innerHeight) * 2 + 1);
  const ray = new THREE.Raycaster();
  ray.setFromCamera(pointer, camera);
  const hit = new THREE.Vector3();
  if (!ray.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), hit)) return null;
  return { x: hit.x / WORLD_SCALE + SERVER_WORLD.width / 2, y: hit.z / WORLD_SCALE + SERVER_WORLD.height / 2 };
}

enterButton.addEventListener("click", joinClearing);
retryButton.addEventListener("click", () => { sleeping.hidden = true; threshold.hidden = false; joinClearing(); });
document.querySelectorAll("[data-gesture]").forEach((button) => button.addEventListener("click", () => triggerGesture(button.dataset.gesture)));
offerButton.addEventListener("click", offerCarriedWord);
gatherButton.addEventListener("pointerdown", (event) => { event.preventDefault(); gatherButton.setPointerCapture?.(event.pointerId); setGatherHeld(true); });
gatherButton.addEventListener("pointerup", () => setGatherHeld(false));
gatherButton.addEventListener("pointercancel", () => setGatherHeld(false));
gatherButton.addEventListener("pointerleave", (event) => { if (event.buttons === 0) setGatherHeld(false); });
gatherButton.addEventListener("click", (event) => {
  // Keyboard and assistive-technology activation cannot express a long pointer hold.
  if (event.detail !== 0 || gatherButton.disabled) return;
  const nearest = nearestWord();
  if (!nearest) return;
  setGatherHeld(true);
  setTimeout(() => setGatherHeld(false), ((GATHER_TIME[nearest.word.temperament] || 1.1) + 0.25) * 1000);
});
gatherButton.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || event.repeat || gatherButton.disabled) return;
  event.preventDefault();
  const nearest = nearestWord();
  if (!nearest) return;
  setGatherHeld(true);
  setTimeout(() => setGatherHeld(false), ((GATHER_TIME[nearest.word.temperament] || 1.1) + 0.25) * 1000);
});

document.addEventListener("keydown", (event) => {
  if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(event.code)) event.preventDefault();
  state.keys.add(event.code);
  state.target = null;
  if (event.code === "Space" && !event.repeat) setGatherHeld(true);
  if (event.code === "KeyQ" && !event.repeat) offerCarriedWord();
  if (event.code === "Digit1" && !event.repeat) triggerGesture("bow");
  if (event.code === "Digit2" && !event.repeat) triggerGesture("beckon");
  if (event.code === "Digit3" && !event.repeat) triggerGesture("call");
  if (event.code === "Digit4" && !event.repeat) triggerGesture("sit");
});
document.addEventListener("keyup", (event) => { state.keys.delete(event.code); if (event.code === "Space") setGatherHeld(false); });
window.addEventListener("blur", () => { state.keys.clear(); setGatherHeld(false); });
canvas.addEventListener("pointerdown", (event) => {
  beginTouchMovement(event);
  if (event.pointerType === "mouse" && state.entered) state.target = pointerWorld(event);
});
canvas.addEventListener("pointermove", moveTouch);
canvas.addEventListener("pointerup", endTouch);
canvas.addEventListener("pointercancel", endTouch);
window.addEventListener("resize", resize);
document.addEventListener("visibilitychange", () => { if (!document.hidden && state.credentials && !state.connected) openStream(); });

initThree();
