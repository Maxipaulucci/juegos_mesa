import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/escobaDel15/menu_partida_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/resumen_ronda_escoba_overlay.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/escobaDel15/textos.dart';
import 'package:app_juegos_mesa/escobaDel15/victoria_escoba_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida de Escoba del 15 (cartas en texto crudo, sin skin).
class PartidaEscobaScreen extends StatefulWidget {
  const PartidaEscobaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
    this.resume,
    this.modoDios = false,
  });

  final List<String> nombres;
  final bool contraPc;
  final String? salaCodigo;
  final String? miNombre;
  final AjustesEstado? ajustesIniciales;
  final PartidaEscobaResume? resume;
  final bool modoDios;

  @override
  State<PartidaEscobaScreen> createState() => _PartidaEscobaScreenState();
}

class _PartidaEscobaScreenState extends State<PartidaEscobaScreen> {
  late PartidaEscoba _partida;
  late List<String> _nombres;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  String? _aviso;
  CartaEscoba? _cartaSeleccionada;
  final List<CartaEscoba> _mesaSeleccion = [];
  bool _pcMostrandoJugada = false;
  String? _mensajePc;
  int _pcToken = 0;

  bool get _mostrarResumenRonda {
    final r = _partida.ultimoResultado;
    if (r == null) return false;
    return _partida.fase == FaseEscoba.finRonda;
  }

  bool get _esPcTurno {
    if (!widget.contraPc) return false;
    return _partida.jugadorActual.nombre == 'PC';
  }

  bool get _bloquearHumano => _esPcTurno || _pcMostrandoJugada;

  JugadorEscoba get _manoVisible {
    if (!widget.contraPc) return _partida.jugadorActual;
    return _partida.jugadores.firstWhere(
      (j) => j.nombre != 'PC',
      orElse: () => _partida.jugadores.first,
    );
  }

  static const int _maxNombre = 15;

  int? get _indiceRenombrable {
    if (_partida.terminada) return null;
    if (widget.contraPc) {
      final i = _partida.jugadores.indexWhere((j) => j.nombre != 'PC');
      return i >= 0 ? i : null;
    }
    final i = _partida.indiceTurno % _partida.jugadores.length;
    if (_partida.jugadores[i].nombre == 'PC') return null;
    return i;
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (nombre == 'PC') return 'Ese nombre está reservado.';
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarDesdeHeader() async {
    final index = _indiceRenombrable;
    if (index == null) return;
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
            style: TextStyle(color: AppColors.mint, fontSize: 18),
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
                  counterStyle:
                      const TextStyle(color: AppColors.textoSuave),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final t = ctrl.text.trim();
                    if (_validarNombre(t, index) case final e?) {
                      setDialogState(() => error = e);
                      return;
                    }
                    Navigator.of(context).pop(t);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: const Color(0xFF062018),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;
    setState(() {
      final anterior = _partida.jugadores[index].nombre;
      _partida.jugadores[index].nombre = nuevo;
      _nombres[index] = nuevo;
      if (_partida.ganador == anterior) {
        _partida.ganador = nuevo;
      }
      if (_partida.mensajeFin != null &&
          _partida.mensajeFin!.contains(anterior)) {
        _partida.mensajeFin =
            _partida.mensajeFin!.replaceFirst(anterior, nuevo);
      }
    });
  }

  int get _sumaMesa =>
      _mesaSeleccion.fold<int>(0, (s, c) => s + c.valorSuma);

  int get _sumaSeleccion {
    final mano = _cartaSeleccionada?.valorSuma ?? 0;
    return mano + _sumaMesa;
  }

  bool get _haySeleccion =>
      _cartaSeleccionada != null || _mesaSeleccion.isNotEmpty;

  bool get _faltaCartaMano =>
      _cartaSeleccionada == null &&
      _mesaSeleccion.isNotEmpty &&
      _sumaMesa == 15;

  bool get _puedeCapturar =>
      !_bloquearHumano &&
      _cartaSeleccionada != null &&
      _mesaSeleccion.isNotEmpty &&
      _sumaSeleccion == 15;

  bool get _puedeTirar =>
      !_bloquearHumano &&
      _cartaSeleccionada != null &&
      _sumaSeleccion != 15;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _nombres = List.of(resume.nombres);
      _ajustes = resume.ajustesIniciales;
      _partida = resume.partida;
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
      return;
    }
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales ?? const AjustesEstado();
    _partida = nuevaPartidaEscoba(nombres: _nombres);
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  void _limpiarSeleccion() {
    _cartaSeleccionada = null;
    _mesaSeleccion.clear();
    _aviso = null;
  }

