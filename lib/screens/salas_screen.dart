import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/cuenta/cuenta_overlay.dart';
import 'package:app_juegos_mesa/shared/salas/cartel_config_sala.dart';
import 'package:app_juegos_mesa/shared/salas/iniciar_desde_sala.dart';
import 'package:app_juegos_mesa/shared/salas/lobby_sala_screen.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/chanchoVa/chancho_va_online_codec.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Lista de salas online abiertas (hub → Salas / nav inferior).
class SalasScreen extends StatefulWidget {
  const SalasScreen({
    super.key,
    this.mostrarVolver = true,
    this.activa = true,
  });

  /// Si false (pestaña del shell), no muestra flecha atrás.
  final bool mostrarVolver;

  /// Si false, pausa el polling (pestaña oculta en el shell).
  final bool activa;

  @override
  State<SalasScreen> createState() => _SalasScreenState();
}

class _SalasScreenState extends State<SalasScreen> {
  List<Sala> _salas = const [];
  bool _cargando = true;
  String? _error;
  String? _uniendoCodigo;
  bool _mostrarCuenta = false;
  VoidCallback? _accionTrasSesion;
  Timer? _poll;

  String? get _nombreUsuario {
    final u = UsuarioMongoService.instance.usuario;
    if (u == null) return null;
    final nick = u.nombreUsuario.trim();
    if (nick.isNotEmpty) return nick;
    final nombre = u.nombre.trim();
    return nombre.isEmpty ? null : nombre;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _uniendoCodigo != null || !widget.activa) return;
      unawaited(_cargar(silencioso: true));
    });
  }

  @override
  void didUpdateWidget(covariant SalasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) {
      unawaited(_cargar(silencioso: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final salas = await SalaService.instance.listarAbiertas();
      if (!mounted) return;
      setState(() {
        _salas = salas;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (!silencioso) {
          _error = e.toString().replaceFirst('Bad state: ', '');
        }
      });
    }
  }

  void _conSesion(VoidCallback accion) {
    if (UsuarioMongoService.instance.haySesion && _nombreUsuario != null) {
      accion();
      return;
    }
    setState(() {
      _accionTrasSesion = accion;
      _mostrarCuenta = true;
    });
  }

  Future<void> _pedirUnirse(Sala sala) async {
    _conSesion(() => unawaited(_unirse(sala)));
  }

  Future<void> _unirse(Sala sala) async {
    final nombre = _nombreUsuario;
    if (nombre == null || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para unirte a una sala.')),
      );
      return;
    }
    if (sala.jugadores.any((j) => j.nombre.toLowerCase() == nombre.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya estás en esa sala.')),
      );
      return;
    }

    setState(() => _uniendoCodigo = sala.codigo);

    try {
      final preview = await SalaService.instance.obtener(sala.codigo);
      if (!mounted) return;
      if (preview.estado != 'lobby') {
        throw StateError('La partida ya empezó.');
      }

      setState(() => _uniendoCodigo = null);
      final aceptar = await mostrarCartelConfigSalaOnline(
        context: context,
        resumen: preview.lobbyOpcionesResumen,
      );
      if (!aceptar || !mounted) return;

      setState(() => _uniendoCodigo = sala.codigo);

      if (preview.juegoId == MenuJuegoScreen.juegoIdChanchoVa) {
        SalaFormStore.totalJugadoresChancho = 4;
        SalaFormStore.opcionesChancho = encodeOpcionesChancho(
          const OpcionesChanchoVa(),
          totalJugadores: 4,
        );
      }

      final result = await SalaService.instance.unirse(
        codigo: preview.codigo,
        nombre: nombre,
        juegoId: preview.juegoId,
      );
      if (!mounted) return;

      final flags = lobbyFlagsParaJuego(preview.juegoId);
      final juegoId = preview.juegoId;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(
            salaInicial: result.sala,
            miId: result.miId,
            mostrarSelectorDados: flags.mostrarSelectorDados,
            editarCategorias: flags.editarCategorias,
            humanosExactosParaIniciar: flags.humanosExactos,
            textoAyudaHumanos: flags.textoAyudaHumanos,
            onIniciarPartida: (ctx, inicio) {
              iniciarPartidaDesdeSalaHub(ctx, juegoId, inicio);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uniendoCodigo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Salas'),
        automaticallyImplyLeading: widget.mostrarVolver,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _uniendoCodigo != null ? null : () => _cargar(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [
                    Color(0xFF2A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.violeta,
              onRefresh: () => _cargar(),
              child: _buildLista(),
            ),
          ),
          if (_mostrarCuenta)
            Positioned.fill(
              child: CuentaOverlay(
                onCerrar: () {
                  setState(() {
                    _mostrarCuenta = false;
                    _accionTrasSesion = null;
                  });
                },
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

  Widget _buildLista() {
    if (_cargando && _salas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _salas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.peligro, height: 1.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => _cargar(),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (_salas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 64),
          Icon(
            Icons.groups_outlined,
            size: 56,
            color: AppColors.textoSuave.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay salas abiertas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando alguien cree una partida online, va a aparecer acá.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.95),
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _salas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final sala = _salas[i];
        final juego = tituloJuegoSala(sala.juegoId);
        final anfitrion = nombreAnfitrionSala(sala) ?? '—';
        final ocupados = sala.jugadores.length;
        final uniendose = _uniendoCodigo == sala.codigo;
        return Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.violeta.withValues(alpha: 0.28),
                  AppColors.carta,
                ],
              ),
              border: Border.all(
                color: AppColors.violeta.withValues(alpha: 0.85),
                width: 1.5,
              ),
              boxShadow: neonGlow(AppColors.violeta, blur: 10),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partida de $juego',
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'del usuario $anfitrion',
                          style: TextStyle(
                            color: AppColors.textoSuave.withValues(alpha: 0.98),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$ocupados / 4 jugadores',
                          style: TextStyle(
                            color: AppColors.mint.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: uniendose || _uniendoCodigo != null
                          ? null
                          : () => _pedirUnirse(sala),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: AppColors.violeta,
                      ),
                      child: uniendose
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Unirse'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
