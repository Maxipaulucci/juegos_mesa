import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/chanchoVa/victoria_chancho_va_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/partida_ui/cambio_jugador_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida de Chancho va (local / vs PC).
class PartidaChanchoVaScreen extends StatefulWidget {
  const PartidaChanchoVaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final PartidaChanchoResume? resume;

  @override
  State<PartidaChanchoVaScreen> createState() => _PartidaChanchoVaScreenState();
}

class _PartidaChanchoVaScreenState extends State<PartidaChanchoVaScreen> {
  late PartidaChancho _partida;
  final Set<int> _numerosElegidos = {};
  int? _cantidadAnuncio;
  DireccionChancho? _direccionAnuncio;
  final List<CartaChancho> _seleccionLocal = [];
  bool _cambioPendiente = false;
  String? _nombreVista;
  int _pcToken = 0;
  /// Tras PC abre Chancho, el humano puede decir aunque no tenga cuarteto.
  bool _chanchoVisiblePorCarrera = false;

  bool get _esLocalHotSeat => !widget.contraPc;

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  JugadorChancho get _yo {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre != TextosChancho.vsPcNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    final nombre = _nombreVista ?? _partida.jugadorActual.nombre;
    return _partida.jugadores.firstWhere(
      (j) => j.nombre == nombre,
      orElse: () => _partida.jugadorActual,
    );
  }

  JugadorChancho? get _pc {
    if (!widget.contraPc) return null;
    for (final j in _partida.jugadores) {
      if (j.nombre == TextosChancho.vsPcNombre) return j;
    }
    return null;
  }

  bool get _esTurnoHumanoAnuncio {
    if (_partida.terminada) return false;
    if (_partida.fase != FaseChancho.anunciando) return false;
    if (_cambioPendiente) return false;
    if (widget.contraPc) {
      return _partida.jugadorActual.nombre != TextosChancho.vsPcNombre;
    }
    return _yo.nombre == _partida.jugadorActual.nombre;
  }

  bool get _puedoElegirCartas {
    if (_partida.fase != FaseChancho.eligiendoCartas) return false;
    if (_cambioPendiente) return false;
    if (_yo.seleccionPaseConfirmada) return false;
    return true;
  }

  bool get _mostrarBotonChancho {
    if (_partida.terminada) return false;
    if (_partida.fase == FaseChancho.eligiendoNumeros ||
        _partida.fase == FaseChancho.eligiendoCartas) {
      return false;
    }
    if (_yo.dijoChancho) return false;
    if (_yo.tieneCuarteto) return true;
    if (_chanchoVisiblePorCarrera && _partida.quienAbrioChancho != null) {
      return true;
    }
    return false;
  }

