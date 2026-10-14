// Prueba de evidencia: 10 funcionarios intentan llamar el MISMO turno a la vez
// y un cliente WebSocket observa el cambio sin recargar.  Uso: npm run test:concurrencia
const WebSocket = require('ws');
const BASE = process.env.BASE || 'http://localhost:3000';
const WS = BASE.replace('http', 'ws') + '/ws';
const j = (r) => r.json();
const post = (p, b) => fetch(BASE + p, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) });
const patch = (p, b) => fetch(BASE + p, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) });

(async () => {
  const eventos = [];
  const ws = new WebSocket(WS);
  await new Promise((r) => ws.on('open', r));
  ws.on('message', (m) => eventos.push(JSON.parse(m)));

  const t = await post('/api/turnos', { asunto: 'prueba concurrencia' }).then(j);
  console.log(`1) Turno creado: #${t.numero} (id ${t.id}) estado=${t.estado}`);

  const intentos = Array.from({ length: 10 }, (_, i) => patch(`/api/turnos/${t.id}`, { estado: 'llamado', funcionario: `Funcionario ${i + 1}` }));
  const resp = await Promise.all(intentos);
  const codigos = resp.map((r) => r.status);
  console.log('2) Códigos HTTP de 10 PATCH simultáneos:', codigos.join(', '));
  const ok = codigos.filter((c) => c === 200).length;
  const conflictos = codigos.filter((c) => c === 409).length;
  console.log(`   Éxitos: ${ok} | Conflictos 409: ${conflictos}`);

  await new Promise((r) => setTimeout(r, 300));
  const act = eventos.filter((e) => e.type === 'turno_actualizado' && e.turno.id === t.id);
  console.log(`3) Eventos WebSocket 'turno_actualizado' recibidos para ese turno: ${act.length}`);
  console.log(`   Ganador según el evento: ${act[0]?.turno.funcionario}`);

  // llamar siguiente concurrentemente con varios pendientes
  for (let i = 0; i < 5; i++) await post('/api/turnos', {});
  const sig = await Promise.all(Array.from({ length: 5 }, (_, i) => post('/api/turnos/siguiente', { funcionario: `Func ${i + 1}` }).then(j)));
  const nums = sig.map((s) => s.numero);
  console.log('4) 5 "llamar siguiente" simultáneos -> turnos asignados:', nums.join(', '));
  console.log('   ¿Sin duplicados?', new Set(nums).size === nums.length ? 'SÍ' : 'NO');

  const pass = ok === 1 && conflictos === 9 && act.length === 1 && new Set(nums).size === nums.length;
  console.log(pass ? '\nRESULTADO: OK (concurrencia garantizada)' : '\nRESULTADO: FALLÓ');
  ws.close();
  process.exit(pass ? 0 : 1);
})();
