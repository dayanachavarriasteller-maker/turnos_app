import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/turno.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

/// Cliente REST. Toda la lógica de negocio vive en el servidor.
class ApiService {
  static const _headers = {'Content-Type': 'application/json'};
  Uri _u(String p) => Uri.parse('${AppConfig.apiBase}$p');

  dynamic _handle(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = (body is Map && body['error'] != null) ? body['error'] as String : 'Error ${r.statusCode}';
    throw ApiException(msg, r.statusCode);
  }

  Future<T> _safe<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 8));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor', 0);
    }
  }

  Future<List<Turno>> listar() => _safe(() async {
        final data = _handle(await http.get(_u('/api/turnos'))) as List;
        return data.map((e) => Turno.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Turno> crear(String? asunto) => _safe(() async {
        final r = await http.post(_u('/api/turnos'),
            headers: _headers, body: jsonEncode({'asunto': asunto}));
        return Turno.fromJson(_handle(r) as Map<String, dynamic>);
      });

  Future<Turno> llamarSiguiente(String funcionario) => _safe(() async {
        final r = await http.post(_u('/api/turnos/siguiente'),
            headers: _headers, body: jsonEncode({'funcionario': funcionario}));
        return Turno.fromJson(_handle(r) as Map<String, dynamic>);
      });

  Future<Turno> _cambiar(int id, String estado, String funcionario) => _safe(() async {
        final r = await http.patch(_u('/api/turnos/$id'),
            headers: _headers,
            body: jsonEncode({'estado': estado, 'funcionario': funcionario}));
        return Turno.fromJson(_handle(r) as Map<String, dynamic>);
      });

  Future<Turno> llamar(int id, String f) => _cambiar(id, 'llamado', f);
  Future<Turno> atender(int id, String f) => _cambiar(id, 'atendido', f);
}
