-- ============================================
-- SCRIPT DE BASE DE DATOS: bd_cobros
-- Sistema de Transporte Santa Cruz
-- ============================================

-- Crear base de datos
CREATE DATABASE bd_cobros;
GO

USE bd_cobros;
GO

-- Tabla de usuarios (estudiantes, civiles, adultos mayores)
CREATE TABLE usuarios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    apellido NVARCHAR(100) NOT NULL,
    ci NVARCHAR(20) UNIQUE NOT NULL,
    email NVARCHAR(150) UNIQUE NOT NULL,
    password NVARCHAR(255) NOT NULL,
    tipo NVARCHAR(20) NOT NULL CHECK (tipo IN ('estudiante', 'civil', 'adulto_mayor')),
    puntos INT DEFAULT 0,
    estado NVARCHAR(10) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo')),
    fecha_creacion DATETIME DEFAULT GETDATE()
);
GO

-- Tabla de conductores
CREATE TABLE conductores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    apellido NVARCHAR(100) NOT NULL,
    ci NVARCHAR(20) UNIQUE NOT NULL,
    licencia NVARCHAR(50) UNIQUE NOT NULL,
    password NVARCHAR(255) NOT NULL,
    telefono NVARCHAR(20),
    estado NVARCHAR(10) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo')),
    fecha_creacion DATETIME DEFAULT GETDATE()
);
GO

-- Tabla de tarjetas NFC
CREATE TABLE tarjetas_nfc (
    id INT IDENTITY(1,1) PRIMARY KEY,
    numero NVARCHAR(50) UNIQUE NOT NULL,
    id_usuario INT NOT NULL,
    estado NVARCHAR(10) DEFAULT 'activa' CHECK (estado IN ('activa', 'bloqueada', 'perdida')),
    fecha_creacion DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
);
GO

-- Tabla de transacciones
CREATE TABLE transacciones (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario INT,
    id_conductor INT NOT NULL,
    puntos INT NOT NULL,
    tipo NVARCHAR(20) NOT NULL CHECK (tipo IN ('cobro_viaje', 'recarga')),
    metodo_pago NVARCHAR(20) NOT NULL CHECK (metodo_pago IN ('tarjeta_nfc', 'qr', 'recarga', 'qr_bancario', 'tigo_money', 'unnocc')),
    estado NVARCHAR(10) DEFAULT 'completada' CHECK (estado IN ('completada', 'fallida', 'pendiente')),
    fecha DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id),
    FOREIGN KEY (id_conductor) REFERENCES conductores(id)
);
GO

-- Tabla de precios por tipo de usuario
CREATE TABLE precios (
    id INT IDENTITY(1,1) PRIMARY KEY,
    tipo_usuario NVARCHAR(20) UNIQUE NOT NULL CHECK (tipo_usuario IN ('estudiante', 'civil', 'adulto_mayor')),
    puntos_por_viaje INT NOT NULL
);
GO

-- ============================================
-- DATOS DE PRUEBA
-- ============================================

-- Insertar precios
INSERT INTO precios (tipo_usuario, puntos_por_viaje) VALUES
('estudiante', 1),
('civil', 3),
('adulto_mayor', 1);
GO

-- Insertar usuarios de prueba (password: 123456)
INSERT INTO usuarios (nombre, apellido, ci, email, password, tipo, puntos) VALUES
('Sebastián', 'Condori', '1234567', 'sebastian@test.com', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', 'estudiante', 15),
('María', 'García', '7654321', 'maria@test.com', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', 'civil', 30),
('Pedro', 'Flores', '1122334', 'pedro@test.com', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', 'adulto_mayor', 10),
('Ana', 'Vargas', '2222222', 'ana.vargas@test.com', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', 'civil', 25);
GO

-- Insertar conductor de prueba
INSERT INTO conductores (nombre, apellido, ci, licencia, password, telefono) VALUES
('Juan', 'Pérez', '9876543', 'LIC-12345', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', '76543210'),
('Carlos', 'Rojas', '1010101', 'LIC-67890', '$2a$10$HxJ1bipGruvCjUxfBXKQnOXzITv2K/yuTUhkoaLwsJmcfQqCYtcG.', '70000001');
GO

-- Insertar tarjetas NFC de prueba
INSERT INTO tarjetas_nfc (numero, id_usuario) VALUES
('NFC-001-2026', 1),
('NFC-002-2026', 2),
('NFC-003-2026', 3);
GO

-- ============================================
-- CONSULTAS ÚTILES
-- ============================================

-- Consultar saldo de un usuario
SELECT nombre, apellido, ci, puntos, tipo
FROM usuarios
WHERE ci = '1234567';

-- Consultar transacciones del día
SELECT u.nombre, u.apellido, u.tipo, t.puntos, t.metodo_pago, t.fecha
FROM transacciones t
INNER JOIN usuarios u ON t.id_usuario = u.id
WHERE CAST(t.fecha AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY t.fecha DESC;

-- Resumen diario de un conductor
SELECT 
    c.nombre + ' ' + c.apellido AS conductor,
    COUNT(t.id) AS total_pasajeros,
    SUM(t.puntos) AS total_puntos
FROM transacciones t
INNER JOIN conductores c ON t.id_conductor = c.id
WHERE CAST(t.fecha AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY c.nombre, c.apellido;

-- Historial de un usuario
SELECT t.fecha, t.tipo, t.puntos, t.metodo_pago
FROM transacciones t
WHERE t.id_usuario = 1
ORDER BY t.fecha DESC;
GO
