import 'package:flutter/material.dart';

/// Paleta del mockup Diez Mil (paño verde + oro).
class AppColors {
  static const fondo = Color(0xFF0B2B1F);
  static const fondoSuave = Color(0xFF123528);
  static const carta = Color(0xFF163D2E);
  static const cartaBorde = Color(0xFF1F4D3A);
  static const acento = Color(0xFFF5C518);
  static const acentoSuave = Color(0xFFE8B40A);
  static const mint = Color(0xFF3DCF9A);
  static const texto = Color(0xFFF7F3E8);
  static const textoSuave = Color(0xFFA8B8B0);
  static const peligro = Color(0xFFE57373);
  static const nav = Color(0xFF071F16);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.acento,
      brightness: Brightness.dark,
      surface: AppColors.fondo,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.fondo,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.texto,
      displayColor: AppColors.texto,
      fontFamily: 'Segoe UI',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.texto,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.acento,
        foregroundColor: const Color(0xFF1A1204),
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        side: const BorderSide(color: AppColors.cartaBorde, width: 1.5),
        backgroundColor: AppColors.carta,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.carta,
      labelStyle: const TextStyle(color: AppColors.textoSuave),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fondoSuave),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.acento, width: 2),
      ),
    ),
  );
}
