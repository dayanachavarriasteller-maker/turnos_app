import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/turno.dart';
import '../services/api_service.dart';

/// Estado de la app (GetX) + conexión WebSocket con reconexión automática.
class TurnosController extends GetxController {
  final _api = ApiService();

  final turnos = <Turno>[].obs;
  final conectado = false.obs;
  final cargando = false.obs;
  final funcionario = ''.obs;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retry;
  int _intentos = 0;
  bool _cerrado = false;

  // ---- Vistas derivadas ----
  List<Turno> get pendientes =>
      turnos.where((t) => t.estado == 'pendiente').toList()..sort((a, b) => a.numero.compareTo(b.numero));
  List<Turno> get llamados =>
      turnos.where((t) => t.estado == 'llamado').toList()..sort((a, b) => a.numero.compareTo(b.numero));
  List<Turno> get atendidos =>
      turnos.where((t) => t.estado == 'atendido').toList()
        ..sort((a, b) => (b.atendidoEn ?? b.creadoEn).compareTo(a.atendidoEn ?? a.creadoEn));

  @override
  void onInit() {
    super.onInit();
    _conectar();
  }

  @override
  void onClose() {
    _cerrado = true;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.onClose();
  }

  // ---- WebSocket ----
  Future<void> _conectar() async {
    if (_cerrado) return;
    try {
      final ch = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      await ch.ready; // lanza excepción si no logra conectar
      _channel = ch;
      conectado.value = true;
      _intentos = 0;
      // El servidor envía un 'snapshot' al conectar: así se recupera el estado real.
      _sub = ch.stream.listen(
        _onMensaje,
        onDone: _onDesconectado,
        onError: (_) => _onDesconectado(),
        cancelOnError: true,
      );
    } catch (_) {
      _onDesconectado();
    }
  }

  void _onDesconectado() {
    conectado.value = false;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    if (_cerrado || (_retry?.isActive ?? false)) return;
    // Backoff exponencial: 1, 2, 4, 8, 16, 30 s
    final espera = min(30, 1 << min(_intentos, 5));
    _intentos++;
    _retry = Timer(Duration(seconds: espera), _conectar);
  }

  void _onMensaje(dynamic raw) {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (data['type']) {
      case 'snapshot':
        turnos.assignAll((data['turnos'] as List).map((e) => Turno.fromJson(e as Map<String, dynamic>)));
        break;
      case 'turno_creado':
      case 'turno_actualizado':
        _upsert(Turno.fromJson(data['turno'] as Map<String, dynamic>));
        break;
    }
  }

  void _upsert(Turno t) {
    final i = turnos.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      turnos[i] = t;
    } else {
      turnos.add(t);
    }
  }

  Future<void> refrescar() async {
    try {
      turnos.assignAll(await _api.listar());
    } on ApiException catch (e) {
      _aviso(e.message, error: true);
    }
  }

  // ---- Acciones ----
  void entrar(String nombre) => funcionario.value = nombre.trim();
  void salir() => funcionario.value = '';

  bool _requiereFuncionario() {
    if (funcionario.value.isEmpty) {
      _aviso('Primero identifícate como funcionario', error: true);
      return false;
    }
    return true;
  }

  Future<void> crearTurno(String? asunto) async {
    cargando.value = true;
    try {
      final t = await _api.crear(asunto == null || asunto.trim().isEmpty ? null : asunto.trim());
      _upsert(t);
      _aviso('Turno ${t.numero} creado');
    } on ApiException catch (e) {
      _aviso(e.message, error: true);
    } finally {
      cargando.value = false;
    }
  }

  Future<void> llamarSiguiente() => _ejecutar(() => _api.llamarSiguiente(funcionario.value),
      exito: (t) => 'Llamaste al turno ${t.numero}');

  Future<void> llamar(Turno t) =>
      _ejecutar(() => _api.llamar(t.id, funcionario.value), exito: (t) => 'Llamaste al turno ${t.numero}');

  Future<void> atender(Turno t) =>
      _ejecutar(() => _api.atender(t.id, funcionario.value), exito: (t) => 'Turno ${t.numero} atendido');

  Future<void> _ejecutar(Future<Turno> Function() accion, {required String Function(Turno) exito}) async {
    if (!_requiereFuncionario()) return;
    cargando.value = true;
    try {
      final t = await accion();
      _upsert(t); // idempotente: el broadcast WebSocket traerá el mismo turno
      _aviso(exito(t));
    } on ApiException catch (e) {
      _aviso(e.message, error: true);
      if (e.status == 409 || e.status == 404) await refrescar(); // alguien se adelantó: resincroniza
    } finally {
      cargando.value = false;
    }
  }

  void _aviso(String msg, {bool error = false}) {
    Get.closeAllSnackbars();
    Get.snackbar(
      error ? 'Aviso' : 'Listo',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      maxWidth: 480,
      margin: const EdgeInsets.all(12),
    );
  }
}
