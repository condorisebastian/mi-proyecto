-- ============================================================
-- Migracion: acceso por PIN unico de 4 digitos
-- Base: `proyecto_cobros` YA existente. NO borra datos.
--
-- Uso (phpMyAdmin): seleccionar `proyecto_cobros` > Importar > este archivo.
-- Uso (CLI):
--   C:\xampp\mysql\bin\mysql.exe -u root proyecto_cobros < database\migration_pin.sql
--
-- A las filas que no coincidan con los datos de prueba se les asigna un PIN
-- automatico (7001+ pasajeros, 8001+ conductores). Consultarlos con:
--   SELECT p.ci, p.pin, u.nombre FROM pasajeros p
--     JOIN usuarios u ON u.id_usuario = p.id_usuario;
-- ============================================================

-- 1) El CI pasa a ser opcional (se conserva el UNIQUE).
ALTER TABLE pasajeros   MODIFY ci VARCHAR(20) NULL;
ALTER TABLE conductores MODIFY ci VARCHAR(20) NULL;

-- 2) Nueva columna pin (NULL temporal para poder poblarla).
ALTER TABLE pasajeros   ADD COLUMN pin CHAR(4) NULL UNIQUE AFTER ci;
ALTER TABLE conductores ADD COLUMN pin CHAR(4) NULL UNIQUE AFTER ci;

-- 3) PINs conocidos de los datos de prueba (identificados por CI).
UPDATE pasajeros   SET pin = '1234' WHERE ci = '1234567'; -- Sebastian (estudiante)
UPDATE pasajeros   SET pin = '2345' WHERE ci = '7654321'; -- Maria (civil)
UPDATE pasajeros   SET pin = '3456' WHERE ci = '1122334'; -- Pedro (adulto mayor)
UPDATE pasajeros   SET pin = '4567' WHERE ci = '2222222'; -- Ana (civil)
UPDATE conductores SET pin = '5678' WHERE ci = '9876543'; -- Juan
UPDATE conductores SET pin = '6789' WHERE ci = '1010101'; -- Carlos

-- 4) PIN automatico y unico para el resto de las filas.
SET @p = 7000;
UPDATE pasajeros SET pin = LPAD(@p := @p + 1, 4, '0')
WHERE pin IS NULL ORDER BY id_pasajero;

SET @c = 8000;
UPDATE conductores SET pin = LPAD(@c := @c + 1, 4, '0')
WHERE pin IS NULL ORDER BY id_conductor;

-- 5) Exigir el PIN.
ALTER TABLE pasajeros   MODIFY pin CHAR(4) NOT NULL;
ALTER TABLE conductores MODIFY pin CHAR(4) NOT NULL;
