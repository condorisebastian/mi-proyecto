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

function b64url_decode(string $s): string
{
    return base64_decode(strtr($s, '-_', '+/') . str_repeat('=', (4 - strlen($s) % 4) % 4));
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
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $b, $s] = $parts;
    if ($h === '' || $b === '' || $s === '') return null;

    $payload = json_decode(b64url_decode($b), true);
    if (!is_array($payload)) return null;

    $sig = b64url_encode(hash_hmac('sha256', "$h.$b", $secret, true));
    if (!hash_equals($sig, $s)) return null;

    if (!isset($payload['exp']) || (int)$payload['exp'] < time()) return null;
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
