import * as THREE from "three";

export const BOOK_JUMPS = {
  pride: {
    title: "Pride and Prejudice",
    author: "Jane Austen · 1813",
    door: "Netherfield, while the dance is turning",
    speaker: "Elizabeth Bennet · Netherfield",
    arrival(detail) {
      return `The music falters. Elizabeth has noticed a sentence no one in Hertfordshire could possibly know: “${detail}” She looks delighted by the impropriety of it.`;
    },
    choices: [
      {
        label: "Tell her it is true",
        outcome: "truth",
        returnLine: "At Netherfield, Elizabeth believed the unpolished truth and made room for it among all those polished opinions.",
      },
      {
        label: "Let Darcy overhear",
        outcome: "mischief",
        returnLine: "At Netherfield, the sentence crossed the ballroom as a rumor; Darcy heard it, misunderstood it beautifully, and looked twice.",
      },
    ],
  },
  dracula: {
    title: "Dracula",
    author: "Bram Stoker · 1897",
    door: "Borgo Pass, after the last safe inn",
    speaker: "Jonathan Harker · Borgo Pass",
    arrival(detail) {
      return `The coach has stopped where no road should end. Harker opens his journal, and your sentence is already wet on the page: “${detail}” Something beyond the gate is reading over his shoulder.`;
    },
    choices: [
      {
        label: "Enter it in the journal",
        outcome: "witness",
        returnLine: "At Borgo Pass, Harker entered the detail into evidence. The ink dried before the rain could deny it.",
      },
      {
        label: "Keep it from the Count",
        outcome: "secret",
        returnLine: "At Borgo Pass, the reader kept one true thing beyond the Count's invitation, and the locked gate failed to learn it.",
      },
    ],
  },
  peter: {
    title: "Peter Pan",
    author: "J. M. Barrie · 1911 novel",
    door: "The nursery roof, one thought before flight",
    speaker: "Wendy Darling · Above Bloomsbury",
    arrival(detail) {
      return `London has become a scatter of lamps below the nursery roof. Wendy says every flight needs one thought with enough truth in it. Tonight yours is: “${detail}”`;
    },
    choices: [
      {
        label: "Use it to fly",
        outcome: "flight",
        returnLine: "Above Bloomsbury, the detail became light enough to fly with and heavy enough not to blow away.",
      },
      {
        label: "Keep it as the way home",
        outcome: "home",
        returnLine: "Above Bloomsbury, Wendy kept the detail as a coordinate for home. Even Neverland could not make it ordinary.",
      },
    ],
  },
};

