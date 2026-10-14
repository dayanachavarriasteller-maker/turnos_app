// API REST (Express) + WebSockets (ws) en el mismo puerto.
const express = require('express');
const cors = require('cors');
const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');
const repo = require('./db');

const PORT = process.env.PORT || 3000;
const ESTADOS = ['pendiente', 'llamado', 'atendido'];

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

// ---------- WebSockets ----------
function broadcast(tipo, turno) {
  const msg = JSON.stringify({ type: tipo, turno });
  for (const c of wss.clients) if (c.readyState === WebSocket.OPEN) c.send(msg);
}

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));
  // Al conectar (o reconectar) el cliente recibe el estado real completo.
  ws.send(JSON.stringify({ type: 'snapshot', turnos: repo.listar() }));
});

// Heartbeat: detecta clientes caídos sin cierre limpio.
const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);
wss.on('close', () => clearInterval(heartbeat));

// ---------- Validación (el servidor NO confía en el cliente) ----------
function validarFuncionario(v) {
  if (typeof v !== 'string') return null;
  const s = v.trim();
  return s.length >= 2 && s.length <= 50 ? s : null;
}

// ---------- REST ----------
app.get('/api/turnos', (req, res) => {
  const { estado } = req.query;
  if (estado && !ESTADOS.includes(estado))
    return res.status(400).json({ error: `estado debe ser uno de: ${ESTADOS.join(', ')}` });
  res.json(repo.listar(estado));
});

app.post('/api/turnos', (req, res) => {
  let asunto = req.body?.asunto;
  if (asunto !== undefined && asunto !== null) {
    if (typeof asunto !== 'string' || asunto.trim().length > 80)
      return res.status(400).json({ error: 'asunto debe ser texto de máximo 80 caracteres' });
    asunto = asunto.trim();
  }
  const turno = repo.crear(asunto);
  broadcast('turno_creado', turno);
  res.status(201).json(turno);
});

// Llamar al siguiente turno pendiente (el servidor elige cuál: el de menor número).
app.post('/api/turnos/siguiente', (req, res) => {
  const funcionario = validarFuncionario(req.body?.funcionario);
  if (!funcionario) return res.status(400).json({ error: 'funcionario es requerido (2 a 50 caracteres)' });
  const turno = repo.llamarSiguiente(funcionario);
  if (!turno) return res.status(404).json({ error: 'No hay turnos pendientes' });
  broadcast('turno_actualizado', turno);
  res.json(turno);
});

// Cambiar estado: pendiente -> llamado -> atendido
app.patch('/api/turnos/:id', (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ error: 'id inválido' });

  const { estado } = req.body || {};
  const funcionario = validarFuncionario(req.body?.funcionario);
  if (!['llamado', 'atendido'].includes(estado))
    return res.status(400).json({ error: "estado debe ser 'llamado' o 'atendido'" });
  if (!funcionario) return res.status(400).json({ error: 'funcionario es requerido (2 a 50 caracteres)' });

  const actual = repo.obtener(id);
  if (!actual) return res.status(404).json({ error: 'Turno no encontrado' });

  const turno = estado === 'llamado' ? repo.llamar(id, funcionario) : repo.atender(id, funcionario);
  if (!turno) {
    // El UPDATE condicional no afectó filas: alguien se nos adelantó o la transición no es válida.
    const ahora = repo.obtener(id);
    const detalle =
      estado === 'llamado'
        ? `El turno ${ahora.numero} ya fue llamado por ${ahora.funcionario || 'otro funcionario'}`
        : `El turno ${ahora.numero} no está en estado 'llamado' por ${funcionario}`;
    return res.status(409).json({ error: detalle, turno: ahora });
  }
  broadcast('turno_actualizado', turno);
  res.json(turno);
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

server.listen(PORT, () => console.log(`API en http://localhost:${PORT}/api/turnos  |  WS en ws://localhost:${PORT}/ws`));
