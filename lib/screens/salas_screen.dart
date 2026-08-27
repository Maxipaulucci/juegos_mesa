import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/cuenta/cuenta_overlay.dart';
import 'package:app_juegos_mesa/shared/home/juego_portada_card.dart';
import 'package:app_juegos_mesa/shared/home/juegos_portada_catalogo.dart';
import 'package:app_juegos_mesa/shared/monedas/apuesta_online_store.dart';
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
  static const _paddingListaH = 32.0; // 16 + 16
  static const _gapTarjetas = 20.0;

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
    _conSesion(() => unawaited(_entrarSala(sala)));
  }

  void _abrirLobby({
    required Sala sala,
    required String miId,
    required String juegoId,
  }) {
    ApuestaOnlineStore.configurar(
      codigo: sala.codigo,
      juego: juegoId,
      apuesta: sala.apuestaMonedas,
    );
    final flags = lobbyFlagsParaJuego(juegoId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LobbySalaScreen(
          salaInicial: sala,
          miId: miId,
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
  }

  Future<void> _entrarSala(Sala sala) async {
    if (_uniendoCodigo != null) return;

    final nombre = _nombreUsuario;
    if (nombre == null || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para unirte a una sala.')),
      );
      return;
    }

    final yaEnSala = sala.jugadores.where(
      (j) => j.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    if (yaEnSala.isNotEmpty) {
      try {
        final actualizada = await SalaService.instance.obtener(sala.codigo);
        if (!mounted) return;
        if (actualizada.estado != 'lobby') {
          throw StateError('La partida ya empezó.');
        }
        _abrirLobby(
          sala: actualizada,
          miId: yaEnSala.first.id,
          juegoId: actualizada.juegoId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
      return;
    }

    await _unirseNuevo(sala);
  }

  Future<void> _unirseNuevo(Sala sala) async {
    final nombre = _nombreUsuario!;
    setState(() => _uniendoCodigo = sala.codigo);

    try {
      final preview = await SalaService.instance.obtener(sala.codigo);
      if (!mounted) return;
      if (preview.estado != 'lobby') {
        throw StateError('La partida ya empezó.');
      }
      if (preview.jugadores.length >= 4) {
        throw StateError('La sala está llena (máx. 4 jugadores).');
      }

      final apuesta = preview.apuestaMonedas;
      final monedas = UsuarioMongoService.instance.usuario?.monedas ?? 0;
      if (apuesta > 0 && monedas < apuesta) {
        throw StateError(
          'Necesitás $apuesta monedas para esta apuesta (tenés $monedas).',
        );
      }

      setState(() => _uniendoCodigo = null);
      final aceptar = await mostrarCartelConfigSalaOnline(
        context: context,
        resumen: preview.lobbyOpcionesResumen,
        apuestaMonedas: apuesta,
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

      if (apuesta > 0) {
        await UsuarioMongoService.instance.retenerApuesta(
          codigoSala: preview.codigo,
          monto: apuesta,
          juegoId: preview.juegoId,
        );
      }

      try {
        final result = await SalaService.instance.unirse(
          codigo: preview.codigo,
          nombre: nombre,
          juegoId: preview.juegoId,
        );
        ApuestaOnlineStore.configurar(
          codigo: result.sala.codigo,
          juego: preview.juegoId,
          apuesta: apuesta,
        );
        if (!mounted) return;

        _abrirLobby(
          sala: result.sala,
          miId: result.miId,
          juegoId: preview.juegoId,
        );
      } catch (e) {
        if (apuesta > 0) {
          try {
            await UsuarioMongoService.instance.reembolsarApuesta(
              codigoSala: preview.codigo,
            );
          } catch (_) {}
        }
        rethrow;
      }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final esCelular = _esCelularSalas(maxW);
        final columnas = _columnasSalas(maxW);

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: columnas == 1
              ? _salas.length
              : (_salas.length + columnas - 1) ~/ columnas,
          separatorBuilder: (_, __) => const SizedBox(height: _gapTarjetas),
          itemBuilder: (context, fila) {
            if (columnas == 1) {
              return _tarjetaSala(
                _salas[fila],
                esCelular: esCelular,
              );
            }
            final i0 = fila * columnas;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columnas; c++) ...[
                  if (c > 0) const SizedBox(width: _gapTarjetas),
                  Expanded(
                    child: i0 + c < _salas.length
                        ? _tarjetaSala(
                            _salas[i0 + c],
                            esCelular: esCelular,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  /// Misma lógica que el menú de juegos: celular = 2 columnas.
  bool _esCelularSalas(double ancho) {
    const altoRef = 400.0;
    final anchoUtil = math.max(0.0, ancho - _paddingListaH);
    final anchoRef = math.max(
      120.0,
      (altoRef - kChromeMinPortadaHome) * kAspectPortadaHome,
    );
    return anchoUtil < 2 * anchoRef + _gapTarjetas;
  }

  int _columnasSalas(double ancho) {
    final anchoUtil = math.max(0.0, ancho - _paddingListaH);
    if (anchoUtil >= 720) return 2;
    if (_esCelularSalas(ancho)) return 2;
    return 1;
  }

  Widget _tarjetaSala(
    Sala sala, {
    required bool esCelular,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        if (!ancho.isFinite || ancho <= 0) {
          return const SizedBox.shrink();
        }
        final compacto = esCelular || ancho < 200;
        final chrome =
            esCelular ? 236.0 : kChromeMinPortadaHome;
        final alto = altoTarjetaPortadaHome(
          ancho,
          chromeMin: chrome,
        );
        final altoImg = alto - chrome;

        return _contenidoTarjetaSala(
          sala: sala,
          ancho: ancho,
          alto: alto,
          altoImg: altoImg,
          compacto: compacto,
        );
      },
    );
  }

  Widget _contenidoTarjetaSala({
    required Sala sala,
    required double ancho,
    required double alto,
    required double altoImg,
    required bool compacto,
  }) {
    final juego = tituloJuegoSala(sala.juegoId);
    final anfitrion = nombreAnfitrionSala(sala) ?? '—';
    final ocupados = sala.jugadores.length;
    final uniendose = _uniendoCodigo == sala.codigo;
    final otroUniendose = _uniendoCodigo != null && !uniendose;
    final meta = portadaMetaDeJuego(sala.juegoId);

    final eslogan = StringBuffer('Anfitrión: $anfitrion\n')
      ..write('$ocupados / 4 jugadores');
    if (sala.apuestaMonedas > 0) {
      eslogan.write('\nApuesta: ${sala.apuestaMonedas} monedas');
    }

    void unirse() {
      if (!uniendose && !otroUniendose) _pedirUnirse(sala);
    }

    return JuegoPortadaCard(
      portadaAsset: meta.portadaAsset,
      accent: meta.accent,
      destacadoFuego: meta.destacadoFuego,
      enabled: !otroUniendose,
      onTap: unirse,
      anchoFijo: ancho,
      altoImg: altoImg,
      altoTotal: alto,
      pie: JuegoPortadaCardPie(
        titulo: juego,
        eslogan: eslogan.toString(),
        compacto: compacto,
        botones: HomeArcadePill(
          label: 'UNIRSE',
          icon: Icons.group_add_rounded,
          colors: const [
            Color(0xFFE1BEE7),
            Color(0xFFBA68C8),
            Color(0xFF7C4DFF),
          ],
          glow: AppColors.violeta,
          foreground: Colors.white,
          width: compacto ? null : 118,
          loading: uniendose,
          onPressed: (uniendose || otroUniendose) ? null : unirse,
        ),
      ),
    );
  }
}
