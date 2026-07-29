import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Estilo arcade / neon del mockup Diez Mil.
class AppColors {
  static const fondo = Color(0xFF12081F);
  static const fondoSuave = Color(0xFF1C0F33);
  static const carta = Color(0xFF24143F);
  static const cartaBorde = Color(0xFF3A2460);
  static const acento = Color(0xFFFFC107);
  static const acentoSuave = Color(0xFFFF9800);
  static const azul = Color(0xFF40C4FF);
  static const azulSuave = Color(0xFF2979FF);
  static const violeta = Color(0xFF7C4DFF);
  static const rosa = Color(0xFFE040FB);
  static const mint = Color(0xFF69F0AE);
  static const texto = Color(0xFFF8F5FF);
  static const textoSuave = Color(0xFFB8A8D4);
  static const peligro = Color(0xFFFF5252);
  static const nav = Color(0xFF0B0514);
}

ThemeData buildAppTheme() {
  // Nunito: misma tipografía en Windows, web y demás (no depende de Segoe UI).
  final textTheme = GoogleFonts.nunitoTextTheme(
    ThemeData(brightness: Brightness.dark).textTheme,
  ).apply(
    bodyColor: AppColors.texto,
    displayColor: AppColors.texto,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violeta,
      brightness: Brightness.dark,
      surface: AppColors.fondo,
    ),
    textTheme: textTheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.texto,
      titleTextStyle: GoogleFonts.nunito(
        color: AppColors.texto,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.acento,
        foregroundColor: const Color(0xFF1A0A00),
        minimumSize: const Size.fromHeight(54),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        side: const BorderSide(color: AppColors.violeta, width: 1.5),
        backgroundColor: AppColors.carta,
        minimumSize: const Size.fromHeight(54),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.carta,
      labelStyle: GoogleFonts.nunito(color: AppColors.textoSuave),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cartaBorde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.acento, width: 2),
      ),
    ),
  );
}

List<BoxShadow> neonGlow(Color color, {double blur = 14, double spread = 0}) => [
      BoxShadow(
        color: color.withValues(alpha: 0.55),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.25),
        blurRadius: blur * 1.8,
        spreadRadius: spread + 1,
      ),
    ];
