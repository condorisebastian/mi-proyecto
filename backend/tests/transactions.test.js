const request = require('supertest');

let mockResults = [];
let mockTxn;

jest.mock('../src/db', () => {
  mockTxn = {
    begin: jest.fn().mockResolvedValue(true),
    commit: jest.fn().mockResolvedValue(true),
    rollback: jest.fn().mockResolvedValue(true),
    request: jest.fn(() => ({
      input: jest.fn().mockReturnThis(),
      query: jest.fn().mockImplementation(() => {
        const r = mockResults.shift() || { recordset: [] };
        return Promise.resolve(r);
      }),
    })),
  };

  return {
    query: jest.fn().mockImplementation(() => {
      const r = mockResults.shift() || { recordset: [] };
      return Promise.resolve(r);
    }),
    getPool: jest.fn().mockReturnValue({ pool: 'fake' }),
    sql: { Int: 1, NVarChar: 2, Transaction: jest.fn(() => mockTxn) },
  };
});

const app = require('../src/app');

describe('Transactions - pay', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockResults = [];
  });

  test('400 si faltan conductor_id o puntos', async () => {
    const res = await request(app).post('/api/transactions/pay').send({ conductor_id: 1 });
    expect(res.status).toBe(400);
  });

  test('404 si el conductor no existe', async () => {
    mockResults = [{ recordset: [] }];
    const res = await request(app).post('/api/transactions/pay').send({ conductor_id: 99, puntos: 5 });
    expect(res.status).toBe(404);
  });

  test('400 saldo insuficiente', async () => {
    mockResults = [
      { recordset: [{ id: 1 }] },
      { recordset: [{ id: 2, puntos: 5 }] },
    ];
    const res = await request(app).post('/api/transactions/pay').send({ conductor_id: 1, user_id: 2, puntos: 10 });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Saldo insuficiente/);
  });

  test('200 cobro sin usuario (tarjeta NFC)', async () => {
    mockResults = [
      { recordset: [{ id: 1 }] },
      { recordset: [{ id: 123 }] },
    ];
    const res = await request(app).post('/api/transactions/pay').send({ conductor_id: 1, puntos: 5 });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });

  test('200 cobro con usuario', async () => {
    mockResults = [
      { recordset: [{ id: 1 }] },
      { recordset: [{ id: 2, puntos: 50 }] },
      { recordset: [{ id: 123 }] },
    ];
    const res = await request(app).post('/api/transactions/pay').send({
      conductor_id: 1, user_id: 2, puntos: 5, metodo_pago: 'qr',
    });
    expect(res.status).toBe(200);
    expect(mockTxn.commit).toHaveBeenCalled();
  });
});

describe('Transactions - recharge', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockResults = [];
  });

  test('400 si el método de pago es inválido', async () => {
    const res = await request(app).post('/api/transactions/recharge').send({
      user_id: 1, puntos: 10, metodo_pago: 'efectivo',
    });
    expect(res.status).toBe(400);
  });

  test('404 si el usuario no existe', async () => {
    mockResults = [{ recordset: [] }];
    const res = await request(app).post('/api/transactions/recharge').send({
      user_id: 99, puntos: 10, metodo_pago: 'qr',
    });
    expect(res.status).toBe(404);
  });

  test('200 recarga exitosa', async () => {
    mockResults = [
      { recordset: [{ id: 1 }] },
      { recordset: [] },
      { recordset: [] },
    ];
    const res = await request(app).post('/api/transactions/recharge').send({
      user_id: 1, puntos: 20, metodo_pago: 'qr',
    });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
    expect(mockTxn.commit).toHaveBeenCalled();
  });
});

describe('Transactions - consultas', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockResults = [];
  });

  test('200 historial de usuario', async () => {
    mockResults = [{ recordset: [{ id: 1, puntos: 5, tipo: 'cobro_viaje' }] }];
    const res = await request(app).get('/api/transactions/user/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });

  test('400 historial de usuario con ID inválido', async () => {
    const res = await request(app).get('/api/transactions/user/0');
    expect(res.status).toBe(400);
  });

  test('200 resumen del conductor', async () => {
    mockResults = [{ recordset: [{ total_pasajeros: 10, total_puntos: 50, estudiantes: 3, civiles: 5, mayores: 2 }] }];
    const res = await request(app).get('/api/transactions/summary/1');
    expect(res.status).toBe(200);
    expect(res.body.total_pasajeros).toBe(10);
  });

  test('200 historial del conductor', async () => {
    mockResults = [{ recordset: [{ id: 1, nombre: 'Ana' }] }];
    const res = await request(app).get('/api/transactions/history/1');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });
});
