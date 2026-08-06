const sql = require('mssql');

const rawServer = process.env.DB_SERVER || 'localhost\\SQLEXPRESS';
const parts = rawServer.split('\\');
const server = parts[0];
const instanceName = parts[1] || null;

const config = {
  server,
  user: process.env.DB_USER || 'sa',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'bd_cobros',
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
  options: {
    encrypt: true,
    trustServerCertificate: true,
    dateStrings: true,
    enableArithAbort: true,
  },
};

if (instanceName) {
  config.options.instanceName = instanceName;
}

let pool = null;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(config);
  }
  return pool;
}

async function query(text, params = {}) {
  const p = await getPool();
  const request = p.request();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null) {
      request.input(key, sql.NVarChar, null);
    } else {
      request.input(key, value);
    }
  });
  const result = await request.query(text);
  return result;
}

module.exports = { getPool, query, sql };
