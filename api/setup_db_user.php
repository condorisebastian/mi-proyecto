<?php
/**
 * Crea un usuario MySQL dedicado para la API con privilegios minimos
 * (sin DDL ni DROP) y guarda sus credenciales en config/.db_creds.php,
 * archivo ignorado por git.
 *
 * Uso (con XAMPP/MariaDB corriendo):
 *   php api/setup_db_user.php
 */

$rootUser = 'root';
$rootPass = '';
$dbName   = 'proyecto_cobros';
$dbUser   = 'transporte_app';

try {
    $pdo = new PDO(
        'mysql:host=127.0.0.1;charset=utf8mb4',
        $rootUser,
        $rootPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (Throwable $e) {
    fwrite(STDERR, "No se pudo conectar a MySQL como root: {$e->getMessage()}\n");
    exit(1);
}

$password = bin2hex(random_bytes(18));
$escaped  = addslashes($password);

$pdo->exec("CREATE USER IF NOT EXISTS '{$dbUser}'@'localhost' IDENTIFIED BY '{$escaped}'");
$pdo->exec("GRANT SELECT, INSERT, UPDATE, DELETE ON `{$dbName}`.* TO '{$dbUser}'@'localhost'");
$pdo->exec('FLUSH PRIVILEGES');

$dir = __DIR__ . '/config';
if (!is_dir($dir)) {
    @mkdir($dir, 0700, true);
}
$file = $dir . '/.db_creds.php';
$content = "<?php\n// Generado por setup_db_user.php (no versionar).\n"
    . "return [\n    'user' => '{$dbUser}',\n    'password' => '{$escaped}',\n];\n";
file_put_contents($file, $content, LOCK_EX);
@chmod($file, 0600);

echo "Usuario MySQL creado con exito: {$dbUser}\n";
echo "Credenciales guardadas en config/.db_creds.php (ignorado por git).\n";
echo "La API usara este usuario limitado (SELECT/INSERT/UPDATE/DELETE, sin DDL/DROP).\n";