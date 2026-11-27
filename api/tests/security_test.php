<?php
require __DIR__ . '/../src/helpers.php';
require __DIR__ . '/../src/private_config.php';

$checks = 0;
function check_security(bool $condition, string $name): void
{
    global $checks;
    if (!$condition) throw new RuntimeException('Falló la comprobación: ' . $name);
    $checks++;
}
function rejects_config(callable $operation, string $name): void
{
    try {
        $operation();
    } catch (RuntimeException $error) {
        check_security(true, $name);
        return;
    }
    check_security(false, $name);
}

$secret = bin2hex(random_bytes(32));
$passenger = ['id' => 7, 'tipo' => 'civil'];
$driver = ['id' => 7, 'rol' => 'conductor'];
$token = jwt_sign($passenger, $secret, 300);
check_security(jwt_verify($token, $secret)['id'] === 7, 'firma válida');
check_security(jwt_verify($token, bin2hex(random_bytes(32))) === null, 'firma ajena');
check_security(jwt_verify(jwt_sign($passenger, $secret, -1), $secret) === null, 'token vencido');
check_security(jwt_verify(str_repeat('x', 9000), $secret) === null, 'límite de tamaño');
foreach (['none', 'HS512'] as $algorithm) {
    $header = b64url_encode(json_encode(['alg' => $algorithm, 'typ' => 'JWT']));
    $body = b64url_encode(json_encode(['id' => 7, 'iat' => time(), 'exp' => time() + 300]));
    $signature = b64url_encode(hash_hmac('sha256', "$header.$body", $secret, true));
    check_security(jwt_verify("$header.$body.$signature", $secret) === null, 'algoritmo obligatorio');
}
check_security(passenger_can_authorize_payment($passenger, 7), 'pago propio');
check_security(!passenger_can_authorize_payment($passenger, 8), 'cuenta ajena');
check_security(!passenger_can_authorize_payment($driver, 7), 'conductor con mismo id');
check_security(!passenger_can_authorize_payment(['id' => 7, 'rol' => 'ADMIN'], 7), 'admin sin consentimiento');
check_security(!passenger_can_authorize_payment(['id' => 7], 7), 'rol desconocido');
check_security(!passenger_can_authorize_payment($passenger, 0), 'pago sin pasajero');

$variables = ['APP_ENV', 'TRANSPORT_PRIVATE_DIR', 'JWT_SECRET', 'DB_USER', 'DB_PASS'];
$previous = [];
foreach ($variables as $name) $previous[$name] = getenv($name);
$directory = sys_get_temp_dir() . '/transita-security-' . bin2hex(random_bytes(8));
mkdir($directory, 0700);
try {
    putenv('TRANSPORT_PRIVATE_DIR=' . $directory);
    putenv('APP_ENV');
    check_security(runtime_environment() === 'production', 'producción por defecto');
    putenv('JWT_SECRET');
    rejects_config('server_jwt_secret', 'sin secreto de producción');
    check_security(!file_exists($directory . '/.jwt_secret'), 'no generar secreto en producción');
    putenv('JWT_SECRET=short');
    rejects_config('server_jwt_secret', 'secreto demasiado corto');
    putenv('JWT_SECRET=' . $secret);
    check_security(hash_equals(server_jwt_secret(), $secret), 'secreto desde entorno');
    putenv('JWT_SECRET');
    file_put_contents($directory . '/.jwt_secret', $secret);
    check_security(hash_equals(server_jwt_secret(), $secret), 'secreto privado estable');
    putenv('DB_USER=root');
    putenv('DB_PASS=' . bin2hex(random_bytes(16)));
    rejects_config('server_database_credentials', 'root prohibido en producción');
    putenv('DB_USER=limited_test');
    putenv('DB_PASS');
    rejects_config('server_database_credentials', 'contraseña obligatoria');
    putenv('DB_PASS=' . bin2hex(random_bytes(16)));
    check_security(server_database_credentials()['user'] === 'limited_test', 'usuario limitado');
    putenv('TRANSPORT_PRIVATE_DIR=' . realpath(__DIR__ . '/../config'));
    rejects_config('private_config_directory', 'secretos fuera de HTTP');
    putenv('TRANSPORT_PRIVATE_DIR=relative/path');
    rejects_config('private_config_directory', 'ruta absoluta obligatoria');
    putenv('TRANSPORT_PRIVATE_DIR=' . $directory . '/../outside');
    rejects_config('private_config_directory', 'ruta sin traversal');
} finally {
    foreach ($previous as $name => $value) putenv($value === false ? $name : "$name=$value");
    if (is_file($directory . '/.jwt_secret')) unlink($directory . '/.jwt_secret');
    rmdir($directory);
}
echo "Seguridad PHP: {$checks} comprobaciones aprobadas; sin valores de credenciales.\n";