export function createBookJumpWorld(kind, { user, kit, mattes, coarse }) {
  const spec = BOOK_JUMPS[kind];
  if (!spec) throw new Error(`Unknown Book Jump: ${kind}`);

  const group = new THREE.Group();
  group.name = `BookJump_${kind}`;
  const owned = [];
  const animated = [];
  let storyPage = null;
  let standPoint = new THREE.Vector3(0, 1.75, 2);
  const seeded = mulberry32(user.seed + ({ pride: 1813, dracula: 1897, peter: 1911 }[kind]));
  const track = (...items) => {
    owned.push(...items);
    return items[0];
  };

  const add = (object) => {
    group.add(object);
    return object;
  };

  function hero(name, position, scale, rotation = [0, 0, 0]) {
    const source = kit?.getObjectByName(name);
    if (!source) return null;
    const clone = source.clone(true);
    clone.position.set(...position);
    clone.scale.setScalar(scale);
    clone.rotation.set(...rotation);
    add(clone);
    return clone;
  }

  function backdrop(texture, position = [0, 5, -28]) {
    if (!texture) return null;
    const geometry = track(new THREE.PlaneGeometry(96, 54));
    const material = track(new THREE.MeshBasicMaterial({
      map: texture,
      fog: false,
      toneMapped: false,
      depthWrite: true,
    }));
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(...position);
    add(mesh);
    animated.push({ type: "backdrop", mesh, originX: position[0] });
    return mesh;
  }

  function panel(title, detail, colors, position, rotation = [0, 0, 0], size = [6.6, 3.8]) {
    const texture = track(textTexture(title, detail, colors));
    const geometry = track(new THREE.PlaneGeometry(...size));
    const material = track(new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
      toneMapped: false,
    }));
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(...position);
    mesh.rotation.set(...rotation);
    add(mesh);
    animated.push({ type: "panel", mesh });
    return mesh;
  }

  function points(name, count, spread, color, size, opacity = 1) {
    const geometry = track(new THREE.BufferGeometry());
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      positions[i * 3] = (seeded() - .5) * spread[0];
      positions[i * 3 + 1] = seeded() * spread[1];
      positions[i * 3 + 2] = (seeded() - .5) * spread[2];
    }
    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    const material = track(new THREE.PointsMaterial({
      color,
      size,
      sizeAttenuation: true,
      transparent: true,
      opacity,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    }));
    const cloud = new THREE.Points(geometry, material);
    cloud.name = name;
    add(cloud);
    return cloud;
  }

  let cameraStart = new THREE.Vector3(0, 2, 10);
  let cameraTarget = new THREE.Vector3(0, 2.4, -5);
  let background = new THREE.Color(0x050308);
  let fog = new THREE.FogExp2(0x050308, .025);

  if (kind === "pride") {
    background = new THREE.Color(0x100907);
    fog = new THREE.FogExp2(0x1b0f0b, coarse ? .034 : .025);
    backdrop(mattes?.pride, [0, 5, -28]);
    const ballroom = hero("BOOK_PRIDE_AND_PREJUDICE", [0, 0, -7.4], 1.18);
    if (ballroom) animated.push({ type: "chandelier", mesh: ballroom.getObjectByName("Pemberley_ChandelierRing") });

    const floorGeometry = track(new THREE.PlaneGeometry(26, 30));
    const floorMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x32160c,
      roughness: .28,
      metalness: .08,
    }));
    const floor = new THREE.Mesh(floorGeometry, floorMaterial);
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, -.02, -5);
    add(floor);

    const curtainGeometry = track(new THREE.PlaneGeometry(4.8, 10));
    const curtainMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x3f0910,
      roughness: .82,
      side: THREE.DoubleSide,
    }));
    for (const x of [-7.4, 7.4]) {
      for (const z of [-4, -11]) {
        const curtain = new THREE.Mesh(curtainGeometry, curtainMaterial);
        curtain.position.set(x, 4.8, z);
        curtain.rotation.y = x < 0 ? Math.PI / 2 : -Math.PI / 2;
        add(curtain);
      }
    }

    const guestGeometry = track(new THREE.CapsuleGeometry(.18, 1.25, 3, 6));
    const guestMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x130b12,
      roughness: .72,
      metalness: .05,
    }));
    const guests = new THREE.InstancedMesh(guestGeometry, guestMaterial, coarse ? 18 : 32);
    for (let i = 0; i < guests.count; i += 1) {
      const side = i % 2 ? -1 : 1;
      const rank = Math.floor(i / 2);
      const z = 2 - (rank % 8) * 1.45;
      const x = side * (2.7 + (rank % 3) * .75);
      const scale = .84 + seeded() * .18;
      const dummy = new THREE.Object3D();
      dummy.position.set(x, .82, z);
      dummy.scale.setScalar(scale);
      dummy.rotation.y = side * (.24 + seeded() * .3);
      dummy.updateMatrix();
      guests.setMatrixAt(i, dummy.matrix);
    }
    add(guests);
    storyPage = panel("A private observation", user.detail, ["#ead8a9", "#3e2113", "#a26b2c"], [3.7, 2.65, -3.8], [0, -.52, 0], [4.5, 2.6]);
    standPoint = new THREE.Vector3(2.25, 1.75, 2.1);
    points("CandleMotes", coarse ? 160 : 320, [16, 8, 24], 0xf3c773, .035, .74);
    add(new THREE.HemisphereLight(0xf0cf9c, 0x1d0907, 2.9));
    for (const x of [-4.7, 0, 4.7]) {
      const candle = new THREE.PointLight(0xffbc68, coarse ? 7 : 11, 12, 2);
      candle.position.set(x, 4.6, -6);
      add(candle);
      animated.push({ type: "candle", light: candle, seed: seeded() * 10 });
    }
    cameraStart = new THREE.Vector3(0, 1.75, 8.8);
    cameraTarget = new THREE.Vector3(0, 2.4, -7);
  }

  if (kind === "dracula") {
    background = new THREE.Color(0x010309);
    fog = new THREE.FogExp2(0x07101b, coarse ? .045 : .033);
    backdrop(mattes?.dracula, [0, 5, -28]);
    hero("BOOK_DRACULA", [0, 0, -8.4], 1.42);

    const groundGeometry = track(new THREE.PlaneGeometry(26, 34));
    const groundMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x08090d,
      roughness: .92,
      metalness: .06,
    }));
    const ground = new THREE.Mesh(groundGeometry, groundMaterial);
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(0, 0, -6);
    add(ground);

    const peakGeometry = track(new THREE.ConeGeometry(3.1, 9, 5));
    const peakMaterial = track(new THREE.MeshStandardMaterial({ color: 0x020307, roughness: 1 }));
    const peaks = new THREE.InstancedMesh(peakGeometry, peakMaterial, coarse ? 10 : 16);
    for (let i = 0; i < peaks.count; i += 1) {
      const dummy = new THREE.Object3D();
      const side = i % 2 ? -1 : 1;
      dummy.position.set(side * (4.2 + seeded() * 9), 2.1 + seeded() * 2, -5 - seeded() * 24);
      dummy.scale.set(.7 + seeded(), .8 + seeded() * 1.4, .7 + seeded());
      dummy.rotation.y = seeded() * Math.PI;
      dummy.updateMatrix();
      peaks.setMatrixAt(i, dummy.matrix);
    }
    add(peaks);

    const rain = points("CarpathianRain", coarse ? 420 : 900, [22, 15, 32], 0x86a8c7, .026, .62);
    animated.push({ type: "rain", mesh: rain });
    storyPage = panel("Harker's journal", user.detail, ["#d7c59a", "#231b17", "#6d1012"], [3.7, 2.5, -3.8], [0, -.54, 0], [4.3, 2.6]);
    standPoint = new THREE.Vector3(2.25, 1.72, 2.2);
    add(new THREE.HemisphereLight(0x526680, 0x020205, 1.75));
    const lightning = new THREE.DirectionalLight(0xb7d9ff, 1.2);
    lightning.position.set(-5, 10, 4);
    add(lightning);
    animated.push({ type: "lightning", light: lightning });
    const gateGlow = new THREE.PointLight(0x8b1017, coarse ? 9 : 15, 13, 2);
    gateGlow.position.set(0, 3.5, -7);
    add(gateGlow);
    cameraStart = new THREE.Vector3(0, 1.72, 8.6);
    cameraTarget = new THREE.Vector3(0, 2.8, -8.4);
  }

  if (kind === "peter") {
    background = new THREE.Color(0x020617);
    fog = new THREE.FogExp2(0x07102a, coarse ? .025 : .017);
    backdrop(mattes?.peter, [0, 5, -28]);
    const roof = hero("BOOK_PETER_PAN", [0, 0, -7], 1.34);
    if (roof) {
      const roofSlab = roof.getObjectByName("Darling_Roof");
      if (roofSlab) roofSlab.visible = false;
      animated.push({ type: "clock", mesh: roof.getObjectByName("Neverland_Clock") });
    }

    const cityGeometry = track(new THREE.BoxGeometry(1, 1, 1));
    const cityMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x050714,
      emissive: 0x211b27,
      emissiveIntensity: .22,
      roughness: .86,
    }));
    const city = new THREE.InstancedMesh(cityGeometry, cityMaterial, coarse ? 22 : 40);
    for (let i = 0; i < city.count; i += 1) {
      const dummy = new THREE.Object3D();
      const x = (seeded() - .5) * 30;
      const z = -3 - seeded() * 34;
      const height = 1.2 + seeded() * 5.8;
      dummy.position.set(x, -2.6 - height / 2, z);
      dummy.scale.set(.8 + seeded() * 1.8, height, .9 + seeded() * 1.9);
      dummy.rotation.y = seeded() * .25;
      dummy.updateMatrix();
      city.setMatrixAt(i, dummy.matrix);
    }
    add(city);

    const stars = points("SecondStarField", coarse ? 520 : 1100, [34, 19, 42], 0xffe9b7, .045, .9);
    stars.position.z = -8;
    animated.push({ type: "stars", mesh: stars });
    storyPage = panel("One thought with weight", user.detail, ["#e7d8b6", "#14182e", "#6ab6c7"], [-3.7, 3.4, -4.8], [0, .48, -.05], [4.6, 2.7]);
    standPoint = new THREE.Vector3(-2.35, 1.9, 1.55);

    const islandGeometry = track(new THREE.ConeGeometry(4.7, 3.6, 9));
    const islandMaterial = track(new THREE.MeshStandardMaterial({
      color: 0x071112,
      emissive: 0x0a332c,
      emissiveIntensity: .38,
      roughness: .9,
    }));
    const island = new THREE.Mesh(islandGeometry, islandMaterial);
    island.position.set(-8, 1.2, -28);
    island.rotation.z = Math.PI;
    add(island);
    add(new THREE.HemisphereLight(0x617cc9, 0x02040c, 2.4));
    const nursery = new THREE.PointLight(0xf0bf70, coarse ? 8 : 13, 15, 2);
    nursery.position.set(0, 4.8, -5);
    add(nursery);
    cameraStart = new THREE.Vector3(0, 2.2, 8.2);
    cameraTarget = new THREE.Vector3(0, 3, -8);
  }

  group.traverse((object) => {
    if (object.isMesh) {
      object.castShadow = false;
      object.receiveShadow = false;
    }
  });
  if (storyPage) {
    storyPage.userData.action = "bookMoment";
    storyPage.userData.label = `${spec.title}'s living Page`;
  }

  return {
    group,
    spec,
    background,
    fog,
    cameraStart,
    cameraTarget,
    interaction: storyPage,
    standPoint,
    bounds: { x: [-7.5, 7.5], z: [-1, 10.5] },
    update(dt, now, camera, cinematic = false) {
      const seconds = now * .001;
      animated.forEach((item) => {
        if (item.type === "panel") {
          item.mesh.position.y += Math.sin(seconds * .7) * dt * .025;
        }
        if (item.type === "backdrop") {
          item.mesh.position.x = item.originX + Math.sin(seconds * .08) * .12;
        }
        if (item.type === "chandelier" && item.mesh) {
          item.mesh.rotation.y += dt * .08;
        }
        if (item.type === "candle") {
          item.light.intensity *= .97 + Math.sin(seconds * 8 + item.seed) * .03;
          item.light.intensity = clamp(item.light.intensity, coarse ? 5 : 8, coarse ? 9 : 14);
        }
        if (item.type === "rain") {
          const position = item.mesh.geometry.attributes.position;
          for (let i = 0; i < position.count; i += 1) {
            let y = position.getY(i) - dt * (7 + (i % 7));
            if (y < 0) y = 15;
            position.setY(i, y);
          }
          position.needsUpdate = true;
        }
        if (item.type === "lightning") {
          const strike = Math.sin(seconds * .71) > .992 || Math.sin(seconds * 1.93) > .998;
          item.light.intensity = strike ? 8 : .55 + Math.sin(seconds * .6) * .12;
        }
        if (item.type === "clock" && item.mesh) {
          item.mesh.rotation.z = Math.sin(seconds * .25) * .015;
        }
        if (item.type === "stars") {
          item.mesh.rotation.y += dt * .012;
        }
      });
      if (cinematic) {
        const sway = coarse ? .035 : .09;
        camera.position.x = cameraStart.x + Math.sin(seconds * .22) * sway;
        camera.position.y = cameraStart.y + Math.sin(seconds * .31) * sway * .45;
        camera.position.z = cameraStart.z + Math.cos(seconds * .17) * sway;
        camera.lookAt(cameraTarget);
      }
    },
    dispose() {
      owned.forEach((item) => item?.dispose?.());
    },
  };
}

