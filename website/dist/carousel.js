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

  function schedule() {
    clearTimeout(timer);
    if (!paused && !reducedMotion.matches && !document.hidden && !hovering && !focusing) {
      timer = setTimeout(() => show(index + 1), 5000);
    }
  }
  function show(next) {
    index = (next + photos.length) % photos.length;
    const photo = photos[index];
    const image = byId('destination-photo');
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
    schedule();
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
  byId('destination-select').addEventListener('change', event => show(Number(event.target.value)));
  byId('destination-prev').addEventListener('click', () => show(index - 1));
  byId('destination-next').addEventListener('click', () => show(index + 1));
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