  Future<void> _talVezPc() async {
    if (!mounted || !_esPcTurno || _partida.terminada) return;
    if (_partida.fase == FaseEscoba.finRonda) return;
    if (_partida.fase == FaseEscoba.ganado) return;
    final token = _pcToken;

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || token != _pcToken) return;
    if (!_esPcTurno || _partida.fase != FaseEscoba.jugando) return;

    final jugada = planificarTurnoPcEscoba(_partida);
    if (jugada == null) return;

    setState(() {
      _pcMostrandoJugada = true;
      _mensajePc = jugada.descripcion;
      _cartaSeleccionada = jugada.carta;
      _mesaSeleccion
        ..clear()
        ..addAll(jugada.mesaElegida ?? const []);
      _aviso = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted || token != _pcToken) return;

    setState(() {
      ejecutarJugadaPcEscoba(_partida, jugada);
      _pcMostrandoJugada = false;
      _cartaSeleccionada = null;
      _mesaSeleccion.clear();
      _aviso = _mensajePc;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || token != _pcToken) return;
    if (_partida.fase == FaseEscoba.jugando && _esPcTurno) {
      setState(() {
        _mensajePc = null;
        _aviso = null;
      });
      await _talVezPc();
    }
  }

  Future<void> _seleccionarMano(CartaEscoba carta) async {
    if (_partida.fase != FaseEscoba.jugando || _bloquearHumano) return;
    setState(() {
      _mensajePc = null;
      _cartaSeleccionada = carta;
      if (_mesaSeleccion.isEmpty) {
        _aviso =
            'Elegí cartas de la mesa o tocá TIRAR para dejar ${carta.etiqueta}';
      } else {
        final suma = carta.valorSuma + _sumaMesa;
        _aviso = suma == 15
            ? '¡Suma 15! Solo podés capturar, no tirar.'
            : 'Suma: $suma / 15';
      }
    });
  }

  void _toggleMesa(CartaEscoba c) {
    if (_partida.fase != FaseEscoba.jugando || _bloquearHumano) return;
    setState(() {
      _mensajePc = null;
      if (_mesaSeleccion.contains(c)) {
        _mesaSeleccion.remove(c);
      } else {
        _mesaSeleccion.add(c);
      }
      if (_cartaSeleccionada == null && _mesaSeleccion.isEmpty) {
        _aviso = null;
      } else if (_cartaSeleccionada == null && _sumaMesa == 15) {
        _aviso =
            '¡Debés elegir una carta de tu mano sí o sí para poder capturar!';
      } else if (_cartaSeleccionada == null) {
        _aviso = 'Suma del pozo: $_sumaMesa / 15';
      } else if (_mesaSeleccion.isNotEmpty) {
        final suma = _cartaSeleccionada!.valorSuma + _sumaMesa;
        _aviso = suma == 15
            ? '¡Suma 15! Solo podés capturar, no tirar.'
            : 'Suma: $suma / 15';
      }
    });
  }

  void _tirarAMesa() {
    final carta = _cartaSeleccionada;
    if (carta == null || !_puedeTirar) return;
    final err = jugarCartaEscoba(_partida, carta, forzarTirar: true);
    setState(() {
      _aviso = err;
      if (err == null) _limpiarSeleccion();
    });
    if (err == null) _talVezPc();
  }

  void _confirmarCaptura() {
    final carta = _cartaSeleccionada;
    if (carta == null || !_puedeCapturar) return;
    final err = jugarCartaEscoba(
      _partida,
      carta,
      mesaElegida: List.of(_mesaSeleccion),
    );
    setState(() {
      _aviso = err;
      if (err == null) _limpiarSeleccion();
    });
    if (err == null) _talVezPc();
  }

  void _continuarRonda() {
    setState(() {
      siguienteRondaEscoba(_partida);
      _partida.ultimoResultado = null;
      _limpiarSeleccion();
    });
    if (_partida.fase == FaseEscoba.jugando) _talVezPc();
  }

  void _volverAJugar() {
    EscobaStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaEscoba(nombres: _nombres);
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  void _salirAlMenu() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _salirGuardandoResumeYVolverAlMenu() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      EscobaStandByStore.limpiar();
      _salirAlMenu();
      return;
    }
    EscobaStandByStore.guardar(
      PartidaEscobaResume(
        partida: _partida,
        nombres: _nombres,
        ajustesIniciales: _ajustes,
        modoDios: widget.modoDios,
      ),
    );
    _pcToken++;
    _salirAlMenu();
  }

