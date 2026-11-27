<?php
/** Catálogo público compartido. No contiene identidades ni credenciales. */
function province_catalog(): array
{
    static $catalog = null;
    if ($catalog === null) {
        $raw = file_get_contents(__DIR__ . '/../../shared/province_routes.json');
        $catalog = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
    }
    return $catalog;
}

function province_fare_cents(string $qrType): ?int
{
    foreach (province_catalog()['routes'] as $route) {
        if ('provincia_' . $route['id'] === $qrType
            && in_array($route['status'], ['piloto', 'verificada'], true)
            && is_int($route['fare_cents']) && $route['fare_cents'] > 0) {
            return $route['fare_cents'];
        }
    }
    return null;
}