  bool get _chanchoHabilitado =>
      _mostrarBotonChancho &&
      (_yo.tieneCuarteto || _partida.quienAbrioChancho != null);

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_cambioPendiente) return '';
    return switch (_partida.fase) {
      FaseChancho.eligiendoNumeros => TextosChancho.eligeNumeros,
      FaseChancho.anunciando => _esTurnoHumanoAnuncio
          ? TextosChancho.anunciando
          : (widget.contraPc
              ? TextosChancho.esperandoPc
              : 'Turno de ${_partida.jugadorActual.nombre}'),
      FaseChancho.eligiendoCartas => _yo.seleccionPaseConfirmada
          ? 'Esperando al resto…'
          : TextosChancho.eligiendoCartas,
      FaseChancho.carreraChancho => TextosChancho.carrera,
      FaseChancho.terminada => '',
    };
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
      _nombreVista = widget.contraPc
          ? _yo.nombre
          : _partida.jugadorActual.nombre;
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
      return;
    }
    _partida = nuevaPartidaChancho(
      nombres: widget.nombres,
      contraPc: widget.contraPc,
    );
    _nombreVista = _partida.jugadorActual.nombre;
    if (_esLocalHotSeat) {
      _cambioPendiente = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_partida.fase == FaseChancho.eligiendoNumeros) {
        _abrirCartelNumeros();
      } else {
        _talVezPc();
      }
    });
  }

  @override
  void dispose() {
    _pcToken++;
    super.dispose();
  }

  void _pedirCambioSiCorresponde(String paraQuien) {
    if (!_esLocalHotSeat || _partida.terminada) return;
    if (_nombreVista == paraQuien && !_cambioPendiente) return;
    setState(() {
      _cambioPendiente = true;
      _nombreVista = paraQuien;
      _seleccionLocal.clear();
    });
  }

  void _aceptarCambio() {
    setState(() {
      _cambioPendiente = false;
      _nombreVista = _partida.fase == FaseChancho.anunciando
          ? _partida.jugadorActual.nombre
          : (_nombreVista ?? _partida.jugadorActual.nombre);
    });
    _talVezPc();
  }

  Future<void> _abrirCartelNumeros() async {
    if (_partida.fase != FaseChancho.eligiendoNumeros) return;
    if (_esLocalHotSeat && _cambioPendiente) return;

    final elegidos = <int>{};
    final cupo = _partida.cantidadJugadores;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              backgroundColor: AppColors.carta,
              title: Text(
                '${TextosChancho.eligeNumeros} ($cupo)',
                style: const TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in numerosChanchoDisponibles)
                      FilterChip(
                        label: Text('$n'),
                        selected: elegidos.contains(n),
                        onSelected: (sel) {
                          setDialog(() {
                            if (sel) {
                              if (elegidos.length >= cupo) return;
                              elegidos.add(n);
                            } else {
                              elegidos.remove(n);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: elegidos.length == cupo
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text(TextosChancho.confirmarNumeros),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    final err = aplicarNumerosElegidosChancho(
      _partida,
      elegidos.toList(),
    );
    setState(() {
      _numerosElegidos
        ..clear()
        ..addAll(elegidos);
      _seleccionLocal.clear();
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esLocalHotSeat) {
      _pedirCambioSiCorresponde(_partida.jugadorActual.nombre);
    } else {
      _talVezPc();
    }
  }

  void _cicloCantidad() {
    if (!_esTurnoHumanoAnuncio) return;
    setState(() {
      final actual = _cantidadAnuncio ?? 0;
      _cantidadAnuncio = actual >= 4 ? 1 : actual + 1;
    });
  }

  void _cicloDireccion() {
    if (!_esTurnoHumanoAnuncio) return;
    setState(() {
      final dirs = DireccionChancho.values;
      final i = _direccionAnuncio == null
          ? -1
          : dirs.indexOf(_direccionAnuncio!);
      _direccionAnuncio = dirs[(i + 1) % dirs.length];
    });
  }

  void _confirmarAnuncio() {
    if (!_esTurnoHumanoAnuncio) return;
    final c = _cantidadAnuncio;
    final d = _direccionAnuncio;
    if (c == null || d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí número y dirección')),
      );
      return;
    }
    final err = anunciarPaseChancho(
      _partida,
      cantidad: c,
      direccion: d,
      anunciante: _yo,
    );
    setState(() => _seleccionLocal.clear());
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _despuesDeAnuncio();
  }

  void _repetirAnuncio() {
    if (!_esTurnoHumanoAnuncio) return;
    final err = repetirUltimoAnuncioChancho(_partida, anunciante: _yo);
    setState(() {
      _seleccionLocal.clear();
      if (_partida.ultimoAnuncio != null) {
        _cantidadAnuncio = _partida.ultimoAnuncio!.cantidad;
        _direccionAnuncio = _partida.ultimoAnuncio!.direccion;
      }
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _despuesDeAnuncio();
  }

  void _despuesDeAnuncio() {
    if (widget.contraPc) {
      _autoConfirmarPcSiCorresponde();
      setState(() {});
      return;
    }
    // Hot-seat: cada jugador elige cartas → handoff al primero que no confirmó.
    final siguiente = _partida.jugadores.firstWhere(
      (j) => !j.seleccionPaseConfirmada,
      orElse: () => _partida.jugadorActual,
    );
    _pedirCambioSiCorresponde(siguiente.nombre);
  }

  void _toggleCarta(CartaChancho c) {
    if (!_puedoElegirCartas) return;
    final cupo = _partida.anuncioActual?.cantidad ?? 0;
    setState(() {
      if (_seleccionLocal.contains(c)) {
        _seleccionLocal.remove(c);
      } else {
        if (_seleccionLocal.length >= cupo) return;
        _seleccionLocal.add(c);
      }
    });
  }

  void _confirmarCartasLocal() {
    if (!_puedoElegirCartas) return;
    final err = confirmarSeleccionPaseChancho(
      _partida,
      jugador: _yo,
      cartas: List.of(_seleccionLocal),
    );
    setState(() => _seleccionLocal.clear());
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_partida.fase == FaseChancho.eligiendoCartas) {
      final siguiente = _partida.jugadores.firstWhere(
        (j) => !j.seleccionPaseConfirmada,
        orElse: () => _yo,
      );
      if (_esLocalHotSeat) {
        _pedirCambioSiCorresponde(siguiente.nombre);
      }
    } else {
      // Pase ejecutado.
      _chanchoVisiblePorCarrera = false;
      _despuesDePase();
    }
  }

  void _despuesDePase() {
    setState(() {});
    if (_partida.terminada) return;
    if (widget.contraPc) {
      _talVezChanchoPc();
      if (_partida.fase == FaseChancho.anunciando) {
        _talVezPc();
      }
      return;
    }
    if (_esLocalHotSeat) {
      _pedirCambioSiCorresponde(_partida.jugadorActual.nombre);
    }
  }

  void _decirChancho() {
    if (!_chanchoHabilitado) return;
    final err = decirChanchoVa(_partida, jugador: _yo);
    setState(() {});
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_partida.fase == FaseChancho.carreraChancho) {
      _chanchoVisiblePorCarrera = true;
      _talVezChanchoPc();
    } else {
      // Carrera resuelta (nueva ronda o fin).
      _chanchoVisiblePorCarrera = false;
      if (!_partida.terminada && _esLocalHotSeat) {
        _pedirCambioSiCorresponde(_partida.jugadorActual.nombre);
      } else if (!_partida.terminada) {
        _talVezPc();
      }
    }
  }

  Future<void> _talVezPc() async {
    if (!widget.contraPc || _partida.terminada) return;
    final token = ++_pcToken;

    if (_partida.fase == FaseChancho.eligiendoNumeros) {
      // Humano elige números aunque sea vs PC (primer jugador).
      return;
    }

    if (_partida.fase == FaseChancho.anunciando &&
        _partida.jugadorActual.nombre == TextosChancho.vsPcNombre) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || token != _pcToken) return;
      final pc = _pc;
      if (pc == null) return;
      final anuncio = planificarAnuncioPcChancho(pc, _partida.ultimoAnuncio);
      anunciarPaseChancho(
        _partida,
        cantidad: anuncio.cantidad,
        direccion: anuncio.direccion,
        anunciante: pc,
      );
      setState(() {
        _cantidadAnuncio = anuncio.cantidad;
        _direccionAnuncio = anuncio.direccion;
      });
      _autoConfirmarPcSiCorresponde();
      // Humano debe elegir cartas.
      setState(() {});
      return;
    }

    if (_partida.fase == FaseChancho.eligiendoCartas) {
      _autoConfirmarPcSiCorresponde();
    }

    _talVezChanchoPc();
  }

  void _autoConfirmarPcSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.fase != FaseChancho.eligiendoCartas) return;
    final pc = _pc;
    final anuncio = _partida.anuncioActual;
    if (pc == null || anuncio == null || pc.seleccionPaseConfirmada) return;
    final cartas = elegirCartasPcChancho(pc, anuncio.cantidad);
    confirmarSeleccionPaseChancho(
      _partida,
      jugador: pc,
      cartas: cartas,
    );
    if (_partida.fase != FaseChancho.eligiendoCartas) {
      _chanchoVisiblePorCarrera = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _despuesDePase();
      });
    }
  }

  Future<void> _talVezChanchoPc() async {
    if (!widget.contraPc || _partida.terminada) return;
    final pc = _pc;
    if (pc == null || pc.dijoChancho) return;
    if (!pcDeberiaDecirChancho(_partida, pc)) return;

    final token = ++_pcToken;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted || token != _pcToken) return;
    if (_partida.terminada || pc.dijoChancho) return;
    if (!pcDeberiaDecirChancho(_partida, pc)) return;

    final abrio = _partida.quienAbrioChancho == null;
    decirChanchoVa(_partida, jugador: pc);
    setState(() {
      // Si la PC abrió, el humano ve el botón aunque no tenga cuarteto.
      if (abrio || _partida.quienAbrioChancho != null) {
        _chanchoVisiblePorCarrera = true;
      }
    });

    if (_partida.fase == FaseChancho.anunciando || _partida.terminada) {
      _chanchoVisiblePorCarrera = false;
      if (!_partida.terminada) _talVezPc();
    }
  }

  void _reiniciar() {
    ChanchoStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaChancho(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
      _numerosElegidos.clear();
      _cantidadAnuncio = null;
      _direccionAnuncio = null;
      _seleccionLocal.clear();
      _chanchoVisiblePorCarrera = false;
      _nombreVista = _partida.jugadorActual.nombre;
      _cambioPendiente = _esLocalHotSeat;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cambioPendiente) return;
      _abrirCartelNumeros();
    });
  }

  void _salir({required bool guardar}) {
    _pcToken++;
    if (guardar && widget.contraPc && !_partida.terminada) {
      ChanchoStandByStore.guardar(
        PartidaChanchoResume(
          partida: _partida,
          nombres: widget.nombres,
          modoDios: widget.modoDios,
        ),
      );
    } else {
      ChanchoStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  PaloEspanolVisual _paloVisual(PaloChancho p) => switch (p) {
        PaloChancho.oro => PaloEspanolVisual.oro,
        PaloChancho.copa => PaloEspanolVisual.copa,
        PaloChancho.espada => PaloEspanolVisual.espada,
        PaloChancho.basto => PaloEspanolVisual.basto,
      };

  String _labelDir(DireccionChancho? d) => switch (d) {
        null => TextosChancho.direccion,
        DireccionChancho.izquierda => TextosChancho.izquierda,
        DireccionChancho.derecha => TextosChancho.derecha,
        DireccionChancho.centro => TextosChancho.centro,
      };

  @override
  Widget build(BuildContext context) {
    final mano = _cambioPendiente ? const <CartaChancho>[] : _yo.mano;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _salir(guardar: widget.contraPc && !_partida.terminada);
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            const Positioned.fill(
              child: EpicBackdrop(centerY: 0.45, fadeRayosAlCentro: true),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _salir(
                            guardar: widget.contraPc && !_partida.terminada,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.texto,
                        ),
                        const Expanded(
                          child: Text(
                            TextosChancho.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
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
                                    TextosChancho.reglas(),
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
                          },
                          icon: const Icon(Icons.help_outline_rounded),
                          color: AppColors.textoSuave,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _MarcadorLetras(jugadores: _partida.jugadores),
                    if (_modoDiosActivo && _pc != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'PC: ${_pc!.mano.map((c) => c.etiqueta).join(' · ')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (_textoEstado.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _textoEstado,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${TextosChancho.tuMano}: ${_yo.nombre}',
                      style: const TextStyle(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 130,
                      child: _cambioPendiente
                          ? const SizedBox.shrink()
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: mano.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final c = mano[i];
                                final sel = _seleccionLocal.contains(c);
                                return GestureDetector(
                                  onTap: _puedoElegirCartas
                                      ? () => _toggleCarta(c)
                                      : null,
                                  child: CartaEspanolaSkin(
                                    numero: c.numero,
                                    etiqueta: c.etiqueta,
                                    palo: _paloVisual(c.palo),
                                    seleccionada: sel,
                                    width: 78,
                                    height: 118,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonAccion(
                            label: _cantidadAnuncio == null
                                ? TextosChancho.numero
                                : '${TextosChancho.numero}: $_cantidadAnuncio',
                            onPressed:
                                _esTurnoHumanoAnuncio ? _cicloCantidad : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotonAccion(
                            label: _labelDir(_direccionAnuncio),
                            onPressed:
                                _esTurnoHumanoAnuncio ? _cicloDireccion : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotonAccion(
                            label: TextosChancho.repetir,
                            onPressed:
                                _esTurnoHumanoAnuncio ? _repetirAnuncio : null,
                          ),
                        ),
                      ],
                    ),
                    if (_esTurnoHumanoAnuncio) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _cantidadAnuncio != null &&
                                  _direccionAnuncio != null
                              ? _confirmarAnuncio
                              : null,
                          child: const Text('Anunciar pase'),
                        ),
                      ),
                    ],
                    if (_puedoElegirCartas) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _seleccionLocal.length ==
                                  (_partida.anuncioActual?.cantidad ?? -1)
                              ? _confirmarCartasLocal
                              : null,
                          child: Text(
                            '${TextosChancho.confirmarPase}'
                            ' (${_seleccionLocal.length}'
                            '/${_partida.anuncioActual?.cantidad ?? 0})',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _chanchoHabilitado ? _decirChancho : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _chanchoHabilitado
                              ? AppColors.peligro
                              : AppColors.carta,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.5),
                        ),
                        child: const Text(
                          TextosChancho.chancho,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_esLocalHotSeat && _cambioPendiente && !_partida.terminada)
              Positioned.fill(
                child: CambioJugadorOverlay(
                  nombreJugador: _nombreVista ?? _partida.jugadorActual.nombre,
                  onAceptar: () {
                    _aceptarCambio();
                    if (_partida.fase == FaseChancho.eligiendoNumeros) {
                      _abrirCartelNumeros();
                    }
                  },
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaChanchoOverlay(
                  partida: _partida,
                  onVolverAJugar: _reiniciar,
                  onVolver: () => _salir(guardar: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarcadorLetras extends StatelessWidget {
  const _MarcadorLetras({required this.jugadores});

  final List<JugadorChancho> jugadores;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < jugadores.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.violeta),
              ),
              child: Column(
                children: [
                  Text(
                    jugadores[i].nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jugadores[i].letrasTexto,
                    style: const TextStyle(
                      color: AppColors.acento,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
