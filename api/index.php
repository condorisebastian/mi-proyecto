<?php
/**
 * API REST del Sistema de Cobro para Transporte Publico.
 * PHP + MySQL/MariaDB (XAMPP). Front controller con router simple.
 *
 * Base URL local: http://localhost/transporte_api
 */
require __DIR__ . '/src/db.php';

// Nunca contaminar el JSON con warnings/notices
ini_set('display_errors', '0');
error_reporting(E_ALL);
require __DIR__ . '/src/helpers.php';
require __DIR__ . '/src/routes/auth.php';
require __DIR__ . '/src/routes/users.php';
require __DIR__ . '/src/routes/transactions.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Ruta relativa a la carpeta de la API (ej: /transporte_api/auth/login -> auth/login)
$base = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');
$uri  = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = preg_replace('#^' . preg_quote($base, '#') . '#', '', $uri) ?: '/';
$path = trim($path, '/');
$seg  = $path === '' ? [] : explode('/', $path);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($seg === [] || $seg[0] === '') {
    json_out([
        'name'    => 'Transporte API',
        'status'  => 'ok',
        'version' => '1.0.0-php',
        'time'    => date('c'),
    ]);
}

switch ($seg[0]) {
    case 'auth':
        handle_auth($method, $seg);
        break;
    case 'users':
        handle_users($method, $seg);
        break;
    case 'transactions':
        handle_transactions($method, $seg);
        break;
    case 'health':
        json_out(['status' => 'ok', 'timestamp' => date('c')]);
        break;
    default:
        json_out(['error' => 'Ruta no encontrada'], 404);
}
