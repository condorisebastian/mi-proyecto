const express = require('express');
const { query } = require('../db');

const router = express.Router();

router.get('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);

    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'ID inválido' });
    }

    const result = await query(
      'SELECT id, nombre, apellido, ci, email, tipo, puntos, estado FROM usuarios WHERE id = @id',
      { id }
    );

    if (result.recordset.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json(result.recordset[0]);
  } catch (err) {
    console.error('get user error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
