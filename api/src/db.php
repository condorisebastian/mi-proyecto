<?php
/** Conexion PDO singleton a MySQL/MariaDB. */

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $cfg = require __DIR__ . '/../config/database.php';
        $c   = $cfg['db'];
        $dsn = "mysql:host={$c['host']};dbname={$c['database']};charset={$c['charset']}";
        $pdo = new PDO($dsn, $c['user'], $c['password'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $pdo;
}
