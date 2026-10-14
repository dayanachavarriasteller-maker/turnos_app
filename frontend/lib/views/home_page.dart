import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/turnos_controller.dart';
import '../models/turno.dart';

String _2(int n) => n.toString().padLeft(2, '0');
String _hora(DateTime d) => '${_2(d.hour)}:${_2(d.minute)}:${_2(d.second)}';
String _fechaHora(DateTime d) => '${_2(d.day)}/${_2(d.month)}/${d.year} ${_hora(d)}';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TurnosController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de turnos en tiempo real'),
        actions: [
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: Icon(Icons.circle, size: 12, color: c.conectado.value ? Colors.green : Colors.red),
                  label: Text(c.conectado.value ? 'En línea' : 'Reconectando…'),
                ),
              )),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _FuncionarioCard()),
                SizedBox(width: 16),
                Expanded(child: _NuevoTurnoCard()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Columna(titulo: 'Pendientes', color: Colors.orange, turnos: c.pendientes)),
                      const SizedBox(width: 12),
                      Expanded(child: _Columna(titulo: 'Llamados', color: Colors.blue, turnos: c.llamados)),
                      const SizedBox(width: 12),
                      Expanded(child: _Columna(titulo: 'Atendidos (historial)', color: Colors.green, turnos: c.atendidos)),
                    ],
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario 1: identificación del funcionario (con validación).
class _FuncionarioCard extends StatefulWidget {
  const _FuncionarioCard();
  @override
  State<_FuncionarioCard> createState() => _FuncionarioCardState();
}

class _FuncionarioCardState extends State<_FuncionarioCard> {
  final _form = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TurnosController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (c.funcionario.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Funcionario', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(c.funcionario.value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: c.cargando.value ? null : c.llamarSiguiente,
                    icon: const Icon(Icons.campaign),
                    label: const Text('Llamar siguiente'),
                  ),
                  OutlinedButton(onPressed: c.salir, child: const Text('Cambiar')),
                ]),
              ],
            );
          }
          return Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _ctrl,
                  decoration: const InputDecoration(labelText: 'Nombre del funcionario', border: OutlineInputBorder()),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'El nombre es obligatorio';
                    if (s.length < 2) return 'Mínimo 2 caracteres';
                    if (s.length > 50) return 'Máximo 50 caracteres';
                    return null;
                  },
                  onFieldSubmitted: (_) => _entrar(c),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _entrar(c), child: const Text('Entrar')),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _entrar(TurnosController c) {
    if (_form.currentState!.validate()) {
      c.entrar(_ctrl.text);
      _ctrl.clear();
    }
  }
}

/// Formulario 2: registrar un nuevo turno (el número lo asigna el servidor).
class _NuevoTurnoCard extends StatefulWidget {
  const _NuevoTurnoCard();
  @override
  State<_NuevoTurnoCard> createState() => _NuevoTurnoCardState();
}

class _NuevoTurnoCardState extends State<_NuevoTurnoCard> {
  final _form = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _crear(TurnosController c) async {
    if (!_form.currentState!.validate()) return;
    await c.crearTurno(_ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TurnosController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: 'Asunto (opcional)',
                  helperText: 'El número consecutivo lo asigna el sistema',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().length > 80 ? 'Máximo 80 caracteres' : null,
                onFieldSubmitted: (_) => _crear(c),
              ),
              const SizedBox(height: 12),
              Obx(() => FilledButton.icon(
                    onPressed: c.cargando.value ? null : () => _crear(c),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo turno'),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<Turno> turnos;
  const _Columna({required this.titulo, required this.color, required this.turnos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: color.withOpacity(0.15),
            child: Text('$titulo (${turnos.length})', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: turnos.isEmpty
                ? const Center(child: Text('Sin turnos'))
                : ListView.separated(
                    itemCount: turnos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _TurnoTile(turno: turnos[i], color: color),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TurnoTile extends StatelessWidget {
  final Turno turno;
  final Color color;
  const _TurnoTile({required this.turno, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TurnosController>();
    final t = turno;
    String detalle;
    Widget? accion;
    switch (t.estado) {
      case 'pendiente':
        detalle = 'Creado ${_hora(t.creadoEn)}';
        accion = TextButton(onPressed: () => c.llamar(t), child: const Text('Llamar'));
        break;
      case 'llamado':
        detalle = 'Llamado por ${t.funcionario} a las ${_hora(t.llamadoEn ?? t.creadoEn)}';
        accion = Obx(() => t.funcionario == c.funcionario.value
            ? TextButton(onPressed: () => c.atender(t), child: const Text('Atender'))
            : const Text('En atención'));
        break;
      default:
        detalle = 'Atendido por ${t.funcionario}\n${_fechaHora(t.atendidoEn ?? t.creadoEn)}';
    }
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Text('${t.numero}')),
      title: Text(t.asunto?.isNotEmpty == true ? t.asunto! : 'Turno ${t.numero}'),
      subtitle: Text(detalle),
      trailing: accion,
      isThreeLine: t.estado == 'atendido',
    );
  }
}
