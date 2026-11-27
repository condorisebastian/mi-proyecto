-- MariaDB / XAMPP: conserva los cobros existentes como un pasaje.
USE proyecto_cobros;
ALTER TABLE cobros
  ADD COLUMN IF NOT EXISTS cantidad_pasajeros SMALLINT UNSIGNED NOT NULL DEFAULT 1;
