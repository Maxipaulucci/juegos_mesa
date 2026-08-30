import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/chanchoVa/chancho_va_online_codec.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/partida_chancho_va_screen.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/partida_culo_sucio_screen.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/partida_culo_sucio_v2_screen.dart';
import 'package:app_juegos_mesa/desconfio/textos.dart';
import 'package:app_juegos_mesa/diezMil/motor.dart';
import 'package:app_juegos_mesa/diezMil/opciones_diez_mil.dart';
import 'package:app_juegos_mesa/diezMil/partida_diez_mil_screen.dart';
import 'package:app_juegos_mesa/escobaDel15/opciones_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/partida_escoba_screen.dart';
import 'package:app_juegos_mesa/generala/opciones_generala.dart';
import 'package:app_juegos_mesa/generala/partida_generala_screen.dart';
import 'package:app_juegos_mesa/guerraDeCartas/textos.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/partida_la_papa_screen.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_store.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/tutiFruti/menu_tuti_fruti_screen.dart';
import 'package:app_juegos_mesa/tutiFruti/partida_tuti_fruti_screen.dart';
import 'package:app_juegos_mesa/unoSolo/partida_uno_solo_screen.dart';

/// Título legible de un [juegoId] de sala.
String tituloJuegoSala(String juegoId) {
  return switch (juegoId) {
    MenuJuegoScreen.juegoIdDiezMil => 'Diez Mil',
    MenuJuegoScreen.juegoIdGenerala => 'Generala',
    MenuJuegoScreen.juegoIdLaPapa => 'La papa',
    MenuJuegoScreen.juegoIdEscobaDel15 => 'Escoba del 15',
    MenuJuegoScreen.juegoIdUnoSolo => 'Uno solo',
    MenuJuegoScreen.juegoIdCuloSucioV1 => 'Culo sucio v1',
    MenuJuegoScreen.juegoIdCuloSucioV2 => 'Culo sucio v2',
    MenuJuegoScreen.juegoIdCasitaRobada => 'Casita robada',
    MenuJuegoScreen.juegoIdChanchoVa => 'Chancho va',
    MenuJuegoScreen.juegoIdGuerraDeCartas => 'Guerra de cartas',
    MenuJuegoScreen.juegoIdDesconfio => 'Desconfío',
    MenuJuegoScreen.juegoIdJodete => 'Jodete',
    juegoIdTutiFruti => 'Tutti Frutti',
    _ => juegoId,
  };
}

String? nombreAnfitrionSala(Sala sala) {
  for (final j in sala.jugadores) {
    if (j.id == sala.anfitrionId) return j.nombre;
  }
  for (final j in sala.jugadores) {
    if (j.rol == RolJugadorSala.anfitrion) return j.nombre;
  }
  return sala.jugadores.isEmpty ? null : sala.jugadores.first.nombre;
}

/// Flags del lobby según el juego.
({
  bool mostrarSelectorDados,
  bool editarCategorias,
  int? humanosExactos,
  String? textoAyudaHumanos,
}) lobbyFlagsParaJuego(String juegoId) {
  return switch (juegoId) {
    MenuJuegoScreen.juegoIdDiezMil => (
        mostrarSelectorDados: true,
        editarCategorias: false,
        humanosExactos: null,
        textoAyudaHumanos: null,
      ),
    juegoIdTutiFruti => (
        mostrarSelectorDados: false,
        editarCategorias: true,
        humanosExactos: null,
        textoAyudaHumanos: null,
      ),
    MenuJuegoScreen.juegoIdChanchoVa => (
        mostrarSelectorDados: false,
        editarCategorias: false,
        humanosExactos: 2,
        textoAyudaHumanos:
            'Chancho online: exactamente 2 personas. '
            'Las PCs se agregan al iniciar.',
      ),
    _ => (
        mostrarSelectorDados: false,
        editarCategorias: false,
        humanosExactos: null,
        textoAyudaHumanos: null,
      ),
  };
}