function textTexture(title, detail, colors) {
  const canvas = document.createElement("canvas");
  canvas.width = 1024;
  canvas.height = 576;
  const context = canvas.getContext("2d");
  const [paper, ink, accent] = colors;
  const gradient = context.createLinearGradient(0, 0, 1024, 576);
  gradient.addColorStop(0, paper);
  gradient.addColorStop(1, shade(paper, -.14));
  context.fillStyle = gradient;
  context.fillRect(0, 0, 1024, 576);
  context.globalAlpha = .1;
  context.strokeStyle = ink;
  for (let i = 0; i < 72; i += 1) {
    const y = Math.random() * 576;
    context.beginPath();
    context.moveTo(0, y);
    context.bezierCurveTo(280, y + Math.random() * 8, 740, y - Math.random() * 8, 1024, y);
    context.stroke();
  }
  context.globalAlpha = 1;
  context.strokeStyle = accent;
  context.lineWidth = 3;
  context.strokeRect(42, 42, 940, 492);
  context.fillStyle = accent;
  context.font = "700 26px ui-sans-serif, system-ui";
  context.letterSpacing = "4px";
  context.fillText(title.toUpperCase(), 82, 108);
  context.fillStyle = ink;
  context.font = "italic 54px Georgia, serif";
  wrapText(context, `“${detail}”`, 82, 210, 860, 69, 4);
  context.fillStyle = accent;
  context.font = "32px Georgia, serif";
  context.fillText("✦", 82, 486);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = 4;
  return texture;
}

function wrapText(context, text, x, y, maxWidth, lineHeight, maxLines) {
  const words = text.split(/\s+/);
  let line = "";
  let lines = 0;
  for (let index = 0; index < words.length; index += 1) {
    const test = line ? `${line} ${words[index]}` : words[index];
    if (context.measureText(test).width > maxWidth && line) {
      context.fillText(line, x, y + lines * lineHeight);
      line = words[index];
      lines += 1;
      if (lines >= maxLines - 1) break;
    } else {
      line = test;
    }
  }
  if (line && lines < maxLines) {
    const remaining = lines === maxLines - 1 && words.join(" ").length > line.length ? `${line}…` : line;
    context.fillText(remaining, x, y + lines * lineHeight);
  }
}

function shade(hex, amount) {
  const color = new THREE.Color(hex);
  color.offsetHSL(0, 0, amount);
  return `#${color.getHexString()}`;
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value));
}

function mulberry32(seed) {
  return function random() {
    let value = seed += 0x6D2B79F5;
    value = Math.imul(value ^ value >>> 15, value | 1);
    value ^= value + Math.imul(value ^ value >>> 7, value | 61);
    return ((value ^ value >>> 14) >>> 0) / 4294967296;
  };
}
