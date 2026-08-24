<?php
/** Rutas de autenticacion: /auth/* (contrato identico al backend legacy). */

function handle_auth(string $method, array $seg): void
{
    $action = $seg[1] ?? '';
    $body   = json_input();
    $cfg    = require __DIR__ . '/../../config/database.php';
    $secret = $cfg['jwt_secret'];
    $ttl    = $cfg['jwt_ttl'];
    $pdo    = db();

    // ---------- POST /auth/register ----------
    if ($method === 'POST' && $action === 'register') {
        require_fields($body, ['nombre', 'apellido', 'ci', 'email', 'password', 'tipo']);
        ['nombre' => $nombre, 'apellido' => $apellido, 'ci' => $ci, 'email' => $email, 'password' => $password, 'tipo' => $tipo] = $body;

        if (!in_array($tipo, ['estudiante', 'civil', 'adulto_mayor'], true)) {
            json_out(['error' => 'Tipo de usuario inválido'], 400);
        }

        $dup = $pdo->prepare(
            'SELECT u.id_usuario FROM usuarios u
             LEFT JOIN pasajeros p ON p.id_usuario = u.id_usuario
             WHERE u.correo = ? OR p.ci = ? LIMIT 1'
        );
        $dup->execute([$email, $ci]);
        if ($dup->fetch()) {
            json_out(['error' => 'El CI o email ya está registrado'], 400);
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                'INSERT INTO usuarios (nombre, apellido, correo, telefono, password, rol)
                 VALUES (?, ?, ?, NULL, ?, "PASAJERO")'
            );
            $st->execute([$nombre, $apellido, $email, $hash]);
            $idUsuario = (int)$pdo->lastInsertId();

            $st = $pdo->prepare('INSERT INTO pasajeros (id_usuario, ci, tipo) VALUES (?, ?, ?)');
            $st->execute([$idUsuario, $ci, $tipo]);
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
                'email'   => $email,
                'tipo'    => $tipo,
                'puntos'  => 0,
                'estado'  => 'activo',
            ],
            'token' => jwt_sign(['id' => $idUsuario, 'tipo' => $tipo], $secret, $ttl),
        ], 201);
    }

    // ---------- POST /auth/login ----------
    if ($method === 'POST' && $action === 'login') {
        require_fields($body, ['ci', 'password', 'tipo']);
        ['ci' => $ci, 'password' => $password, 'tipo' => $tipo] = $body;

        $st = $pdo->prepare(
            'SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.password AS hash,
                    u.estado, p.tipo, s.saldo_actual
             FROM pasajeros p
             JOIN usuarios u ON u.id_usuario = p.id_usuario
             LEFT JOIN saldos s ON s.id_pasajero = p.id_pasajero
             WHERE p.ci = ?
             LIMIT 1'
        );
        $st->execute([$ci]);
        $row = $st->fetch();
        if (!$row) {
            json_out(['error' => 'Credenciales incorrectas'], 401);
        }
        if ($row['tipo'] !== $tipo) {
            json_out(['error' => 'El tipo de usuario no coincide'], 401);
        }
        if (!password_verify($password, $row['hash'])) {
            json_out(['error' => 'Credenciales incorrectas'], 401);
        }
        if ($row['estado'] !== 'activo') {
            json_out(['error' => 'El usuario está inactivo'], 403);
        }

        $id = (int)$row['id_usuario'];
        json_out([
            'user' => [
                'id'      => $id,
                'nombre'  => $row['nombre'],
                'apellido'=> $row['apellido'],
                'ci'      => $ci,
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
        require_fields($body, ['nombre', 'apellido', 'ci', 'licencia', 'password']);
        ['nombre' => $nombre, 'apellido' => $apellido, 'ci' => $ci, 'licencia' => $licencia, 'password' => $password] = $body;
        $telefono = $body['telefono'] ?? null;

        $dup = $pdo->prepare(
            'SELECT id_conductor FROM conductores WHERE ci = ? OR numero_licencia = ? LIMIT 1'
        );
        $dup->execute([$ci, $licencia]);
        if ($dup->fetch()) {
            json_out(['error' => 'El CI o la licencia ya está registrado'], 400);
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $correo = 'cond.' . strtolower(preg_replace('/[^a-z0-9]/i', '', $licencia)) . '@transporte.com';

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                'INSERT INTO usuarios (nombre, apellido, correo, telefono, password, rol)
                 VALUES (?, ?, ?, ?, ?, "CONDUCTOR")'
            );
            $st->execute([$nombre, $apellido, $correo, $telefono, $hash]);

            $st = $pdo->prepare(
                'INSERT INTO conductores (id_usuario, ci, numero_licencia, fecha_vencimiento)
                 VALUES (?, ?, ?, DATE_ADD(CURDATE(), INTERVAL 5 YEAR))'
            );
            $st->execute([(int)$pdo->lastInsertId(), $ci, $licencia]);
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
        require_fields($body, ['licencia', 'password']);
        ['licencia' => $licencia, 'password' => $password] = $body;

        $st = $pdo->prepare(
            'SELECT c.id_conductor, c.ci, c.numero_licencia, c.estado AS est_cond, u.telefono
             FROM conductores c
             JOIN usuarios u ON u.id_usuario = c.id_usuario
             WHERE c.numero_licencia = ?
             LIMIT 1'
        );
        $st->execute([$licencia]);
        $row = $st->fetch();

        if (!$row) {
            json_out(['error' => 'Credenciales incorrectas'], 401);
        }

        // El hash vive en usuarios
        $st2 = $pdo->prepare('SELECT u.nombre, u.apellido, u.telefono, u.password AS hash, u.estado FROM usuarios u WHERE u.id_usuario = (SELECT id_usuario FROM conductores WHERE id_conductor = ?)');
        $st2->execute([$row['id_conductor']]);
        $u = $st2->fetch();

        if (!password_verify($password, $u['hash'])) {
            json_out(['error' => 'Credenciales incorrectas'], 401);
        }
        if ($row['est_cond'] !== 'activo' || $u['estado'] !== 'activo') {
            json_out(['error' => 'El conductor está inactivo'], 403);
        }

        json_out([
            'conductor' => [
                'id'       => (int)$row['id_conductor'],
                'nombre'   => $u['nombre'],
                'apellido' => $u['apellido'],
                'ci'       => $row['ci'],
                'licencia' => $row['numero_licencia'],
                'telefono' => $u['telefono'],
                'estado'   => $row['est_cond'],
            ],
            'token' => jwt_sign(['id' => (int)$row['id_conductor'], 'rol' => 'conductor'], $secret, $ttl),
        ]);
    }

    json_out(['error' => 'Ruta no encontrada'], 404);
}
