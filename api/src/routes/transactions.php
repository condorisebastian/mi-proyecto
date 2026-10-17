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
    $cfg    = require __DIR__ . '/../../config/database.php';
    $secret = $cfg['jwt_secret'];

    // Conductor autenticado: payload { id, rol => 'conductor' }.
    $isConductor = function (array $p): bool {
        return ($p['rol'] ?? '') === 'conductor';
    };

    // ---------- POST /transactions/pay ----------
    if ($method === 'POST' && $action === 'pay') {
        $payload = bearer_payload($secret);
        $conductorId = (int)($body['conductor_id'] ?? 0);
        $centavos    = money_cents($body['puntos'] ?? 0);
        $puntos      = $centavos === null ? '0.00' : money_decimal($centavos);
        $userIdIn    = (int)($body['user_id'] ?? 0);
        $reference = $body['payment_reference'] ?? null;
        $cantidad = filter_var($body['cantidad_pasajeros'] ?? 1, FILTER_VALIDATE_INT);

        if (!$conductorId || $centavos === null || $centavos <= 0 || $centavos > 100000000 || $cantidad === false || $cantidad < 1 || $cantidad > 50) {
            json_out(['error' => 'conductor_id y puntos son obligatorios'], 400);
        }
        if (($body['metodo_pago'] ?? 'qr') !== 'qr'
            || (isset($body['tipo_usuario']) && !is_string($body['tipo_usuario']))
            || ($reference !== null && (!is_string($reference)
                || !preg_match('/^[a-zA-Z0-9_-]{1,80}$/', $reference)))) {
            json_out(['error' => 'Datos de pago inválidos'], 400);
        }
        $codigo = $reference === null ? uniqid('TXN-')
            : 'QR-' . substr(hash('sha256', $userIdIn . ':' . $conductorId . ':' . $reference), 0, 40);

        // El cobro lo hace el conductor autenticado (siempre) y si paga un
        // pasajero vinculado, este debe ser el dueño del token.
        if ($isConductor($payload)) {
            if ((int)$payload['id'] !== $conductorId) {
                json_out(['error' => 'No autorizado'], 401);
            }
        } else {
            if (!$userIdIn || (int)$payload['id'] !== $userIdIn) {
                json_out(['error' => 'No autorizado'], 401);
            }
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
            $metodoPago = 'qr';
            $tipoUsuario = null;

            if (!empty($body['user_id'])) {
                $userId = (int)$body['user_id'];

                $st = $pdo->prepare(
                    "SELECT p.id_pasajero, p.tipo, s.saldo_actual
                     FROM usuarios u
                     JOIN pasajeros p ON p.id_usuario = u.id_usuario
                     LEFT JOIN saldos s ON s.id_pasajero = p.id_pasajero
                     WHERE u.id_usuario = ? AND u.estado = 'activo' FOR UPDATE"
                );
                $st->execute([$userId]);
                $row = $st->fetch();

                if (!$row) {
                    $pdo->rollBack();
                    json_out(['error' => 'Usuario no encontrado'], 404);
                }
                if (!trip_payment_matches($row['tipo'], $body['tipo_usuario'] ?? null, $centavos, $cantidad)) {
                    $pdo->rollBack();
                    json_out(['error' => 'El QR no corresponde a tu tipo de pasajero o tarifa'], 400);
                }
                $st = $pdo->prepare('SELECT id_cobro FROM cobros WHERE codigo_transaccion = ?');
                $st->execute([$codigo]);
                if ($st->fetch()) {
                    $pdo->rollBack();
                    json_out(['error' => 'Este QR ya fue pagado. Pide al conductor uno nuevo.'], 409);
                }
                if (money_cents($row['saldo_actual'] ?? 0) < $centavos) {
                    $pdo->rollBack();
                    json_out(['error' => 'Saldo insuficiente'], 400);
                }

                $idPasajero = (int)$row['id_pasajero'];
                $metodoPago = $body['metodo_pago'] ?? 'qr';
                $tipoUsuario = $row['tipo'];

                $st = $pdo->prepare(
                    'UPDATE saldos SET saldo_actual = saldo_actual - ? WHERE id_pasajero = ?'
                );
                $st->execute([$puntos, $idPasajero]);
            }

            if ($tipoUsuario === null && isset($body['tipo_usuario'])
                && $body['tipo_usuario'] !== '' && $body['tipo_usuario'] !== 'personalizado') {
                $tipoUsuario = $body['tipo_usuario'];
            }

            $st = $pdo->prepare(
                'INSERT INTO cobros (id_pasajero, id_conductor, monto, metodo_pago, tipo_usuario, codigo_transaccion, cantidad_pasajeros)
                 VALUES (?, ?, ?, ?, ?, ?, ?)'
            );
            $st->execute([$idPasajero, $conductorId, $puntos, $metodoPago, $tipoUsuario, $codigo, $cantidad]);

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
        $payload = bearer_payload($secret);
        $userId     = (int)($body['user_id'] ?? 0);
        $centavos   = money_cents($body['puntos'] ?? 0);
        $puntos     = $centavos === null ? '0.00' : money_decimal($centavos);
        $metodoPago = $body['metodo_pago'] ?? '';

        // Solo un pasajero puede recargar SU cuenta.
        if ($isConductor($payload) || (int)$payload['id'] !== $userId) {
            json_out(['error' => 'No autorizado'], 401);
        }

        if (!$userId || $centavos === null || $centavos <= 0) {
            json_out(['error' => 'user_id y puntos son obligatorios'], 400);
        }

        $validMethods = ['qr', 'recarga', 'qr_bancario', 'tigo_money', 'unnocc'];
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
        $payload = bearer_payload($secret);

        // Solo el dueño de la cuenta ve su historial.
        if ($isConductor($payload) || (int)$payload['id'] !== $userId) {
            json_out(['error' => 'No autorizado'], 401);
        }

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
                    c.monto AS puntos,
                    'cobro_viaje' AS tipo,
                    c.metodo_pago,
                    c.estado,
                    c.cantidad_pasajeros,
                    CONCAT(c.fecha, ' ', c.hora) AS fecha_orden,
                    CONCAT(c.fecha, ' ', c.hora) AS fecha
               FROM cobros c
               JOIN usuarios u ON u.id_usuario = ?
              WHERE c.id_pasajero = ?
             UNION ALL
             SELECT -r.id_recarga AS id,
                    u.id_usuario AS id_usuario,
                    1 AS id_conductor,
                    r.monto AS puntos,
                    'recarga' AS tipo,
                    r.metodo_pago,
                    r.estado,
                    1 AS cantidad_pasajeros,
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
                'puntos'       => (float)$r['puntos'],
                'tipo'         => $r['tipo'],
                'metodo_pago'  => $r['metodo_pago'],
                'estado'       => $r['estado'],
                'cantidad_pasajeros' => (int)$r['cantidad_pasajeros'],
                'fecha'        => $r['fecha'],
            ];
        }
        json_out($out);
    }

    // ---------- GET /transactions/summary/{conductorId} ----------
    if ($method === 'GET' && $action === 'summary' && isset($seg[2]) && ctype_digit($seg[2])) {
        $payload = bearer_payload($secret);
        // Solo el conductor autenticado consulta SU resumen.
        if (!$isConductor($payload) || (int)$payload['id'] !== (int)$seg[2]) {
            json_out(['error' => 'No autorizado'], 401);
        }

        $st = $pdo->prepare(
            "SELECT COALESCE(SUM(c.cantidad_pasajeros), 0) AS total_pasajeros,
                    COALESCE(SUM(c.monto), 0) AS total_puntos,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'estudiante' THEN c.cantidad_pasajeros ELSE 0 END), 0) AS estudiantes,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'civil' THEN c.cantidad_pasajeros ELSE 0 END), 0) AS civiles,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'adulto_mayor' THEN c.cantidad_pasajeros ELSE 0 END), 0) AS mayores,
                    COALESCE(SUM(CASE WHEN COALESCE(c.tipo_usuario, p.tipo) = 'discapacitado' THEN c.cantidad_pasajeros ELSE 0 END), 0) AS discapacitados
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
            'total_puntos'    => (float)$r['total_puntos'],
            'estudiantes'     => (int)$r['estudiantes'],
            'civiles'         => (int)$r['civiles'],
            'mayores'         => (int)$r['mayores'],
            'discapacitados'  => (int)$r['discapacitados'],
        ]);
    }

    // ---------- GET /transactions/history/{conductorId} ----------
    if ($method === 'GET' && $action === 'history' && isset($seg[2]) && ctype_digit($seg[2])) {
        $payload = bearer_payload($secret);
        // Solo el conductor autenticado consulta SU historial diario.
        if (!$isConductor($payload) || (int)$payload['id'] !== (int)$seg[2]) {
            json_out(['error' => 'No autorizado'], 401);
        }

        $st = $pdo->prepare(
            "SELECT c.id_cobro AS id,
                    u.id_usuario AS id_usuario,
                    c.id_conductor AS id_conductor,
                    c.monto AS puntos,
                    'cobro_viaje' AS tipo,
                    c.metodo_pago,
                    c.estado,
                    c.cantidad_pasajeros,
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
                'puntos'       => (float)$r['puntos'],
                'tipo'         => $r['tipo'],
                'metodo_pago'  => $r['metodo_pago'],
                'estado'       => $r['estado'],
                'cantidad_pasajeros' => (int)$r['cantidad_pasajeros'],
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
