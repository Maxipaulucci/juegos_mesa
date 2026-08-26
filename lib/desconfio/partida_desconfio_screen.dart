import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/desconfio/ia_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/menu_partida_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/standby_store.dart';
import 'package:app_juegos_mesa/desconfio/textos.dart';
import 'package:app_juegos_mesa/desconfio/victoria_desconfio_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/animacion_orden_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/boton_ordenar_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/cartas/ordenar_mano_cartas.dart';
import 'package:app_juegos_mesa/shared/cartas/reordenar_carta_mano.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/monedas/premiar_monedas_victoria_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Desconfío.
class PartidaDesconfioScreen extends StatefulWidget {
  const PartidaDesconfioScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.dificultad = DificultadPc.medio,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final DificultadPc dificultad;
  final PartidaDesconfioResume? resume;

  @override
  State<PartidaDesconfioScreen> createState() => _PartidaDesconfioScreenState();
}

class _PartidaDesconfioScreenState extends State<PartidaDesconfioScreen> {
  static const double _cartaW = 64;
  static const double _cartaH = 96;
  static const int _maxNombre = 15;

  late PartidaDesconfio _partida;
  late List<String> _nombres;
  late bool _modoDios;
  late DificultadPc _dificultad;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  int? _seleccionMano;
  bool _pcPensando = false;
  /// Último modo de orden aplicado con el botón (null = aún no se usó).
  ModoOrdenManoCartas? _modoOrdenMano;
  /// Se incrementa al ordenar para disparar la animación de deslizamiento.
  int _ordenAnimGen = 0;
  /// Copia del orden de la mano justo antes del último ordenado automático.
  List<CartaDesconfio>? _ordenAntesAnim;

  bool get _esLocalHotSeat => !widget.contraPc;
  bool get _modoDiosActivo => _modoDios && widget.contraPc;

  JugadorDesconfio get _humanoPrincipal {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadorActual;
  }

