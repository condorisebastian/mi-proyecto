-- Generado por tools/generate_routes.py desde shared/province_routes.json.
-- Importar explícitamente al inicializar el catálogo. No modifica saldos ni cuentas.
begin;
with source as (select $catalog${
  "version": "2026-10-22.1",
  "origin": "Santa Cruz de la Sierra",
  "currency": "BOB",
  "notice": "Tarifa por verificar. Los destinos se muestran para consulta; los cobros provinciales se habilitarán al confirmar el importe, el servicio y la vigencia.",
  "reference_url": "https://gacetaoficial.santacruz.gob.bo/verpdf/decreto-departamental-no-494",
  "routes": [
    {
      "id": "la_guardia",
      "destination": "La Guardia",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "cotoca",
      "destination": "Cotoca",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "el_torno",
      "destination": "El Torno",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "porongo",
      "destination": "Porongo",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "warnes",
      "destination": "Warnes",
      "province": "Warnes",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "okinawa_uno",
      "destination": "Okinawa Uno",
      "province": "Warnes",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "montero",
      "destination": "Montero",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "general_saavedra",
      "destination": "General Saavedra",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "minero",
      "destination": "Minero",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "pailon",
      "destination": "Pailón",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_jose",
      "destination": "San José de Chiquitos",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "robore",
      "destination": "Roboré",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "portachuelo",
      "destination": "Portachuelo",
      "province": "Sara",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "cuatro_canadas",
      "destination": "Cuatro Cañadas",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_javier",
      "destination": "San Javier",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "concepcion",
      "destination": "Concepción",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "buena_vista",
      "destination": "Buena Vista",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_carlos",
      "destination": "San Carlos",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "yapacani",
      "destination": "Yapacaní",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "samaipata",
      "destination": "Samaipata",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "mairana",
      "destination": "Mairana",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "pampa_grande",
      "destination": "Pampa Grande",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "comarapa",
      "destination": "Comarapa",
      "province": "Manuel María Caballero",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "vallegrande",
      "destination": "Vallegrande",
      "province": "Vallegrande",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "camiri",
      "destination": "Camiri",
      "province": "Cordillera",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_ignacio",
      "destination": "San Ignacio de Velasco",
      "province": "José Miguel de Velasco",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "puerto_suarez",
      "destination": "Puerto Suárez",
      "province": "Germán Busch",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_matias",
      "destination": "San Matías",
      "province": "Ángel Sandóval",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "ascension_guarayos",
      "destination": "Ascensión de Guarayos",
      "province": "Guarayos",
      "fare_cents": null,
      "status": "pendiente"
    }
  ],
  "geography_reference_url": "https://gacetaoficial.santacruz.gob.bo/verpdf/decreto-departamental-415"
}$catalog$::jsonb as data)
insert into public.web_catalog_meta (id, version, origin, currency, notice)
select true, data->>'version', data->>'origin', data->>'currency', data->>'notice' from source
on conflict (id) do update set version=excluded.version, origin=excluded.origin,
currency=excluded.currency, notice=excluded.notice;

with source as (select $catalog${
  "version": "2026-10-22.1",
  "origin": "Santa Cruz de la Sierra",
  "currency": "BOB",
  "notice": "Tarifa por verificar. Los destinos se muestran para consulta; los cobros provinciales se habilitarán al confirmar el importe, el servicio y la vigencia.",
  "reference_url": "https://gacetaoficial.santacruz.gob.bo/verpdf/decreto-departamental-no-494",
  "routes": [
    {
      "id": "la_guardia",
      "destination": "La Guardia",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "cotoca",
      "destination": "Cotoca",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "el_torno",
      "destination": "El Torno",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "porongo",
      "destination": "Porongo",
      "province": "Andrés Ibáñez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "warnes",
      "destination": "Warnes",
      "province": "Warnes",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "okinawa_uno",
      "destination": "Okinawa Uno",
      "province": "Warnes",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "montero",
      "destination": "Montero",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "general_saavedra",
      "destination": "General Saavedra",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "minero",
      "destination": "Minero",
      "province": "Obispo Santistevan",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "pailon",
      "destination": "Pailón",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_jose",
      "destination": "San José de Chiquitos",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "robore",
      "destination": "Roboré",
      "province": "Chiquitos",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "portachuelo",
      "destination": "Portachuelo",
      "province": "Sara",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "cuatro_canadas",
      "destination": "Cuatro Cañadas",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_javier",
      "destination": "San Javier",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "concepcion",
      "destination": "Concepción",
      "province": "Ñuflo de Chávez",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "buena_vista",
      "destination": "Buena Vista",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_carlos",
      "destination": "San Carlos",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "yapacani",
      "destination": "Yapacaní",
      "province": "Ichilo",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "samaipata",
      "destination": "Samaipata",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "mairana",
      "destination": "Mairana",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "pampa_grande",
      "destination": "Pampa Grande",
      "province": "Florida",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "comarapa",
      "destination": "Comarapa",
      "province": "Manuel María Caballero",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "vallegrande",
      "destination": "Vallegrande",
      "province": "Vallegrande",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "camiri",
      "destination": "Camiri",
      "province": "Cordillera",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_ignacio",
      "destination": "San Ignacio de Velasco",
      "province": "José Miguel de Velasco",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "puerto_suarez",
      "destination": "Puerto Suárez",
      "province": "Germán Busch",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "san_matias",
      "destination": "San Matías",
      "province": "Ángel Sandóval",
      "fare_cents": null,
      "status": "pendiente"
    },
    {
      "id": "ascension_guarayos",
      "destination": "Ascensión de Guarayos",
      "province": "Guarayos",
      "fare_cents": null,
      "status": "pendiente"
    }
  ],
  "geography_reference_url": "https://gacetaoficial.santacruz.gob.bo/verpdf/decreto-departamental-415"
}$catalog$::jsonb as data)
insert into public.web_routes (id, destination, province, fare_cents, status, sort_order, published)
select entry->>'id', entry->>'destination', entry->>'province',
(entry->>'fare_cents')::integer, entry->>'status', position::integer, true
from source, jsonb_array_elements(data->'routes') with ordinality as routes(entry, position)
on conflict (id) do update set destination=excluded.destination, province=excluded.province,
fare_cents=excluded.fare_cents, status=excluded.status, sort_order=excluded.sort_order,
published=excluded.published;
commit;
