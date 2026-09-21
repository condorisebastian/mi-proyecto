<?php
/** Rutas de autenticacion: /auth/* (acceso por PIN unico de 4 digitos). */

function handle_auth(string $method, array $seg): void
{
    $action = $seg[1] ?? '';
    $body   = json_input();
    $cfg    = require __DIR__ . '/../../config/database.php';
    $secret = $cfg['jwt_secret'];
    $ttl    = $cfg['jwt_ttl'];
    $pdo    = db();

    // Devuelve true si el PIN ya existe en pasajeros o conductores.
    $pinEnUso = function (string $pin) use ($pdo): bool {
        $st = $pdo->prepare(
            'SELECT id_pasajero FROM pasajeros WHERE pin = ?
             UNION
             SELECT id_conductor FROM conductores WHERE pin = ? LIMIT 1'
        );
        $st->execute([$pin, $pin]);
        return (bool)$st->fetch();
    };

    // ---------- Anti fuerza bruta (PIN) ----------
    // Permite 5 intentos fallidos en una ventana de 15 minutos por PIN.
    $lockDir = sys_get_temp_dir() . '/transporte_pin_locks';
    if (!is_dir($lockDir)) {
        @mkdir($lockDir, 0700, true);
    }
    $lockFileFor = function (string $pin) use ($lockDir): string {
        return $lockDir . '/lock_' . preg_replace('/[^0-9a-zA-Z]/', '', $pin) . '.json';
    };
    $lockWait = function (string $pin) use ($lockFileFor): ?int {
        $f = $lockFileFor($pin);
        if (!is_file($f)) return null;
        $d = json_decode((string)file_get_contents($f), true);
        if (!is_array($d)) return null;
        $window = (int)($d['window'] ?? 0);
        $count  = (int)($d['count'] ?? 0);
        if (time() > $window) {
            @unlink($f);
            return null;
        }
        if ($count >= 5) return (int)ceil($window - time());
        return null;
    };
    $lockFail = function (string $pin) use ($lockFileFor): void {
        $f    = $lockFileFor($pin);
        $d    = [];
        if (is_file($f)) {
            $candidate = json_decode((string)file_get_contents($f), true);
            if (is_array($candidate)) $d = $candidate;
        }
        $window = (int)($d['window'] ?? 0);
        if (time() > $window) {
            $d = ['window' => time() + 900, 'count' => 0];
        }
        $d['count'] = (int)($d['count'] ?? 0) + 1;
        @file_put_contents($f, json_encode($d), LOCK_EX);
    };
    $lockClear = function (string $pin) use ($lockFileFor): void {
        $f = $lockFileFor($pin);
        if (is_file($f)) @unlink($f);
    };

    // ---------- POST /auth/register (pasajero) ----------
    if ($method === 'POST' && $action === 'register') {
        require_fields($body, ['nombre', 'apellido', 'ci', 'pin', 'tipo']);
        ['nombre' => $nombre, 'apellido' => $apellido, 'ci' => $ci,
         'pin' => $pin, 'tipo' => $tipo] = $body;
        $ci = trim((string)$ci);

        if (!in_array($tipo, ['estudiante', 'civil', 'adulto_mayor', 'discapacitado'], true)) {
            json_out(['error' => 'Tipo de usuario inválido'], 400);
        }
        if ($ci === '') {
            json_out(['error' => 'Ingrese su número de carnet'], 400);
        }
        if (!preg_match('/^[0-9]{4}$/', $pin)) {
            json_out(['error' => 'El PIN debe tener 4 dígitos'], 400);
        }
        if ($pinEnUso($pin)) {
            json_out(['error' => 'El PIN ya está en uso'], 400);
        }
        $dupCi = $pdo->prepare('SELECT id_pasajero FROM pasajeros WHERE ci = ? LIMIT 1');
        $dupCi->execute([$ci]);
        if ($dupCi->fetch()) {
            json_out(['error' => 'El carnet ya está registrado'], 400);
        }

        $hash   = password_hash(bin2hex(random_bytes(8)), PASSWORD_BCRYPT);
        $correo = 'pas.' . $pin . '@transporte.com';

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                'INSERT INTO usuarios (nombre, apellido, correo, telefono, password, rol)
                 VALUES (?, ?, ?, NULL, ?, "PASAJERO")'
            );
            $st->execute([$nombre, $apellido, $correo, $hash]);
            $idUsuario = (int)$pdo->lastInsertId();

            $st = $pdo->prepare(
                'INSERT INTO pasajeros (id_usuario, ci, pin, tipo) VALUES (?, ?, ?, ?)'
            );
            $st->execute([$idUsuario, $ci, $pin, $tipo]);
            $idPasajero = (int)$pdo->lastInsertId();

            $st = $pdo->prepare('INSERT INTO saldos (id_pasajero, saldo_actual) VALUES (?, 0)');
            $st->execute([$idPasajero]);

            $st = $pdo->prepare(
                'INSERT INTO tarjetas (id_pasajero, codigo_qr) VALUES (?, ?)'
            );
            $st->execute([$idPasajero, 'QR-PAS-' . str_pad((string)$idPasajero, 4, '0', STR_PAD_LEFT)]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            json_out(['error' => 'Error interno del servidor'], 500);
        }

        json_out([
            'user' => [
                'id'      => $idUsuario,
                'nombre'  => $nombre,
                'apellido'=> $apellido,
                'ci'      => $ci,
                'email'   => $correo,
                'tipo'    => $tipo,
                'puntos'  => 0,
                'estado'  => 'activo',
            ],
            'token' => jwt_sign(['id' => $idUsuario, 'tipo' => $tipo], $secret, $ttl),
        ], 201);
    }

    // ---------- POST /auth/login (pasajero) ----------
    if ($method === 'POST' && $action === 'login') {
        require_fields($body, ['pin', 'tipo']);
        ['pin' => $pin, 'tipo' => $tipo] = $body;
        $ci = trim((string)($body['ci'] ?? ''));

        $wait = $lockWait($pin);
        if ($wait !== null) {
            json_out(['error' => "Demasiados intentos. Intente en {$wait} s"], 429);
        }

        $st = $pdo->prepare(
            'SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.estado,
                    p.ci, p.tipo, s.saldo_actual
             FROM pasajeros p
             JOIN usuarios u ON u.id_usuario = p.id_usuario
             LEFT JOIN saldos s ON s.id_pasajero = p.id_pasajero
             WHERE p.pin = ?
             LIMIT 1'
        );
        $st->execute([$pin]);
        $row = $st->fetch();
        if (!$row) {
            $lockFail($pin);
            json_out(['error' => 'PIN incorrecto'], 401);
        }
        if ($row['tipo'] !== $tipo) {
            $lockFail($pin);
            json_out(['error' => 'El tipo de usuario no coincide'], 401);
        }
        if ($ci !== '' && $row['ci'] !== null && $row['ci'] !== $ci) {
            $lockFail($pin);
            json_out(['error' => 'El número de carnet no coincide'], 401);
        }
        if ($row['estado'] !== 'activo') {
            $lockFail($pin);
            json_out(['error' => 'El usuario está inactivo'], 403);
        }
        $lockClear($pin);

        $id = (int)$row['id_usuario'];
        json_out([
            'user' => [
                'id'      => $id,
                'nombre'  => $row['nombre'],
                'apellido'=> $row['apellido'],
                'ci'      => $row['ci'] ?? '',
                'email'   => $row['correo'],
                'tipo'    => $row['tipo'],
                'puntos'  => (int)round((float)$row['saldo_actual']),
                'estado'  => $row['estado'],
            ],
            'token' => jwt_sign(['id' => $id, 'tipo' => $row['tipo']], $secret, $ttl),
        ]);
    }

    // ---------- POST /auth/register-conductor ----------
    if ($method === 'POST' && $action === 'register-conductor') {
        require_fields($body, ['nombre', 'apellido', 'ci', 'pin']);
        ['nombre' => $nombre, 'apellido' => $apellido, 'ci' => $ci,
         'pin' => $pin] = $body;
        $ci = trim((string)$ci);
        $licencia = $body['licencia'] ?? null;
        $telefono = $body['telefono'] ?? null;

        if ($ci === '') {
            json_out(['error' => 'Ingrese su número de carnet'], 400);
        }
        if (!preg_match('/^[0-9]{4}$/', $pin)) {
            json_out(['error' => 'El PIN debe tener 4 dígitos'], 400);
        }
        if ($pinEnUso($pin)) {
            json_out(['error' => 'El PIN ya está en uso'], 400);
        }
        $dupCi = $pdo->prepare('SELECT id_conductor FROM conductores WHERE ci = ? LIMIT 1');
        $dupCi->execute([$ci]);
        if ($dupCi->fetch()) {
            json_out(['error' => 'El carnet ya está registrado'], 400);
        }
        if ($licencia !== null && $licencia !== '') {
            $dup = $pdo->prepare('SELECT id_conductor FROM conductores WHERE numero_licencia = ? LIMIT 1');
            $dup->execute([$licencia]);
            if ($dup->fetch()) {
                json_out(['error' => 'La licencia ya está registrada'], 400);
            }
        }

        $hash   = password_hash(bin2hex(random_bytes(8)), PASSWORD_BCRYPT);
        $correo = 'cond.' . $pin . '@transporte.com';

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                'INSERT INTO usuarios (nombre, apellido, correo, telefono, password, rol)
                 VALUES (?, ?, ?, ?, ?, "CONDUCTOR")'
            );
            $st->execute([$nombre, $apellido, $correo, $telefono, $hash]);
            $idUsuario = (int)$pdo->lastInsertId();

            if ($licencia === null || $licencia === '') {
                $licencia = 'LIC-' . str_pad((string)$idUsuario, 5, '0', STR_PAD_LEFT);
            }

            $st = $pdo->prepare(
                'INSERT INTO conductores (id_usuario, ci, pin, numero_licencia, fecha_vencimiento)
                 VALUES (?, ?, ?, ?, DATE_ADD(CURDATE(), INTERVAL 5 YEAR))'
            );
            $st->execute([$idUsuario, $ci, $pin, $licencia]);
            $idConductor = (int)$pdo->lastInsertId();

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            json_out(['error' => 'Error interno del servidor'], 500);
        }

        json_out([
            'conductor' => [
                'id'       => $idConductor,
                'nombre'   => $nombre,
                'apellido' => $apellido,
                'ci'       => $ci,
                'licencia' => $licencia,
                'telefono' => $telefono,
                'estado'   => 'activo',
            ],
            'token' => jwt_sign(['id' => $idConductor, 'rol' => 'conductor'], $secret, $ttl),
        ], 201);
    }

    // ---------- POST /auth/login-conductor ----------
    if ($method === 'POST' && $action === 'login-conductor') {
        require_fields($body, ['pin']);
        ['pin' => $pin] = $body;
        $ci = trim((string)($body['ci'] ?? ''));

        $wait = $lockWait($pin);
        if ($wait !== null) {
            json_out(['error' => "Demasiados intentos. Intente en {$wait} s"], 429);
        }

        $st = $pdo->prepare(
            'SELECT c.id_conductor, c.ci, c.numero_licencia, c.estado AS est_cond,
                    u.nombre, u.apellido, u.telefono, u.estado AS est_usr
             FROM conductores c
             JOIN usuarios u ON u.id_usuario = c.id_usuario
             WHERE c.pin = ?
             LIMIT 1'
        );
        $st->execute([$pin]);
        $row = $st->fetch();

        if (!$row) {
            $lockFail($pin);
            json_out(['error' => 'PIN incorrecto'], 401);
        }
        if ($ci !== '' && $row['ci'] !== null && $row['ci'] !== $ci) {
            $lockFail($pin);
            json_out(['error' => 'El número de carnet no coincide'], 401);
        }
        if ($row['est_cond'] !== 'activo' || $row['est_usr'] !== 'activo') {
            $lockFail($pin);
            json_out(['error' => 'El conductor está inactivo'], 403);
        }
        $lockClear($pin);

        json_out([
            'conductor' => [
                'id'       => (int)$row['id_conductor'],
                'nombre'   => $row['nombre'],
                'apellido' => $row['apellido'],
                'ci'       => $row['ci'] ?? '',
                'licencia' => $row['numero_licencia'],
                'telefono' => $row['telefono'],
                'estado'   => $row['est_cond'],
            ],
            'token' => jwt_sign(['id' => (int)$row['id_conductor'], 'rol' => 'conductor'], $secret, $ttl),
        ]);
    }

    json_out(['error' => 'Ruta no encontrada'], 404);
}
