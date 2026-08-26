import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/menu_partida_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';
import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/casitaRobada/victoria_casita_overlay.dart';
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
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Casita robada.
class PartidaCasitaScreen extends StatefulWidget {
  const PartidaCasitaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final PartidaCasitaResume? resume;

  @override
  State<PartidaCasitaScreen> createState() => _PartidaCasitaScreenState();
}

class _PartidaCasitaScreenState extends State<PartidaCasitaScreen> {
  late PartidaCasita _partida;
  late List<String> _nombres;
  int _pcToken = 0;
  int? _cartaSeleccionada;
  final List<CartaCasita> _mesaSeleccion = [];
  /// Último modo de orden aplicado con el botón (null = aún no se usó).
  ModoOrdenManoCartas? _modoOrdenMano;
  /// Se incrementa al ordenar para disparar la animación de deslizamiento.
  int _ordenAnimGen = 0;
  /// Copia del orden de la mano justo antes del último ordenado automático.
  List<CartaCasita>? _ordenAntesAnim;
  /// Nombre del dueño de la casita rival seleccionada para robar.
  String? _nombreCasitaRobo;
  bool _jugando = false;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  AjustesEstado _ajustes = const AjustesEstado();

  bool get _esLocalHotSeat => !widget.contraPc;

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  JugadorCasita get _yo {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadorActual;
  }

  /// Quién mira la mesa abajo (vs PC = humano; local = turno actual).
  JugadorCasita get _vistaAbajo => widget.contraPc ? _yo : _partida.jugadorActual;

  /// Rivales en orden de mesa desde el siguiente a [_vistaAbajo].
  List<JugadorCasita> get _oponentes {
    final todos = _partida.jugadores;
    final yo = _vistaAbajo;
    final idx = todos.indexWhere((j) => j.nombre == yo.nombre);
    if (idx < 0) {
      return [for (final j in todos) if (j.nombre != yo.nombre) j];
    }
    return [
      for (var i = 1; i < todos.length; i++)
        todos[(idx + i) % todos.length],
    ];
  }

  /// PC1 / 1.º → arriba-izq; PC2 / 2.º → arriba-der; PC3 / 3.º → abajo-der.
  ({
    JugadorCasita? arribaIzq,
    JugadorCasita? arribaDer,
    JugadorCasita? abajoDer,
  }) get _asientosCasitasRival {
    final ops = _oponentes;
    return switch (ops.length) {
      0 => (arribaIzq: null, arribaDer: null, abajoDer: null),
      1 => (arribaIzq: ops[0], arribaDer: null, abajoDer: null),
      2 => (arribaIzq: ops[0], arribaDer: ops[1], abajoDer: null),
      _ => (arribaIzq: ops[0], arribaDer: ops[1], abajoDer: ops[2]),
    };
  }

  JugadorCasita get _rival {
    if (widget.contraPc) {
      if (_esTurnoPc) return _partida.jugadorActual;
      return _partida.rivalActual;
    }
    return _partida.rivalActual;
  }

  bool get _roboCasitaSeleccionado => _nombreCasitaRobo != null;

  JugadorCasita? get _casitaRoboSel {
    final n = _nombreCasitaRobo;
    if (n == null) return null;
    for (final j in _partida.jugadores) {
      if (j.nombre == n) return j;
    }
    return null;
  }

  bool get _esTurnoHumano {
    if (_partida.terminada) return false;
    if (!widget.contraPc) return true;
    return !esNombrePc(_partida.jugadorActual.nombre);
  }

  bool get _esTurnoPc =>
      widget.contraPc &&
      !_partida.terminada &&
      esNombrePc(_partida.jugadorActual.nombre);

  bool get _bloquearHumano => !_esTurnoHumano || _jugando || _partida.terminada;

  CartaCasita? get _cartaManoSel {
    final i = _cartaSeleccionada;
    if (i == null) return null;
    final mano = widget.contraPc ? _yo.mano : _partida.jugadorActual.mano;
    if (i < 0 || i >= mano.length) return null;
    return mano[i];
  }

