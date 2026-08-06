const express = require('express');
const { query, getPool, sql } = require('../db');

const router = express.Router();

router.post('/pay', async (req, res) => {
  const { conductor_id, puntos } = req.body;

  if (!conductor_id || !puntos || puntos <= 0) {
    return res.status(400).json({ error: 'conductor_id y puntos son obligatorios' });
  }

  const pool = await getPool();
  const transaction = new sql.Transaction(pool);

  try {
    await transaction.begin();

    const conductorCheck = await transaction
      .request()
      .input('id', sql.Int, conductor_id)
      .query('SELECT id FROM conductores WHERE id = @id AND estado = \'activo\'');

    if (conductorCheck.recordset.length === 0) {
      await transaction.rollback();
      return res.status(404).json({ error: 'Conductor no encontrado' });
    }

    let idUsuario = null;
    let metodoPago = 'tarjeta_nfc';

    if (req.body.user_id) {
      const userId = Number(req.body.user_id);

      const userResult = await transaction
        .request()
        .input('id', sql.Int, userId)
        .query('SELECT id, puntos FROM usuarios WHERE id = @id AND estado = \'activo\'');

      if (userResult.recordset.length === 0) {
        await transaction.rollback();
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      const user = userResult.recordset[0];

      if (user.puntos < puntos) {
        await transaction.rollback();
        return res.status(400).json({ error: 'Saldo insuficiente' });
      }

      idUsuario = userId;
      metodoPago = req.body.metodo_pago || 'qr';

      await transaction
        .request()
        .input('id', sql.Int, userId)
        .input('puntos', sql.Int, puntos)
        .query('UPDATE usuarios SET puntos = puntos - @puntos WHERE id = @id');
    }

    const tipoUsuario = req.body.tipo_usuario || null;

    await transaction
      .request()
      .input('id_usuario', sql.Int, idUsuario)
      .input('id_conductor', sql.Int, conductor_id)
      .input('puntos', sql.Int, puntos)
      .input('tipo', sql.NVarChar, 'cobro_viaje')
      .input('metodo_pago', sql.NVarChar, metodoPago)
      .input('tipo_usuario', sql.NVarChar, tipoUsuario)
      .query(
        `INSERT INTO transacciones (id_usuario, id_conductor, puntos, tipo, metodo_pago, tipo_usuario)
         VALUES (@id_usuario, @id_conductor, @puntos, @tipo, @metodo_pago, @tipo_usuario);
         SELECT SCOPE_IDENTITY() AS id;`
      );

    await transaction.commit();
    res.json({ ok: true });
  } catch (err) {
    await transaction.rollback();
    console.error('pay error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post('/recharge', async (req, res) => {
  try {
    const { user_id, puntos, metodo_pago } = req.body;

    if (!user_id || !puntos || puntos <= 0) {
      return res.status(400).json({ error: 'user_id y puntos son obligatorios' });
    }

    const validMethods = ['tarjeta_nfc', 'qr', 'recarga', 'qr_bancario', 'tigo_money', 'unnocc'];
    if (!validMethods.includes(metodo_pago)) {
      return res.status(400).json({ error: 'Método de pago inválido' });
    }

    const userResult = await query(
      'SELECT id FROM usuarios WHERE id = @id AND estado = \'activo\'',
      { id: Number(user_id) }
    );

    if (userResult.recordset.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    const pool = await getPool();
    const transaction = new sql.Transaction(pool);
    await transaction.begin();

    try {
      await transaction
        .request()
        .input('id', sql.Int, Number(user_id))
        .input('puntos', sql.Int, puntos)
        .query('UPDATE usuarios SET puntos = puntos + @puntos WHERE id = @id');

      await transaction
        .request()
        .input('id_usuario', sql.Int, Number(user_id))
        .input('puntos', sql.Int, puntos)
        .input('metodo_pago', sql.NVarChar, metodo_pago)
        .query(
          `INSERT INTO transacciones (id_usuario, id_conductor, puntos, tipo, metodo_pago)
           VALUES (@id_usuario, 1, @puntos, 'recarga', @metodo_pago);`
        );

      await transaction.commit();
      res.json({ ok: true });
    } catch (err) {
      await transaction.rollback();
      throw err;
    }
  } catch (err) {
    console.error('recharge error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/user/:userId', async (req, res) => {
  try {
    const userId = Number(req.params.userId);

    if (!Number.isInteger(userId) || userId <= 0) {
      return res.status(400).json({ error: 'ID inválido' });
    }

    const result = await query(
      `SELECT id, id_usuario, id_conductor, puntos, tipo, metodo_pago, estado, fecha
       FROM transacciones
       WHERE id_usuario = @id
       ORDER BY fecha DESC`,
      { id: userId }
    );

    res.json(result.recordset);
  } catch (err) {
    console.error('user history error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/summary/:conductorId', async (req, res) => {
  try {
    const conductorId = Number(req.params.conductorId);

    if (!Number.isInteger(conductorId) || conductorId <= 0) {
      return res.status(400).json({ error: 'ID inválido' });
    }

    const result = await query(
      `SELECT
         COUNT(*) AS total_pasajeros,
         ISNULL(SUM(t.puntos), 0) AS total_puntos,
         ISNULL(SUM(CASE WHEN COALESCE(t.tipo_usuario, u.tipo) = 'estudiante' THEN 1 ELSE 0 END), 0) AS estudiantes,
         ISNULL(SUM(CASE WHEN COALESCE(t.tipo_usuario, u.tipo) = 'civil' THEN 1 ELSE 0 END), 0) AS civiles,
         ISNULL(SUM(CASE WHEN COALESCE(t.tipo_usuario, u.tipo) = 'adulto_mayor' THEN 1 ELSE 0 END), 0) AS mayores
       FROM transacciones t
       LEFT JOIN usuarios u ON t.id_usuario = u.id
       WHERE t.id_conductor = @id
         AND t.tipo = 'cobro_viaje'
         AND CAST(t.fecha AS DATE) = CAST(GETDATE() AS DATE)`,
      { id: conductorId }
    );

    res.json(result.recordset[0]);
  } catch (err) {
    console.error('summary error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/history/:conductorId', async (req, res) => {
  try {
    const conductorId = Number(req.params.conductorId);

    if (!Number.isInteger(conductorId) || conductorId <= 0) {
      return res.status(400).json({ error: 'ID inválido' });
    }

    const result = await query(
      `SELECT t.id, t.id_usuario, t.id_conductor, t.puntos, t.tipo, t.metodo_pago, t.estado, t.fecha,
              u.nombre, u.apellido, COALESCE(t.tipo_usuario, u.tipo) AS tipo_usuario
       FROM transacciones t
       LEFT JOIN usuarios u ON t.id_usuario = u.id
       WHERE t.id_conductor = @id
         AND CAST(t.fecha AS DATE) = CAST(GETDATE() AS DATE)
       ORDER BY t.fecha DESC`,
      { id: conductorId }
    );

    res.json(result.recordset);
  } catch (err) {
    console.error('history error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