/// Abre la partida online cuando el anfitrión inicia desde el lobby (hub Salas).
void iniciarPartidaDesdeSalaHub(
  BuildContext context,
  String juegoId,
  InicioPartidaOnline inicio,
) {
  switch (juegoId) {
    case MenuJuegoScreen.juegoIdDiezMil:
      final modo = inicio.dados == 6 ? Modo.seis : Modo.cinco;
      final opciones = const OpcionesDiezMil().copyWith(seisDados: inicio.dados == 6);
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Iniciando partida',
        acento: AppColors.acento,
        builder: (_) => PartidaDiezMilScreen(
          nombres: inicio.nombres,
          modo: modo,
          opciones: opciones,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        ),
      );
    case MenuJuegoScreen.juegoIdGenerala:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Iniciando partida',
        acento: AppColors.violeta,
        builder: (_) => PartidaGeneralaScreen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
          opciones: const OpcionesGenerala(),
        ),
      );
    case MenuJuegoScreen.juegoIdLaPapa:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Preparando hoja',
        acento: AppColors.mint,
        builder: (_) => PartidaLaPapaScreen(
          nombres: inicio.nombres,
          opciones: const OpcionesPapa(),
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        ),
      );
    case MenuJuegoScreen.juegoIdUnoSolo:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Preparando tablero',
        acento: AppColors.mint,
        builder: (_) => PartidaUnoSoloScreen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        ),
      );
    case MenuJuegoScreen.juegoIdEscobaDel15:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Preparando cartas',
        acento: AppColors.azul,
        builder: (_) => PartidaEscobaScreen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
          opciones: const OpcionesEscoba(),
        ),
      );
    case MenuJuegoScreen.juegoIdCuloSucioV1:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Conectando partida',
        acento: AppColors.peligro,
        builder: (_) => PartidaCuloSucioScreen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
          opciones: const OpcionesCuloSucio(),
        ),
      );
    case MenuJuegoScreen.juegoIdCuloSucioV2:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Conectando partida',
        acento: AppColors.acentoSuave,
        builder: (_) => PartidaCuloSucioV2Screen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
          opciones: const OpcionesCuloSucioV2(),
        ),
      );
    case MenuJuegoScreen.juegoIdChanchoVa:
      final humanos = inicio.nombres
          .where((n) => !TextosChancho.esPc(n))
          .toList(growable: false);
      if (humanos.length != 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chancho online requiere exactamente 2 personas reales.',
            ),
          ),
        );
        return;
      }
      final nombres = inicio.nombres.length >= 3
          ? List<String>.from(inicio.nombres)
          : nombresMesaChanchoOnline(
              humanos: humanos,
              totalJugadores: SalaFormStore.totalJugadoresChancho,
            );
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Conectando Chancho va',
        acento: AppColors.acentoSuave,
        builder: (_) => PartidaChanchoVaScreen(
          nombres: nombres,
          contraPc: true,
          ajustesIniciales: AjustesStore.instance.estado,
          opciones: const OpcionesChanchoVa(),
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        ),
      );
    case juegoIdTutiFruti:
      navegarConCarga<void>(
        context,
        replace: true,
        mensaje: 'Iniciando partida',
        acento: AppColors.rosa,
        builder: (_) => PartidaTutiFrutiScreen(
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        ),
      );
    case MenuJuegoScreen.juegoIdCasitaRobada:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TextosCasita.onlineProximamente)),
      );
    case MenuJuegoScreen.juegoIdDesconfio:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TextosDesconfio.onlineProximamente)),
      );
    case MenuJuegoScreen.juegoIdJodete:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TextosJodete.onlineProximamente)),
      );
    case MenuJuegoScreen.juegoIdGuerraDeCartas:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TextosGuerra.onlineProximamente)),
      );
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online no disponible para $juegoId.')),
      );
  }
}
