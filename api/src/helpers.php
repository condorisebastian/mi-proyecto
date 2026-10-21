<?php
/** Helpers HTTP + JWT (HS256) compartido con el backend legacy. */

function json_out($data, int $code = 200): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function json_input(): array
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '[]', true);
    return is_array($data) ? $data : [];
}

function require_fields(array $body, array $fields): void
{
    foreach ($fields as $f) {
        if (!isset($body[$f]) || $body[$f] === '' || $body[$f] === null) {
            json_out(['error' => 'Faltan campos obligatorios'], 400);
        }
    }
}

function b64url_encode(string $s): string
{
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

function b64url_decode(string $s): string|false
{
    return base64_decode(strtr($s, '-_', '+/') . str_repeat('=', (4 - strlen($s) % 4) % 4), true);
}

function jwt_sign(array $payload, string $secret, int $ttl): string
{
    $payload['iat'] = time();
    $payload['exp'] = time() + $ttl;
    $header = b64url_encode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $body   = b64url_encode(json_encode($payload));
    $sig    = b64url_encode(hash_hmac('sha256', "$header.$body", $secret, true));
    return "$header.$body.$sig";
}

function jwt_verify(string $token, string $secret): ?array
{
    if (strlen($token) > 8192 || !preg_match('/^[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]{43}$/D', $token)) return null;
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $b, $s] = $parts;
    if ($h === '' || $b === '' || $s === '') return null;

    $headerBytes = b64url_decode($h);
    $payloadBytes = b64url_decode($b);
    if ($headerBytes === false || $payloadBytes === false) return null;
    $header = json_decode($headerBytes, true);
    $payload = json_decode($payloadBytes, true);
    if (!is_array($header) || ($header['alg'] ?? null) !== 'HS256'
        || ($header['typ'] ?? null) !== 'JWT' || !is_array($payload)) return null;

    $sig = b64url_encode(hash_hmac('sha256', "$h.$b", $secret, true));
    if (!hash_equals($sig, $s)) return null;

    if (!is_int($payload['exp'] ?? null) || !is_int($payload['iat'] ?? null)
        || $payload['exp'] <= time() || $payload['iat'] > time() + 60
        || $payload['exp'] <= $payload['iat']) return null;
    return $payload;
}

/** Devuelve la cabecera Authorization sin importar cómo la exponga el server. */
function http_auth_header(): string
{
    foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $k) {
        if (!empty($_SERVER[$k])) return (string)$_SERVER[$k];
    }
    if (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        if (isset($headers['Authorization'])) return $headers['Authorization'];
    }
    return '';
}

/**
 * Exige un JWT válido y devuelve su payload; si no hay token o es inválido
 * responde 401. El payload del pasajero trae `id` + `tipo`; el del conductor
 * trae `id` + `rol => 'conductor'`.
 */
function bearer_payload(string $secret): array
{
    $auth  = http_auth_header();
    $match = [];
    if (preg_match('/^Bearer\s+(.+)$/i', trim($auth), $match)) {
        $payload = jwt_verify(trim($match[1]), $secret);
        if (is_array($payload)) return $payload;
    }
    json_out(['error' => 'No autorizado'], 401);
    exit;
}

/** Un conductor nunca puede debitar la cuenta de un pasajero por su cuenta. */
function passenger_can_authorize_payment(array $payload, int $userId): bool
{
    return $userId > 0 && ($payload['id'] ?? null) === $userId
        && !isset($payload['rol'])
        && in_array($payload['tipo'] ?? null, ['estudiante', 'civil', 'adulto_mayor', 'discapacitado'], true);
}

/** Convierte bolivianos a centavos sin truncar ni aceptar fracciones menores. */
function money_cents($value): ?int
{
    if (!is_int($value) && !is_float($value) && !is_string($value)) return null;
    $text = trim(str_replace(',', '.', (string)$value));
    if (!preg_match('/^([0-9]{1,10})(?:\.([0-9]{1,2}))?$/D', $text, $parts)) return null;
    $whole = (int)$parts[1];
    if ($whole > 1000000000) return null;
    return $whole * 100 + (int)str_pad($parts[2] ?? '', 2, '0');
}

/** Cadena decimal exacta para enlazar importes a columnas DECIMAL de MySQL. */
function money_decimal(int $cents): string
{
    return intdiv($cents, 100) . '.' . str_pad((string)($cents % 100), 2, '0', STR_PAD_LEFT);
}

/** El monto personalizado es el total acordado; las categorías mantienen su tarifa. */
function trip_payment_matches(string $passengerType, ?string $qrType, int $cents, int $quantity): bool
{
    $fares = ['estudiante' => 100, 'civil' => 350, 'adulto_mayor' => 100, 'discapacitado' => 100];
    if (!isset($fares[$passengerType]) || $cents <= 0 || $cents > 100000000
        || $quantity < 1 || $quantity > 50) return false;
    if ($qrType === 'personalizado') return true;
    return ($qrType === null || $qrType === $passengerType)
        && $fares[$passengerType] * $quantity === $cents;
}
