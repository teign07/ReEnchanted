/* One close-look viewer for the Book, its marginalia, and sample issues. */
(() => {
  'use strict';
  const viewer = document.createElement('dialog');
  viewer.className = 'image-viewer';
  viewer.id = 'image-viewer';
  viewer.setAttribute('aria-labelledby', 'image-viewer-caption');
  viewer.innerHTML = `<div class="image-viewer-inner">
    <header class="image-viewer-header"><p id="image-viewer-caption"></p><button type="button" data-image-close aria-label="Close picture and return">×</button></header>
    <nav class="image-viewer-tools" aria-label="Picture zoom">
      <button type="button" data-image-fit>Fit</button><button type="button" data-image-actual>100%</button>
      <button type="button" data-image-minus aria-label="Zoom out">−</button><output aria-live="polite" aria-label="Zoom level"></output><button type="button" data-image-plus aria-label="Zoom in">+</button>
      <a target="_blank" rel="noopener" data-image-original>Open image ↗</a>
    </nav>
    <div class="image-viewer-stage" tabindex="0" aria-label="Picture, scroll to explore"><div class="image-viewer-canvas"><img alt=""></div></div>
  </div>`;
  document.body.append(viewer);
  const image = viewer.querySelector('img');
  const pane = viewer.querySelector('.image-viewer-stage');
  const caption = viewer.querySelector('#image-viewer-caption');
  const zoom = viewer.querySelector('output');
  let scale = 1, fitted = true, returnFocus = null, previousOverflow = '';

  function description(source) {
    if (source.alt?.trim()) return source.alt.trim();
    const drawing = [...(window.PublicMarginalia?.marks || []), ...(window.PublicMarginalia?.notes || []), ...(window.PublicMarginalia?.seasonal || [])]
      .find(mark => new URL(mark.src, document.baseURI).href === source.src);
    return drawing?.alt || source.closest('figure')?.querySelector('figcaption')?.textContent.trim() || 'A picture from the Book';
  }
  function eligible(source) {
    return source instanceof HTMLImageElement && source.getAttribute('src') &&
      !source.closest('#image-viewer, .book-atmosphere, .room-pixie, .monthly-cover-face, .is-cover, [data-kind="cover"], [inert]') &&
      !source.classList.contains('leaf-watermark') &&
      (!source.closest('button') || source.closest('[data-plate]'));
  }
  function size(value, center = false) {
    if (!image.naturalWidth) return;
    const x = (pane.scrollLeft + pane.clientWidth / 2) / pane.scrollWidth;
    const y = (pane.scrollTop + pane.clientHeight / 2) / pane.scrollHeight;
    scale = Math.max(.1, Math.min(4, value));
    image.style.width = `${image.naturalWidth * scale}px`;
    image.style.height = `${image.naturalHeight * scale}px`;
    zoom.value = `${Math.round(scale * 100)}%`;
    viewer.querySelector('[data-image-minus]').disabled = scale <= .1;
    viewer.querySelector('[data-image-plus]').disabled = scale >= 4;
    if (center) {
      pane.scrollLeft = x * pane.scrollWidth - pane.clientWidth / 2;
      pane.scrollTop = y * pane.scrollHeight - pane.clientHeight / 2;
    } else {
      pane.scrollLeft = Math.max(0, (pane.scrollWidth - pane.clientWidth) / 2);
      pane.scrollTop = 0;
    }
  }
  function fit() {
    fitted = true;
    if (image.naturalWidth) size(Math.min(2, (pane.clientWidth - 48) / image.naturalWidth, (pane.clientHeight - 48) / image.naturalHeight));
  }
  function actual() { fitted = false; size(1); }
  function open(source) {
    if (!eligible(source)) return;
    if (!viewer.open) {
      returnFocus = document.activeElement;
      previousOverflow = document.body.style.overflow;
      viewer.showModal();
      document.body.style.overflow = 'hidden';
    }
    const label = description(source);
    caption.textContent = label;
    caption.title = label;
    image.alt = label;
    image.style.width = image.style.height = '';
    image.src = source.currentSrc || source.src;
    viewer.querySelector('[data-image-original]').href = image.src;
    fitted = true;
    fit();
    viewer.querySelector('[data-image-close]').focus({preventScroll: true});
  }
  image.addEventListener('load', () => { if (fitted) fit(); });
  image.addEventListener('click', () => { if (fitted) actual(); else fit(); });
  image.addEventListener('error', () => { caption.textContent = 'The picture didn’t open. Try “Open image” above.'; });
  viewer.querySelector('[data-image-close]').addEventListener('click', () => viewer.close());
  viewer.querySelector('[data-image-fit]').addEventListener('click', fit);
  viewer.querySelector('[data-image-actual]').addEventListener('click', actual);
  viewer.querySelector('[data-image-minus]').addEventListener('click', () => { fitted = false; size(scale / 1.25, true); });
  viewer.querySelector('[data-image-plus]').addEventListener('click', () => { fitted = false; size(scale * 1.25, true); });
  viewer.addEventListener('click', event => {
    if (event.target !== viewer) return;
    const bounds = viewer.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) viewer.close();
  });
  viewer.addEventListener('close', () => {
    document.body.style.overflow = previousOverflow;
    if (returnFocus?.isConnected) returnFocus.focus({preventScroll: true});
  });
  window.addEventListener('resize', () => { if (viewer.open && fitted) fit(); });

  function prepare(root) {
    const images = root instanceof HTMLImageElement ? [root] : [...(root.querySelectorAll?.('img') || [])];
    for (const source of images) {
      if (!eligible(source)) continue;
      source.dataset.imageOpen = '';
      const link = source.closest('a');
      const directLink = link && link.href === source.src;
      if (directLink) {
        link.dataset.imageLink = '';
        link.setAttribute('aria-haspopup', 'dialog');
        link.setAttribute('aria-label', `Look closer: ${description(source)}`);
      } else if (!source.closest('a, button')) {
        source.tabIndex = 0;
        source.setAttribute('role', 'button');
        source.setAttribute('aria-haspopup', 'dialog');
        source.setAttribute('aria-label', `Look closer: ${description(source)}`);
        source.removeAttribute('aria-hidden');
      }
    }
  }
  function clickedImage(event) {
    const target = event.target instanceof Element ? event.target : null;
    return target?.closest('img') || target?.closest('[data-image-link], [data-plate]')?.querySelector('img');
  }
  // Stop a picture tap becoming a page turn or a link to another surface.
  for (const type of ['pointerdown', 'mousedown', 'touchstart']) document.addEventListener(type, event => {
    if (eligible(clickedImage(event))) event.stopPropagation();
  }, {capture: true, passive: true});
  document.addEventListener('click', event => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const source = clickedImage(event);
    if (!eligible(source)) return;
    event.preventDefault(); event.stopPropagation(); open(source);
  }, true);
  document.addEventListener('keydown', event => {
    if (!['Enter', ' '].includes(event.key)) return;
    const source = clickedImage(event);
    if (!eligible(source)) return;
    event.preventDefault(); event.stopPropagation(); open(source);
  }, true);
  prepare(document);
  new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes') prepare(record.target);
      else for (const node of record.addedNodes) if (node instanceof Element) prepare(node);
    }
  }).observe(document.body, {subtree: true, childList: true, attributes: true, attributeFilter: ['src', 'alt']});
  window.PublicImageViewer = {open, isOpen: () => viewer.open};
})();
