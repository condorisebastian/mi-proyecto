<?php
/**
 * Configuracion de la API (XAMPP / MariaDB).
 * BD: proyecto_cobros  | usuario root sin clave (default XAMPP)
 */
return [
    'db' => [
        'host'     => '127.0.0.1',
        'database' => 'proyecto_cobros',
        'user'     => 'root',
        'password' => '',
        'charset'  => 'utf8mb4',
    ],
    // Secreto JWT compartido con las apps (8h de validez)
    'jwt_secret' => 'transporte_sc_2026_secret_key',
    'jwt_ttl'    => 28800, // 8 horas
];
