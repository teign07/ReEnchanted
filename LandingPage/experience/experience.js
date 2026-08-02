import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { BOOK_JUMPS, createBookJumpWorld } from "./book-jumps.js?v=6";

const clamp = THREE.MathUtils.clamp;

export function createFirstFall(root, options = {}) {
  const canvas = root.querySelector("#first-fall-canvas");
  const intake = root.querySelector("#first-fall-intake");
  const loading = root.querySelector("#first-fall-loading");
  const hud = root.querySelector("#first-fall-hud");
  const objective = root.querySelector("#first-fall-objective");
  const forwardButton = root.querySelector("#first-fall-forward");
  const interactButton = root.querySelector("#first-fall-interact");
  const status = root.querySelector("#first-fall-status");
  const dialogue = root.querySelector("#first-fall-dialogue");
  const speaker = root.querySelector("#first-fall-speaker");
  const line = root.querySelector("#first-fall-line");
  const choices = root.querySelector("#first-fall-choices");
  const dialoguePortrait = root.querySelector(".first-fall-portrait img");
  const binding = root.querySelector("#first-fall-binding");
  const bindingText = root.querySelector("#first-fall-binding-text");
  const perf = root.querySelector("#first-fall-perf");
  const a11y = root.querySelector("#first-fall-a11y");
  const coarse = window.matchMedia("(pointer: coarse)").matches;
  const showPerf = new URLSearchParams(location.search).has("perf");

  let renderer;
  let scene;
  let camera;
  let clock;
  let frame = 0;
  let phase = "idle";
  let active = false;
  let renderScale = 1;
  let lastScaleChange = 0;
  let frameBucket = [];
  let bucketStarted = performance.now();
  let yaw = 0;
  let pitch = 0;
  let fallElapsed = 0;
  let jumpEnergy = 0;
  let currentTarget = null;
  let paperField;
  let radio;
  let radioContext;
  let radioAnalyser;
  let radioData;
  let wirelessRings;
  let wickerApparition;
  let bookJumpKit;
  let bookMattes = {};
  let homeChildren = [];
  let destinationWorld;
  let bookChoice = "";
  let bookOutcome = "";
  let user = null;
  let lastTouch = null;
  let touchWalking = false;
  let autoWalk = false;
  const keys = new Set();
  const interactives = [];
  const disposables = [];
  const timers = new Set();
  const visited = { wicker: false, radio: false, jump: false };
  let disposition = "wait";

  const raycaster = new THREE.Raycaster();
  const center = new THREE.Vector2(0, 0);
  const tempMatrix = new THREE.Matrix4();
  const tempObject = new THREE.Object3D();

  function setObjective(value) {
    objective.textContent = value;
    a11y.textContent = value;
  }

  function later(action, delay) {
    const timer = window.setTimeout(() => {
      timers.delete(timer);
      action();
    }, delay);
    timers.add(timer);
    return timer;
  }

  function paperTexture() {
    const size = 384;
    const textureCanvas = document.createElement("canvas");
    textureCanvas.width = textureCanvas.height = size;
    const context = textureCanvas.getContext("2d");
    const gradient = context.createLinearGradient(0, 0, size, size);
    gradient.addColorStop(0, "#ead9b4");
    gradient.addColorStop(.52, "#c9ae7d");
    gradient.addColorStop(1, "#80613b");
    context.fillStyle = gradient;
    context.fillRect(0, 0, size, size);
    const image = context.getImageData(0, 0, size, size);
    for (let i = 0; i < image.data.length; i += 4) {
      const noise = (Math.random() - .5) * 22;
      image.data[i] += noise;
      image.data[i + 1] += noise * .88;
      image.data[i + 2] += noise * .55;
    }
    context.putImageData(image, 0, 0);
    context.globalAlpha = .16;
    context.strokeStyle = "#49311f";
    for (let i = 0; i < 90; i += 1) {
      context.beginPath();
      const y = Math.random() * size;
      context.moveTo(0, y);
      context.bezierCurveTo(size * .3, y + Math.random() * 8, size * .7, y - Math.random() * 8, size, y);
      context.stroke();
    }
    const texture = new THREE.CanvasTexture(textureCanvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.anisotropy = 4;
    disposables.push(texture);
    return texture;
  }

  function labelTexture(title, subtitle, color) {
    const textureCanvas = document.createElement("canvas");
    textureCanvas.width = 768;
    textureCanvas.height = 1024;
    const context = textureCanvas.getContext("2d");
    context.clearRect(0, 0, 768, 1024);
    const glow = context.createRadialGradient(384, 520, 10, 384, 520, 430);
    glow.addColorStop(0, `${color}bb`);
    glow.addColorStop(.42, `${color}38`);
    glow.addColorStop(1, "rgba(0,0,0,0)");
    context.fillStyle = glow;
    context.fillRect(0, 0, 768, 1024);
    context.strokeStyle = `${color}aa`;
    context.lineWidth = 3;
    context.strokeRect(74, 82, 620, 860);
    context.textAlign = "center";
    context.fillStyle = "#f1dfbd";
    context.font = "600 72px Georgia";
    context.fillText(title, 384, 470);
    context.fillStyle = "#cfb985";
    context.font = "italic 34px Georgia";
    context.fillText(subtitle, 384, 534);
    context.fillStyle = `${color}cc`;
    context.font = "34px Georgia";
    context.fillText("✦", 384, 630);
    const texture = new THREE.CanvasTexture(textureCanvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    disposables.push(texture);
    return texture;
  }

  function createPortal(id, title, subtitle, x, color) {
    const group = new THREE.Group();
    const darkMetal = new THREE.MeshStandardMaterial({
      color: 0x160e17,
      metalness: .72,
      roughness: .29,
      emissive: new THREE.Color(color).multiplyScalar(.06),
    });
    const page = new THREE.Mesh(
      new THREE.PlaneGeometry(3.5, 5.5),
      new THREE.MeshStandardMaterial({
        map: labelTexture(title, subtitle, `#${new THREE.Color(color).getHexString()}`),
        transparent: true,
        side: THREE.DoubleSide,
        emissive: new THREE.Color(color),
        emissiveIntensity: .22,
        roughness: .5,
      }),
    );
    page.position.y = 3.05;
    page.userData.action = id;
    page.userData.label = title;
    group.add(page);
    interactives.push(page);

    const postGeometry = new THREE.BoxGeometry(.24, 5.9, .36);
    for (const side of [-1, 1]) {
      const post = new THREE.Mesh(postGeometry, darkMetal);
      post.position.set(side * 1.93, 3, .1);
      group.add(post);
    }
    const arch = new THREE.Mesh(new THREE.TorusGeometry(1.93, .18, 7, 28, Math.PI), darkMetal);
    arch.position.set(0, 5.92, .1);
    group.add(arch);
    const light = new THREE.PointLight(color, coarse ? 9 : 14, 9, 2);
    light.position.set(0, 3.2, 1.3);
    group.add(light);
    group.position.set(x, 0, -18);
    scene.add(group);
    disposables.push(darkMetal, postGeometry, arch.geometry, page.geometry, page.material);
    return group;
  }

  function addArchitecture() {
    const paper = paperTexture();
    const floorMaterial = new THREE.MeshStandardMaterial({
      map: paper,
      color: 0x4b3627,
      roughness: .88,
      metalness: .02,
    });
    paper.repeat.set(3, 10);
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(18, 58, 1, 1), floorMaterial);
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, 0, 7);
    scene.add(floor);
    disposables.push(floor.geometry, floorMaterial);

    const gutter = new THREE.Mesh(
      new THREE.PlaneGeometry(.24, 58),
      new THREE.MeshBasicMaterial({ color: 0xd8a858, transparent: true, opacity: .34 }),
    );
    gutter.rotation.x = -Math.PI / 2;
    gutter.position.set(0, .015, 7);
    scene.add(gutter);
    disposables.push(gutter.geometry, gutter.material);

    const edgeGlowMaterial = new THREE.MeshBasicMaterial({ color: 0xb57a36, transparent: true, opacity: .12 });
    const edgeGlowGeometry = new THREE.PlaneGeometry(.06, 58);
    for (const x of [-2.8, 2.8]) {
      const edge = new THREE.Mesh(edgeGlowGeometry, edgeGlowMaterial);
      edge.rotation.x = -Math.PI / 2;
      edge.position.set(x, .02, 7);
      scene.add(edge);
    }
    disposables.push(edgeGlowGeometry, edgeGlowMaterial);

    const columnGeometry = new THREE.BoxGeometry(.48, 11, .48);
    const columnMaterial = new THREE.MeshStandardMaterial({
      color: 0x24130d,
      roughness: .45,
      metalness: .18,
    });
    const columns = new THREE.InstancedMesh(columnGeometry, columnMaterial, 28);
    let c = 0;
    for (let z = -14; z <= 26; z += 6.7) {
      for (const x of [-7.6, 7.6]) {
        tempObject.position.set(x, 5.5, z);
        tempObject.rotation.set(0, .08 * Math.sin(z), 0);
        tempObject.updateMatrix();
        columns.setMatrixAt(c++, tempObject.matrix);
      }
    }
    columns.count = c;
    scene.add(columns);
    disposables.push(columnGeometry, columnMaterial);

    const archGeometry = new THREE.TorusGeometry(7.55, .22, 6, 30, Math.PI);
    const arches = new THREE.InstancedMesh(archGeometry, columnMaterial, 8);
    c = 0;
    for (let z = -14; z <= 28; z += 6.7) {
      tempObject.position.set(0, 6.5, z);
      tempObject.rotation.set(0, 0, 0);
      tempObject.updateMatrix();
      arches.setMatrixAt(c++, tempObject.matrix);
    }
    arches.count = c;
    scene.add(arches);
    disposables.push(archGeometry);

    const pageGeometry = new THREE.PlaneGeometry(.7, 1.02);
    const pageMaterial = new THREE.MeshStandardMaterial({
      map: paper,
      color: 0xd8c397,
      side: THREE.DoubleSide,
      roughness: .8,
      transparent: true,
      opacity: .78,
      depthWrite: false,
    });
    const pageCount = coarse ? 110 : 220;
    paperField = new THREE.InstancedMesh(pageGeometry, pageMaterial, pageCount);
    const seeded = mulberry32(user.seed);
    for (let i = 0; i < pageCount; i += 1) {
      tempObject.position.set((seeded() - .5) * 16, seeded() * 12 + 1, (seeded() - .5) * 52 + 6);
      tempObject.rotation.set(seeded() * Math.PI, seeded() * Math.PI, seeded() * Math.PI);
      const scale = .25 + seeded() * .8;
      tempObject.scale.setScalar(scale);
      tempObject.updateMatrix();
      paperField.setMatrixAt(i, tempObject.matrix);
    }
    scene.add(paperField);
    disposables.push(pageGeometry, pageMaterial);

    createPortal("radio", "The Wireless", "hear the Stacks breathe", -5.2, 0x3da8a4);
    createPortal("wicker", "Duskthorn", "answer without being written first", 0, 0x7f4aa8);
    createPortal("jump", "Book Jump", "one spine · one door · a return", 5.2, 0xd2a34f);
  }

  async function addBlenderStacks() {
    const [gltf, bindingTexture] = await Promise.all([
      new GLTFLoader().loadAsync("./experience/assets/stacks-kit.glb"),
      new THREE.TextureLoader().loadAsync("./experience/assets/stacks-material.jpg"),
    ]);
    bindingTexture.colorSpace = THREE.SRGBColorSpace;
    bindingTexture.anisotropy = 4;
    disposables.push(bindingTexture);
    const sources = [];
    gltf.scene.traverse((child) => {
      if (child.isMesh) sources.push(child);
    });
    const placements = [];
    for (let z = -12; z <= 28; z += 8) {
      placements.push({ x: -7.1, z, rotation: Math.PI / 2 });
      placements.push({ x: 7.1, z, rotation: -Math.PI / 2 });
    }
    sources.forEach((source) => {
      const instances = new THREE.InstancedMesh(source.geometry, source.material, placements.length);
      placements.forEach((place, index) => {
        tempObject.position.set(place.x, .1, place.z);
        tempObject.rotation.set(0, place.rotation, 0);
        tempObject.scale.setScalar(.84);
        tempObject.updateMatrix();
        instances.setMatrixAt(index, tempObject.matrix);
      });
      scene.add(instances);
    });

    const friezeGeometry = new THREE.PlaneGeometry(4.8, 3.1);
    const friezeMaterial = new THREE.MeshStandardMaterial({
      map: bindingTexture,
      color: 0xc7ab78,
      roughness: .66,
      metalness: .12,
      side: THREE.DoubleSide,
      emissive: 0x2a160d,
      emissiveIntensity: .26,
    });
    const friezes = new THREE.InstancedMesh(friezeGeometry, friezeMaterial, 8);
    let index = 0;
    for (const x of [-7.42, 7.42]) {
      for (const z of [-8, 2, 12, 22]) {
        tempObject.position.set(x, 7.2, z);
        tempObject.rotation.set(0, x < 0 ? Math.PI / 2 : -Math.PI / 2, 0);
        tempObject.updateMatrix();
        friezes.setMatrixAt(index++, tempObject.matrix);
      }
    }
    scene.add(friezes);
    disposables.push(friezeGeometry, friezeMaterial);
  }

  async function addMoonshotAssets() {
    const [jumpGltf, apparitionTexture, prideMatte, draculaMatte, peterMatte] = await Promise.all([
      new GLTFLoader().loadAsync("./experience/assets/book-jumps-kit.glb"),
      new THREE.TextureLoader().loadAsync("./experience/assets/wicker-apparition-v2.jpg"),
      new THREE.TextureLoader().loadAsync("./experience/assets/pride-ballroom-matte-v1.jpg"),
      new THREE.TextureLoader().loadAsync("./experience/assets/dracula-castle-matte-v1.jpg"),
      new THREE.TextureLoader().loadAsync("./experience/assets/peter-neverland-matte-v1.jpg"),
    ]);
    bookJumpKit = jumpGltf.scene;
    apparitionTexture.colorSpace = THREE.SRGBColorSpace;
    apparitionTexture.anisotropy = 4;
    disposables.push(apparitionTexture);
    bookMattes = { pride: prideMatte, dracula: draculaMatte, peter: peterMatte };
    Object.values(bookMattes).forEach((texture) => {
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.anisotropy = 4;
      disposables.push(texture);
    });

    const apparitionGeometry = new THREE.PlaneGeometry(3.55, 5.35);
    const apparitionMaterial = new THREE.MeshBasicMaterial({
      map: apparitionTexture,
      color: 0xd8c9ff,
      transparent: true,
      opacity: .88,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      toneMapped: false,
    });
    wickerApparition = new THREE.Mesh(apparitionGeometry, apparitionMaterial);
    wickerApparition.position.set(0, 3.05, -17.72);
    scene.add(wickerApparition);
    disposables.push(apparitionGeometry, apparitionMaterial);

    wirelessRings = new THREE.Group();
    const ringGeometry = new THREE.TorusGeometry(1.06, .027, 6, 48);
    for (let index = 0; index < 4; index += 1) {
      const ringMaterial = new THREE.MeshBasicMaterial({
        color: index % 2 ? 0x83f0da : 0x3da8a4,
        transparent: true,
        opacity: .14,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      });
      const ring = new THREE.Mesh(ringGeometry, ringMaterial);
      ring.position.z = index * .13;
      ring.userData.offset = index * .23;
      wirelessRings.add(ring);
      disposables.push(ringMaterial);
    }
    wirelessRings.position.set(-5.2, 3.1, -17.6);
    scene.add(wirelessRings);
    disposables.push(ringGeometry);

    const seen = new Set();
    bookJumpKit.traverse((child) => {
      if (!child.isMesh) return;
      if (child.geometry && !seen.has(child.geometry)) {
        disposables.push(child.geometry);
        seen.add(child.geometry);
      }
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      materials.filter(Boolean).forEach((material) => {
        if (!seen.has(material)) {
          disposables.push(material);
          seen.add(material);
        }
      });
    });
  }

  function addLighting() {
    scene.add(new THREE.HemisphereLight(0x8f88b0, 0x1c0d08, coarse ? 1.8 : 2.25));
    const key = new THREE.DirectionalLight(0xf2d7a2, coarse ? 2.2 : 3.2);
    key.position.set(-5, 12, 10);
    scene.add(key);
    [
      [0x5a3f78, -8],
      [0x3a8a82, 6],
      [0xc28a43, 20],
    ].forEach(([color, z]) => {
      const light = new THREE.PointLight(color, coarse ? 8 : 14, 19, 2);
      light.position.set(0, 6, z);
      scene.add(light);
    });

    const lampGeometry = new THREE.SphereGeometry(.08, 8, 6);
    const lampMaterial = new THREE.MeshBasicMaterial({ color: 0xffd595 });
    const lamps = new THREE.InstancedMesh(lampGeometry, lampMaterial, 12);
    let lampIndex = 0;
    for (let z = -10; z <= 24; z += 6.8) {
      for (const x of [-3.25, 3.25]) {
        tempObject.position.set(x, .18, z);
        tempObject.scale.set(1, 1.8, 1);
        tempObject.updateMatrix();
        lamps.setMatrixAt(lampIndex++, tempObject.matrix);
      }
    }
    lamps.count = lampIndex;
    scene.add(lamps);
    disposables.push(lampGeometry, lampMaterial);
  }

  async function ensureRenderer() {
    if (renderer) return;
    renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: !coarse,
      alpha: false,
      powerPreference: "high-performance",
      stencil: false,
    });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = coarse ? 1.02 : 1.14;
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x020105);
    scene.fog = new THREE.FogExp2(0x07040b, coarse ? .028 : .021);
    camera = new THREE.PerspectiveCamera(69, 1, .08, 100);
    clock = new THREE.Clock();
    resize();
    addLighting();
    addArchitecture();
    await Promise.all([addBlenderStacks(), addMoonshotAssets()]);
    homeChildren = [...scene.children];
    bindControls();
  }

  function bindControls() {
    window.addEventListener("resize", resize);
    window.addEventListener("keydown", keyDown);
    window.addEventListener("keyup", keyUp);
    document.addEventListener("pointerlockchange", pointerLock);
    canvas.addEventListener("click", lockPointer);
    canvas.addEventListener("pointerdown", touchStart);
    canvas.addEventListener("pointermove", touchMove);
    canvas.addEventListener("pointerup", touchEnd);
    interactButton.addEventListener("click", interact);
    forwardButton.addEventListener("click", followGutter);
    canvas.addEventListener("webglcontextlost", contextLost);
    document.addEventListener("visibilitychange", visibility);
  }

  function unbindControls() {
    window.removeEventListener("resize", resize);
    window.removeEventListener("keydown", keyDown);
    window.removeEventListener("keyup", keyUp);
    document.removeEventListener("pointerlockchange", pointerLock);
    canvas.removeEventListener("click", lockPointer);
    canvas.removeEventListener("pointerdown", touchStart);
    canvas.removeEventListener("pointermove", touchMove);
    canvas.removeEventListener("pointerup", touchEnd);
    interactButton.removeEventListener("click", interact);
    forwardButton.removeEventListener("click", followGutter);
    canvas.removeEventListener("webglcontextlost", contextLost);
    document.removeEventListener("visibilitychange", visibility);
  }

  function keyDown(event) {
    keys.add(event.code);
    if (event.code === "KeyE") interact();
  }

  function keyUp(event) { keys.delete(event.code); }
  function pointerLock() { status.textContent = document.pointerLockElement === canvas ? "The Stacks have your attention." : "Click the world to look."; }
  function isWalkingPhase() { return phase === "walk" || phase === "bookWalk"; }
  function lockPointer() {
    if (coarse || !isWalkingPhase() || !dialogue.hidden) return;
    canvas.requestPointerLock?.();
  }
  function touchStart(event) {
    if (!coarse || !isWalkingPhase() || !dialogue.hidden) return;
    lastTouch = { x: event.clientX, y: event.clientY };
    touchWalking = true;
    canvas.setPointerCapture?.(event.pointerId);
  }
  function touchMove(event) {
    if (!coarse || !lastTouch) return;
    yaw -= (event.clientX - lastTouch.x) * .004;
    pitch -= (event.clientY - lastTouch.y) * .003;
    pitch = clamp(pitch, -.62, .62);
    lastTouch = { x: event.clientX, y: event.clientY };
  }
  function touchEnd() { lastTouch = null; touchWalking = false; }
  function followGutter() {
    if (!isWalkingPhase() || !dialogue.hidden) return;
    autoWalk = true;
    forwardButton.hidden = true;
    setObjective(phase === "bookWalk"
      ? `The borrowed line is carrying you deeper into ${destinationWorld.spec.title}.`
      : "The gutter is carrying you toward Duskthorn.");
  }
  function contextLost(event) {
    event.preventDefault();
    startIllustrated(user);
  }
  function visibility() {
    if (document.hidden) clock?.stop();
    else if (active) clock?.start();
  }

  function resize() {
    if (!renderer || !camera) return;
    const width = root.clientWidth;
    const height = root.clientHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, coarse ? 1.25 : 1.5);
    renderer.setPixelRatio(dpr * renderScale);
    renderer.setSize(width, height, false);
    camera.aspect = width / Math.max(1, height);
    camera.updateProjectionMatrix();
  }

  function updateLook(event) {
    if (document.pointerLockElement !== canvas || !isWalkingPhase() || !dialogue.hidden) return;
    yaw -= event.movementX * .0018;
    pitch -= event.movementY * .0016;
    pitch = clamp(pitch, -.62, .62);
  }
  document.addEventListener("mousemove", updateLook);

  function updateMovement(dt) {
    if (!isWalkingPhase() || !dialogue.hidden) return;
    const forward = new THREE.Vector3(-Math.sin(yaw), 0, -Math.cos(yaw));
    const right = new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw));
    const velocity = new THREE.Vector3();
    if (autoWalk && phase === "walk") {
      camera.position.x += (0 - camera.position.x) * Math.min(1, dt * 2);
      camera.position.z -= dt * 4.5;
      yaw += (0 - yaw) * Math.min(1, dt * 2.5);
      pitch += (0 - pitch) * Math.min(1, dt * 2.5);
      if (camera.position.z <= -10.1) {
        camera.position.z = -10.1;
        autoWalk = false;
        setObjective("Duskthorn is looking back. Answer the illuminated Page.");
      }
    }
    if (autoWalk && phase === "bookWalk" && destinationWorld) {
      const target = destinationWorld.standPoint;
      const path = new THREE.Vector3(target.x - camera.position.x, 0, target.z - camera.position.z);
      const distance = path.length();
      if (distance > .22) {
        path.normalize();
        camera.position.addScaledVector(path, Math.min(distance, dt * (coarse ? 2.8 : 3.8)));
      } else {
        camera.position.x = target.x;
        camera.position.z = target.z;
        autoWalk = false;
        setObjective("The living Page has your sentence. Read it.");
      }
      const focus = destinationWorld.interaction.getWorldPosition(new THREE.Vector3()).sub(camera.position);
      const horizontal = Math.hypot(focus.x, focus.z);
      const targetYaw = Math.atan2(-focus.x, -focus.z);
      const targetPitch = Math.atan2(focus.y, Math.max(.001, horizontal));
      yaw += Math.atan2(Math.sin(targetYaw - yaw), Math.cos(targetYaw - yaw)) * Math.min(1, dt * 3.2);
      pitch += (targetPitch - pitch) * Math.min(1, dt * 3.2);
    }
    if (keys.has("KeyW") || keys.has("ArrowUp") || touchWalking) velocity.add(forward);
    if (keys.has("KeyS") || keys.has("ArrowDown")) velocity.sub(forward);
    if (keys.has("KeyA")) velocity.sub(right);
    if (keys.has("KeyD")) velocity.add(right);
    if (velocity.lengthSq()) {
      autoWalk = false;
      velocity.normalize().multiplyScalar(dt * (coarse ? 2.6 : 3.6));
      camera.position.add(velocity);
      const bounds = phase === "bookWalk" && destinationWorld
        ? destinationWorld.bounds
        : { x: [-6.35, 6.35], z: [-14.8, 27] };
      camera.position.x = clamp(camera.position.x, ...bounds.x);
      camera.position.z = clamp(camera.position.z, ...bounds.z);
    }
    camera.rotation.set(pitch, yaw, 0, "YXZ");
  }

  function targetInteraction() {
    if (!isWalkingPhase() || !dialogue.hidden) {
      currentTarget = null;
      interactButton.hidden = true;
      return;
    }
    raycaster.setFromCamera(center, camera);
    const candidates = phase === "bookWalk" && destinationWorld?.interaction
      ? [destinationWorld.interaction]
      : interactives;
    const hit = raycaster.intersectObjects(candidates, false)[0];
    currentTarget = hit && hit.distance < 10 ? hit.object : null;
    interactButton.hidden = !currentTarget;
    if (currentTarget) {
      interactButton.textContent = phase === "bookWalk"
        ? `Read ${currentTarget.userData.label}`
        : `Enter ${currentTarget.userData.label}`;
    }
  }

  function interact() {
    const action = currentTarget?.userData.action;
    if (!action || !isWalkingPhase()) return;
    if (phase === "bookWalk" && action === "bookMoment") {
      encounterBookMoment();
      return;
    }
    if (action === "wicker") encounterWicker();
    if (action === "radio") encounterRadio();
    if (action === "jump") encounterJump();
  }

  function showDialogue(who, copy, buttons, voice = "wicker") {
    speaker.textContent = who;
    line.textContent = copy;
    dialogue.dataset.voice = voice;
    dialoguePortrait.hidden = voice !== "wicker";
    choices.replaceChildren();
    buttons.forEach(({ label, action }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = label;
      button.addEventListener("click", action, { once: true });
      choices.appendChild(button);
    });
    dialogue.hidden = false;
    document.exitPointerLock?.();
  }

  function encounterWicker() {
    showDialogue(
      "Wicker Eddies · Duskthorn",
      `You expected a portrait. I prefer weather. So this is what you carried through the fall: “${user.detail}” Interesting. Not impressive. Interesting is rarer. Does it become part of the story?`,
      [
        { label: "Keep the true thing", action: () => finishWicker("keep") },
        { label: "Let it wait", action: () => finishWicker("wait") },
      ],
    );
  }

  function finishWicker(choice) {
    disposition = choice;
    visited.wicker = true;
    setObjective(choice === "keep"
      ? "The sentence became architecture. Find the Wireless, or choose a spine."
      : "The sentence waits without punishment. Find the Wireless, or choose a spine.");
    root.dataset.disposition = choice;
    showDialogue(
      "The Page folds into a map",
      "You can still walk anywhere. Or let the golden gutter carry this first visit to the Wireless.",
      [
        { label: "Tune the Wireless", action: encounterRadio },
        { label: "Explore on my own", action: () => { dialogue.hidden = true; } },
      ],
    );
  }

  function encounterRadio() {
    if (!radio) {
      radio = new Audio("./assets/audio/thornwave-wicker-id-03.m4a");
      radio.preload = "auto";
      radio.volume = .68;
    }
    radio.play().catch(() => {});
    connectRadioAnalysis();
    visited.radio = true;
    showDialogue(
      "103.7 Thornwave · Wicker on air",
      "You are listening to the part of the library that refuses to whisper. Watch the brass breathe. This signal will cross into whichever book you choose.",
      [
        { label: "Open the Book Jump", action: encounterJump },
        { label: "Take the signal and explore", action: () => {
          dialogue.hidden = true;
          setObjective("The Wireless remembers your frequency. The Book Jump is awake.");
        } },
      ],
    );
  }

  function encounterJump() {
    if (!visited.wicker) {
      setObjective("The Jump will not take an unwritten reader. Answer Duskthorn first.");
      return;
    }
    showDialogue(
      "Book Jumping · choose one controlled beat",
      "Three old spines have opened. Your true detail will cross with you, alter one scene, and return. Which book is allowed to notice you?",
      [
        { label: "Pride and Prejudice", action: () => startBookJump("pride") },
        { label: "Dracula", action: () => startBookJump("dracula") },
        { label: "Peter Pan", action: () => startBookJump("peter") },
      ],
      "books",
    );
  }

  function connectRadioAnalysis() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext || !radio || radioAnalyser) return;
    try {
      radioContext = new AudioContext();
      const source = radioContext.createMediaElementSource(radio);
      radioAnalyser = radioContext.createAnalyser();
      radioAnalyser.fftSize = 128;
      radioAnalyser.smoothingTimeConstant = .82;
      radioData = new Uint8Array(radioAnalyser.frequencyBinCount);
      source.connect(radioAnalyser);
      radioAnalyser.connect(radioContext.destination);
      radioContext.resume().catch(() => {});
    } catch {
      radioAnalyser = null;
    }
  }

  function startBookJump(kind) {
    bookChoice = kind;
    bookOutcome = "";
    visited.jump = true;
    phase = "jump";
    jumpEnergy = 0;
    root.classList.add("is-jumping");
    root.dataset.book = kind;
    dialogue.hidden = true;
    setObjective(`${BOOK_JUMPS[kind].title} is opening under your feet.`);
    document.exitPointerLock?.();
    later(() => arriveInBook(kind), 1900);
  }

  function arriveInBook(kind) {
    homeChildren.forEach((child) => { child.visible = false; });
    destinationWorld?.dispose();
    destinationWorld?.group.removeFromParent();
    destinationWorld = createBookJumpWorld(kind, {
      user,
      kit: bookJumpKit,
      mattes: bookMattes,
      coarse,
    });
    scene.add(destinationWorld.group);
    scene.background = destinationWorld.background;
    scene.fog = destinationWorld.fog;
    camera.position.copy(destinationWorld.cameraStart);
    camera.lookAt(destinationWorld.cameraTarget);
    const direction = destinationWorld.cameraTarget.clone().sub(camera.position).normalize();
    yaw = Math.atan2(-direction.x, -direction.z);
    pitch = Math.asin(clamp(direction.y, -1, 1));
    phase = "bookArrival";
    root.classList.remove("is-jumping");
    setObjective(destinationWorld.spec.door);
    status.textContent = `${destinationWorld.spec.title} · the Book has admitted you`;
    later(() => {
      phase = "bookWalk";
      setObjective(`Explore ${destinationWorld.spec.title}. The borrowed sentence is ahead.`);
      status.textContent = coarse ? "Hold to move. Drag to look." : "Click to look. WASD to move.";
      forwardButton.textContent = "Follow the borrowed line";
      forwardButton.hidden = false;
    }, 1250);
  }

  function encounterBookMoment() {
    if (phase !== "bookWalk" || !destinationWorld) return;
    const spec = destinationWorld.spec;
    showDialogue(
      spec.speaker,
      spec.arrival(user.detail),
      spec.choices.map((choice) => ({
        label: choice.label,
        action: () => finishBookJump(choice),
      })),
      bookChoice,
    );
  }

  function finishBookJump(choice) {
    bookOutcome = choice.outcome;
    dialogue.hidden = true;
    setObjective("The borrowed story is returning what belongs to you.");
    root.classList.add("is-returning");
    later(showBinding, 850);
  }

  function showBinding() {
    phase = "binding";
    active = false;
    cancelAnimationFrame(frame);
    hud.hidden = true;
    forwardButton.hidden = true;
    dialogue.hidden = true;
    binding.hidden = false;
    const name = user.name === "Reader" ? "The reader" : user.name;
    const kept = disposition === "keep"
      ? `${name} kept the moment exactly as it arrived: ${user.detail}`
      : `${name} let the sentence wait, and the Book did not punish the quiet: ${user.detail}`;
    const signal = visited.radio
      ? " Somewhere below the floor, Thornwave kept broadcasting, low and amused, as if doubt itself had become a door."
      : " The Wireless stayed quiet, but one brass dial turned by itself in the dark.";
    const selected = BOOK_JUMPS[bookChoice];
    const returnLine = selected
      ? ` ${selected.choices.find((choice) => choice.outcome === bookOutcome)?.returnLine || `${selected.title} returned the reader without explanation.`}`
      : "";
    const stop = /[.!?…]$/.test(kept) ? "" : ".";
    bindingText.textContent = `${kept}${stop}${signal}${returnLine} The Stacks closed the borrowed cover and opened back onto ${user.month}.`;
    status.textContent = "The Book returned you.";
  }

  function animate() {
    if (!active || !renderer) return;
    frame = requestAnimationFrame(animate);
    const dt = Math.min(.05, clock.getDelta());
    const now = performance.now();
    frameBucket.push(dt * 1000);

    if (phase === "fall") {
      fallElapsed += dt;
      const t = clamp(fallElapsed / 3.15, 0, 1);
      const eased = 1 - Math.pow(1 - t, 4);
      camera.position.set(Math.sin(t * 8) * (1 - t) * 2.2, 34 - eased * 32.25, 24 + (1 - t) * 4);
      camera.rotation.set(-.12 + Math.sin(t * 9) * .05, Math.sin(t * 4) * .16, Math.sin(t * 6) * .05);
      if (t >= 1) {
        phase = "walk";
        root.classList.remove("is-falling");
        camera.position.set(0, 1.75, 24);
        camera.rotation.set(0, 0, 0);
        forwardButton.textContent = "Follow the golden gutter";
        setObjective("Walk the gutter. Three doors are awake.");
        forwardButton.hidden = false;
        status.textContent = coarse ? "Hold to move. Drag to look." : "Click to look. WASD to move.";
      }
    } else {
      updateMovement(dt);
    }

    if (paperField) {
      const count = paperField.count;
      const spin = phase === "jump" ? 2.4 : .06;
      jumpEnergy = phase === "jump" ? Math.min(1, jumpEnergy + dt) : Math.max(0, jumpEnergy - dt);
      for (let i = 0; i < count; i += 1) {
        paperField.getMatrixAt(i, tempMatrix);
        tempMatrix.decompose(tempObject.position, tempObject.quaternion, tempObject.scale);
        tempObject.rotation.y += dt * spin * (i % 2 ? 1 : -1);
        tempObject.position.y += Math.sin(now * .00035 + i) * dt * .04 + jumpEnergy * dt * 2.2;
        if (tempObject.position.y > 15) tempObject.position.y = .4;
        tempObject.updateMatrix();
        paperField.setMatrixAt(i, tempObject.matrix);
      }
      paperField.instanceMatrix.needsUpdate = true;
    }

    if (wickerApparition && wickerApparition.visible) {
      wickerApparition.position.y = 3.05 + Math.sin(now * .00072) * .055;
      wickerApparition.material.opacity = .79 + Math.sin(now * .0019) * .09;
      wickerApparition.rotation.y = Math.sin(now * .00031) * .035;
    }

    if (wirelessRings && wirelessRings.visible) {
      let signal = .12 + (Math.sin(now * .002) + 1) * .08;
      if (radioAnalyser && radioData) {
        radioAnalyser.getByteFrequencyData(radioData);
        signal = radioData.reduce((sum, value) => sum + value, 0) / Math.max(1, radioData.length) / 255;
      }
      wirelessRings.children.forEach((ring, index) => {
        const pulse = 1 + ((now * .00032 + ring.userData.offset) % 1) * (visited.radio ? .85 : .18);
        ring.scale.setScalar(pulse);
        ring.material.opacity = clamp(.08 + signal * .72 - index * .012, .06, .58);
        ring.rotation.z = now * .00008 * (index % 2 ? 1 : -1);
      });
    }

    if ((phase === "bookArrival" || phase === "bookWalk") && destinationWorld) {
      destinationWorld.update(dt, now, camera, phase === "bookArrival");
    }

    targetInteraction();
    renderer.render(scene, camera);
    tuneQuality(now);
  }

  function tuneQuality(now) {
    if (now - bucketStarted < 2000) return;
    const average = frameBucket.reduce((sum, value) => sum + value, 0) / Math.max(1, frameBucket.length);
    const fps = 1000 / Math.max(1, average);
    if (now - lastScaleChange > 2000) {
      if (fps < 52 && renderScale > .66) {
        renderScale = Math.max(.66, renderScale - .1);
        lastScaleChange = now;
        resize();
      } else if (fps > 59 && renderScale < 1) {
        renderScale = Math.min(1, renderScale + .05);
        lastScaleChange = now;
        resize();
      }
    }
    if (showPerf) {
      perf.hidden = false;
      perf.value = `${fps.toFixed(0)} fps\n${renderer.info.render.calls} calls\n${renderer.info.render.triangles.toLocaleString()} tris\n${renderScale.toFixed(2)} scale`;
    }
    frameBucket = [];
    bucketStarted = now;
  }

  async function start(data) {
    user = data;
    root.classList.remove("is-illustrated");
    loading.hidden = false;
    intake.hidden = true;
    binding.hidden = true;
    forwardButton.hidden = true;
    await ensureRenderer();
    restoreHomeWorld();
    loading.hidden = true;
    hud.hidden = false;
    forwardButton.hidden = true;
    active = true;
    phase = "fall";
    fallElapsed = 0;
    camera.position.set(0, 34, 28);
    root.classList.add("is-falling");
    status.textContent = "Reality is becoming text.";
    setObjective("Fall. The Book has the landing.");
    clock.start();
    animate();
  }

  function startIllustrated(data) {
    user = data;
    active = false;
    cancelAnimationFrame(frame);
    root.classList.add("is-illustrated");
    root.classList.remove("is-falling", "is-jumping", "is-returning");
    loading.hidden = true;
    intake.hidden = true;
    binding.hidden = true;
    hud.hidden = false;
    phase = "illustrated";
    setObjective("The illustrated Stacks opened. Wicker is waiting in the margin.");
    later(() => {
      showDialogue(
        "Wicker Eddies · Duskthorn",
        `You brought “${user.detail}” into my margin. Keep it, or don't. I'm testing your taste, not your obedience.`,
        [
          { label: "Keep the true thing", action: () => illustratedRadio("keep") },
          { label: "Let it wait", action: () => illustratedRadio("wait") },
        ],
      );
    }, 350);
  }

  function illustratedRadio(choice) {
    disposition = choice;
    visited.wicker = true;
    showDialogue(
      "103.7 Thornwave · the illustrated dial",
      "The radio does not need a renderer to find you. Wicker's signal presses violet ink into the edge of the Page.",
      [
        { label: "Tune in and choose a book", action: () => {
          radio ||= new Audio("./assets/audio/thornwave-wicker-id-03.m4a");
          radio.volume = .68;
          radio.play().catch(() => {});
          connectRadioAnalysis();
          visited.radio = true;
          illustratedChooseBook();
        } },
      ],
    );
  }

  function illustratedChooseBook() {
    showDialogue(
      "Book Jumping · illustrated route",
      "Choose the old book that is allowed to notice your detail. You will enter one scene and bring one consequence back.",
      [
        { label: "Pride and Prejudice", action: () => illustratedBook("pride") },
        { label: "Dracula", action: () => illustratedBook("dracula") },
        { label: "Peter Pan", action: () => illustratedBook("peter") },
      ],
      "books",
    );
  }

  function illustratedBook(kind) {
    bookChoice = kind;
    visited.jump = true;
    root.dataset.book = kind;
    const spec = BOOK_JUMPS[kind];
    setObjective(spec.door);
    showDialogue(
      spec.speaker,
      spec.arrival(user.detail),
      spec.choices.map((choice) => ({
        label: choice.label,
        action: () => finishBookJump(choice),
      })),
      kind,
    );
  }

  function restoreHomeWorld() {
    if (!scene) return;
    destinationWorld?.dispose();
    destinationWorld?.group.removeFromParent();
    destinationWorld = null;
    homeChildren.forEach((child) => { child.visible = true; });
    scene.background = new THREE.Color(0x020105);
    scene.fog = new THREE.FogExp2(0x07040b, coarse ? .028 : .021);
    delete root.dataset.book;
    root.classList.remove("is-jumping", "is-returning");
    forwardButton.textContent = "Follow the golden gutter";
  }

  function reset() {
    active = false;
    cancelAnimationFrame(frame);
    timers.forEach((timer) => window.clearTimeout(timer));
    timers.clear();
    radio?.pause();
    restoreHomeWorld();
    root.className = "first-fall";
    delete root.dataset.disposition;
    loading.hidden = true;
    hud.hidden = true;
    forwardButton.hidden = true;
    dialogue.hidden = true;
    binding.hidden = true;
    phase = "idle";
    autoWalk = false;
    yaw = 0;
    pitch = 0;
    visited.wicker = visited.radio = visited.jump = false;
    disposition = "wait";
    bookChoice = "";
    bookOutcome = "";
  }

  function destroy() {
    reset();
    document.exitPointerLock?.();
    unbindControls();
    document.removeEventListener("mousemove", updateLook);
    if (renderer) {
      renderer.dispose();
      renderer.forceContextLoss?.();
    }
    disposables.forEach((item) => item?.dispose?.());
    radioContext?.close?.().catch(() => {});
    renderer = scene = camera = clock = paperField = null;
    bookJumpKit = null;
    bookMattes = {};
    homeChildren = [];
    interactives.length = 0;
  }

  return { start, startIllustrated, reset, destroy };
}

function mulberry32(seed) {
  return function random() {
    let value = seed += 0x6D2B79F5;
    value = Math.imul(value ^ value >>> 15, value | 1);
    value ^= value + Math.imul(value ^ value >>> 7, value | 61);
    return ((value ^ value >>> 14) >>> 0) / 4294967296;
  };
}
