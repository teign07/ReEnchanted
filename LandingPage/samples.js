(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const requested = new URLSearchParams(location.search).get('issue');
  const issueID = requested === 'monthly' ? 'monthly' : 'weekly';
  let issue, manifest, current = 0;
  const status = message => { $('reader-status').textContent = message; };
  function requestedPage() {
    const value = Number(new URLSearchParams(location.hash.slice(1)).get('page'));
    return Number.isInteger(value) && value > 0 ? value - 1 : 0;
  }
  function showPage(index, updateURL = true) {
    current = Math.max(0, Math.min(issue.pages.length - 1, index));
    const page = issue.pages[current];
    $('previous').disabled = current === 0;
    $('next').disabled = current === issue.pages.length - 1;
    $('page-picker').value = String(current);
    $('page-image').alt = `${issue.title}, Page ${current + 1} of ${issue.pages.length}`;
    $('page-image').hidden = false;
    $('page-image').src = page.image;
    $('page-text').textContent = page.text || 'This is an illustrated Page. The downloadable PDF preserves its full layout.';
    status(`Page ${current + 1} of ${issue.pages.length}`);
    if (updateURL) history.replaceState(null, '', `?issue=${issueID}#page=${current + 1}`);
    // Only the next Page is prefetched; a monthly issue need not download all
    // its illustrated leaves before somebody has decided to read it.
    if (issue.pages[current + 1]) { const next = new Image(); next.src = issue.pages[current + 1].image; }
  }
  $('previous').addEventListener('click', () => showPage(current - 1));
  $('next').addEventListener('click', () => showPage(current + 1));
  $('page-picker').addEventListener('change', event => showPage(Number(event.target.value)));
  $('zoom').addEventListener('click', () => {
    const large = $('page-window').classList.toggle('is-large');
    $('zoom').setAttribute('aria-pressed', String(large));
    $('zoom').textContent = large ? 'Fit Page' : 'Larger Page';
  });
  $('page-image').addEventListener('error', () => status('This Page could not load. Try the PDF above, or reload the Page.'));
  document.addEventListener('keydown', event => {
    if (!issue || event.altKey || event.ctrlKey || event.metaKey || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(event.target.tagName)) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault(); showPage(current + (event.key === 'ArrowLeft' ? -1 : 1));
    }
  });
  window.addEventListener('hashchange', () => {
    if (issue && location.hash.startsWith('#page=')) showPage(requestedPage(), false);
  });
  async function open() {
    const response = await fetch('./assets/samples/catalogue.json', {cache: 'no-cache'});
    if (!response.ok) throw new Error('No sample catalogue');
    manifest = await response.json(); issue = manifest.issues[issueID];
    if (!issue?.pages?.length) throw new Error('No sample Pages');
    document.title = `${issue.title} · ReEnchanted`;
    $('issue-title').textContent = issue.title;
    $('issue-description').textContent = issue.description;
    document.querySelector(`[data-issue="${issueID}"]`).setAttribute('aria-current', 'page');
    for (const id of ['download-pdf', 'open-pdf']) { $(id).href = issue.pdf; $(id).hidden = false; }
    $('download-pdf').textContent = `Keep the PDF ↓ · ${issue.sizeLabel}`;
    issue.pages.forEach((page, index) => {
      const option = document.createElement('option'); option.value = index;
      option.textContent = `${index + 1} / ${issue.pages.length}`; $('page-picker').append(option);
    });
    $('page-picker').disabled = false;
    for (const [kind, book] of Object.entries(manifest.issues)) {
      if (!book.braidPage) continue;
      const link = document.createElement('a');
      link.href = `?issue=${kind}#page=${book.braidPage}`;
      link.textContent = `“The bakery” in the ${kind === 'weekly' ? 'week' : 'month'} · Page ${book.braidPage} ↗`;
      $('braid-pages').append(link);
    }
    for (const page of manifest.keptPages) {
      const article = document.createElement('article'); article.className = 'source-page';
      const label = document.createElement('p'); label.className = 'source-label'; label.textContent = page.label;
      const body = document.createElement('blockquote'); body.textContent = page.text;
      article.append(label, body); $('source-pages').append(article);
    }
    for (const sheet of manifest.pagewright) {
      const figure = document.createElement('figure'), link = document.createElement('a');
      link.href = sheet.image; link.target = '_blank'; link.rel = 'noopener';
      const image = document.createElement('img'); image.src = sheet.image; image.alt = sheet.alt; image.loading = 'lazy';
      const caption = document.createElement('figcaption'); caption.textContent = `${sheet.title} · Open the kept sheet ↗`;
      link.append(image); figure.append(link, caption); $('pagewright-sheets').append(figure);
    }
    $('sample-provenance').textContent = manifest.provenance;
    showPage(requestedPage(), false);
  }
  open().catch(() => {
    $('issue-title').textContent = 'The binding didn’t open.';
    status('Please reload, or return to the living Book and try again.');
  });
})();
