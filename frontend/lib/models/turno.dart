class Turno {
  final int id;
  final int numero;
  final String? asunto;
  final String estado; // pendiente | llamado | atendido
  final String? funcionario;
  final DateTime creadoEn;
  final DateTime? llamadoEn;
  final DateTime? atendidoEn;

  const Turno({
    required this.id,
    required this.numero,
    required this.estado,
    required this.creadoEn,
    this.asunto,
    this.funcionario,
    this.llamadoEn,
    this.atendidoEn,
  });

  factory Turno.fromJson(Map<String, dynamic> j) {
    DateTime? f(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
    return Turno(
      id: j['id'] as int,
      numero: j['numero'] as int,
      asunto: j['asunto'] as String?,
      estado: j['estado'] as String,
      funcionario: j['funcionario'] as String?,
      creadoEn: f(j['creado_en'])!,
      llamadoEn: f(j['llamado_en']),
      atendidoEn: f(j['atendido_en']),
    );
  }
}
