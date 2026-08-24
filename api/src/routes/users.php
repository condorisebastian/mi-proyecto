<?php
/** GET /users/{id}: perfil del usuario pasajero. */

function handle_users(string $method, array $seg): void
{
    if ($method === 'GET' && isset($seg[1]) && ctype_digit($seg[1])) {
        $pdo = db();
        $st = $pdo->prepare(
            'SELECT u.id_usuario, u.nombre, u.apellido, p.ci, u.correo AS email,
                    p.tipo, s.saldo_actual, u.estado
             FROM usuarios u
             JOIN pasajeros p ON p.id_usuario = u.id_usuario
             LEFT JOIN saldos s ON s.id_pasajero = p.id_pasajero
             WHERE u.id_usuario = ?
             LIMIT 1'
        );
        $st->execute([(int)$seg[1]]);
        $row = $st->fetch();

        if (!$row) {
            json_out(['error' => 'Usuario no encontrado'], 404);
        }

        json_out([
            'id'      => (int)$row['id_usuario'],
            'nombre'  => $row['nombre'],
            'apellido'=> $row['apellido'],
            'ci'      => $row['ci'],
            'email'   => $row['email'],
            'tipo'    => $row['tipo'],
            'puntos'  => (int)round((float)$row['saldo_actual']),
            'estado'  => $row['estado'],
        ]);
    }

    json_out(['error' => 'Ruta no encontrada'], 404);
}
