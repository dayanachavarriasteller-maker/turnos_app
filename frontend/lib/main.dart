import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/turnos_controller.dart';
import 'views/home_page.dart';

void main() {
  runApp(const TurnosApp());
}

class TurnosApp extends StatelessWidget {
  const TurnosApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(TurnosController());
    return GetMaterialApp(
      title: 'Gestión de turnos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const HomePage(),
    );
  }
}
