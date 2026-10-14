/// Dirección del backend. Usa el mismo host desde el que se sirve la web,
/// así funciona igual en localhost o desde otro equipo de la red.
class AppConfig {
  static String get _host => Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
  static String get apiBase => 'http://$_host:3000';
  static String get wsUrl => 'ws://$_host:3000/ws';
}
