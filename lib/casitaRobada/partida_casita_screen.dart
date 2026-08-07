import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/menu_partida_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';
import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/casitaRobada/victoria_casita_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
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
  bool _roboCasitaSeleccionado = false;
  bool _jugando = false;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  AjustesEstado _ajustes = const AjustesEstado();

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  JugadorCasita get _yo {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre != TextosCasita.vsPcNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadorActual;
  }

  JugadorCasita get _rival {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == TextosCasita.vsPcNombre,
        orElse: () => _partida.jugadores.last,
      );
    }
    return _partida.rivalActual;
  }

  bool get _esTurnoHumano {
    if (_partida.terminada) return false;
    if (!widget.contraPc) return true;
    return _partida.jugadorActual.nombre != TextosCasita.vsPcNombre;
  }

  bool get _esTurnoPc =>
      widget.contraPc &&
      !_partida.terminada &&
      _partida.jugadorActual.nombre == TextosCasita.vsPcNombre;

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
      return puedeRobarCasita(carta, _rival);
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
    _roboCasitaSeleccionado = false;
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

  bool _esPcNombre(String nombre) =>
      nombre == TextosCasita.vsPcNombre ||
      (nombre.startsWith('PC ') && nombre.length > 3);

  bool _puedeRenombrar(int index) {
    if (_partida.terminada) return false;
    if (index < 0 || index >= _partida.jugadores.length) return false;
    return !_esPcNombre(_partida.jugadores[index].nombre);
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
      _roboCasitaSeleccionado = plan.robarCasita;
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
        jugarCartaCasita(
          _partida,
          indiceEnMano: plan.indiceMano,
          robarCasita: true,
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
      _roboCasitaSeleccionado = false;
    });
  }

  void _seleccionarMesa(CartaCasita carta) {
    if (_bloquearHumano) return;
    final mano = _cartaManoSel;
    if (mano == null) return;
    if (carta.numero != mano.numero) return;
    setState(() {
      _roboCasitaSeleccionado = false;
      if (_mesaSeleccion.contains(carta)) {
        _mesaSeleccion.remove(carta);
      } else {
        _mesaSeleccion.add(carta);
      }
    });
  }

  void _tocarCasitaRival() {
    if (_bloquearHumano) return;
    final mano = _cartaManoSel;
    if (mano == null) return;
    if (!puedeRobarCasita(mano, _rival)) return;
    setState(() {
      _mesaSeleccion.clear();
      _roboCasitaSeleccionado = !_roboCasitaSeleccionado;
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
      _partida = nuevaPartidaCasita(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _limpiarSeleccion();
      _jugando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  PaloEspanolVisual _paloVisual(PaloCasita p) => switch (p) {
        PaloCasita.oro => PaloEspanolVisual.oro,
        PaloCasita.copa => PaloEspanolVisual.copa,
        PaloCasita.espada => PaloEspanolVisual.espada,
        PaloCasita.basto => PaloEspanolVisual.basto,
      };

  @override
  Widget build(BuildContext context) {
    final manoAbajo = widget.contraPc ? _yo : _partida.jugadorActual;
    final manoArriba = widget.contraPc ? _rival : _partida.rivalActual;
    final pozoAbajo = manoAbajo;
    final pozoArriba = manoArriba;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_mostrarAjustes) {
          setState(() => _mostrarAjustes = false);
          return;
        }
        if (_mostrarMenu) {
          setState(() => _mostrarMenu = false);
          return;
        }
        setState(() {
          _mostrarMenu = true;
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
                              nombre: _partida.jugadores[i].nombre,
                              cartasMano:
                                  _partida.jugadores[i].mano.length,
                              cartasPozo:
                                  _partida.jugadores[i].cartasPozo,
                              activo: !_partida.terminada &&
                                  _partida.indiceTurno == i,
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
                  // Rival: mano centrada; casita a la izquierda (no desplaza el centro)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 148,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${TextosCasita.manoRival}: ${manoArriba.nombre}',
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
                                    cartas: manoArriba.mano,
                                    bocaArriba: _modoDiosActivo,
                                    paloVisual: _paloVisual,
                                    seleccionIndex:
                                        _esTurnoPc ? _cartaSeleccionada : null,
                                    indiceRevelado:
                                        _esTurnoPc ? _cartaSeleccionada : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 18,
                            child: _PozoCasita(
                              titulo: TextosCasita.casitaRival,
                              jugador: pozoArriba,
                              paloVisual: _paloVisual,
                              // El humano selecciona la casita rival para robar.
                              seleccionada: _roboCasitaSeleccionado &&
                                  _esTurnoHumano,
                              onTap: _esTurnoHumano && !_jugando
                                  ? _tocarCasitaRival
                                  : null,
                            ),
                          ),
                        ],
                      ),
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
                      cartasSeleccionadas: _mesaSeleccion,
                      onTapCarta: _esTurnoHumano && !_jugando
                          ? _seleccionarMesa
                          : null,
                    ),
                  ),
                  if (_partida.ultimaJugada != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  // Yo: mano centrada; casita a la izquierda (no desplaza el centro)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${TextosCasita.tuMano}: ${manoAbajo.nombre}',
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 116,
                                  width: double.infinity,
                                  child: _FilaCartas(
                                    cartas: manoAbajo.mano,
                                    bocaArriba: true,
                                    paloVisual: _paloVisual,
                                    seleccionIndex: _esTurnoHumano
                                        ? _cartaSeleccionada
                                        : null,
                                    onTapIndex: _esTurnoHumano && !_jugando
                                        ? (i) async => _seleccionarMano(i)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: _PozoCasita(
                              titulo: TextosCasita.tuCasita,
                              jugador: pozoAbajo,
                              paloVisual: _paloVisual,
                              resaltar: true,
                              // La PC selecciona tu casita cuando te la va a robar.
                              seleccionada: _roboCasitaSeleccionado &&
                                  _esTurnoPc,
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
                  onCerrar: () => setState(() => _mostrarMenu = false),
                  onReglas: () {
                    setState(() => _mostrarMenu = false);
                    _mostrarReglas();
                  },
                  onSalir: () {
                    setState(() => _mostrarMenu = false);
                    _salirAlMenu(
                      guardar: widget.contraPc && !_partida.terminada,
                    );
                  },
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaCasitaOverlay(
                  partida: _partida,
                  gane: widget.contraPc
                      ? (_partida.ganador == _yo.nombre)
                      : (_partida.ganador != null),
                  onOtraVez: _reiniciar,
                  onVolver: () => _salirAlMenu(guardar: false),
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
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final String nombre;
  final int cartasMano;
  final int cartasPozo;
  final bool activo;
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
          ),
          Text(
            'mano $cartasMano · casita $cartasPozo',
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
  });

  final String titulo;
  final JugadorCasita jugador;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final bool resaltar;
  final bool seleccionada;
  final VoidCallback? onTap;

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

    final cuerpo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: seleccionada
                ? colorSeleccionCartaEspanola
                : (resaltar ? AppColors.mint : AppColors.textoSuave),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${jugador.cartasPozo}',
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        cartaWidget,
      ],
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

class _FilaCartas extends StatelessWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.paloVisual,
    this.onTapIndex,
    this.onTapCarta,
    this.seleccionIndex,
    this.indiceRevelado,
    this.cartasSeleccionadas = const [],
  });

  final List<CartaCasita> cartas;
  final bool bocaArriba;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final Future<void> Function(int index)? onTapIndex;
  final void Function(CartaCasita carta)? onTapCarta;
  final int? seleccionIndex;
  /// Carta tapada que se muestra boca arriba (preview de la PC).
  final int? indiceRevelado;
  final List<CartaCasita> cartasSeleccionadas;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoFila = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (cartas.length * 74.0).clamp(68.0, 900.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: anchoFila),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < cartas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Builder(
                    builder: (context) {
                      final c = cartas[i];
                      final seleccionada = seleccionIndex == i ||
                          cartasSeleccionadas.contains(c);
                      final visible =
                          bocaArriba || indiceRevelado == i;
                      const deslizamiento = 14.0;
                      const cardW = 68.0;
                      const cardH = 102.0;
                      Widget card;
                      if (!visible) {
                        card = Container(
                          width: cardW,
                          height: cardH,
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
                      } else {
                        card = CartaEspanolaSkin(
                          numero: c.numero,
                          etiqueta: c.etiqueta,
                          palo: paloVisual(c.palo),
                          seleccionada: seleccionada,
                          width: cardW,
                          height: cardH,
                        );
                      }
                      final tarjeta = SizedBox(
                        width: cardW,
                        height: cardH + deslizamiento,
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          alignment: seleccionada
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          child: card,
                        ),
                      );
                      if (onTapIndex == null && onTapCarta == null) {
                        return tarjeta;
                      }
                      void onTap() {
                        if (onTapIndex != null) {
                          onTapIndex!(i);
                        } else if (onTapCarta != null) {
                          onTapCarta!(c);
                        }
                      }
                      // Sin hover si no está seleccionada (evita sombra/rectángulo arriba).
                      if (!seleccionada) {
                        return GestureDetector(
                          onTap: onTap,
                          behavior: HitTestBehavior.opaque,
                          child: tarjeta,
                        );
                      }
                      return Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(14),
                          splashColor: colorSeleccionCartaEspanola
                              .withValues(alpha: 0.25),
                          highlightColor: colorSeleccionCartaEspanola
                              .withValues(alpha: 0.18),
                          hoverColor: colorSeleccionCartaEspanola
                              .withValues(alpha: 0.22),
                          child: tarjeta,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