  JugadorDesconfio get _vistaLocal {
    if (widget.contraPc) return _humanoPrincipal;
    // En reacción local: ve el que puede desconfiar / seguir (no el que tiró).
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final d = _desafianteActual;
      if (d != null) {
        for (final j in _partida.jugadores) {
          if (j.nombre == d) return j;
        }
      }
    }
    return _partida.jugadorActual;
  }

  @override
  void initState() {
    super.initState();
    _modoDios = widget.modoDios;
    _dificultad = widget.dificultad;
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
      _nombres = List.of(resume.nombres);
      // Seguir con el modo dios de la partida guardada; el del menú
      // solo se aplica al reiniciar / actualizar partida.
      _modoDios = resume.modoDios;
    } else {
      _nombres = List.of(widget.nombres);
      _partida = nuevaPartidaDesconfio(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  PaloEspanolVisual _paloVisual(PaloDesconfio p) => switch (p) {
        PaloDesconfio.oro => PaloEspanolVisual.oro,
        PaloDesconfio.copa => PaloEspanolVisual.copa,
        PaloDesconfio.espada => PaloEspanolVisual.espada,
        PaloDesconfio.basto => PaloEspanolVisual.basto,
      };

  Widget _carta(CartaDesconfio c, {required bool bocaArriba, bool sel = false}) {
    return CartaEspanolaSkin(
      numero: c.numero,
      etiqueta: c.etiqueta,
      palo: _paloVisual(c.palo),
      bocaArriba: bocaArriba,
      seleccionada: sel,
      width: _cartaW,
      height: _cartaH,
    );
  }

  void _snack(String? err) {
    if (err == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  bool _puedeRenombrar(JugadorDesconfio j) {
    if (_partida.terminada) return false;
    if (j.rendido) return false;
    return !esNombrePc(j.nombre);
  }

  String? _validarNombre(String nombre, int index) {
    final t = nombre.trim();
    if (t.isEmpty) return 'El nombre no puede estar vacío.';
    if (t.length > _maxNombre) return 'Máximo $_maxNombre caracteres.';
    if (esNombrePc(t)) return 'Ese nombre está reservado para la PC.';
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == t,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (index < 0 || index >= _partida.jugadores.length) return;
    final j = _partida.jugadores[index];
    if (!_puedeRenombrar(j)) return;
    final actual = j.nombre;
    final ctrl = TextEditingController(text: actual);
    String? error;

    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cambiar nombre',
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Máximo 15 caracteres.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: _maxNombre,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  hintText: 'Nombre del jugador',
                  errorText: error,
                  counterStyle: const TextStyle(color: AppColors.textoSuave),
                ),
                onSubmitted: (_) {
                  final t = ctrl.text.trim();
                  final err = _validarNombre(t, index);
                  if (err != null) {
                    setDialogState(() => error = err);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  final err = _validarNombre(t, index);
                  if (err != null) {
                    setDialogState(() => error = err);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peligro,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;
    setState(() {
      _partida.jugadores[index].nombre = nuevo;
      if (index < _nombres.length) _nombres[index] = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      for (var i = 0; i < _partida.pozo.length; i++) {
        final c = _partida.pozo[i];
        if (c.jugador == actual) {
          _partida.pozo[i] =
              CartaEnPozoDesconfio(carta: c.carta, jugador: nuevo);
        }
      }
      for (var i = 0; i < _partida.historial.length; i++) {
        final h = _partida.historial[i];
        if (h.jugador != actual &&
            h.desconfiador != actual &&
            h.quienSeLleva != actual) {
          continue;
        }
        _partida.historial[i] = EntradaHistorialDesconfio(
          jugador: h.jugador == actual ? nuevo : h.jugador,
          carta: h.carta,
          paloDeclarado: h.paloDeclarado,
          desconfiador:
              h.desconfiador == actual ? nuevo : h.desconfiador,
          eraDelPalo: h.eraDelPalo,
          quienSeLleva:
              h.quienSeLleva == actual ? nuevo : h.quienSeLleva,
          cartasLlevadas: h.cartasLlevadas,
        );
      }
      final ur = _partida.ultimoResultado;
      if (ur != null &&
          (ur.desconfiador == actual ||
              ur.tirador == actual ||
              ur.quienSeLleva == actual)) {
        _partida.ultimoResultado = ResultadoDesconfio(
          desconfiador:
              ur.desconfiador == actual ? nuevo : ur.desconfiador,
          tirador: ur.tirador == actual ? nuevo : ur.tirador,
          carta: ur.carta,
          eraDelPalo: ur.eraDelPalo,
          quienSeLleva:
              ur.quienSeLleva == actual ? nuevo : ur.quienSeLleva,
          cartasLlevadas: ur.cartasLlevadas,
        );
      }
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
      final um = _partida.ultimoMensaje;
      if (um != null && um.contains(actual)) {
        _partida.ultimoMensaje = um.replaceAll(actual, nuevo);
      }
    });
    _guardarResumeSiCorresponde();
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      DesconfioStandByStore.limpiar();
      return;
    }
    DesconfioStandByStore.guardar(
      PartidaDesconfioResume(
        partida: _partida,
        nombres: _nombres,
        modoDios: _modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      DesconfioStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _reiniciar() {
    DesconfioStandByStore.limpiar();
    setState(() {
      _modoDios = modoDiosElegidoEnMenu(
        MenuJuegoScreen.juegoIdDesconfio,
        fallback: widget.modoDios,
      );
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(
              MenuJuegoScreen.juegoIdDesconfio,
            ) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaDesconfio(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
      _seleccionMano = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  void _mostrarReglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.azulSuave,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            reglasDesconfio(),
            style: const TextStyle(color: AppColors.texto, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _elegirPalo(PaloDesconfio palo) {
    final err = elegirPaloDesconfio(_partida, palo);
    setState(() => _seleccionMano = null);
    _snack(err);
    _talVezPc();
  }

  void _tirarSeleccionada() {
    final i = _seleccionMano;
    if (i == null) {
      _snack('Elegí una carta de tu mano');
      return;
    }
    final err = tirarCartaDesconfio(_partida, i);
    setState(() => _seleccionMano = null);
    _snack(err);
    if (err == null && widget.contraPc) {
      _talVezReaccionPc();
    }
  }

  /// Segundo toque a la misma carta, o toque al pozo con carta seleccionada.
  void _tirarSeleccionSiCorresponde() {
    if (_seleccionMano == null || !_puedeElegirCartaParaTirar) return;
    if (_partida.fase == FaseDesconfio.jugando) {
      _tirarSeleccionada();
      return;
    }
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      _tirarSinDesconfiar();
    }
  }

  void _alTocarCartaMano(int i) {
    if (!_puedeElegirCartaParaTirar) return;
    if (_seleccionMano == i) {
      _tirarSeleccionSiCorresponde();
      return;
    }
    setState(() => _seleccionMano = i);
  }

  void _reordenarMano(int desde, int hacia) {
    if (_partida.terminada) return;
    final mano = _vistaLocal.mano;
    if (desde < 0 ||
        hacia < 0 ||
        desde >= mano.length ||
        hacia >= mano.length) {
      return;
    }
    if (desde == hacia) return;
    final carta = mano.removeAt(desde);
    mano.insert(hacia, carta);
    setState(() {
      final sel = _seleccionMano;
      if (sel == null) return;
      if (sel == desde) {
        _seleccionMano = hacia;
      } else if (desde < hacia && sel > desde && sel <= hacia) {
        _seleccionMano = sel - 1;
      } else if (hacia < desde && sel >= hacia && sel < desde) {
        _seleccionMano = sel + 1;
      }
    });
  }

  void _ciclarOrdenMano() {
    if (_partida.terminada) return;
    final mano = _vistaLocal.mano;
    if (mano.length < 2) return;
    final ordenAntes = List<CartaDesconfio>.of(mano);
    CartaDesconfio? selCarta;
    final selIdx = _seleccionMano;
    if (selIdx != null && selIdx >= 0 && selIdx < mano.length) {
      selCarta = mano[selIdx];
    }
    final modo = ciclarOrdenManoCartas(
      mano,
      modoActual: _modoOrdenMano,
      claves: (c) => ClavesOrdenCarta(
        numero: c.numero,
        palo: c.palo.index,
      ),
    );
    setState(() {
      _modoOrdenMano = modo;
      _ordenAntesAnim = ordenAntes;
      _ordenAnimGen++;
      if (selCarta != null) {
        final nuevo = mano.indexOf(selCarta);
        _seleccionMano = nuevo >= 0 ? nuevo : null;
      }
    });
  }

  /// No desconfío: paso el turno y tiro la carta elegida al pozo.
  void _tirarSinDesconfiar() {
    final i = _seleccionMano;
    if (i == null) {
      _snack('Elegí una carta de tu mano');
      return;
    }
    // Guardamos la carta por valor: tras seguir el índice sigue valiendo
    // en la misma mano del humano.
    final errSeguir = seguirTrasTiradaDesconfio(_partida);
    if (errSeguir != null) {
      _snack(errSeguir);
      setState(() {});
      return;
    }
    if (_partida.terminada) {
      setState(() => _seleccionMano = null);
      return;
    }
    final yo = widget.contraPc ? _humanoPrincipal : _partida.jugadorActual;
    if (_partida.jugadorActual.nombre != yo.nombre) {
      setState(() => _seleccionMano = null);
      _talVezPc();
      return;
    }
    if (i < 0 || i >= yo.mano.length) {
      setState(() => _seleccionMano = null);
      _snack('Elegí una carta de tu mano');
      return;
    }
    final errTirar = tirarCartaDesconfio(_partida, i);
    setState(() => _seleccionMano = null);
    _snack(errTirar);
    if (errTirar == null && widget.contraPc) {
      _talVezReaccionPc();
    }
  }

  void _desconfiar(String nombre) {
    if (_partida.pozo.isEmpty) {
      _snack('No hay carta en el pozo para desconfiar.');
      return;
    }
    final tirador = _partida.ultimaDelPozo?.jugador;
    if (tirador != null && tirador == _vistaLocal.nombre) {
      _snack('No podés desconfiar de tu propia carta.');
      return;
    }
    final err = desconfiarDesconfio(_partida, nombre);
    setState(() => _seleccionMano = null);
    _snack(err);
  }

  void _continuarRevelacion() {
    final err = continuarTrasRevelacionDesconfio(_partida);
    setState(() {});
    _snack(err);
    _talVezPc();
  }

  /// Tras el tiro de la PC: puedo elegir carta y tocar Tirar / Desconfío.
  bool get _puedeElegirCartaParaTirar {
    if (_partida.terminada || _pcPensando) return false;
    if (_partida.fase == FaseDesconfio.jugando) {
      if (_turnoDePc) return false;
      return _partida.jugadorActual.nombre == _vistaLocal.nombre;
    }
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (tirador == null) return false;
      // Solo si tiró la PC (o un rival), no si tiré yo.
      // Nota: jugadorActual sigue siendo el tirador (PC), pero igual
      // el humano debe poder elegir carta para Tirar.
      if (widget.contraPc) {
        return esNombrePc(tirador);
      }
      return tirador != _vistaLocal.nombre;
    }
    return false;
  }

  bool get _turnoDePc {
    if (!widget.contraPc || _partida.terminada) return false;
    return esNombrePc(_partida.jugadorActual.nombre);
  }

  /// Tras una tirada humana (u otra): la PC decide desconfiar o seguir.
  Future<void> _talVezReaccionPc() async {
    if (!widget.contraPc || !mounted || _partida.terminada) return;
    if (_partida.fase != FaseDesconfio.esperandoReaccion) return;
    final ultima = _partida.ultimaDelPozo;
    if (ultima == null) return;
    // Solo reacciona la PC si quien tiró no es PC (o hay otra PC rival).
    // Si tiró un humano, decide la PC. Si tiró una PC, espera al humano.
    if (esNombrePc(ultima.jugador)) return;
    if (_pcPensando) return;
    _pcPensando = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || _partida.fase != FaseDesconfio.esperandoReaccion) {
      _pcPensando = false;
      return;
    }

    final quien = pcQueDesconfia(
      partida: _partida,
      dificultad: _dificultad,
    );
    if (!mounted) {
      _pcPensando = false;
      return;
    }
    if (quien != null) {
      setState(() {
        desconfiarDesconfio(_partida, quien.nombre);
        _pcPensando = false;
      });
    } else {
      setState(() {
        seguirTrasTiradaDesconfio(_partida);
        _pcPensando = false;
      });
      _talVezPc();
    }
  }

  Future<void> _talVezPc() async {
    if (!_turnoDePc || !mounted || _pcPensando) return;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || !_turnoDePc) return;

    final j = _partida.jugadorActual;
    if (_partida.fase == FaseDesconfio.elegirPalo) {
      // Elige el palo del que más cartas tiene.
      final counts = <PaloDesconfio, int>{
        for (final p in PaloDesconfio.values) p: 0,
      };
      for (final c in j.mano) {
        counts[c.palo] = (counts[c.palo] ?? 0) + 1;
      }
      var mejor = PaloDesconfio.oro;
      var maxN = -1;
      for (final e in counts.entries) {
        if (e.value > maxN) {
          maxN = e.value;
          mejor = e.key;
        }
      }
      setState(() => elegirPaloDesconfio(_partida, mejor));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted || !_turnoDePc) return;
    if (_partida.fase == FaseDesconfio.jugando && j.mano.isNotEmpty) {
      final palo = _partida.paloDeclarado;
      var idx = 0;
      if (palo != null) {
        final delPalo = [
          for (var i = 0; i < j.mano.length; i++)
            if (j.mano[i].palo == palo) i,
        ];
        final otras = [
          for (var i = 0; i < j.mano.length; i++)
            if (j.mano[i].palo != palo) i,
        ];
        final rng = math.Random();
        final chanceMentir = switch (_dificultad) {
          DificultadPc.facil => 0.12,
          DificultadPc.medio => 0.28,
          DificultadPc.dificil => 0.42,
        };
        final quiereMentir =
            otras.isNotEmpty && rng.nextDouble() < chanceMentir;
        if (delPalo.isNotEmpty && !quiereMentir) {
          idx = delPalo.first;
        } else if (otras.isNotEmpty) {
          idx = otras[rng.nextInt(otras.length)];
        } else {
          idx = 0;
        }
      }
      setState(() => tirarCartaDesconfio(_partida, idx));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    // Tras tirar la PC, el humano decide (no auto-seguir).
    // Si no hay humano (solo PCs), otra PC puede reaccionar.
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final hayHumano = _partida.jugadores.any((x) => !esNombrePc(x.nombre));
      if (!hayHumano) {
        final quien = pcQueDesconfia(
          partida: _partida,
          dificultad: _dificultad,
        );
        if (quien != null) {
          setState(() => desconfiarDesconfio(_partida, quien.nombre));
        } else {
          setState(() => seguirTrasTiradaDesconfio(_partida));
          _talVezPc();
        }
      }
    }

    if (!mounted) return;
    if (_partida.fase == FaseDesconfio.revelando) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => continuarTrasRevelacionDesconfio(_partida));
      _talVezPc();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vista = _vistaLocal;
    final ur = _partida.ultimoResultado;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_mostrarAjustes) {
          setState(() => _mostrarAjustes = false);
          return;
        }
        if (_mostrarMenu) {
          setState(() {
            _mostrarMenu = false;
            _confirmarRendicion = false;
          });
          return;
        }
        setState(() {
          _mostrarMenu = true;
          _confirmarRendicion = false;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            const Positioned.fill(
              child: EpicBackdrop(centerY: 0.45, fadeRayosAlCentro: true),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarMenu = true;
                            _confirmarRendicion = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosDesconfio.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.contraPc)
                          BotonReiniciarPartidaPc(
                            onPressed: _pedirReiniciarVsPc,
                          ),
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarAjustes = true;
                            _mostrarMenu = false;
                          }),
                          icon: const Icon(
                            Icons.settings,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_partida.ultimoMensaje != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _partida.ultimoMensaje!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          // Tarjetas de todos los jugadores, centradas.
                          SizedBox(
                            height: 80,
                            width: double.infinity,
                            child: Center(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0;
                                        i < _partida.jugadores.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(width: 12),
                                      _chipJugador(
                                        _partida.jugadores[i],
                                        i,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Pozo (aviso de PC arriba del pozo)
                          Expanded(child: Center(child: _pozoWidget())),
                          const SizedBox(height: 8),
                          // Mano
                          SizedBox(
                            height: 40,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '${_esLocalHotSeat ? 'Mano de ${vista.nombre}' : TextosDesconfio.tuMano} - ${vista.mano.length} carta${vista.mano.length == 1 ? '' : 's'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: BotonOrdenarMano(
                                      size: 38,
                                      onPressed: vista.mano.length < 2 ||
                                              _partida.terminada
                                          ? null
                                          : _ciclarOrdenMano,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: _cartaH + 28,
                            child: _ManoConFlechas(
                              cartas: vista.mano,
                              seleccion: _seleccionMano,
                              puedeElegir: _puedeElegirCartaParaTirar,
                              cartaW: _cartaW,
                              cartaH: _cartaH,
                              animaciones: _ajustes.animaciones,
                              onTapIndex: _alTocarCartaMano,
                              onReordenar: _reordenarMano,
                              ordenAnimGen: _ordenAnimGen,
                              ordenAntesAnim: _ordenAntesAnim,
                              buildCarta: (c, {required sel}) => _carta(
                                c,
                                bocaArriba: true,
                                sel: sel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Desconfío / Tirar: siempre debajo de la mano (también
                          // al elegir palo); se habilitan según la fase.
                          _botonesDesconfioYTirar(vista),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_partida.fase == FaseDesconfio.elegirPalo &&
                _partida.jugadorActual.nombre == vista.nombre &&
                !_turnoDePc) ...[
              Positioned.fill(
                child: _overlayElegirPalo(),
              ),
              // Solo menú y ajustes por encima del oscuro (no reiniciar).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarMenu = true;
                            _confirmarRendicion = false;
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarAjustes = true;
                            _mostrarMenu = false;
                          }),
                          icon: const Icon(
                            Icons.settings,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_partida.fase == FaseDesconfio.revelando && ur != null)
              Positioned.fill(
                child: _overlayRevelacion(ur),
              ),
            if (_mostrarAjustes)
              Positioned.fill(
                child: AjustesOverlay(
                  ajustes: _ajustes,
                  onChanged: (a) => setState(() => _ajustes = a),
                  onCerrar: () => setState(() => _mostrarAjustes = false),
                ),
              ),
            if (_mostrarMenu)
              Positioned.fill(
                child: MenuPartidaDesconfio(
                  jugador: vista.nombre,
                  partidaTerminada: _partida.terminada,
                  confirmarRendicion: _confirmarRendicion,
                  permitirRendirse: _esLocalHotSeat,
                  onCerrar: () => setState(() {
                    _mostrarMenu = false;
                    _confirmarRendicion = false;
                  }),
                  onReglas: () {
                    setState(() => _mostrarMenu = false);
                    _mostrarReglas();
                  },
                  onSalirORendirse: () {
                    if (_esLocalHotSeat) {
                      setState(() => _confirmarRendicion = true);
                    } else {
                      _salirAlMenu(guardar: true);
                    }
                  },
                  onConfirmarRendicion: () {
                    if (_esLocalHotSeat) {
                      setState(() {
                        _mostrarMenu = false;
                        _confirmarRendicion = false;
                        rendirseDesconfio(_partida, vista.nombre);
                      });
                    } else {
                      _salirAlMenu(guardar: true);
                    }
                  },
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: PremiarMonedasVictoriaPc(
                  aplicar: widget.contraPc &&
                      _partida.ganador == _humanoPrincipal.nombre,
                  juegoId: MenuJuegoScreen.juegoIdDesconfio,
                  child: VictoriaDesconfioOverlay(
                    partida: _partida,
                    gane: !widget.contraPc ||
                        _partida.ganador == _humanoPrincipal.nombre,
                    animaciones: _ajustes.animaciones,
                    onVolverAJugar: _reiniciar,
                    onVolver: () => _salirAlMenu(guardar: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Quién debe actuar ahora (para el contorno amarillo de la tarjeta).
  String? get _nombreTurnoResaltado {
    if (_partida.terminada) return null;
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (tirador == null) return _partida.jugadorActual.nombre;
      // Reacciona quien no tiró (desconfiar / tirar), no el tirador.
      if (widget.contraPc) {
        if (!esNombrePc(tirador)) {
          for (final j in _partida.jugadores) {
            if (!j.rendido && esNombrePc(j.nombre)) return j.nombre;
          }
          return null;
        }
        return _humanoPrincipal.nombre;
      }
      return _desafianteActual ?? _partida.jugadorActual.nombre;
    }
    return _partida.jugadorActual.nombre;
  }

  Widget _chipJugador(JugadorDesconfio j, int index) {
    final turno = _nombreTurnoResaltado == j.nombre;
    final verCartas = _modoDiosActivo && esNombrePc(j.nombre);
    final puedeRenombrar = _puedeRenombrar(j);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: turno ? AppColors.acento : AppColors.cartaBorde,
          width: turno ? 2.4 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            child: NombreJugadorEditable(
              nombre: j.nombre,
              puedeRenombrar: puedeRenombrar,
              onRenombrar:
                  puedeRenombrar ? () => _renombrarJugador(index) : null,
              colorTexto: turno ? AppColors.acento : AppColors.texto,
              fontSize: 12,
              mayusculas: false,
            ),
          ),
          Text(
            verCartas && j.mano.isNotEmpty
                ? j.mano.map((c) => c.etiqueta).take(3).join(' · ')
                : '${j.cartasEnMano} carta(s)',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso de turno/pensamiento de la PC (se muestra arriba del pozo).
  String? get _textoEstadoPc {
    if (_partida.terminada) return null;
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (widget.contraPc &&
          tirador != null &&
          !esNombrePc(tirador)) {
        return 'La PC está pensando…';
      }
      return null;
    }
    if (_partida.fase == FaseDesconfio.jugando) {
      if (_turnoDePc || _pcPensando) {
        return 'La PC está pensando…';
      }
      return null;
    }
    if (_turnoDePc || _pcPensando) {
      return 'La PC está pensando…';
    }
    return null;
  }

  Widget _pozoWidget() {
    final n = _partida.pozo.length;
    final palo = _partida.paloDeclarado;
    final avisoPc = _textoEstadoPc;
    bool verCartaPozo(CartaEnPozoDesconfio c) =>
        _modoDiosActivo && esNombrePc(c.jugador);
    final puedeTirarAlPozo =
        _seleccionMano != null && _puedeElegirCartaParaTirar;

    Widget pila;
    if (n == 0) {
      pila = Container(
        width: _cartaW,
        height: _cartaH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: puedeTirarAlPozo
                ? colorSeleccionCartaEspanola
                : AppColors.cartaBorde,
            width: puedeTirarAlPozo ? 2.2 : 1,
          ),
          color: const Color(0xFF1A0A33),
        ),
        child: const Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    } else {
      pila = SizedBox(
        width: _cartaW + 16,
        height: _cartaH + 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < (n - 1).clamp(0, 3); i++)
              Transform.translate(
                offset: Offset(i * 3.0, i * 2.0),
                child: _carta(
                  _partida.pozo[i].carta,
                  bocaArriba: verCartaPozo(_partida.pozo[i]),
                ),
              ),
            Transform.translate(
              offset: Offset(
                (n - 1).clamp(0, 3) * 3.0,
                (n - 1).clamp(0, 3) * 2.0,
              ),
              child: _carta(
                _partida.pozo.last.carta,
                bocaArriba: verCartaPozo(_partida.pozo.last),
                sel: puedeTirarAlPozo,
              ),
            ),
          ],
        ),
      );
    }

    if (puedeTirarAlPozo) {
      pila = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _tirarSeleccionSiCorresponde,
          borderRadius: BorderRadius.circular(14),
          child: pila,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TextosDesconfio.pozo,
              style: TextStyle(
                color: puedeTirarAlPozo
                    ? colorSeleccionCartaEspanola
                    : AppColors.textoSuave,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (palo != null) ...[
              const SizedBox(height: 6),
              _cartaPaloIndicador(palo),
            ],
            const SizedBox(height: 8),
            pila,
            if (n > 0) ...[
              const SizedBox(height: 6),
              Text(
                puedeTirarAlPozo ? 'Tocá para tirar' : '$n en el pozo',
                style: TextStyle(
                  color: puedeTirarAlPozo
                      ? colorSeleccionCartaEspanola
                      : AppColors.textoSuave,
                  fontSize: 12,
                  fontWeight:
                      puedeTirarAlPozo ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ] else if (puedeTirarAlPozo) ...[
              const SizedBox(height: 6),
              Text(
                'Tocá para tirar',
                style: TextStyle(
                  color: colorSeleccionCartaEspanola,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        // Flota arriba del “Pozo” sin empujar el layout.
        if (avisoPc != null)
          Positioned(
            top: -26,
            left: -40,
            right: -40,
            child: Text(
              avisoPc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  /// Misma carta de palo que en la elección, solo como indicador (sin tap).
  Widget _cartaPaloIndicador(PaloDesconfio palo) {
    return CartaEspanolaSkin(
      numero: 0,
      etiqueta: nombrePaloDesconfio(palo),
      palo: _paloVisual(palo),
      width: 56,
      height: 84,
    );
  }

  /// Nombre de quien puede decir «¡Desconfío!» en la fase de reacción, o null.
  String? get _desafianteActual {
    if (_partida.fase != FaseDesconfio.esperandoReaccion) return null;
    final tirador = _partida.ultimaDelPozo?.jugador;
    if (tirador == null) return null;
    if (widget.contraPc) {
      // Tras mi tiro la PC decide sola.
      if (!esNombrePc(tirador)) return null;
      return _humanoPrincipal.nombre;
    }
    final otros = [
      for (final j in _partida.jugadores)
        if (!j.rendido && j.nombre != tirador) j.nombre,
    ];
    return otros.isEmpty ? null : otros.first;
  }

  /// Fila fija ¡Desconfío! / Tirar debajo de la mano (visible desde elegir palo).
  Widget _botonesDesconfioYTirar(JugadorDesconfio vista) {
    if (_partida.terminada) return const SizedBox.shrink();

    VoidCallback? onDesconfio;
    VoidCallback? onTirar;

    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (!(widget.contraPc &&
          tirador != null &&
          !esNombrePc(tirador))) {
        final desafiante = _desafianteActual;
        // Sin cartas en el pozo (p. ej. antes de la 1ª tirada) no se puede
        // desconfiar; tampoco quien acaba de tirar.
        final puedeDesconfiar = desafiante != null &&
            !_pcPensando &&
            _partida.pozo.isNotEmpty &&
            vista.nombre == desafiante &&
            vista.nombre != tirador;
        if (puedeDesconfiar) {
          onDesconfio = () => _desconfiar(desafiante);
          onTirar =
              _seleccionMano == null ? null : _tirarSinDesconfiar;
        }
      }
    } else if (_partida.fase == FaseDesconfio.jugando) {
      if (!(_turnoDePc || _pcPensando) &&
          _partida.jugadorActual.nombre == vista.nombre) {
        // Primera carta (u otra) con pozo vacío: solo Tirar, nunca Desconfío.
        onTirar =
            _seleccionMano == null ? null : _tirarSeleccionada;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peligro,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.peligro.withValues(alpha: 0.35),
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.55),
                  minimumSize: const Size.fromHeight(52),
                  maximumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onDesconfio,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    TextosDesconfio.desconfio,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.azul.withValues(alpha: 0.35),
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.55),
                  minimumSize: const Size.fromHeight(52),
                  maximumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onTirar,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    TextosDesconfio.tirar,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayElegirPalo() {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B1D6E),
                Color(0xFF1A0A33),
                Color(0xFF2A1050),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.acento, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                TextosDesconfio.elegirPalo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tocá una carta para declarar el palo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final p in PaloDesconfio.values) ...[
                      if (p != PaloDesconfio.values.first)
                        const SizedBox(width: 10),
                      _cartaPaloElegible(p),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartaPaloElegible(PaloDesconfio palo) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _elegirPalo(palo),
        borderRadius: BorderRadius.circular(14),
        child: CartaEspanolaSkin(
          numero: 0,
          etiqueta: nombrePaloDesconfio(palo),
          palo: _paloVisual(palo),
          width: 78,
          height: 118,
        ),
      ),
    );
  }

  Widget _overlayRevelacion(ResultadoDesconfio ur) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ur.eraDelPalo ? AppColors.mint : AppColors.peligro,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ur.desconfiador} desconfió',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ur.eraDelPalo ? '¡Era verdad!' : '¡Mentira!',
                style: TextStyle(
                  color: ur.eraDelPalo ? AppColors.mint : AppColors.peligro,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              _carta(ur.carta, bocaArriba: true),
              const SizedBox(height: 12),
              Text(
                _partida.ultimoMensaje ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texto, height: 1.35),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _continuarRevelacion,
                child: const Text(TextosDesconfio.continuar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mano horizontal con contenedor, flechas y reorden por arrastre.
class _ManoConFlechas extends StatefulWidget {
  const _ManoConFlechas({
    required this.cartas,
    required this.seleccion,
    required this.puedeElegir,
    required this.onTapIndex,
    required this.buildCarta,
    required this.cartaW,
    required this.cartaH,
    required this.animaciones,
    this.onReordenar,
    this.ordenAnimGen = 0,
    this.ordenAntesAnim,
  });

  final List<CartaDesconfio> cartas;
  final int? seleccion;
  final bool puedeElegir;
  final ValueChanged<int> onTapIndex;
  final Widget Function(CartaDesconfio c, {required bool sel}) buildCarta;
  final double cartaW;
  final double cartaH;
  final bool animaciones;
  final void Function(int desde, int hacia)? onReordenar;
  /// Generación de ordenado automático (botón); 0 = sin animación de sort.
  final int ordenAnimGen;
  /// Orden de la mano justo antes del último sort (copia; no la lista viva).
  final List<CartaDesconfio>? ordenAntesAnim;

  @override
  State<_ManoConFlechas> createState() => _ManoConFlechasState();
}

class _ManoConFlechasState extends State<_ManoConFlechas> {
  static const double _gap = 6;
  static const double _pasoScroll = 160;

  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  final _reorden = ReordenarCartaManoDrag();
  bool _hayIzquierda = false;
  bool _hayDerecha = false;
  bool _priorizarReorden = false;
  Map<Object, double> _dxOrden = const {};
  int _genOrden = 0;

  bool get _arrastrando => _reorden.arrastrando;
  bool get _tieneReorden => widget.onReordenar != null;
  bool get _bloquearScroll => _arrastrando || _priorizarReorden;
  double get _paso => widget.cartaW + _gap;

  void _setPriorizarReorden(bool v) {
    if (!mounted) return;
    if (!v && _arrastrando) return;
    if (_priorizarReorden == v) return;
    setState(() => _priorizarReorden = v);
  }

  void _limpiarAnimOrden() {
    if (_dxOrden.isEmpty) return;
    _dxOrden = const {};
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_actualizarFlechas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
  }

  @override
  void didUpdateWidget(covariant _ManoConFlechas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartas.length != widget.cartas.length ||
        oldWidget.cartaW != widget.cartaW) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
    }

    final mismoGen = widget.ordenAnimGen == oldWidget.ordenAnimGen;
    final largoCambio = oldWidget.cartas.length != widget.cartas.length;
    final turnoCambio = oldWidget.puedeElegir != widget.puedeElegir;

    if (turnoCambio || (mismoGen && largoCambio)) {
      _limpiarAnimOrden();
      if (largoCambio &&
          widget.cartas.length > oldWidget.cartas.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        });
      }
      if (mismoGen) return;
    }

    if (!mismoGen &&
        widget.ordenAnimGen > 0 &&
        widget.animaciones &&
        widget.ordenAntesAnim != null &&
        widget.ordenAntesAnim!.length == widget.cartas.length &&
        widget.cartas.isNotEmpty) {
      _dxOrden = deltasInicioOrdenMano(
        antes: <Object>[for (final c in widget.ordenAntesAnim!) c],
        despues: <Object>[for (final c in widget.cartas) c],
        paso: _paso,
      );
      _genOrden = widget.ordenAnimGen;
      Future<void>.delayed(kDuracionAnimacionOrdenMano, () {
        if (!mounted) return;
        if (_genOrden != widget.ordenAnimGen) return;
        setState(_limpiarAnimOrden);
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_actualizarFlechas);
    _scroll.dispose();
    super.dispose();
  }

  void _actualizarFlechas() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final izq = pos.maxScrollExtent > 0.5 && pos.pixels > 1;
    final der =
        pos.maxScrollExtent > 0.5 && pos.pixels < pos.maxScrollExtent - 1;
    if (izq != _hayIzquierda || der != _hayDerecha) {
      setState(() {
        _hayIzquierda = izq;
        _hayDerecha = der;
      });
    }
  }

  void _desplazar(double delta) {
    if (!_scroll.hasClients) return;
    final destino =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  int _indiceInsercionDesdeGlobal(double globalX) {
    return indiceInsercionDesdeGlobalReorden(
      rowKey: _rowKey,
      drag: _reorden,
      globalX: globalX,
      cantidad: widget.cartas.length,
      anchoCarta: widget.cartaW,
      gap: _gap,
    );
  }

  void _iniciarDrag(int index, Offset localPosition) {
    setState(() {
      _reorden.iniciar(
        index: index,
        localPosition: localPosition,
        anchoCarta: widget.cartaW,
      );
    });
  }

  void _actualizarDrag(DragUpdateDetails details) {
    if (!_reorden.arrastrando) return;
    autoScrollDuranteDragReorden(
      scroll: _scroll,
      context: context,
      globalX: details.globalPosition.dx,
    );
    setState(() {
      _reorden.actualizar(
        details: details,
        indiceInsercionDesdeGlobal: _indiceInsercionDesdeGlobal,
      );
    });
  }

  void _soltarDrag() {
    final resultado = _reorden.soltar();
    _priorizarReorden = false;
    if (resultado != null) {
      widget.onReordenar?.call(resultado.desde, resultado.hacia);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _cancelarDrag() {
    setState(() {
      _reorden.cancelar();
      _priorizarReorden = false;
    });
  }

  Widget _flecha({required bool izquierda, required bool visible}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: AppColors.carta.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: visible
                ? () => _desplazar(izquierda ? -_pasoScroll : _pasoScroll)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                izquierda
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.acento,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cartas.isEmpty) {
      return const Center(
        child: Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    }

    final altoSlot = widget.cartaH + kDeslizamientoSeleccionCarta;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A33).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.violeta.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _actualizarFlechas();
              return false;
            },
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is! PointerScrollEvent) return;
                if (!_scroll.hasClients || _bloquearScroll) {
                  return;
                }
                final delta =
                    signal.scrollDelta.dx.abs() > signal.scrollDelta.dy.abs()
                        ? signal.scrollDelta.dx
                        : signal.scrollDelta.dy;
                if (delta == 0) return;
                final destino = (_scroll.offset + delta).clamp(
                  0.0,
                  _scroll.position.maxScrollExtent,
                );
                _scroll.jumpTo(destino);
              },
              child: ScrollConfiguration(
                behavior: const _ManoScrollBehavior(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minW = math.max(0.0, constraints.maxWidth - 68);
                    final n = widget.cartas.length;
                    final contentW =
                        n == 0 ? 0.0 : n * widget.cartaW + (n - 1) * _gap;
                    final filaW = math.max(minW, contentW);
                    return SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      // Solo bloquea scroll al tocar/arrastrar la seleccionada.
                      physics: physicsScrollManoReorden(
                        bloquearPorReorden: _bloquearScroll,
                        cuandoLibre: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 34,
                        vertical: 4,
                      ),
                      child: SizedBox(
                        width: filaW,
                        height: altoSlot,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Row(
                              key: _rowKey,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0;
                                    i < widget.cartas.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: _gap),
                                  Builder(
                                    key: ValueKey<String>(
                                      'slot_${widget.cartas[i].etiqueta}',
                                    ),
                                    builder: (context) {
                                      final c = widget.cartas[i];
                                      final sel = widget.seleccion == i;
                                      final esLaQueArrastro =
                                          _reorden.dragIndex == i;
                                      final atenuar =
                                          _arrastrando && !esLaQueArrastro;
                                      final skin =
                                          widget.buildCarta(c, sel: sel);

                                      Widget child = CartaOpacidadReorden(
                                        esLaQueArrastro: esLaQueArrastro,
                                        atenuar: atenuar,
                                        child: CartaSlotSeleccion(
                                          seleccionada: sel,
                                          animaciones: widget.animaciones &&
                                              widget.puedeElegir,
                                          width: widget.cartaW,
                                          height: widget.cartaH,
                                          child: skin,
                                        ),
                                      );

                                      child = CartaDeslizOrdenMano(
                                        key: ValueKey<String>(
                                          'ord_${c.etiqueta}_$_genOrden',
                                        ),
                                        dxInicial: _dxOrden[c] ?? 0,
                                        animaciones: widget.animaciones,
                                        child: child,
                                      );

                                      child = CartaConHuecoReorden(
                                        arrastrandoMano: _arrastrando,
                                        esLaQueArrastro: esLaQueArrastro,
                                        shiftX: _reorden.shiftX(i, _paso),
                                        duration: widget.animaciones
                                            ? kDuracionHuecoReordenMano
                                            : Duration.zero,
                                        child: child,
                                      );

                                      child = CartaArrastreVisualReorden(
                                        esLaQueArrastro: esLaQueArrastro,
                                        dragDx: _reorden.dragDx,
                                        dragDy: _reorden.dragDy,
                                        ocultarEnSlot: true,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: child,
                                      );

                                      final puedeInteractuar =
                                          widget.puedeElegir;
                                      final puedeArrastrar = _tieneReorden &&
                                          sel &&
                                          puedeInteractuar;

                                      return Material(
                                        color: Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: Listener(
                                          onPointerDown: puedeArrastrar
                                              ? (_) =>
                                                  _setPriorizarReorden(true)
                                              : null,
                                          onPointerUp: puedeArrastrar
                                              ? (_) =>
                                                  _setPriorizarReorden(false)
                                              : null,
                                          onPointerCancel: puedeArrastrar
                                              ? (_) =>
                                                  _setPriorizarReorden(false)
                                              : null,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: puedeInteractuar
                                                ? () => widget.onTapIndex(i)
                                                : null,
                                            onPanStart: puedeArrastrar
                                                ? (details) => _iniciarDrag(
                                                      i,
                                                      details.localPosition,
                                                    )
                                                : null,
                                            onPanUpdate: _arrastrando
                                                ? _actualizarDrag
                                                : null,
                                            onPanEnd: _arrastrando
                                                ? (_) => _soltarDrag()
                                                : null,
                                            onPanCancel: _arrastrando
                                                ? _cancelarDrag
                                                : null,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (_reorden.dragIndex != null)
                              CartaFlotanteReorden(
                                rowKey: _rowKey,
                                index: _reorden.dragIndex!,
                                cantidad: widget.cartas.length,
                                anchoCarta: widget.cartaW,
                                gap: _gap,
                                dragDx: _reorden.dragDx,
                                dragDy: _reorden.dragDy,
                                borderRadius: BorderRadius.circular(14),
                                child: CartaSlotSeleccion(
                                  seleccionada: true,
                                  animaciones: false,
                                  width: widget.cartaW,
                                  height: widget.cartaH,
                                  child: widget.buildCarta(
                                    widget.cartas[_reorden.dragIndex!],
                                    sel: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            child: _flecha(izquierda: true, visible: _hayIzquierda),
          ),
          Positioned(
            right: 2,
            child: _flecha(izquierda: false, visible: _hayDerecha),
          ),
        ],
      ),
    );
  }
}

/// Permite arrastrar la mano con dedo, mouse, stylus y trackpad.
class _ManoScrollBehavior extends MaterialScrollBehavior {
  const _ManoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
