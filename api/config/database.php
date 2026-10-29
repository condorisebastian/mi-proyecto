<?php
require_once __DIR__ . '/../src/private_config.php';

$credentials = server_database_credentials();
$secret = server_jwt_secret();

return [
    'db' => [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'database' => getenv('DB_NAME') ?: 'proyecto_cobros',
        'user' => $credentials['user'],
        'password' => $credentials['password'],
        'charset' => 'utf8mb4',
    ],
    'jwt_secret' => $secret,
    'jwt_ttl' => runtime_environment() === 'production' ? 3600 : 28800,
];