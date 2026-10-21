<?php
/**
 * Crea un usuario MySQL dedicado para la API con privilegios minimos
 * (sin DDL ni DROP) y guarda sus credenciales fuera del directorio HTTP,
 * en un archivo ignorado por git. No imprime claves ni excepciones SQL.
 *
 * Uso (con XAMPP/MariaDB corriendo):
 *   php api/setup_db_user.php
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require_once __DIR__ . '/src/private_config.php';

$rootUser = getenv('DB_ADMIN_USER') ?: 'root';
$rootPass = getenv('DB_ADMIN_PASS') ?: '';
$dbName   = 'proyecto_cobros';
$dbUser   = 'transporte_app';

try {
    $dir = private_config_directory();
    if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
        throw new RuntimeException('No se pudo preparar el directorio privado');
    }
    $file = $dir . '/.db_creds.php';
    $existing = is_file($file) ? require $file : [];
    $password = is_array($existing) && ($existing['user'] ?? null) === $dbUser
        && is_string($existing['password'] ?? null) && strlen($existing['password']) >= 32
        ? $existing['password'] : bin2hex(random_bytes(32));
    $pdo = new PDO(
        'mysql:host=127.0.0.1;charset=utf8mb4',
        $rootUser,
        $rootPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $escaped = addslashes($password);
    $pdo->exec("CREATE USER IF NOT EXISTS '{$dbUser}'@'localhost' IDENTIFIED BY '{$escaped}'");
    $pdo->exec("ALTER USER '{$dbUser}'@'localhost' IDENTIFIED BY '{$escaped}'");
    $pdo->exec("GRANT SELECT, INSERT, UPDATE, DELETE ON `{$dbName}`.* TO '{$dbUser}'@'localhost'");
    $pdo->exec('FLUSH PRIVILEGES');

    $content = "<?php\n// Generado por setup_db_user.php (no versionar).\n"
        . 'return ' . var_export(['user' => $dbUser, 'password' => $password], true) . ";\n";
    if (file_put_contents($file, $content, LOCK_EX) !== strlen($content)) {
        throw new RuntimeException('No se pudieron guardar las credenciales');
    }
    @chmod($file, 0600);

    echo "Usuario MySQL creado con exito: {$dbUser}\n";
    echo "Credenciales guardadas fuera del directorio HTTP (ignoradas por git).\n";
    echo "La API usara este usuario limitado (SELECT/INSERT/UPDATE/DELETE, sin DDL/DROP).\n";
} catch (Throwable $error) {
    fwrite(STDERR, "No se completó la configuración del usuario limitado. Revisa MySQL y los permisos del directorio privado.\n");
    exit(1);
}