  bool get _puedeCapturar {
    if (_bloquearHumano) return false;
    final carta = _cartaManoSel;
    if (carta == null) return false;
    if (_roboCasitaSeleccionado) {
      final rival = _casitaRoboSel;
      if (rival == null) return false;
      return puedeRobarCasita(carta, rival);
    }
    if (_mesaSeleccion.isEmpty) return false;
    return _mesaSeleccion.every((c) => c.numero == carta.numero);
  }

  bool get _puedeTirar {
    if (_bloquearHumano) return false;
    if (_cartaManoSel == null) return false;
    return !_puedeCapturar;
  }

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_esTurnoPc) return TextosCasita.esperandoPc;
    if (!_esTurnoHumano) {
      return 'Turno de ${_partida.jugadorActual.nombre}';
    }
    if (_cartaSeleccionada == null) return TextosCasita.juegaUna;
    if (_puedeCapturar) {
      return 'Listo${TextosCasita.listoCapturar}';
    }
    if (_mesaSeleccion.isEmpty && !_roboCasitaSeleccionado) {
      return 'Carta elegida${TextosCasita.faltaMesaOCasita}';
    }
    return TextosCasita.juegaUna;
  }

  void _limpiarSeleccion() {
    _cartaSeleccionada = null;
    _mesaSeleccion.clear();
    _nombreCasitaRobo = null;
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    if (resume != null) {
      _partida = resume.partida;
      _nombres = List.of(resume.nombres);
    } else {
      _partida = nuevaPartidaCasita(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [
        for (final j in _partida.jugadores) j.nombre,
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      CasitaStandByStore.limpiar();
      return;
    }
    CasitaStandByStore.guardar(
      PartidaCasitaResume(
        partida: _partida,
        nombres: _nombres,
        modoDios: widget.modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    _pcToken++;
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      CasitaStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static const int _maxNombre = 15;

  bool _esPcNombre(String nombre) => esNombrePc(nombre);

  bool _puedeRenombrar(int index) {
    if (_partida.terminada) return false;
    if (index < 0 || index >= _partida.jugadores.length) return false;
    final j = _partida.jugadores[index];
    if (j.rendido) return false;
    return !_esPcNombre(j.nombre);
  }

  void _rendirse() {
    if (_partida.terminada || !_esLocalHotSeat) return;
    final yo = _partida.jugadorActual;
    if (yo.rendido) return;

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _limpiarSeleccion();
      rendirseCasita(_partida, yo.nombre);
    });
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (_esPcNombre(nombre)) {
      return 'Ese nombre está reservado para la PC.';
    }
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (!_puedeRenombrar(index)) return;
    final actual = _partida.jugadores[index].nombre;
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
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
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
      if (_partida.ultimoQueCapturo == actual) {
        _partida.ultimoQueCapturo = nuevo;
      }
      final uj = _partida.ultimaJugada;
      if (uj != null) {
        if (uj.jugador == actual) uj.jugador = nuevo;
        if (uj.robadoDe == actual) uj.robadoDe = nuevo;
      }
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
    });
  }

  void _mostrarReglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.mint,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            reglasCasitaRobada(),
            style: const TextStyle(
              color: AppColors.texto,
              height: 1.35,
            ),
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

  Future<void> _talVezTurnoPc() async {
    if (!_esTurnoPc || _jugando) return;
    final token = ++_pcToken;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || token != _pcToken || !_esTurnoPc) return;

    final plan = planificarJugadaPcCasita(_partida);
    if (plan == null) return;

    // Preview de selección (captura o tiro) como si jugara el humano.
    setState(() {
      _cartaSeleccionada = plan.indiceMano;
      _mesaSeleccion
        ..clear()
        ..addAll(plan.mesaElegida);
      _nombreCasitaRobo =
          plan.robarCasita ? plan.robarDeNombre : null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || token != _pcToken || !_esTurnoPc) return;

    setState(() {
      if (plan.tirar) {
        jugarCartaCasita(
          _partida,
          indiceEnMano: plan.indiceMano,
          forzarTirar: true,
        );
      } else if (plan.robarCasita) {
        JugadorCasita? rival;
        final nombre = plan.robarDeNombre;
        if (nombre != null) {
          for (final j in _partida.jugadores) {
            if (j.nombre == nombre) {
              rival = j;
              break;
            }
          }
        }
        jugarCartaCasita(
          _partida,
          indiceEnMano: plan.indiceMano,
          robarCasita: true,
          rivalObjetivo: rival,
        );
      } else {
        jugarCartaCasita(
          _partida,
          indiceEnMano: plan.indiceMano,
          mesaElegida: plan.mesaElegida,
        );
      }
      _limpiarSeleccion();
    });

    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) _talVezTurnoPc();
    }
  }

  void _seleccionarMano(int indice) {
    if (_bloquearHumano) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      if (_cartaSeleccionada == indice) {
        _limpiarSeleccion();
        return;
      }
      _cartaSeleccionada = indice;
      _mesaSeleccion.clear();
      _nombreCasitaRobo = null;
    });
  }

  void _reordenarMano(int desde, int hacia) {
    if (_bloquearHumano) return;
    final mano = _vistaAbajo.mano;
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
      final sel = _cartaSeleccionada;
      if (sel == null) return;
      if (sel == desde) {
        _cartaSeleccionada = hacia;
      } else if (desde < hacia && sel > desde && sel <= hacia) {
        _cartaSeleccionada = sel - 1;
      } else if (hacia < desde && sel >= hacia && sel < desde) {
        _cartaSeleccionada = sel + 1;
      }
    });
  }

  void _ciclarOrdenMano() {
    if (_bloquearHumano) return;
    final mano = _vistaAbajo.mano;
    if (mano.length < 2) return;
    final ordenAntes = List<CartaCasita>.of(mano);
    CartaCasita? selCarta;
    final selIdx = _cartaSeleccionada;
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
        _cartaSeleccionada = nuevo >= 0 ? nuevo : null;
      }
    });
  }

  void _seleccionarMesa(CartaCasita carta) {
    if (_bloquearHumano) return;
    final mano = _cartaManoSel;
    if (mano == null) return;
    if (carta.numero != mano.numero) return;
    setState(() {
      _nombreCasitaRobo = null;
      if (_mesaSeleccion.contains(carta)) {
        _mesaSeleccion.remove(carta);
      } else {
        _mesaSeleccion.add(carta);
      }
    });
  }

  void _tocarCasitaRival(JugadorCasita rival) {
    if (_bloquearHumano) return;
    final mano = _cartaManoSel;
    if (mano == null) return;
    if (!puedeRobarCasita(mano, rival)) return;
    setState(() {
      _mesaSeleccion.clear();
      _nombreCasitaRobo =
          _nombreCasitaRobo == rival.nombre ? null : rival.nombre;
    });
  }

  Future<void> _tirarAMesa() async {
    if (!_puedeTirar) return;
    final idx = _cartaSeleccionada;
    if (idx == null) return;
    setState(() => _jugando = true);
    final err = jugarCartaCasita(
      _partida,
      indiceEnMano: idx,
      forzarTirar: true,
    );
    setState(() {
      _jugando = false;
      _limpiarSeleccion();
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _confirmarCaptura() async {
    if (!_puedeCapturar) return;
    final idx = _cartaSeleccionada;
    if (idx == null) return;
    setState(() => _jugando = true);
    final err = jugarCartaCasita(
      _partida,
      indiceEnMano: idx,
      mesaElegida: _roboCasitaSeleccionado ? null : List.of(_mesaSeleccion),
      robarCasita: _roboCasitaSeleccionado,
      rivalObjetivo: _casitaRoboSel,
    );
    setState(() {
      _jugando = false;
      _limpiarSeleccion();
    });
    if (err != null && mounted) {
      // Mensajes de guía no se muestran como cartel; solo errores reales.
      if (!err.startsWith('Elegí carta')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) _talVezTurnoPc();
    }
  }

  void _reiniciar() {
    _pcToken++;
    CasitaStandByStore.limpiar();
    setState(() {
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(MenuJuegoScreen.juegoIdCasitaRobada) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(actuales: _nombres, cantidadPc: pcs);
      }
      _partida = nuevaPartidaCasita(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _limpiarSeleccion();
      _jugando = false;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  PaloEspanolVisual _paloVisual(PaloCasita p) => switch (p) {
        PaloCasita.oro => PaloEspanolVisual.oro,
        PaloCasita.copa => PaloEspanolVisual.copa,
        PaloCasita.espada => PaloEspanolVisual.espada,
        PaloCasita.basto => PaloEspanolVisual.basto,
      };

  @override
  Widget build(BuildContext context) {
    final manoAbajo = _vistaAbajo;
    final manoArriba = widget.contraPc ? _rival : _partida.rivalActual;
    final asientos = _asientosCasitasRival;
    final pozoAbajo = manoAbajo;

    Widget pozoRival(JugadorCasita j, {bool textoALaIzquierda = false}) {
      return _PozoCasita(
        titulo: TextosCasita.casitaRivalDe(j.nombre),
        jugador: j,
        paloVisual: _paloVisual,
        seleccionada: _nombreCasitaRobo == j.nombre,
        textoALaIzquierda: textoALaIzquierda,
        onTap: _esTurnoHumano && !_jugando && !j.rendido
            ? () => _tocarCasitaRival(j)
            : null,
      );
    }

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
          _mostrarAjustes = false;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            const Positioned.fill(
              child: EpicBackdrop(centerY: 0.42, fadeRayosAlCentro: true),
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
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosCasita.titulo,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (var i = 0;
                            i < _partida.jugadores.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _ChipJugador(
                              nombre: _partida.jugadores[i].rendido
                                  ? '${_partida.jugadores[i].nombre} (fuera)'
                                  : _partida.jugadores[i].nombre,
                              cartasMano:
                                  _partida.jugadores[i].mano.length,
                              cartasPozo:
                                  _partida.jugadores[i].cartasPozo,
                              activo: !_partida.terminada &&
                                  !_partida.jugadores[i].rendido &&
                                  _partida.indiceTurno == i,
                              rendido: _partida.jugadores[i].rendido,
                              puedeRenombrar: _puedeRenombrar(i),
                              onRenombrar: _puedeRenombrar(i)
                                  ? () => _renombrarJugador(i)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_textoEstado.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _textoEstado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _esTurnoHumano
                            ? AppColors.mint
                            : AppColors.textoSuave,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 170,
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${TextosCasita.manoRival}: ${manoArriba.nombre}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Mismo margen lateral que arriba/abajo
                                      // (carta casita = 102).
                                      final margen = ((constraints.maxHeight -
                                                  102) /
                                              2)
                                          .clamp(0.0, 40.0);
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _FilaCartas(
                                            cartas: manoArriba.mano,
                                            bocaArriba: _modoDiosActivo,
                                            paloVisual: _paloVisual,
                                            animaciones: _ajustes.animaciones,
                                            seleccionIndex: _esTurnoPc
                                                ? _cartaSeleccionada
                                                : null,
                                            indiceRevelado: _esTurnoPc
                                                ? _cartaSeleccionada
                                                : null,
                                          ),
                                          if (asientos.arribaIzq != null)
                                            Positioned(
                                              left: margen,
                                              top: 0,
                                              bottom: 0,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerLeft,
                                                child: pozoRival(
                                                  asientos.arribaIzq!,
                                                ),
                                              ),
                                            ),
                                          if (asientos.arribaDer != null)
                                            Positioned(
                                              right: margen,
                                              top: 0,
                                              bottom: 0,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: pozoRival(
                                                  asientos.arribaDer!,
                                                  textoALaIzquierda: true,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${TextosCasita.mesa} · mazo ${_partida.mazo.length}',
                            style: const TextStyle(
                              color: AppColors.textoSuave,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 116,
                            width: double.infinity,
                            child: _FilaCartas(
                              cartas: _partida.mesa,
                              bocaArriba: true,
                              paloVisual: _paloVisual,
                              animaciones: _ajustes.animaciones,
                              cartasSeleccionadas: _mesaSeleccion,
                              onTapCarta: _esTurnoHumano && !_jugando
                                  ? _seleccionarMesa
                                  : null,
                            ),
                          ),
                          if (_partida.ultimaJugada != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 72,
                              ),
                              child: Text(
                                _partida.ultimaJugada!.descripcion,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.acento,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          SizedBox(
                            height: 170,
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        '${TextosCasita.tuMano}: ${manoAbajo.nombre}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.mint,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: BotonOrdenarMano(
                                            size: 38,
                                            onPressed: manoAbajo.mano.length <
                                                        2 ||
                                                    _bloquearHumano
                                                ? null
                                                : _ciclarOrdenMano,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final margen = ((constraints.maxHeight -
                                                  102) /
                                              2)
                                          .clamp(0.0, 40.0);
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _FilaCartas(
                                            cartas: manoAbajo.mano,
                                            bocaArriba: true,
                                            paloVisual: _paloVisual,
                                            animaciones: _ajustes.animaciones,
                                            seleccionIndex: _esTurnoHumano
                                                ? _cartaSeleccionada
                                                : null,
                                            puedeElegir: _esTurnoHumano &&
                                                !_jugando,
                                            onTapIndex: (i) async =>
                                                _seleccionarMano(i),
                                            onReordenar: _reordenarMano,
                                            ordenAnimGen: _ordenAnimGen,
                                            ordenAntesAnim: _ordenAntesAnim,
                                          ),
                                          Positioned(
                                            left: margen,
                                            top: 0,
                                            bottom: 0,
                                            child: Align(
                                              alignment:
                                                  Alignment.centerLeft,
                                              child: _PozoCasita(
                                                titulo: widget.contraPc
                                                    ? TextosCasita.tuCasita
                                                    : TextosCasita
                                                        .tuCasitaDe(
                                                        pozoAbajo.nombre,
                                                      ),
                                                jugador: pozoAbajo,
                                                paloVisual: _paloVisual,
                                                resaltar: true,
                                                seleccionada:
                                                    _nombreCasitaRobo ==
                                                        pozoAbajo.nombre,
                                              ),
                                            ),
                                          ),
                                          if (asientos.abajoDer != null)
                                            Positioned(
                                              right: margen,
                                              top: 0,
                                              bottom: 0,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: pozoRival(
                                                  asientos.abajoDer!,
                                                  textoALaIzquierda: true,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 54,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _puedeTirar ? _tirarAMesa : null,
                              child: Text(
                                _cartaSeleccionada == null || _bloquearHumano
                                    ? 'Tirar'
                                    : _puedeCapturar
                                        ? 'Tirar (bloqueado)'
                                        : 'Tirar (${_cartaManoSel!.numero})',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.mint,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.mint.withValues(alpha: 0.38),
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.78),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed:
                                  _puedeCapturar ? _confirmarCaptura : null,
                              child: Text(
                                _puedeCapturar
                                    ? (_roboCasitaSeleccionado
                                        ? 'Capturar (casita)'
                                        : 'Capturar (${_mesaSeleccion.length + 1})')
                                    : 'Capturar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
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
                child: MenuPartidaCasita(
                  jugador: widget.contraPc
                      ? _yo.nombre
                      : _partida.jugadorActual.nombre,
                  partidaTerminada: _partida.terminada,
                  permitirRendirse: _esLocalHotSeat,
                  confirmarRendicion:
                      _confirmarRendicion && _esLocalHotSeat,
                  onCerrar: () => setState(() {
                    _mostrarMenu = false;
                    _confirmarRendicion = false;
                  }),
                  onReglas: () {
                    setState(() {
                      _mostrarMenu = false;
                      _confirmarRendicion = false;
                    });
                    _mostrarReglas();
                  },
                  onSalirORendirse: _partida.terminada || !_esLocalHotSeat
                      ? () {
                          setState(() {
                            _mostrarMenu = false;
                            _confirmarRendicion = false;
                          });
                          _salirAlMenu(
                            guardar:
                                widget.contraPc && !_partida.terminada,
                          );
                        }
                      : () => setState(() => _confirmarRendicion = true),
                  onConfirmarRendicion: _rendirse,
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: PremiarMonedasVictoriaPc(
                  aplicar: widget.contraPc &&
                      (_partida.ganador == _yo.nombre),
                  child: VictoriaCasitaOverlay(
                    partida: _partida,
                    gane: widget.contraPc
                        ? (_partida.ganador == _yo.nombre)
                        : (_partida.ganador != null),
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
}

class _ChipJugador extends StatelessWidget {
  const _ChipJugador({
    required this.nombre,
    required this.cartasMano,
    required this.cartasPozo,
    required this.activo,
    this.rendido = false,
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final String nombre;
  final int cartasMano;
  final int cartasPozo;
  final bool activo;
  final bool rendido;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo ? AppColors.mint : AppColors.cartaBorde,
          width: activo ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          NombreJugadorEditable(
            nombre: nombre,
            puedeRenombrar: puedeRenombrar,
            onRenombrar: onRenombrar,
            fontSize: 13,
            tachado: rendido,
            colorTexto: rendido ? AppColors.textoSuave : AppColors.texto,
          ),
          Text(
            rendido
                ? 'rendido'
                : 'mano $cartasMano · casita $cartasPozo',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PozoCasita extends StatelessWidget {
  const _PozoCasita({
    required this.titulo,
    required this.jugador,
    required this.paloVisual,
    this.resaltar = false,
    this.seleccionada = false,
    this.onTap,
    /// Si true, el texto va a la izquierda de la carta (casitas del lado derecho).
    this.textoALaIzquierda = false,
  });

  final String titulo;
  final JugadorCasita jugador;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final bool resaltar;
  final bool seleccionada;
  final VoidCallback? onTap;
  final bool textoALaIzquierda;

  @override
  Widget build(BuildContext context) {
    final cima = jugador.cimaPozo;
    final borde = seleccionada
        ? colorSeleccionCartaEspanola
        : (resaltar ? AppColors.mint.withValues(alpha: 0.55) : AppColors.cartaBorde);

    Widget cartaWidget;
    if (cima == null) {
      cartaWidget = Container(
        width: 68,
        height: 102,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borde,
            width: seleccionada ? 2.4 : 1.5,
          ),
        ),
        child: const Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    } else {
      cartaWidget = CartaEspanolaSkin(
        numero: cima.numero,
        etiqueta: cima.etiqueta,
        palo: paloVisual(cima.palo),
        seleccionada: seleccionada,
        width: 68,
        height: 102,
      );
    }

    final texto = SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: textoALaIzquierda
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            textAlign:
                textoALaIzquierda ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: seleccionada
                  ? colorSeleccionCartaEspanola
                  : (resaltar ? AppColors.mint : AppColors.textoSuave),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${jugador.cartasPozo}',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    final cuerpo = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: textoALaIzquierda
          ? [texto, const SizedBox(width: 6), cartaWidget]
          : [cartaWidget, const SizedBox(width: 6), texto],
    );

    if (onTap == null) return cuerpo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: cuerpo,
      ),
    );
  }
}

class _FilaCartas extends StatefulWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.paloVisual,
    required this.animaciones,
    this.onTapIndex,
    this.onTapCarta,
    this.seleccionIndex,
    this.indiceRevelado,
    this.cartasSeleccionadas = const [],
    this.onReordenar,
    this.puedeElegir = true,
    this.ordenAnimGen = 0,
    this.ordenAntesAnim,
  });

  final List<CartaCasita> cartas;
  final bool bocaArriba;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final bool animaciones;
  final Future<void> Function(int index)? onTapIndex;
  final void Function(CartaCasita carta)? onTapCarta;
  final int? seleccionIndex;
  /// Carta tapada que se muestra boca arriba (preview de la PC).
  final int? indiceRevelado;
  final List<CartaCasita> cartasSeleccionadas;
  final void Function(int desde, int hacia)? onReordenar;
  /// Si false, no anima subida de selección (p. ej. cambio de turno).
  final bool puedeElegir;
  /// Generación de ordenado automático (botón); 0 = sin animación de sort.
  final int ordenAnimGen;
  /// Orden de la mano justo antes del último sort (copia; no la lista viva).
  final List<CartaCasita>? ordenAntesAnim;

  @override
  State<_FilaCartas> createState() => _FilaCartasState();
}

class _FilaCartasState extends State<_FilaCartas> {
  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  final _reorden = ReordenarCartaManoDrag();
  bool _priorizarReorden = false;
  Map<Object, double> _dxOrden = const {};
  int _genOrden = 0;

  static const double _cardW = 68;
  static const double _cardH = 102;
  static const double _gap = 6;

  bool get _arrastrando => _reorden.arrastrando;
  bool get _tieneReorden => widget.onReordenar != null;
  bool get _bloquearScroll => _arrastrando || _priorizarReorden;

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
  void didUpdateWidget(covariant _FilaCartas oldWidget) {
    super.didUpdateWidget(oldWidget);

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
        paso: _cardW + _gap,
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
    _scroll.dispose();
    super.dispose();
  }

  int _indiceInsercionDesdeGlobal(double globalX) {
    return indiceInsercionDesdeGlobalReorden(
      rowKey: _rowKey,
      drag: _reorden,
      globalX: globalX,
      cantidad: widget.cartas.length,
      anchoCarta: _cardW,
      gap: _gap,
    );
  }

  void _iniciarDrag(int index, Offset localPosition) {
    setState(() {
      _reorden.iniciar(
        index: index,
        localPosition: localPosition,
        anchoCarta: _cardW,
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

  Widget _skin(CartaCasita c, {required bool seleccionada, required bool visible}) {
    if (!visible) {
      return Container(
        width: _cardW,
        height: _cardH,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada
                ? colorSeleccionCartaEspanola
                : AppColors.acento,
            width: seleccionada ? 2.4 : 2,
          ),
        ),
        child: const Center(
          child: Text(
            '?',
            style: TextStyle(
              color: AppColors.acento,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return CartaEspanolaSkin(
      numero: c.numero,
      etiqueta: c.etiqueta,
      palo: widget.paloVisual(c.palo),
      seleccionada: seleccionada,
      width: _cardW,
      height: _cardH,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cartas.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }

    final altoSlot = _cardH + kDeslizamientoSeleccionCarta;
    final contenedor = BoxDecoration(
      color: const Color(0xFF1A0A33).withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.violeta.withValues(alpha: 0.55),
        width: 1.2,
      ),
    );

    return Container(
      decoration: contenedor,
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minW = math.max(0.0, constraints.maxWidth - 24);
          final n = widget.cartas.length;
          final contentW = n == 0 ? 0.0 : n * _cardW + (n - 1) * _gap;
          final filaW = math.max(minW, contentW);
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Solo bloquea scroll al tocar/arrastrar la carta seleccionada.
            physics: physicsScrollManoReorden(bloquearPorReorden: _bloquearScroll),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
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
                      for (var i = 0; i < widget.cartas.length; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Builder(
                          key: ValueKey<String>(
                            'slot_${widget.cartas[i].etiqueta}',
                          ),
                          builder: (context) {
                            final c = widget.cartas[i];
                            final seleccionada =
                                widget.seleccionIndex == i ||
                                    widget.cartasSeleccionadas.contains(c);
                            final visible =
                                widget.bocaArriba ||
                                    widget.indiceRevelado == i;
                            final esLaQueArrastro = _reorden.dragIndex == i;
                            final atenuar =
                                _arrastrando && !esLaQueArrastro;
                            final puedeInteractuar = widget.puedeElegir &&
                                (widget.onTapIndex != null ||
                                    widget.onTapCarta != null);
                            final puedeArrastrar = _tieneReorden &&
                                seleccionada &&
                                puedeInteractuar;

                            Widget child = CartaOpacidadReorden(
                              esLaQueArrastro: esLaQueArrastro,
                              atenuar: atenuar,
                              child: CartaSlotSeleccion(
                                seleccionada: seleccionada,
                                animaciones: widget.animaciones &&
                                    widget.puedeElegir,
                                width: _cardW,
                                height: _cardH,
                                child: _skin(
                                  c,
                                  seleccionada: seleccionada,
                                  visible: visible,
                                ),
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
                              shiftX: _reorden.shiftX(i, _cardW + _gap),
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
                              borderRadius: BorderRadius.circular(14),
                              child: child,
                            );

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: Listener(
                                onPointerDown: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(true)
                                    : null,
                                onPointerUp: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(false)
                                    : null,
                                onPointerCancel: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(false)
                                    : null,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: !puedeInteractuar
                                      ? null
                                      : () {
                                          if (widget.onTapIndex != null) {
                                            widget.onTapIndex!(i);
                                          } else if (widget.onTapCarta !=
                                              null) {
                                            widget.onTapCarta!(c);
                                          }
                                        },
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
                      anchoCarta: _cardW,
                      gap: _gap,
                      dragDx: _reorden.dragDx,
                      dragDy: _reorden.dragDy,
                      borderRadius: BorderRadius.circular(14),
                      child: CartaSlotSeleccion(
                        seleccionada: true,
                        animaciones: false,
                        width: _cardW,
                        height: _cardH,
                        child: _skin(
                          widget.cartas[_reorden.dragIndex!],
                          seleccionada: true,
                          visible: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
