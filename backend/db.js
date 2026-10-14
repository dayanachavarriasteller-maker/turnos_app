// Capa de persistencia: SQLite (archivo turnos.db, sobrevive a reinicios).
const Database = require('better-sqlite3');
const path = require('path');

const db = new Database(process.env.DB_FILE || path.join(__dirname, 'turnos.db'));
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');

db.exec(`
  CREATE TABLE IF NOT EXISTS turnos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    numero      INTEGER NOT NULL UNIQUE,            -- consecutivo asignado por el servidor
    asunto      TEXT,
    estado      TEXT NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','llamado','atendido')),
    funcionario TEXT,
    creado_en   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    llamado_en  TEXT,
    atendido_en TEXT
  );
  CREATE INDEX IF NOT EXISTS idx_turnos_estado_numero ON turnos(estado, numero);
`);

const AHORA = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";

const listar = (estado) =>
  estado
    ? db.prepare('SELECT * FROM turnos WHERE estado = ? ORDER BY numero').all(estado)
    : db.prepare('SELECT * FROM turnos ORDER BY numero').all();

const obtener = (id) => db.prepare('SELECT * FROM turnos WHERE id = ?').get(id);

// El consecutivo se calcula DENTRO de una transacción inmediata: nadie más puede
// escribir entre el MAX() y el INSERT. Además numero es UNIQUE como segunda defensa.
const crear = db.transaction((asunto) => {
  const { n } = db.prepare('SELECT COALESCE(MAX(numero),0) + 1 AS n FROM turnos').get();
  return db
    .prepare('INSERT INTO turnos (numero, asunto) VALUES (?, ?) RETURNING *')
    .get(n, asunto || null);
}).immediate;

// --- Transiciones de estado: UPDATE condicional atómico (compare-and-set) ---
// La condición "AND estado = 'pendiente'" va en el propio UPDATE, así que la base
// de datos decide un único ganador. Si changes = 0, otro funcionario llegó primero.

const llamar = (id, funcionario) =>
  db
    .prepare(
      `UPDATE turnos SET estado='llamado', funcionario=?, llamado_en=${AHORA}
       WHERE id=? AND estado='pendiente' RETURNING *`
    )
    .get(funcionario, id);

const llamarSiguiente = (funcionario) =>
  db
    .prepare(
      `UPDATE turnos SET estado='llamado', funcionario=?, llamado_en=${AHORA}
       WHERE id = (SELECT id FROM turnos WHERE estado='pendiente' ORDER BY numero LIMIT 1)
         AND estado='pendiente'
       RETURNING *`
    )
    .get(funcionario);

const atender = (id, funcionario) =>
  db
    .prepare(
      `UPDATE turnos SET estado='atendido', atendido_en=${AHORA}
       WHERE id=? AND estado='llamado' AND funcionario=? RETURNING *`
    )
    .get(id, funcionario);

module.exports = { listar, obtener, crear, llamar, llamarSiguiente, atender };
