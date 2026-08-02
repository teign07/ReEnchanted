const overlay = document.querySelector("#first-fall");
const triggers = Array.from(document.querySelectorAll("[data-first-fall-open]"));

if (overlay && triggers.length) {
  const loading = overlay.querySelector("#first-fall-loading");
  const intake = overlay.querySelector("#first-fall-intake");
  const begin = overlay.querySelector("#first-fall-begin");
  const illustrated = overlay.querySelector("#first-fall-illustrated");
  const runtimeNote = overlay.querySelector("#first-fall-runtime-note");
  const detail = overlay.querySelector("#first-fall-detail");
  const name = overlay.querySelector("#first-fall-name");
  const exitButton = overlay.querySelector("#first-fall-exit");
  const replay = overlay.querySelector("#first-fall-replay");
  const finish = overlay.querySelector("[data-first-fall-finish]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const saveData = Boolean(navigator.connection?.saveData);
  let runtime = null;
  let opener = null;
  let modulePromise = null;

  function runtimeFailureMessage() {
    return location.protocol === "file:"
      ? "This world needs a local web server. Run python3 -m http.server 50123 --bind 127.0.0.1 --directory LandingPage, then open http://127.0.0.1:50123/."
      : "The experience bundle is unavailable. Refresh once and try again.";
  }

  function showRuntimeFailure() {
    const message = runtimeFailureMessage();
    overlay.querySelector("#first-fall-status").textContent = message;
    runtimeNote.textContent = message;
    runtimeNote.hidden = false;
    illustrated.textContent = "Retry loading the world";
  }

  function context() {
    return {
      detail: detail.value.trim(),
      name: name.value.trim() || "Reader",
      daypart: new Date().getHours() < 6 ? "night"
        : new Date().getHours() < 9 ? "dawn"
          : new Date().getHours() < 17 ? "day"
            : new Date().getHours() < 20 ? "dusk" : "night",
      month: new Date().toLocaleDateString("en-US", { month: "long" }),
      seed: Number(new Date().toISOString().slice(0, 10).replaceAll("-", "")),
    };
  }

  async function ensureRuntime() {
    modulePromise ||= import("./experience.js?v=11").catch((error) => {
      modulePromise = null;
      throw error;
    });
    const module = await modulePromise;
    runtime ||= module.createFirstFall(overlay, { close });
    return runtime;
  }

  async function open(event) {
    opener = event.currentTarget;
    overlay.hidden = false;
    document.body.classList.add("first-fall-open");
    window.dispatchEvent(new CustomEvent("reenchanted:immersive", { detail: { active: true } }));
    document.querySelectorAll("audio, video").forEach((media) => media.pause());
    loading.hidden = false;
    intake.hidden = true;
    try {
      await ensureRuntime();
      loading.hidden = true;
      intake.hidden = false;
      runtimeNote.hidden = true;
      illustrated.textContent = "Take the illustrated path";
      detail.focus();
    } catch (error) {
      console.error("The First Fall could not initialize.", error);
      loading.hidden = true;
      intake.hidden = false;
      showRuntimeFailure();
    }
  }

  async function start(mode) {
    const data = context();
    if (!data.detail) {
      detail.focus();
      detail.setAttribute("aria-invalid", "true");
      return;
    }
    detail.removeAttribute("aria-invalid");
    let active;
    try {
      active = await ensureRuntime();
      runtimeNote.hidden = true;
      illustrated.textContent = "Take the illustrated path";
    } catch (error) {
      console.error("The First Fall runtime is unavailable.", error);
      showRuntimeFailure();
      return;
    }
    if (mode === "illustrated" || reduceMotion || saveData) {
      active.startIllustrated(data);
      return;
    }
    try {
      await active.start(data);
    } catch (error) {
      console.error("The First Fall switched to its illustrated path.", error);
      active.startIllustrated(data);
    }
  }

  function close() {
    window.__reenchantedFirstFallRequested = null;
    runtime?.destroy();
    runtime = null;
    overlay.hidden = true;
    overlay.className = "first-fall";
    document.body.classList.remove("first-fall-open");
    window.dispatchEvent(new CustomEvent("reenchanted:immersive", { detail: { active: false } }));
    opener?.focus();
  }

  triggers.forEach((trigger) => trigger.addEventListener("click", open));
  begin.addEventListener("click", () => start("3d"));
  illustrated.addEventListener("click", () => start("illustrated"));
  exitButton.addEventListener("click", close);
  replay.addEventListener("click", () => {
    runtime?.reset();
    intake.hidden = false;
    detail.focus();
  });
  finish.addEventListener("click", close);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !overlay.hidden) close();
  });
  window.__reenchantedFirstFallReady = true;
  const requestedOpener = window.__reenchantedFirstFallRequested;
  if (requestedOpener) {
    window.__reenchantedFirstFallRequested = null;
    open({ currentTarget: requestedOpener });
  }
}
