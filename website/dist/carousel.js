const byId = id => document.getElementById(id);

export function startCarousel(photos, onProvince) {
  if (!photos.length) return;
  const region = byId('destination-carousel');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let index = 0;
  let paused = reducedMotion.matches;
  let timer;
  let hovering = false;
  let focusing = false;
  let requestedIndex = 0;
  let requestVersion = 0;
  let outgoing;
  let fade;
  const preloaded = new Map();

  function prepare(photo) {
    if (!preloaded.has(photo.path)) {
      const pending = new Image();
      pending.src = photo.path;
      const ready = pending.decode().catch(error => {
        preloaded.delete(photo.path);
        throw error;
      });
      preloaded.set(photo.path, ready);
    }
    return preloaded.get(photo.path);
  }

  function schedule() {
    clearTimeout(timer);
    if (!paused && !reducedMotion.matches && !document.hidden && !hovering && !focusing) {
      timer = setTimeout(() => show(requestedIndex + 1, 'automatic'), 3000);
    }
  }
  async function show(next, source = 'initial') {
    clearTimeout(timer);
    const target = (next + photos.length) % photos.length;
    requestedIndex = target;
    const version = ++requestVersion;
    const photo = photos[target];
    try {
      await prepare(photo);
    } catch {
      if (version === requestVersion) {
        byId('photo-status').textContent = 'No se pudo cargar esta fotografía. Puedes seguir recorriendo las provincias.';
        schedule();
      }
      return;
    }
    if (version !== requestVersion) return;
    if (source === 'automatic' && (paused || hovering || focusing || document.hidden)) {
      requestedIndex = index;
      return;
    }
    const image = byId('destination-photo');
    fade?.cancel();
    outgoing?.remove();
    const animate = target !== index && !image.hidden && !reducedMotion.matches && typeof image.animate === 'function';
    if (animate) {
      outgoing = image.cloneNode();
      outgoing.removeAttribute('id');
      outgoing.setAttribute('aria-hidden', 'true');
      outgoing.alt = '';
      outgoing.className = 'destination-photo-outgoing';
      image.parentElement.append(outgoing);
    }
    index = target;
    image.src = photo.path;
    image.alt = photo.alt;
    byId('destination-name').textContent = photo.province;
    byId('destination-place').textContent = photo.place;
    byId('destination-municipalities').textContent = photo.destinations.join(' · ');
    byId('destination-count').textContent = `${String(index + 1).padStart(2, '0')} / ${photos.length}`;
    byId('destination-source').href = photo.page_url;
    byId('destination-source').textContent = `Foto: ${photo.author} · ${photo.license}`;
    byId('destination-license').href = photo.license_url;
    byId('destination-select').value = String(index);
    byId('destination-link').onclick = () => onProvince(photo.province);
    byId('photo-status').textContent = '';
    if (animate) {
      const previous = outgoing;
      fade = previous.animate([{opacity: 1}, {opacity: 0}], {duration: 650, easing: 'ease-in-out', fill: 'forwards'});
      fade.onfinish = () => previous.remove();
      byId('destination-caption').animate([{opacity: 0.3}, {opacity: 1}], {duration: 500, easing: 'ease-out'});
    }
    region.dispatchEvent(new CustomEvent('transita:destinationchange', {
      bubbles: true, detail: {index, province: photo.province, place: photo.place, source},
    }));
    schedule();
    void prepare(photos[(index + 1) % photos.length]).catch(() => {});
  }
  function updatePlayback() {
    byId('destination-play').textContent = reducedMotion.matches ? 'Modo manual' : paused ? 'Reproducir' : 'Pausar';
    byId('destination-play').disabled = reducedMotion.matches;
    byId('destination-play').setAttribute('aria-pressed', String(!paused));
    byId('destination-caption').setAttribute('aria-live', paused ? 'polite' : 'off');
  }
  for (const [position, photo] of photos.entries()) {
    const option = document.createElement('option');
    option.value = position;
    option.textContent = photo.province;
    byId('destination-select').append(option);
  }
  byId('destination-select').addEventListener('change', event => show(Number(event.target.value), 'select'));
  byId('destination-prev').addEventListener('click', () => show(requestedIndex - 1, 'previous'));
  byId('destination-next').addEventListener('click', () => show(requestedIndex + 1, 'next'));
  byId('destination-play').addEventListener('click', () => {
    paused = !paused;
    if (!paused) {hovering = false; focusing = false;}
    updatePlayback();
    schedule();
  });
  region.addEventListener('mouseenter', () => {hovering = true; schedule();});
  region.addEventListener('mouseleave', () => {hovering = false; schedule();});
  region.addEventListener('focusin', () => {focusing = true; schedule();});
  region.addEventListener('focusout', event => {
    focusing = region.contains(event.relatedTarget);
    schedule();
  });
  document.addEventListener('visibilitychange', schedule);
  reducedMotion.addEventListener('change', () => {
    paused = reducedMotion.matches;
    updatePlayback();
    schedule();
  });
  updatePlayback();
  byId('destination-photo').addEventListener('error', () => {
    byId('destination-photo').hidden = true;
    byId('photo-status').textContent = 'No se pudo cargar la fotografía. Puedes seguir consultando los destinos.';
  });
  byId('destination-photo').addEventListener('load', () => {
    byId('destination-photo').hidden = false;
    byId('photo-status').textContent = '';
  });
  show(0);
}
