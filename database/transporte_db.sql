-- ============================================================
-- transporte_db.sql
-- Base de datos MySQL/MariaDB del Sistema de Cobro para
-- Transporte Publico (segun planificacion_bd_xampp.pdf)
-- Servidor: XAMPP (MariaDB 10.4) | phpMyAdmin: bd `proyecto_cobros`
-- Contraseña de todos los usuarios de prueba: 123456
--
-- Desviaciones sobre el PDF para soportar el flujo real de las apps:
--   * pasajeros.tipo        -> tarifa por tipo (estudiante/civil/adulto_mayor)
--   * conductores.ci        -> registro/login de conductor usa CI
--   * cobros.id_vehiculo/id_ruta NULL -> flujo actual no asigna vehiculo/ruta
--   * cobros.metodo_pago/tipo_usuario -> paridad con el historial de las apps
-- ============================================================

CREATE DATABASE IF NOT EXISTS proyecto_cobros
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE proyecto_cobros;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS cobros;
DROP TABLE IF EXISTS recargas;
DROP TABLE IF EXISTS saldos;
DROP TABLE IF EXISTS tarjetas;
DROP TABLE IF EXISTS rutas;
DROP TABLE IF EXISTS vehiculos;
DROP TABLE IF EXISTS conductores;
DROP TABLE IF EXISTS pasajeros;
DROP TABLE IF EXISTS usuarios;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- TABLA usuarios (acceso al sistema; roles: PASAJERO, CONDUCTOR, ADMIN)
-- ============================================================
CREATE TABLE usuarios (
  id_usuario     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre         VARCHAR(80)   NOT NULL,
  apellido       VARCHAR(80)   NOT NULL,
  correo         VARCHAR(150)  NOT NULL UNIQUE,
  telefono       VARCHAR(20)   NULL,
  password       VARCHAR(255)  NOT NULL COMMENT 'hash bcrypt (password_hash/password_verify)',
  rol            ENUM('PASAJERO','CONDUCTOR','ADMIN') NOT NULL DEFAULT 'PASAJERO',
  estado         ENUM('activo','inactivo','bloqueado') NOT NULL DEFAULT 'activo',
  fecha_registro DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA pasajeros (datos especificos del pasajero)
-- ============================================================
CREATE TABLE pasajeros (
  id_pasajero      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuario       INT UNSIGNED NOT NULL,
  ci               VARCHAR(20)  NOT NULL UNIQUE,
  tipo             ENUM('estudiante','civil','adulto_mayor') NOT NULL DEFAULT 'civil'
                   COMMENT 'define la tarifa del viaje en las apps',
  fecha_nacimiento DATE         NULL,
  direccion        VARCHAR(150) NULL,
  estado           ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  CONSTRAINT fk_pasajero_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA conductores (datos especificos del conductor)
-- ============================================================
CREATE TABLE conductores (
  id_conductor     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_usuario       INT UNSIGNED NOT NULL,
  ci               VARCHAR(20)  NOT NULL UNIQUE
                   COMMENT 'las apps registran/login de conductores por CI',
  numero_licencia  VARCHAR(30)  NOT NULL UNIQUE,
  fecha_vencimiento DATE        NOT NULL,
  estado           ENUM('activo','suspendido','inactivo') NOT NULL DEFAULT 'activo',
  CONSTRAINT fk_conductor_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA vehiculos
-- ============================================================
CREATE TABLE vehiculos (
  id_vehiculo INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  placa       VARCHAR(15)  NOT NULL UNIQUE,
  modelo      VARCHAR(50)  NOT NULL,
  marca       VARCHAR(50)  NOT NULL,
  color       VARCHAR(30)  NULL,
  capacidad   SMALLINT UNSIGNED NOT NULL DEFAULT 40,
  estado      ENUM('activo','mantenimiento','baja') NOT NULL DEFAULT 'activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA rutas
-- ============================================================
CREATE TABLE rutas (
  id_ruta     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(100)    NOT NULL,
  numero      VARCHAR(20)     NOT NULL UNIQUE,
  descripcion VARCHAR(255)    NULL,
  tarifa      DECIMAL(6,2)    NOT NULL DEFAULT 2.00,
  estado      ENUM('activa','inactiva') NOT NULL DEFAULT 'activa'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA tarjetas (codigo QR asociado al pasajero)
-- ============================================================
CREATE TABLE tarjetas (
  id_tarjeta    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_pasajero   INT UNSIGNED NOT NULL,
  codigo_qr     VARCHAR(100) NOT NULL UNIQUE,
  fecha_emision DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado        ENUM('activa','bloqueada','vencida') NOT NULL DEFAULT 'activa',
  CONSTRAINT fk_tarjeta_pasajero FOREIGN KEY (id_pasajero)
    REFERENCES pasajeros(id_pasajero) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA saldos (saldo actual por pasajero)
-- ============================================================
CREATE TABLE saldos (
  id_saldo            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_pasajero         INT UNSIGNED NOT NULL UNIQUE,
  saldo_actual        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  fecha_actualizacion DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_saldo_pasajero FOREIGN KEY (id_pasajero)
    REFERENCES pasajeros(id_pasajero) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_saldo_no_negativo CHECK (saldo_actual >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA recargas
-- ============================================================
CREATE TABLE recargas (
  id_recarga  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_pasajero INT UNSIGNED NOT NULL,
  monto       DECIMAL(10,2) NOT NULL,
  metodo_pago VARCHAR(30)   NOT NULL DEFAULT 'efectivo',
  fecha       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado      ENUM('exitosa','anulada') NOT NULL DEFAULT 'exitosa',
  CONSTRAINT fk_recarga_pasajero FOREIGN KEY (id_pasajero)
    REFERENCES pasajeros(id_pasajero) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_recarga_monto CHECK (monto > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA cobros (viaje pagado; transaccion atomica con BEGIN/COMMIT)
-- ============================================================
CREATE TABLE cobros (
  id_cobro           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_pasajero        INT UNSIGNED NULL
                     COMMENT 'NULL = viaje sin usuario registrado',
  id_conductor       INT UNSIGNED NOT NULL,
  id_vehiculo        INT UNSIGNED NULL COMMENT 'opcional: el flujo actual no asigna vehiculo',
  id_ruta            INT UNSIGNED NULL COMMENT 'opcional: el flujo actual no asigna ruta',
  monto              DECIMAL(10,2) NOT NULL,
  metodo_pago        VARCHAR(30)   NOT NULL DEFAULT 'qr',
  tipo_usuario       VARCHAR(20)   NULL COMMENT 'tipo del pasajero al momento del cobro',
  fecha              DATE          NOT NULL DEFAULT (CURRENT_DATE),
  hora               TIME          NOT NULL DEFAULT (CURRENT_TIME),
  codigo_transaccion VARCHAR(50)   NOT NULL UNIQUE,
  estado             ENUM('exitoso','anulado','reembolsado') NOT NULL DEFAULT 'exitoso',
  CONSTRAINT fk_cobro_pasajero  FOREIGN KEY (id_pasajero)
    REFERENCES pasajeros(id_pasajero)   ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cobro_conductor FOREIGN KEY (id_conductor)
    REFERENCES conductores(id_conductor) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cobro_vehiculo  FOREIGN KEY (id_vehiculo)
    REFERENCES vehiculos(id_vehiculo)   ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cobro_ruta      FOREIGN KEY (id_ruta)
    REFERENCES rutas(id_ruta)           ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_cobro_monto CHECK (monto >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DATOS DE PRUEBA (password de todos: 123456)
-- Hash bcrypt compatible con password_hash()/password_verify() de PHP
-- ============================================================
INSERT INTO usuarios (nombre, apellido, correo, telefono, password, rol) VALUES
('Administrador', 'Sistema', 'admin@transporte.com', '70000000', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'ADMIN'),
('Sebastian', 'Condori', 'sebastian@test.com', '71234567', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'PASAJERO'),
('Maria', 'Garcia', 'maria@test.com', '72345678', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'PASAJERO'),
('Pedro', 'Flores', 'pedro@test.com', '73456789', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'PASAJERO'),
('Ana', 'Vargas', 'ana.vargas@test.com', '74567890', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'PASAJERO'),
('Juan', 'Perez', 'juan.perez@test.com', '76543210', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'CONDUCTOR'),
('Carlos', 'Rojas', 'carlos.rojas@test.com', '70000001', '$2a$10$s38tCRwnFEZTOHuJEp1/T.GP35V3V8Y8adAiaYgTdmqkQRUty4p0C', 'CONDUCTOR');

INSERT INTO pasajeros (id_usuario, ci, tipo, fecha_nacimiento, direccion) VALUES
((SELECT id_usuario FROM usuarios WHERE correo = 'sebastian@test.com'), '1234567', 'estudiante', '2002-05-14', 'Av. Banzer 3er anillo'),
((SELECT id_usuario FROM usuarios WHERE correo = 'maria@test.com'), '7654321', 'civil', '1995-09-23', 'Barrio Villa Primero de Mayo'),
((SELECT id_usuario FROM usuarios WHERE correo = 'pedro@test.com'), '1122334', 'adulto_mayor', '1958-03-02', 'Zone Plan 3000'),
((SELECT id_usuario FROM usuarios WHERE correo = 'ana.vargas@test.com'), '2222222', 'civil', '1990-11-11', 'Av. Radial 27');

INSERT INTO conductores (id_usuario, ci, numero_licencia, fecha_vencimiento) VALUES
((SELECT id_usuario FROM usuarios WHERE correo = 'juan.perez@test.com'), '9876543', 'LIC-12345', '2027-12-31'),
((SELECT id_usuario FROM usuarios WHERE correo = 'carlos.rojas@test.com'), '1010101', 'LIC-67890', '2028-06-30');

INSERT INTO vehiculos (placa, modelo, marca, color, capacidad) VALUES
('1234-ABC', '2015', 'Mercedes-Benz', 'Blanco', 45),
('5678-DEF', '2018', 'Yutong', 'Verde', 50);

INSERT INTO rutas (nombre, numero, descripcion, tarifa) VALUES
('Centro - Villa Primero de Mayo', '1', 'Ida y vuelta por av. Integracion', 2.00),
('Terminal - Plan 3000', '41', 'Ruta expresa por doble via la barrera', 2.50);

INSERT INTO tarjetas (id_pasajero, codigo_qr) VALUES
((SELECT id_pasajero FROM pasajeros WHERE ci = '1234567'), 'QR-PAS-0001'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '7654321'), 'QR-PAS-0002'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '1122334'), 'QR-PAS-0003'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '2222222'), 'QR-PAS-0004');

INSERT INTO saldos (id_pasajero, saldo_actual) VALUES
((SELECT id_pasajero FROM pasajeros WHERE ci = '1234567'), 50.00),
((SELECT id_pasajero FROM pasajeros WHERE ci = '7654321'), 30.00),
((SELECT id_pasajero FROM pasajeros WHERE ci = '1122334'), 15.00),
((SELECT id_pasajero FROM pasajeros WHERE ci = '2222222'), 25.00);

INSERT INTO recargas (id_pasajero, monto, metodo_pago) VALUES
((SELECT id_pasajero FROM pasajeros WHERE ci = '1234567'), 50.00, 'qr'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '7654321'), 30.00, 'efectivo');

INSERT INTO cobros (id_pasajero, id_conductor, id_vehiculo, id_ruta, monto, metodo_pago, tipo_usuario, codigo_transaccion) VALUES
((SELECT id_pasajero FROM pasajeros WHERE ci = '1234567'),
 (SELECT id_conductor FROM conductores WHERE numero_licencia = 'LIC-12345'),
 (SELECT id_vehiculo FROM vehiculos WHERE placa = '1234-ABC'),
 (SELECT id_ruta FROM rutas WHERE numero = '1'), 2.00, 'qr', 'estudiante', 'TXN-20260821-000001'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '7654321'),
 (SELECT id_conductor FROM conductores WHERE numero_licencia = 'LIC-12345'),
 (SELECT id_vehiculo FROM vehiculos WHERE placa = '1234-ABC'),
 (SELECT id_ruta FROM rutas WHERE numero = '1'), 2.00, 'qr', 'civil', 'TXN-20260821-000002'),
((SELECT id_pasajero FROM pasajeros WHERE ci = '2222222'),
 (SELECT id_conductor FROM conductores WHERE numero_licencia = 'LIC-67890'),
 (SELECT id_vehiculo FROM vehiculos WHERE placa = '5678-DEF'),
 (SELECT id_ruta FROM rutas WHERE numero = '41'), 2.50, 'qr', 'civil', 'TXN-20260821-000003');

-- ============================================================
-- CONSULTAS UTILES
-- ============================================================
-- Saldo de un pasajero por CI:
--   SELECT p.ci, u.nombre, s.saldo_actual
--   FROM saldos s JOIN pasajeros p ON p.id_pasajero = s.id_pasajero
--   JOIN usuarios u ON u.id_usuario = p.id_usuario
--   WHERE p.ci = '1234567';
--
-- Historial de cobros de un pasajero:
--   SELECT c.fecha, c.hora, r.nombre AS ruta, c.monto, c.estado
--   FROM cobros c
--   JOIN pasajeros p ON p.id_pasajero = c.id_pasajero
--   JOIN rutas r ON r.id_ruta = c.id_ruta
--   WHERE p.ci = '1234567' ORDER BY c.fecha DESC, c.hora DESC;
--
-- Recaudacion de un conductor por fecha:
--   SELECT c.fecha, COUNT(*) AS pasajeros, SUM(c.monto) AS total
--   FROM cobros c JOIN conductores cond ON cond.id_conductor = c.id_conductor
--   WHERE cond.numero_licencia = 'LIC-12345' AND c.estado = 'exitoso'
--   GROUP BY c.fecha;
