import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/cuenta/cuenta_overlay.dart';
import 'package:app_juegos_mesa/shared/salas/crear_sala_screen.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/shared/salas/unirse_sala_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/tutiFruti/partida_tuti_fruti_screen.dart';

const String juegoIdTutiFruti = 'tutiFruti';

/// Menú Tutti Frutti: solo Crear / Unirse (online).
class MenuTutiFrutiScreen extends StatefulWidget {
  const MenuTutiFrutiScreen({super.key});

  @override
  State<MenuTutiFrutiScreen> createState() => _MenuTutiFrutiScreenState();
}

class _MenuTutiFrutiScreenState extends State<MenuTutiFrutiScreen> {
  bool _mostrarCuenta = false;
  VoidCallback? _accionTrasSesion;

  void _abrirPartida(BuildContext context, InicioPartidaOnline inicio) {
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
  }

  void _conSesion(VoidCallback accion) {
    if (UsuarioMongoService.instance.haySesion) {
      accion();
      return;
    }
    setState(() {
      _accionTrasSesion = accion;
      _mostrarCuenta = true;
    });
  }

  void _abrirCrear() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CrearSalaScreen(
          juegoId: juegoIdTutiFruti,
          mostrarSelectorDados: false,
          editarCategorias: true,
          onIniciarPartida: _abrirPartida,
        ),
      ),
    );
  }

  void _abrirUnirse() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnirseSalaScreen(
          juegoId: juegoIdTutiFruti,
          mostrarSelectorDados: false,
          editarCategorias: true,
          onIniciarPartida: _abrirPartida,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Tutti Frutti')),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: [
                    Color(0xFF3A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Multijugador online',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El anfitrión elige las categorías.\n'
                    'Luego ruleta de letras, escritura y puntaje.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _conSesion(() {
                      SalaFormStore.setResumenOpciones(const [
                        'Las categorías y rondas las elige el anfitrión en el lobby.',
                      ]);
                      _abrirCrear();
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rosa,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Crear'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _conSesion(_abrirUnirse),
                    child: const Text('Unirse'),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          if (_mostrarCuenta)
            Positioned.fill(
              child: CuentaOverlay(
                onCerrar: () => setState(() {
                  _mostrarCuenta = false;
                  _accionTrasSesion = null;
                }),
                onSesion: () {
                  final accion = _accionTrasSesion;
                  setState(() {
                    _mostrarCuenta = false;
                    _accionTrasSesion = null;
                  });
                  accion?.call();
                },
              ),
            ),
        ],
      ),
    );
  }
}
