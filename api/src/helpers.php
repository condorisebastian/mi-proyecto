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
