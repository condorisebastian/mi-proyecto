"""Genera el catálogo público para Flutter y la web desde una única fuente."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def supabase_seed(raw):
    if '$catalog$' in raw:
        raise ValueError('Separador SQL no permitido en el catálogo')
    return '''-- Generado por tools/generate_routes.py desde shared/province_routes.json.
-- Importar explícitamente al inicializar el catálogo. No modifica saldos ni cuentas.
begin;
with source as (select $catalog$''' + raw.strip() + '''$catalog$::jsonb as data)
insert into public.web_catalog_meta (id, version, origin, currency, notice)
select true, data->>'version', data->>'origin', data->>'currency', data->>'notice' from source
on conflict (id) do update set version=excluded.version, origin=excluded.origin,
currency=excluded.currency, notice=excluded.notice;

with source as (select $catalog$''' + raw.strip() + '''$catalog$::jsonb as data)
insert into public.web_routes (id, destination, province, fare_cents, status, sort_order, published)
select entry->>'id', entry->>'destination', entry->>'province',
(entry->>'fare_cents')::integer, entry->>'status', position::integer, true
from source, jsonb_array_elements(data->'routes') with ordinality as routes(entry, position)
on conflict (id) do update set destination=excluded.destination, province=excluded.province,
fare_cents=excluded.fare_cents, status=excluded.status, sort_order=excluded.sort_order,
published=excluded.published;
commit;
'''


def generate(check=False):
    raw = (ROOT / 'shared/province_routes.json').read_text(encoding='utf-8')
    data = json.loads(raw)
    ids = set()
    for route in data['routes']:
        if route['id'] in ids or not route['id'].replace('_', '').isalnum():
            raise ValueError('Identificador de ruta inválido o duplicado')
        ids.add(route['id'])
        fare = route['fare_cents']
        if fare is not None and (type(fare) is not int or fare <= 0):
            raise ValueError('Importe inválido')
        if (fare is None) != (route['status'] == 'pendiente'):
            raise ValueError('Estado de tarifa incoherente')
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    dart = '// Generado por tools/generate_routes.py. Editar shared/province_routes.json.\n'
    dart += "import '../models/province_route.dart';\n\n"
    dart += 'const provinceRoutes = <ProvinceRoute>[\n'
    for route in data['routes']:
        dart += '  ProvinceRoute(\n'
        for key in ('id', 'destination', 'province'):
            dart += f'    {key}: {quote(route[key])},\n'
        dart += f"    fareCents: {route['fare_cents'] if route['fare_cents'] is not None else 'null'},\n"
        dart += '  ),\n'
    dart += '];\n'
    outputs = {
        ROOT / 'transita_bolivia/lib/data/province_routes.dart': dart,
        ROOT / 'website/dist/routes.json': raw,
        ROOT / 'transita_bolivia/functions/province_routes.json': raw,
        ROOT / 'website/supabase/seed.sql': supabase_seed(raw),
    }
    for path, content in outputs.items():
        if check:
            # dart format puede cambiar comillas y espacios; el contenido JSON
            # se verifica por separado y los modelos se validan en Flutter.
            if path.suffix in ('.json', '.sql') and (not path.exists() or path.read_text(encoding='utf-8') != content):
                raise SystemExit('Catálogo web desactualizado; ejecutar tools/generate_routes.py')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding='utf-8', newline='\n')
    print(f"Catálogo: {len(ids)} destinos, {len({r['province'] for r in data['routes']})} provincias.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    generate(parser.parse_args().check)
