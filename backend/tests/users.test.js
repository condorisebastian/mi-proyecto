const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');

jest.mock('../src/db', () => ({
  query: jest.fn(),
}));

describe('Users', () => {
  beforeEach(() => jest.clearAllMocks());

  test('200 devuelve el usuario', async () => {
    db.query.mockResolvedValueOnce({
      recordset: [{ id: 1, nombre: 'Ana', apellido: 'Vargas', ci: '2222222', tipo: 'civil', puntos: 50, estado: 'activo' }],
    });
    const res = await request(app).get('/api/users/1');
    expect(res.status).toBe(200);
    expect(res.body.nombre).toBe('Ana');
  });

  test('400 si el ID es inválido', async () => {
    const res = await request(app).get('/api/users/0');
    expect(res.status).toBe(400);
    expect(db.query).not.toHaveBeenCalled();
  });

  test('400 si el ID no es numérico', async () => {
    const res = await request(app).get('/api/users/abc');
    expect(res.status).toBe(400);
  });

  test('404 si el usuario no existe', async () => {
    db.query.mockResolvedValueOnce({ recordset: [] });
    const res = await request(app).get('/api/users/999');
    expect(res.status).toBe(404);
  });
});
