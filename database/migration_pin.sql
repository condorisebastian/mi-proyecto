-- ============================================================
-- Migracion: acceso por PIN unico de 4 digitos
-- Base: `proyecto_cobros` YA existente. NO borra datos.
--
-- Uso (phpMyAdmin): seleccionar `proyecto_cobros` > Importar > este archivo.
-- Uso (CLI):
--   C:\xampp\mysql\bin\mysql.exe -u root proyecto_cobros < database\migration_pin.sql
-- ============================================================

-- 1) El CI pasa a ser opcional (se conserva el UNIQUE).
ALTER TABLE pasajeros   MODIFY ci VARCHAR(20) NULL;
ALTER TABLE conductores MODIFY ci VARCHAR(20) NULL;

-- 2) Nueva columna pin (NULL temporal para poder poblarla).
ALTER TABLE pasajeros   ADD COLUMN pin CHAR(4) NULL UNIQUE AFTER ci;
ALTER TABLE conductores ADD COLUMN pin CHAR(4) NULL UNIQUE AFTER ci;

-- 3) PINs para los datos de prueba existentes (identificados por CI).
UPDATE pasajeros   SET pin = '1234' WHERE ci = '1234567'; -- Sebastian (estudiante)
UPDATE pasajeros   SET pin = '2345' WHERE ci = '7654321'; -- Maria (civil)
UPDATE pasajeros   SET pin = '3456' WHERE ci = '1122334'; -- Pedro (adulto mayor)
UPDATE pasajeros   SET pin = '4567' WHERE ci = '2222222'; -- Ana (civil)
UPDATE conductores SET pin = '5678' WHERE ci = '9876543'; -- Juan
UPDATE conductores SET pin = '6789' WHERE ci = '1010101'; -- Carlos

-- 4) Exigir el PIN. Si existieran filas sin PIN, asignar uno unico a cada
--    una ANTES de ejecutar este paso (el UNIQUE rechaza duplicados/NULL).
ALTER TABLE pasajeros   MODIFY pin CHAR(4) NOT NULL;
ALTER TABLE conductores MODIFY pin CHAR(4) NOT NULL;
