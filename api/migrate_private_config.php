<?php
/** Traslada los archivos privados existentes sin imprimir sus valores. */
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require_once __DIR__ . '/src/private_config.php';

try {
    $directory = private_config_directory();
    if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
        throw new RuntimeException('No se pudo preparar el directorio privado');
    }
    if (in_array('--development', $argv, true)) {
        if (file_put_contents($directory . '/.environment', 'development', LOCK_EX) === false) {
            throw new RuntimeException('No se pudo configurar el entorno local');
        }
        chmod($directory . '/.environment', 0600);
    }
    $moved = 0;
    foreach (['.jwt_secret', '.db_creds.php'] as $name) {
        $source = __DIR__ . '/config/' . $name;
        if (!is_file($source)) continue;
        $target = $directory . '/' . $name;
        if (!is_file($target)) {
            $input = fopen($source, 'rb');
            $output = fopen($target, 'xb');
            if (!$input || !$output) throw new RuntimeException('No se pudo copiar la configuración');
            try {
                if (stream_copy_to_stream($input, $output) === false || !fflush($output)) {
                    throw new RuntimeException('No se pudo guardar la configuración');
                }
            } finally {
                fclose($input);
                fclose($output);
            }
            chmod($target, 0600);
        }
        $sourceHash = $name === '.jwt_secret'
            ? hash('sha256', trim((string)file_get_contents($source))) : hash_file('sha256', $source);
        $targetHash = $name === '.jwt_secret'
            ? hash('sha256', trim((string)file_get_contents($target))) : hash_file('sha256', $target);
        if (!hash_equals($sourceHash, $targetHash)) {
            throw new RuntimeException('La copia privada no coincide; se conservó el original');
        }
        if (!unlink($source)) throw new RuntimeException('No se pudo retirar el archivo del directorio HTTP');
        $moved++;
    }
    echo "Configuración privada trasladada y verificada: {$moved} archivo(s). No se mostraron valores.\n";
} catch (Throwable $error) {
    fwrite(STDERR, "No se completó la migración. Se conservaron los archivos que no pudieron verificarse.\n");
    exit(1);
}
