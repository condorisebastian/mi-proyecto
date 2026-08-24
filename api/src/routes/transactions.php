<?php
/**
 * Rutas de transacciones (contrato identico al backend legacy):
 *   POST /transactions/pay
 *   POST /transactions/recharge
 *   GET  /transactions/user/{userId}
 *   GET  /transactions/summary/{conductorId}
 *   GET  /transactions/history/{conductorId}
 */

function handle_transactions(string $method, array $seg): void
{
    $action = $seg[1] ?? '';
    $pdo    = db();
    $body   = json_input();

    // ---------- POST /transactions/pay ----------
    if ($method === 'POST' && $action === 'pay') {
        $conductorId = (int)($body['conductor_id'] ?? 0);
        $puntos      = (int)($body['puntos'] ?? 0);

        if (!$conductorId || $puntos <= 0) {
            json_out(['error' => 'conductor_id y puntos son obligatorios'], 400);
        }

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                "SELECT id_conductor FROM conductores WHERE id_conductor = ? AND estado = 'activo'"
            );
            $st->execute([$conductorId]);
            if (!$st->fetch()) {
                $pdo->rollBack();
                json_out(['error' => 'Conductor no encontrado'], 404);
            }

            $idPasajero = null;
            $metodoPago = 'tarjeta_nfc';
            $tipoUsuario = null;

            if (!empty($body['user_id'])) {
                $userId = (int)$body['user_id'];

                $st = $pdo->prepare(
                    "SELECT p.id_pasajero, s.saldo_actual
                     FROM usuarios u
                     JOIN pasajeros p ON p.id_usuario = u.id_usuario
                     LEFT JOIN saldos s ON s.id_pasajero = p.id_pasajero
                     WHERE u.id_usuario = ? AND u.estado = 'activo'"
                );
                $st->execute([$userId]);
                $row = $st->fetch();

                if (!$row) {
                    $pdo->rollBack();
                    json_out(['error' => 'Usuario no encontrado'], 404);
                }
                if ((float)($row['saldo_actual'] ?? 0) < $puntos) {
                    $pdo->rollBack();
                    json_out(['error' => 'Saldo insuficiente'], 400);
                }

                $idPasajero = (int)$row['id_pasajero'];
                $metodoPago = $body['metodo_pago'] ?? 'qr';

                $st = $pdo->prepare(
                    'UPDATE saldos SET saldo_actual = saldo_actual - ? WHERE id_pasajero = ?'
                );
                $st->execute([$puntos, $idPasajero]);
            }

            $tipoUsuario = isset($body['tipo_usuario']) && $body['tipo_usuario'] !== ''
                ? $body['tipo_usuario'] : null;

            $codigo = uniqid('TXN-');
            $st = $pdo->prepare(
                'INSERT INTO cobros (id_pasajero, id_conductor, monto, metodo_pago, tipo_usuario, codigo_transaccion)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            $st->execute([$idPasajero, $conductorId, $puntos, $metodoPago, $tipoUsuario, $codigo]);

            $pdo->commit();
            json_out(['ok' => true]);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            json_out(['error' => 'Error interno del servidor'], 500);
        }
    }

    // ---------- POST /transactions/recharge ----------
    if ($method === 'POST' && $action === 'recharge') {
        $userId     = (int)($body['user_id'] ?? 0);
        $puntos     = (int)($body['puntos'] ?? 0);
        $metodoPago = $body['metodo_pago'] ?? '';

        if (!$userId || $puntos <= 0) {
            json_out(['error' => 'user_id y puntos son obligatorios'], 400);
        }

        $validMethods = ['tarjeta_nfc', 'qr', 'recarga', 'qr_bancario', 'tigo_money', 'unnocc'];
        if (!in_array($metodoPago, $validMethods, true)) {
            json_out(['error' => 'Método de pago inválido'], 400);
        }

        $st = $pdo->prepare("SELECT id_usuario FROM usuarios WHERE id_usuario = ? AND estado = 'activo'");
        $st->execute([$userId]);
        if (!$st->fetch()) {
            json_out(['error' => 'Usuario no encontrado'], 404);
        }

        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare(
                'SELECT p.id_pasajero FROM pasajeros p WHERE p.id_usuario = ?'
            );
            $st->execute([$userId]);
            $row = $st->fetch();
            if (!$row) {
                throw new RuntimeException('pasajero inexistente');
            }
            $idPasajero = (int)$row['id_pasajero'];

            $st = $pdo->prepare(
                'UPDATE saldos SET saldo_actual = saldo_actual + ? WHERE id_pasajero = ?'
            );
            $st->execute([$puntos, $idPasajero]);

            $st = $pdo->prepare(
                'INSERT INTO recargas (id_pasajero, monto, metodo_pago) VALUES (?, ?, ?)'
            );
            $st->execute([$idPasajero, $puntos, $metodoPago]);

            $pdo->commit();
            json_out(['ok' => true]);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            json_out(['error' => 'Error interno del servidor'], 500);
        }
    }

    // ---------- GET /transactions/user/{userId} ----------
    if ($method === 'GET' && $action === 'user' && isset($seg[2]) && ctype_digit($seg[2])) {
        $userId = (int)$seg[2];

        $st = $pdo->prepare('SELECT id_pasajero FROM pasajeros WHERE id_usuario = ?');
        $st->execute([$userId]);
        $p = $st->fetch();
        if (!$p) {
            json_out([]);
        }
        $idPasajero = (int)$p['id_pasajero'];

        // Union cobros + recargas con la forma legacy que consumen las apps.
        $st = $pdo->prepare(
            "(SELECT c.id_cobro AS id,
                    u.id_usuario AS id_usuario,
                    c.id_conductor AS id_conductor,
                    CAST(c.monto AS SIGNED) AS puntos,
                    'cobro_viaje' AS tipo,
                    c.metodo_pago,
                    c.estado,
                    CONCAT(c.fecha, ' ', c.hora) AS fecha_orden,
                    CONCAT(c.fecha, ' ', c.hora) AS fecha
               FROM cobros c
               JOIN usuarios u ON u.id_usuario = ?
              WHERE c.id_pasajero = ?
             UNION ALL
             SELECT -r.id_recarga AS id,
                    u.id_usuario AS id_usuario,
                    1 AS id_conductor,
                    CAST(r.monto AS SIGNED) AS puntos,
                    'recarga' AS tipo,
                    r.metodo_pago,
                    r.estado,
                    r.fecha AS fecha_orden,
                    DATE_FORMAT(r.fecha, '%Y-%m-%d %H:%i:%s') AS fecha
               FROM recargas r
               JOIN pasajeros pa ON pa.id_pasajero = r.id_pasajero
               JOIN usuarios u ON u.id_usuario = pa.id_usuario AND u.id_usuario = ?
              WHERE r.id_pasajero = ?)
             ORDER BY fecha_orden DESC"
        );
        $st->execute([$userId, $idPasajero, $userId, $idPasajero]);

        $out = [];
        foreach ($st->fetchAll() as $r) {
            $out[] = [
                'id'           => (int)$r['id'],
                'id_usuario'   => (int)$r['id_usuario'],
                'id_conductor' => (int)$r['id_conductor'],
                'puntos'       => (int)$r['puntos'],
                'tipo'         => $r['tipo'],
                'metodo_pago'  => $r['metodo_pago'],
                'estado'       => $r['estado'],
                'fecha'        => $r['fecha'],
            ];
        }
        json_out($out);
    }

    // ---------- GET /transactions/summary/{conductorId} ----------
    if ($method === 'GET' && $action === 'summary' && isset($seg[2]) && ctype_digit($seg[2])) {
        $st = $pdo->prepare(
            "SELECT COUNT(*) AS total_pasajeros,
                    COALESCE(SUM(c.monto), 0) AS total_puntos,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'estudiante' THEN 1 ELSE 0 END), 0) AS estudiantes,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'civil' THEN 1 ELSE 0 END), 0) AS civiles,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'adulto_mayor' THEN 1 ELSE 0 END), 0) AS mayores
               FROM cobros c
               LEFT JOIN pasajeros p ON p.id_pasajero = c.id_pasajero
              WHERE c.id_conductor = ?
                AND c.estado = 'exitoso'
                AND c.fecha = CURDATE()"
        );
        $st->execute([(int)$seg[2]]);
        $r = $st->fetch();

        json_out([
            'total_pasajeros' => (int)$r['total_pasajeros'],
            'total_puntos'    => (int)round((float)$r['total_puntos']),
            'estudiantes'     => (int)$r['estudiantes'],
            'civiles'         => (int)$r['civiles'],
            'mayores'         => (int)$r['mayores'],
        ]);
    }

    // ---------- GET /transactions/history/{conductorId} ----------
    if ($method === 'GET' && $action === 'history' && isset($seg[2]) && ctype_digit($seg[2])) {
        $st = $pdo->prepare(
            "SELECT c.id_cobro AS id,
                    u.id_usuario AS id_usuario,
                    c.id_conductor AS id_conductor,
                    CAST(c.monto AS SIGNED) AS puntos,
                    'cobro_viaje' AS tipo,
                    c.metodo_pago,
                    c.estado,
                    CONCAT(c.fecha, ' ', c.hora) AS fecha,
                    COALESCE(u.nombre, '') AS nombre,
                    COALESCE(u.apellido, '') AS apellido,
                    COALESCE(c.tipo_usuario, p.tipo, '') AS tipo_usuario
               FROM cobros c
               LEFT JOIN pasajeros p ON p.id_pasajero = c.id_pasajero
               LEFT JOIN usuarios u ON u.id_usuario = p.id_usuario
              WHERE c.id_conductor = ?
                AND c.fecha = CURDATE()
              ORDER BY c.fecha DESC, c.hora DESC"
        );
        $st->execute([(int)$seg[2]]);

        $out = [];
        foreach ($st->fetchAll() as $r) {
            $out[] = [
                'id'           => (int)$r['id'],
                'id_usuario'   => $r['id_usuario'] !== null ? (int)$r['id_usuario'] : null,
                'id_conductor' => (int)$r['id_conductor'],
                'puntos'       => (int)$r['puntos'],
                'tipo'         => $r['tipo'],
                'metodo_pago'  => $r['metodo_pago'],
                'estado'       => $r['estado'],
                'fecha'        => $r['fecha'],
                'nombre'       => $r['nombre'],
                'apellido'     => $r['apellido'],
                'tipo_usuario' => $r['tipo_usuario'],
            ];
        }
        json_out($out);
    }

    json_out(['error' => 'Ruta no encontrada'], 404);
}
