-- ============================================================
-- Migracion: tabla `incidencias` (centro de atencion / call center)
-- Base: `proyecto_cobros` YA existente. NO borra datos.
--
-- Contexto: el call center funcionaba solo en Cloud Firestore
-- (coleccion `incidencias`). Esta migracion agrega la persistencia
-- en MySQL para que el modelo conceptual/relacional sea completo.
--
-- Uso (phpMyAdmin): seleccionar `proyecto_cobros` > Importar > este archivo.
-- Uso (CLI):
--   C:\xampp\mysql\bin\mysql.exe -u root proyecto_cobros < database\migration_incidencias.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS incidencias (
  id_incidencia    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  canal            ENUM('pasajero','conductor') NOT NULL
                   COMMENT 'quien reporta: app pasajero o conductor',
  reportante_clave VARCHAR(20)  NOT NULL
                   COMMENT 'PIN o CI del reportante (usado por la app)',
  nombre           VARCHAR(160) NOT NULL COMMENT 'nombre del reportante',
  tipo             VARCHAR(30)  NOT NULL DEFAULT 'otros',
  descripcion      TEXT         NOT NULL,
  prioridad        ENUM('baja','media','alta') NOT NULL DEFAULT 'media',
  estado           ENUM('nueva','en_curso','resuelta','cerrada') NOT NULL DEFAULT 'nueva',
  respuesta        TEXT         NULL,
  notas            JSON         NULL COMMENT 'bitacora: [{fecha, texto, usuario}]',
  acciones         JSON         NULL COMMENT 'estado historico de la incidencia',
  fecha_creacion   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_resolucion DATETIME     NULL,
  INDEX idx_inci_reportante (canal, reportante_clave),
  INDEX idx_inci_estado (estado),
  INDEX idx_inci_fecha (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;