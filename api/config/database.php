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

// Credenciales de BD: NUNCA hardcodeadas en el repositorio.
// Prioridad: env DB_USER/DB_PASS > archivo local config/.db_creds.php
// (generado por api/setup_db_user.php, ignorado por git) > root local (XAMPP).
$dbUser = 'root';
$dbPass = '';
$envDbUser = getenv('DB_USER');
if ($envDbUser !== false && $envDbUser !== '') {
    $dbUser = $envDbUser;
    $dbPass = getenv('DB_PASS') !== false ? (string)getenv('DB_PASS') : '';
} else {
    $credsFile = __DIR__ . '/.db_creds.php';
    if (is_file($credsFile)) {
        $local = require $credsFile;
        if (is_array($local) && isset($local['user'])) {
            $dbUser = $local['user'];
            $dbPass = $local['password'] ?? '';
        }
    }
}

return [
    'db' => [
        'host'     => '127.0.0.1',
        'database' => 'proyecto_cobros',
        'user'     => $dbUser,
        'password' => $dbPass,
        'charset'  => 'utf8mb4',
    ],
    // Secreto JWT compartido con las apps (8h de validez)
    'jwt_secret' => $jwtSecret,
    'jwt_ttl'    => 28800, // 8 horas
];
