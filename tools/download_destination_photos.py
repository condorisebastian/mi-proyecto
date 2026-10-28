"""Descarga las fotos revisadas del carrusel con sus licencias de Commons."""
import concurrent.futures
import hashlib
import html
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADERS = {'User-Agent': 'TransitaBolivia/1.0 (educational transport project)'}


def request(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=25) as response:
                return response.read()
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(1 + attempt)


def clean(value):
    return ' '.join(html.unescape(re.sub('<[^>]+>', '', str(value))).split())


def main():
    sources = json.loads((ROOT / 'website/photo_sources.json').read_text(encoding='utf-8'))
    catalog = json.loads((ROOT / 'shared/province_routes.json').read_text(encoding='utf-8'))
    params = dict(action='query', titles='|'.join(photo['title'] for photo in sources), prop='imageinfo',
                  iiprop='url|extmetadata|size|mime', iiurlwidth=1280, format='json')
    cache = ROOT / '.transita-private/photo-metadata.json'
    if cache.exists():
        data = json.loads(cache.read_text(encoding='utf-8'))
    else:
        data = json.loads(request('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(params)))
        cache.parent.mkdir(exist_ok=True)
        cache.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    pages = {page['title']: page for page in data['query']['pages'].values()}
    output = ROOT / 'website/dist/assets/destinations'
    output.mkdir(parents=True, exist_ok=True)

    def download(source):
        info = pages[source['title']]['imageinfo'][0]
        metadata = info['extmetadata']
        value = lambda name: clean(metadata.get(name, {}).get('value', ''))
        license_name = value('LicenseShortName')
        if not (license_name.startswith('CC BY') or license_name in ('CC0', 'Public domain')):
            raise ValueError('Revisar licencia: ' + source['title'])
        extension = { 'image/jpeg': '.jpg', 'image/png': '.png' }[info['mime']]
        filename = source['slug'] + extension
        image_url = info.get('thumburl', info['url'])
        target = output / filename
        if target.exists():
            content = target.read_bytes()
        else:
            try:
                content = request(image_url)
            except OSError:
                content = request(info['url'])
                image_url = info['url']
        if not (content.startswith(b'\xff\xd8\xff') or content.startswith(b'\x89PNG\r\n\x1a\n')):
            raise ValueError('La descarga no es una imagen: ' + source['slug'])
        (output / filename).write_bytes(content)
        credit = dict(source, path='assets/destinations/' + filename, page_url=info['descriptionurl'],
                      author=value('Artist'), license=license_name, license_url=value('LicenseUrl'),
                      original_url=info['url'], image_url=image_url,
                      sha256=hashlib.sha256(content).hexdigest(),
                      presentation='Miniatura de Wikimedia; encuadre visual con CSS, sin modificar el archivo.',
                      destinations=[r['destination'] for r in catalog['routes'] if r['province'] == source['province']])
        if not credit['license_url']:
            credit['license_url'] = 'https://creativecommons.org/publicdomain/zero/1.0/' if license_name == 'CC0' else 'https://creativecommons.org/publicdomain/mark/1.0/'
        print(source['slug'] + ': ' + str(len(content)) + ' bytes · ' + license_name, flush=True)
        return credit

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        credits = list(pool.map(download, sources))
    (output / 'credits.json').write_text(json.dumps(credits, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    rows = []
    for photo in credits:
        escaped = {key: html.escape(str(value), quote=True) for key, value in photo.items()}
        rows.append('<article><h2>{province}</h2><p>{place}</p><p>Foto: {author}. '
                    '<a href="{page_url}" rel="noopener noreferrer">Archivo original en Wikimedia Commons</a> · '
                    '<a href="{license_url}" rel="noopener noreferrer">{license}</a>.</p>'
                    '<p>{presentation}</p></article>'.format(**escaped))
    page = '<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    page += '<title>Créditos de fotografías · Transita Bolivia</title><link rel="stylesheet" href="styles.css">'
    page += '<main class="section"><a href="index.html">← Volver a Transita Bolivia</a><h1>Créditos de fotografías</h1>'
    page += '<p>Las fotografías representan lugares de cada provincia. Cada autor conserva los derechos y la licencia indicada.</p>'
    page += ''.join(rows) + '</main></html>'
    (ROOT / 'website/dist/credits.html').write_text(page + '\n', encoding='utf-8')
    print('Carrusel: 15 fotografías y créditos guardados.', flush=True)


if __name__ == '__main__':
    main()
