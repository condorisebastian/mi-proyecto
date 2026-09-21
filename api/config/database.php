<?php
/**
 * Configuracion de la API (XAMPP / MariaDB).
 * BD: proyecto_cobros  | usuario root sin clave (default XAMPP)
 */

// Secreto JWT: NUNCA hardcodeado en el repositorio.
// Prioridad: variable de entorno JWT_SECRET > archivo local .jwt_secret
// (se genera una sola vez, no se versiona).
$jwtSecret = getenv('JWT_SECRET');
if ($jwtSecret === false || $jwtSecret === '') {
    $secretFile = __DIR__ . '/.jwt_secret';
    if (is_file($secretFile)) {
        $jwtSecret = trim((string)file_get_contents($secretFile));
    } else {
        $jwtSecret = bin2hex(random_bytes(32));
        @file_put_contents($secretFile, $jwtSecret);
    }
}

return [
    'db' => [
        'host'     => '127.0.0.1',
        'database' => 'proyecto_cobros',
        'user'     => 'root',
        'password' => '',
        'charset'  => 'utf8mb4',
    ],
    // Secreto JWT compartido con las apps (8h de validez)
    'jwt_secret' => $jwtSecret,
    'jwt_ttl'    => 28800, // 8 horas
];
