const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');

jest.mock('../src/db', () => ({
  query: jest.fn(),
  getPool: jest.fn(),
  sql: { Int: 1, NVarChar: 2 },
}));

const HASH_123456 = '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.';

describe('Auth - register', () => {
  beforeEach(() => jest.clearAllMocks());

  test('201 crea usuario y devuelve token', async () => {
    db.query
      .mockResolvedValueOnce({ recordset: [] })
      .mockResolvedValueOnce({
        recordset: [{ id: 6, nombre: 'Ana', apellido: 'Vargas', ci: '2222222', email: 'ana@test.com', tipo: 'civil', puntos: 0, estado: 'activo' }],
      });

    const res = await request(app).post('/api/auth/register').send({
      nombre: 'Ana', apellido: 'Vargas', ci: '2222222', email: 'ana@test.com',
      password: '123456', tipo: 'civil',
    });

    expect(res.status).toBe(201);
    expect(res.body.user.ci).toBe('2222222');
    expect(res.body.token).toBeTruthy();
  });

  test('400 si faltan campos', async () => {
    const res = await request(app).post('/api/auth/register').send({ nombre: 'Ana' });
    expect(res.status).toBe(400);
  });

  test('400 si el tipo de usuario es inválido', async () => {
    const res = await request(app).post('/api/auth/register').send({
      nombre: 'A', apellido: 'B', ci: '1', email: 'a@b.com', password: 'x', tipo: 'admin',
    });
    expect(res.status).toBe(400);
  });

  test('400 si CI o email ya existen', async () => {
    db.query.mockResolvedValueOnce({ recordset: [{ ci: '2222222', email: 'ana@test.com' }] });
    const res = await request(app).post('/api/auth/register').send({
      nombre: 'Ana', apellido: 'Vargas', ci: '2222222', email: 'ana@test.com',
      password: '123456', tipo: 'civil',
    });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/ya está registrado/);
  });
});

describe('Auth - login', () => {
  beforeEach(() => jest.clearAllMocks());

  test('200 devuelve usuario sin password y con token', async () => {
    db.query.mockResolvedValueOnce({
      recordset: [{ id: 1, nombre: 'Ana', apellido: 'Vargas', ci: '2222222', tipo: 'civil', estado: 'activo', password: HASH_123456 }],
    });

    const res = await request(app).post('/api/auth/login').send({ ci: '2222222', password: '123456', tipo: 'civil' });

    expect(res.status).toBe(200);
    expect(res.body.user.password).toBeUndefined();
    expect(res.body.token).toBeTruthy();
  });

  test('400 si faltan credenciales', async () => {
    const res = await request(app).post('/api/auth/login').send({ ci: '2222222' });
    expect(res.status).toBe(400);
  });

  test('401 si el CI no existe', async () => {
    db.query.mockResolvedValueOnce({ recordset: [] });
    const res = await request(app).post('/api/auth/login').send({ ci: '999', password: '123456', tipo: 'civil' });
    expect(res.status).toBe(401);
  });

  test('401 si la contraseña es incorrecta', async () => {
    db.query.mockResolvedValueOnce({
      recordset: [{ id: 1, ci: '2222222', tipo: 'civil', estado: 'activo', password: HASH_123456 }],
    });
    const res = await request(app).post('/api/auth/login').send({ ci: '2222222', password: 'mala', tipo: 'civil' });
    expect(res.status).toBe(401);
  });

  test('401 si el tipo no coincide', async () => {
    db.query.mockResolvedValueOnce({
      recordset: [{ id: 1, ci: '2222222', tipo: 'civil', estado: 'activo', password: HASH_123456 }],
    });
    const res = await request(app).post('/api/auth/login').send({ ci: '2222222', password: '123456', tipo: 'estudiante' });
    expect(res.status).toBe(401);
  });
});

describe('Auth - login-conductor', () => {
  beforeEach(() => jest.clearAllMocks());

  test('200 devuelve conductor con token', async () => {
    db.query.mockResolvedValueOnce({
      recordset: [{ id: 1, nombre: 'Carlos', apellido: 'Rojas', licencia: 'LIC-67890', estado: 'activo', password: HASH_123456 }],
    });

    const res = await request(app).post('/api/auth/login-conductor').send({ licencia: 'LIC-67890', password: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.conductor.licencia).toBe('LIC-67890');
    expect(res.body.token).toBeTruthy();
  });

  test('401 con licencia incorrecta', async () => {
    db.query.mockResolvedValueOnce({ recordset: [] });
    const res = await request(app).post('/api/auth/login-conductor').send({ licencia: 'NO-EXISTE', password: '123456' });
    expect(res.status).toBe(401);
  });
});
