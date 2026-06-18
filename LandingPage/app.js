const root = document.documentElement;
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function updateScene() {
  const max = Math.max(1, document.body.scrollHeight - window.innerHeight);
  root.style.setProperty("--scroll", String(Math.min(1, window.scrollY / max)));
}

window.addEventListener("scroll", updateScene, { passive: true });
updateScene();

window.addEventListener("pointermove", (event) => {
  const x = event.clientX / window.innerWidth - 0.5;
  const y = event.clientY / window.innerHeight - 0.5;
  root.style.setProperty("--mx", x.toFixed(3));
  root.style.setProperty("--my", y.toFixed(3));
});

document.querySelectorAll(".choice-pill").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".choice-pill").forEach((pill) => pill.classList.remove("active"));
    button.classList.add("active");
  });
});

async function initThreeField() {
  if (reduceMotion) return;

  const canvas = document.querySelector("#spell-field");
  if (!canvas) return;

  try {
    const THREE = await import("https://unpkg.com/three@0.161.0/build/three.module.js");
    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 100);
    camera.position.z = 8;

    const count = 140;
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const gold = new THREE.Color("#ffc76f");
    const teal = new THREE.Color("#2aa3a3");

    for (let i = 0; i < count; i += 1) {
      const radius = 2.2 + Math.random() * 6;
      const angle = Math.random() * Math.PI * 2;
      positions[i * 3] = Math.cos(angle) * radius;
      positions[i * 3 + 1] = Math.sin(angle) * radius * 0.7;
      positions[i * 3 + 2] = -Math.random() * 5;

      const color = Math.random() > 0.78 ? teal : gold;
      colors[i * 3] = color.r;
      colors[i * 3 + 1] = color.g;
      colors[i * 3 + 2] = color.b;
    }

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));

    const material = new THREE.PointsMaterial({
      size: 0.035,
      vertexColors: true,
      transparent: true,
      opacity: 0.82,
      depthWrite: false,
    });

    const points = new THREE.Points(geometry, material);
    scene.add(points);

    function resize() {
      const width = window.innerWidth;
      const height = window.innerHeight;
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      renderer.setSize(width, height, false);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
    }

    function tick(time) {
      points.rotation.z = time * 0.000045 + window.scrollY * 0.00008;
      points.rotation.x = Math.sin(time * 0.00018) * 0.05;
      renderer.render(scene, camera);
      requestAnimationFrame(tick);
    }

    window.addEventListener("resize", resize);
    resize();
    requestAnimationFrame(tick);
  } catch {
    canvas.remove();
  }
}

initThreeField();
