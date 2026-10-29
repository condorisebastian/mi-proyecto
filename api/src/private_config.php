<?php
/** Configuración privada del servidor, situada fuera del directorio HTTP. */

function runtime_environment(): string
{
    $value = getenv('APP_ENV');
    if ($value === false || $value === '') {
        $marker = private_config_directory() . '/.environment';
        $value = is_file($marker) ? trim((string)file_get_contents($marker)) : 'production';
    }
    if (!in_array($value, ['development', 'test', 'production'], true)) {
        throw new RuntimeException('APP_ENV no válido');
    }
    return $value;
}

function private_config_directory(): string
{
    $directory = getenv('TRANSPORT_PRIVATE_DIR') ?: dirname(__DIR__, 2) . '/.transita-private';
    if (!preg_match('~^(?:[A-Za-z]:[\\\\/]|/|\\\\\\\\)~', $directory)) {
        throw new RuntimeException('El directorio privado debe ser absoluto');
    }
    $normalized = strtolower(str_replace('\\', '/', $directory));
    if (in_array('..', explode('/', $normalized), true)) {
        throw new RuntimeException('El directorio privado no admite segmentos relativos');
    }
    // Resolver también enlaces/junctions del padre si el destino aún no existe.
    $ancestor = $directory;
    $suffix = [];
    while (!file_exists($ancestor)) {
        $parent = dirname($ancestor);
        if ($parent === $ancestor) throw new RuntimeException('El directorio privado no se puede resolver');
        array_unshift($suffix, basename($ancestor));
        $ancestor = $parent;
    }
    $canonical = realpath($ancestor);
    if ($canonical === false || !is_dir($ancestor)) {
        throw new RuntimeException('El directorio privado no es válido');
    }
    $canonical = rtrim($canonical, '/\\') . ($suffix ? '/' . implode('/', $suffix) : '');
    $roots = [dirname(__DIR__)];
    if (!empty($_SERVER['DOCUMENT_ROOT'])) $roots[] = $_SERVER['DOCUMENT_ROOT'];
    foreach ($roots as $root) {
        $root = strtolower(rtrim(str_replace('\\', '/', realpath($root) ?: $root), '/'));
        $resolved = strtolower(rtrim(str_replace('\\', '/', $canonical), '/'));
        if ($resolved === $root || str_starts_with($resolved, $root . '/')) {
            throw new RuntimeException('La configuración privada no puede estar dentro del directorio HTTP');
        }
    }
    return $canonical;
}

function server_jwt_secret(): string
{
    $secret = getenv('JWT_SECRET');
    if ($secret !== false && $secret !== '') {
        if (strlen($secret) < 32) throw new RuntimeException('JWT_SECRET no cumple la longitud mínima');
        return $secret;
    }
    $private = private_config_directory();
    $file = $private . '/.jwt_secret';
    $production = runtime_environment() === 'production';
    if ($production) {
        $secret = is_file($file) ? trim((string)file_get_contents($file)) : '';
        if (strlen($secret) < 32) throw new RuntimeException('Falta configurar el secreto de producción');
        return $secret;
    }
    if (!is_dir($private) && !mkdir($private, 0700, true) && !is_dir($private)) {
        throw new RuntimeException('No se pudo preparar el directorio privado');
    }
    $handle = fopen($file, 'c+');
    if ($handle === false || !flock($handle, LOCK_EX)) {
        if (is_resource($handle)) fclose($handle);
        throw new RuntimeException('No se pudo bloquear la configuración privada');
    }
    try {
        $secret = trim((string)stream_get_contents($handle));
        if ($secret === '') {
            // Compatibilidad temporal: no invalidar las sesiones locales existentes.
            $legacy = dirname(__DIR__) . '/config/.jwt_secret';
            $secret = is_file($legacy) ? trim((string)file_get_contents($legacy)) : bin2hex(random_bytes(32));
            if (strlen($secret) < 32) throw new RuntimeException('El secreto local no cumple la longitud mínima');
            rewind($handle);
            if (fwrite($handle, $secret) !== strlen($secret) || !fflush($handle)) {
                throw new RuntimeException('No se pudo guardar la configuración privada');
            }
        }
        if (strlen($secret) < 32) throw new RuntimeException('El secreto local no cumple la longitud mínima');
        chmod($file, 0600);
        return $secret;
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function server_database_credentials(): array
{
    $production = runtime_environment() === 'production';
    $user = getenv('DB_USER');
    if ($user !== false && $user !== '') {
        $credentials = ['user' => $user, 'password' => getenv('DB_PASS') ?: ''];
    } else {
        $file = private_config_directory() . '/.db_creds.php';
        if (!$production && !is_file($file)) $file = dirname(__DIR__) . '/config/.db_creds.php';
        $credentials = is_file($file) ? require $file : ['user' => 'root', 'password' => ''];
    }
    if (!is_array($credentials) || !is_string($credentials['user'] ?? null) || trim($credentials['user']) === ''
        || !is_string($credentials['password'] ?? null)) {
        throw new RuntimeException('Configuración de base de datos no válida');
    }
    if ($production && ($credentials['user'] === 'root' || $credentials['password'] === '')) {
        throw new RuntimeException('Producción requiere un usuario limitado y contraseña de base de datos');
    }
    return $credentials;
}