  int get _idxManoForzar {
    if (widget.contraPc) {
      return _partida.jugadores.indexWhere((j) => j.nombre != 'PC');
    }
    return _partida.indiceTurno % _partida.jugadores.length;
  }

  Future<void> _abrirForzarCartas() async {
    if (!widget.modoDios || _partida.terminada || _bloquearHumano) return;
    if (_partida.fase != FaseEscoba.jugando) return;

    final cupoMesa = _partida.mesa.length;
    final cupoMano = _manoVisible.mano.length;
    if (cupoMesa == 0 && cupoMano == 0) {
      setState(() => _aviso = 'No hay cartas en mesa ni en mano para forzar.');
      return;
    }

    final resultado = await showDialog<_ForzarCartasResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DialogoForzarCartasEscoba(
        mesaInicial: List.of(_partida.mesa),
        manoInicial: List.of(_manoVisible.mano),
        cupoMesa: cupoMesa,
        cupoMano: cupoMano,
      ),
    );
    if (resultado == null || !mounted) return;

    setState(() {
      _limpiarSeleccion();
      _mensajePc = null;

      final mesaElegidas = List.of(resultado.mesa);
      final manoElegidas = List.of(resultado.mano);

      final mesaFinal = completarCartasEscobaConAzar(
        mesaElegidas,
        cupoMesa,
        ocupadas: {...manoElegidas},
      );
      final manoFinal = completarCartasEscobaConAzar(
        manoElegidas,
        cupoMano,
        ocupadas: {...mesaFinal},
      );

      if (cupoMesa > 0) forzarMesaEscoba(_partida, mesaFinal);
      if (cupoMano > 0) {
        final idx = _idxManoForzar;
        if (idx >= 0) forzarManoEscoba(_partida, idx, manoFinal);
      }
      _aviso = 'Cartas forzadas aplicadas.';
    });
  }

  void _rendirse() {
    if (_partida.terminada || widget.contraPc) return;
    final yo = _partida.jugadorActual.nombre;
    final otros = [
      for (final j in _partida.jugadores)
        if (j.nombre != yo) j.nombre,
    ];
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
      _partida.fase = FaseEscoba.ganado;
      if (otros.isEmpty) {
        _partida.ganador = yo;
        _partida.mensajeFin = '$yo se rindió.';
      } else {
        _partida.ganador = otros.first;
        _partida.mensajeFin =
            '$yo se rindió. ¡${otros.first} gana por abandono!';
      }
    });
  }

  void _abrirCombos(JugadorEscoba jugador) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.carta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HojaCombosJugador(
        jugador: jugador,
        esRondaAnterior: _partida.reiniciarCombosEnProximaJugada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _partida.jugadorActual;
    final mano = _manoVisible;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          _mostrarMenu = true;
                          _confirmarRendicion = false;
                        }),
                        icon: const Icon(Icons.menu, color: AppColors.texto),
                      ),
                      Expanded(
                        child: Center(
                          child: _TituloNombreEditable(
                            etiquetaJuego: 'Escoba',
                            nombre: widget.contraPc
                                ? _manoVisible.nombre
                                : j.nombre,
                            puedeEditar: _indiceRenombrable != null,
                            onEditar: _renombrarDesdeHeader,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _mostrarAjustes = true),
                        icon: const Icon(
                          Icons.settings,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MarcadoresFila(
                    partida: _partida,
                    onVerCartas: _abrirCombos,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _partida.fase == FaseEscoba.finRonda
                        ? 'Fin de ronda'
                        : _pcMostrandoJugada
                            ? '¡Mirá la jugada de la PC!'
                            : _esPcTurno
                                ? 'Turno de la PC…'
                                : !_haySeleccion
                                    ? (_mensajePc != null
                                        ? 'Tu turno · mazo ${_partida.mazo.length}'
                                        : 'Elegí cartas de la mesa y/o de tu mano · mazo ${_partida.mazo.length}')
                                    : 'Suma: $_sumaSeleccion / 15'
                                        '${_puedeCapturar ? ' · ¡listo para capturar!' : _cartaSeleccionada == null ? ' · falta tu carta' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _pcMostrandoJugada || _puedeCapturar
                          ? AppColors.mint
                          : AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: _faltaCartaMano && !_bloquearHumano
                        ? Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.acento.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.acento,
                                width: 1.8,
                              ),
                              boxShadow: neonGlow(AppColors.acento, blur: 10),
                            ),
                            child: const Text(
                              '👆 ¡Debés elegir una carta de tu mano sí o sí!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.acento,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : (_mensajePc != null || _aviso != null)
                            ? Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: _mensajePc != null
                                    ? BoxDecoration(
                                        color: AppColors.rosa
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.rosa,
                                          width: 1.6,
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  _mensajePc ?? _aviso!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _mensajePc != null
                                        ? AppColors.rosa
                                        : (_puedeCapturar
                                            ? AppColors.mint
                                            : AppColors.acento),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pcMostrandoJugada && _mesaSeleccion.isNotEmpty
                              ? 'MESA · PC elige ${_mesaSeleccion.length}'
                              : _mesaSeleccion.isEmpty
                                  ? 'MESA (pozo)'
                                  : 'MESA · ${_mesaSeleccion.length} seleccionada(s)',
                          style: const TextStyle(
                            color: AppColors.azul,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (widget.modoDios)
                        Material(
                          color: AppColors.carta,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: (_partida.terminada ||
                                    _bloquearHumano ||
                                    _partida.fase != FaseEscoba.jugando)
                                ? null
                                : _abrirForzarCartas,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.textoSuave
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.bug_report,
                                size: 20,
                                color: AppColors.textoSuave,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 2,
                    child: _ZonaCartas(
                      cartas: _partida.mesa,
                      seleccionadas: _mesaSeleccion,
                      onTap: (_bloquearHumano ||
                              _partida.fase != FaseEscoba.jugando)
                          ? null
                          : _toggleMesa,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.contraPc)
                    SizedBox(
                      height: 72,
                      child: _pcMostrandoJugada && _cartaSeleccionada != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'LA PC JUEGA CON',
                                  style: TextStyle(
                                    color: AppColors.rosa,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _CartaTexto(
                                  carta: _cartaSeleccionada!,
                                  seleccionada: true,
                                  compacta: true,
                                ),
                              ],
                            )
                          : Center(
                              child: Text(
                                _esPcTurno ? 'PC está eligiendo…' : '',
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                    ),
                  if (widget.contraPc) const SizedBox(height: 8),
                  SizedBox(
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
                                  : _sumaSeleccion == 15
                                      ? 'Tirar (bloqueado)'
                                      : 'Tirar (${_cartaSeleccionada!.valorSuma})',
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
                                  ? 'Capturar ($_sumaSeleccion)'
                                  : 'Capturar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TU MANO · ${mano.nombre}',
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 2,
                    child: _ZonaCartas(
                      cartas: mano.mano,
                      seleccionadas: _bloquearHumano
                          ? const []
                          : [
                              if (_cartaSeleccionada != null)
                                _cartaSeleccionada!,
                            ],
                      onTap: (_bloquearHumano ||
                              _partida.fase != FaseEscoba.jugando)
                          ? null
                          : (c) {
                              unawaited(_seleccionarMano(c));
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarResumenRonda && _partida.ultimoResultado != null)
            Positioned.fill(
              child: ResumenRondaEscobaOverlay(
                resultado: _partida.ultimoResultado!,
                onContinuar: _continuarRonda,
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
              child: MenuPartidaEscoba(
                jugador: widget.contraPc
                    ? _manoVisible.nombre
                    : _partida.jugadorActual.nombre,
                partidaTerminada: _partida.terminada,
                esContraPc: widget.contraPc,
                confirmarRendicion:
                    _confirmarRendicion && !widget.contraPc,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: () {
                  setState(() => _mostrarMenu = false);
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
                          reglasEscobaDel15(),
                          style: const TextStyle(color: AppColors.texto),
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
                },
                onSalirORendirse: _partida.terminada
                    ? () {
                        EscobaStandByStore.limpiar();
                        _salirAlMenu();
                      }
                    : (widget.contraPc
                        ? _salirGuardandoResumeYVolverAlMenu
                        : () => setState(() => _confirmarRendicion = true)),
                onConfirmarRendicion: _rendirse,
                onCancelarRendicion: () =>
                    setState(() => _confirmarRendicion = false),
              ),
            ),
          if (_partida.terminada)
            Positioned.fill(
              child: VictoriaEscobaOverlay(
                partida: _partida,
                animaciones: _ajustes.animaciones,
                onVolverAJugar: _volverAJugar,
                onVolver: () {
                  EscobaStandByStore.limpiar();
                  _salirAlMenu();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TituloNombreEditable extends StatelessWidget {
  const _TituloNombreEditable({
    required this.etiquetaJuego,
    required this.nombre,
    required this.puedeEditar,
    required this.onEditar,
  });

  final String etiquetaJuego;
  final String nombre;
  final bool puedeEditar;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: puedeEditar ? onEditar : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$etiquetaJuego · ',
                        style: const TextStyle(
                          color: AppColors.mint,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: nombre,
                        style: TextStyle(
                          color: puedeEditar
                              ? AppColors.texto
                              : AppColors.mint,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (puedeEditar) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: AppColors.textoSuave.withValues(alpha: 0.9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarcadoresFila extends StatelessWidget {
  const _MarcadoresFila({
    required this.partida,
    required this.onVerCartas,
  });

  final PartidaEscoba partida;
  final ValueChanged<JugadorEscoba> onVerCartas;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < partida.jugadores.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.carta.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: i == partida.indiceTurno % partida.jugadores.length
                      ? AppColors.mint
                      : AppColors.textoSuave.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partida.jugadores[i].nombre,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      MarcadorPalitosEscoba(
                        puntos: partida.jugadores[i].puntos,
                        color: AppColors.acento,
                        tamanoGrupo: 22,
                      ),
                      Text(
                        '${partida.jugadores[i].puntos} pts'
                        '${partida.jugadores[i].escobasRonda > 0 ? ' · ${partida.jugadores[i].escobasRonda} escoba(s)' : ''}',
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.azul.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onVerCartas(partida.jugadores[i]),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.style_rounded,
                              color: AppColors.azul,
                              size: 18,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cartas',
                              style: TextStyle(
                                color: AppColors.azul,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HojaCombosJugador extends StatelessWidget {
  const _HojaCombosJugador({
    required this.jugador,
    required this.esRondaAnterior,
  });

  final JugadorEscoba jugador;
  final bool esRondaAnterior;

  @override
  Widget build(BuildContext context) {
    final n = jugador.combos.length;
    final combos = [
      for (var i = n - 1; i >= 0; i--) jugador.combos[i],
    ];
    final maxH = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textoSuave.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cartas de ${jugador.nombre}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                esRondaAnterior
                    ? 'Última ronda · orden #n → #1 (★ = escoba)'
                    : 'Orden #n → #1 · la más reciente arriba (★ = escoba)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: combos.isEmpty
                    ? const Center(
                        child: Text(
                          'Todavía no agarró ningún combo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: combos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final combo = combos[i];
                          final numero = n - i;
                          final esUltima = i == 0;
                          final titulo = combo.esPozoFinal
                              ? 'Pozo final'
                              : (combo.escoba ? 'Escoba' : 'Captura');
                          final colorMarca = combo.escoba
                              ? AppColors.acento
                              : (esUltima ? AppColors.mint : AppColors.azul);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorMarca.withValues(alpha: 0.75),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      combo.escoba
                                          ? '#$numero ★'
                                          : '#$numero',
                                      style: TextStyle(
                                        color: colorMarca,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: const TextStyle(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (esUltima)
                                      const Text(
                                        'más reciente',
                                        style: TextStyle(
                                          color: AppColors.mint,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  combo.resumen,
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonaCartas extends StatelessWidget {
  const _ZonaCartas({
    required this.cartas,
    this.seleccionadas = const [],
    this.onTap,
  });

  final List<CartaEscoba> cartas;
  final List<CartaEscoba> seleccionadas;
  final ValueChanged<CartaEscoba>? onTap;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return Center(
        child: Text(
          '— vacía —',
          style: TextStyle(
            color: AppColors.textoSuave.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final c in cartas)
            _CartaTexto(
              carta: c,
              seleccionada: seleccionadas.contains(c),
              onTap: onTap == null ? null : () => onTap!(c),
            ),
        ],
      ),
    );
  }
}

class _CartaTexto extends StatelessWidget {
  const _CartaTexto({
    required this.carta,
    required this.seleccionada,
    this.onTap,
    this.compacta = false,
  });

  final CartaEscoba carta;
  final bool seleccionada;
  final VoidCallback? onTap;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final accent = carta.esOro ? AppColors.acento : AppColors.azul;
    final padH = compacta ? 10.0 : 12.0;
    final padV = compacta ? 8.0 : 14.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          constraints: BoxConstraints(
            minWidth: compacta ? 84 : 96,
            minHeight: compacta ? 44 : 56,
          ),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionada ? AppColors.mint : accent,
              width: seleccionada ? 2.4 : 1.4,
            ),
            boxShadow: seleccionada ? neonGlow(AppColors.mint, blur: 10) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                carta.etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: compacta ? 12 : 13,
                ),
              ),
              SizedBox(height: compacta ? 1 : 2),
              Text(
                'vale ${carta.valorSuma}',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: compacta ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForzarCartasResult {
  const _ForzarCartasResult({
    required this.mesa,
    required this.mano,
  });

  final List<CartaEscoba> mesa;
  final List<CartaEscoba> mano;
}

enum _ModoForzarCartas { mesa, mano }

class _DialogoForzarCartasEscoba extends StatefulWidget {
  const _DialogoForzarCartasEscoba({
    required this.mesaInicial,
    required this.manoInicial,
    required this.cupoMesa,
    required this.cupoMano,
  });

  final List<CartaEscoba> mesaInicial;
  final List<CartaEscoba> manoInicial;
  final int cupoMesa;
  final int cupoMano;

  @override
  State<_DialogoForzarCartasEscoba> createState() =>
      _DialogoForzarCartasEscobaState();
}

class _DialogoForzarCartasEscobaState extends State<_DialogoForzarCartasEscoba> {
  late final List<CartaEscoba> _todas;
  late List<CartaEscoba> _mesa;
  late List<CartaEscoba> _mano;
  late _ModoForzarCartas _modo;

  int get _cupoMesa => widget.cupoMesa;
  int get _cupoMano => widget.cupoMano;

  @override
  void initState() {
    super.initState();
    _todas = crearMazoEscoba()
      ..sort((a, b) {
        final p = a.palo.index.compareTo(b.palo.index);
        if (p != 0) return p;
        return a.numero.compareTo(b.numero);
      });
    _mesa = List.of(widget.mesaInicial.take(_cupoMesa));
    _mano = List.of(widget.manoInicial.take(_cupoMano));
    _modo = _cupoMesa > 0
        ? _ModoForzarCartas.mesa
        : _ModoForzarCartas.mano;
  }

  bool _enMesa(CartaEscoba c) => _mesa.contains(c);
  bool _enMano(CartaEscoba c) => _mano.contains(c);

  void _toggle(CartaEscoba c) {
    setState(() {
      if (_modo == _ModoForzarCartas.mesa) {
        if (_cupoMesa <= 0) return;
        if (_enMesa(c)) {
          _mesa.remove(c);
          return;
        }
        if (_enMano(c)) _mano.remove(c);
        if (_mesa.length >= _cupoMesa) return;
        _mesa.add(c);
      } else {
        if (_cupoMano <= 0) return;
        if (_enMano(c)) {
          _mano.remove(c);
          return;
        }
        if (_enMesa(c)) _mesa.remove(c);
        if (_mano.length >= _cupoMano) return;
        _mano.add(c);
      }
    });
  }

  Color _bordeCarta(CartaEscoba c) {
    if (_enMesa(c)) return AppColors.azul;
    if (_enMano(c)) return AppColors.mint;
    return AppColors.textoSuave.withValues(alpha: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      backgroundColor: AppColors.carta,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              const Text(
                '🎯 Forzar cartas',
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _modo == _ModoForzarCartas.mesa
                    ? 'Modo mesa: elegí hasta $_cupoMesa '
                        '(si faltan, se completan al azar)'
                    : 'Modo mano: elegí hasta $_cupoMano '
                        '(si faltan, se completan al azar)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.textoSuave.withValues(alpha: 0.25),
                          ),
                        ),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 110,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: _todas.length,
                          itemBuilder: (context, i) {
                            final c = _todas[i];
                            final sel = _enMesa(c) || _enMano(c);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggle(c),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.carta,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _bordeCarta(c),
                                      width: sel ? 2.2 : 1.2,
                                    ),
                                    boxShadow: sel
                                        ? neonGlow(_bordeCarta(c), blur: 8)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        c.etiqueta,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'vale ${c.valorSuma}',
                                        style: TextStyle(
                                          color: AppColors.textoSuave
                                              .withValues(alpha: 0.95),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (_enMesa(c))
                                        const Text(
                                          'MESA',
                                          style: TextStyle(
                                            color: AppColors.azul,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                          ),
                                        ),
                                      if (_enMano(c))
                                        const Text(
                                          'MANO',
                                          style: TextStyle(
                                            color: AppColors.mint,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 132,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_cupoMesa > 0) ...[
                            _BotonModoForzar(
                              label: 'Tirar en\nla mesa',
                              sublabel: '${_mesa.length}/$_cupoMesa',
                              color: AppColors.azul,
                              activo: _modo == _ModoForzarCartas.mesa,
                              onTap: () => setState(
                                () => _modo = _ModoForzarCartas.mesa,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_cupoMano > 0)
                            _BotonModoForzar(
                              label: 'Mano',
                              sublabel: '${_mano.length}/$_cupoMano',
                              color: AppColors.mint,
                              activo: _modo == _ModoForzarCartas.mano,
                              onTap: () => setState(
                                () => _modo = _ModoForzarCartas.mano,
                              ),
                            ),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.acento,
                              foregroundColor: const Color(0xFF1A0A00),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(
                                _ForzarCartasResult(
                                  mesa: List.of(_mesa),
                                  mano: List.of(_mano),
                                ),
                              );
                            },
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonModoForzar extends StatelessWidget {
  const _BotonModoForzar({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: activo
                ? color.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activo ? color : color.withValues(alpha: 0.45),
              width: activo ? 2.2 : 1.3,
            ),
            boxShadow: activo ? neonGlow(color, blur: 10) : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sublabel,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
