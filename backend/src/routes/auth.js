const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query, sql } = require('../db');

const router = express.Router();

function signToken(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET || 'transporte_sc_2026_secret_key', {
    expiresIn: '8h',
  });
}

router.post('/register', async (req, res) => {
  try {
    const { nombre, apellido, ci, email, password, tipo } = req.body;

    if (!nombre || !apellido || !ci || !email || !password || !tipo) {
      return res.status(400).json({ error: 'Todos los campos son obligatorios' });
    }

    if (!['estudiante', 'civil', 'adulto_mayor'].includes(tipo)) {
      return res.status(400).json({ error: 'Tipo de usuario inválido' });
    }

    const exists = await query(
      'SELECT ci, email FROM usuarios WHERE ci = @ci OR email = @email',
      { ci, email }
    );

    if (exists.recordset.length > 0) {
      return res.status(400).json({ error: 'El CI o email ya está registrado' });
    }

    const hashed = await bcrypt.hash(password, 10);

    const result = await query(
      `INSERT INTO usuarios (nombre, apellido, ci, email, password, tipo)
       VALUES (@nombre, @apellido, @ci, @email, @password, @tipo);
       SELECT id, nombre, apellido, ci, email, tipo, puntos, estado
       FROM usuarios WHERE ci = @ci;`,
      { nombre, apellido, ci, email, password: hashed, tipo }
    );

    const user = result.recordset[0];
    res.status(201).json({ user, token: signToken({ id: user.id, tipo }) });
  } catch (err) {
    console.error('register error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { ci, password, tipo } = req.body;

    if (!ci || !password || !tipo) {
      return res.status(400).json({ error: 'CI, contraseña y tipo son obligatorios' });
    }

    const result = await query(
      'SELECT * FROM usuarios WHERE ci = @ci',
      { ci }
    );

    if (result.recordset.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const user = result.recordset[0];

    if (user.tipo !== tipo) {
      return res.status(401).json({ error: 'El tipo de usuario no coincide' });
    }

    const match = await bcrypt.compare(password, user.password);

    if (!match) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    if (user.estado !== 'activo') {
      return res.status(403).json({ error: 'El usuario está inactivo' });
    }

    const { password: _, ...safeUser } = user;
    res.json({ user: safeUser, token: signToken({ id: user.id, tipo: user.tipo }) });
  } catch (err) {
    console.error('login error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post('/register-conductor', async (req, res) => {
  try {
    const { nombre, apellido, ci, licencia, password, telefono } = req.body;

    if (!nombre || !apellido || !ci || !licencia || !password) {
      return res.status(400).json({ error: 'Nombre, apellido, CI, licencia y contraseña son obligatorios' });
    }

    const exists = await query(
      'SELECT ci, licencia FROM conductores WHERE ci = @ci OR licencia = @licencia',
      { ci, licencia }
    );

    if (exists.recordset.length > 0) {
      return res.status(400).json({ error: 'El CI o la licencia ya está registrado' });
    }

    const hashed = await bcrypt.hash(password, 10);

    const result = await query(
      `INSERT INTO conductores (nombre, apellido, ci, licencia, password, telefono)
       VALUES (@nombre, @apellido, @ci, @licencia, @password, @telefono);
       SELECT id, nombre, apellido, ci, licencia, telefono, estado
       FROM conductores WHERE ci = @ci;`,
      { nombre, apellido, ci, licencia, password: hashed, telefono: telefono || null }
    );

    const conductor = result.recordset[0];
    res.status(201).json({ conductor, token: signToken({ id: conductor.id, rol: 'conductor' }) });
  } catch (err) {
    console.error('register-conductor error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post('/login-conductor', async (req, res) => {
  try {
    const { licencia, password } = req.body;

    if (!licencia || !password) {
      return res.status(400).json({ error: 'Licencia y contraseña son obligatorios' });
    }

    const result = await query(
      'SELECT * FROM conductores WHERE licencia = @licencia',
      { licencia }
    );

    if (result.recordset.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const conductor = result.recordset[0];

    const match = await bcrypt.compare(password, conductor.password);

    if (!match) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    if (conductor.estado !== 'activo') {
      return res.status(403).json({ error: 'El conductor está inactivo' });
    }

    const { password: _, ...safeConductor } = conductor;
    res.json({ conductor: safeConductor, token: signToken({ id: conductor.id, rol: 'conductor' }) });
  } catch (err) {
    console.error('login-conductor error:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;
