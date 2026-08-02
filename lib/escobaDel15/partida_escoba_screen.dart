import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/textos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Partida de Escoba del 15 (cartas en texto crudo, sin skin).
class PartidaEscobaScreen extends StatefulWidget {
  const PartidaEscobaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.dificultadPc,
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
  });

  final List<String> nombres;
  final bool contraPc;
  final DificultadPc? dificultadPc;
  final String? salaCodigo;
  final String? miNombre;
  final AjustesEstado? ajustesIniciales;

  @override
  State<PartidaEscobaScreen> createState() => _PartidaEscobaScreenState();
}

class _PartidaEscobaScreenState extends State<PartidaEscobaScreen> {
  late PartidaEscoba _partida;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarSalir = false;
  String? _aviso;
  CartaEscoba? _cartaSeleccionada;
  final List<CartaEscoba> _mesaSeleccion = [];

  bool get _esPcTurno {
    if (!widget.contraPc) return false;
    return _partida.jugadorActual.nombre == 'PC';
  }

  @override
  void initState() {
    super.initState();
    _ajustes = widget.ajustesIniciales ?? const AjustesEstado();
    _partida = nuevaPartidaEscoba(nombres: widget.nombres);
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  void _talVezPc() {
    if (!mounted || !_esPcTurno || _partida.terminada) return;
    if (_partida.fase == FaseEscoba.finRonda) return;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_esPcTurno) return;
      setState(() {
        jugarTurnoPcEscoba(_partida);
        _cartaSeleccionada = null;
        _mesaSeleccion.clear();
        _aviso = null;
      });
      if (_partida.fase == FaseEscoba.jugando) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
      }
    });
  }

  Future<void> _jugarCarta(CartaEscoba carta) async {
    if (_partida.fase != FaseEscoba.jugando || _esPcTurno) return;
    final caps = capturasPosiblesEscoba(carta, _partida.mesa);
    if (caps.isEmpty) {
      setState(() {
        _aviso = jugarCartaEscoba(_partida, carta);
        _cartaSeleccionada = null;
        _mesaSeleccion.clear();
      });
      _talVezPc();
      return;
    }
    if (caps.length == 1) {
      setState(() {
        _aviso = jugarCartaEscoba(
          _partida,
          carta,
          mesaElegida: caps.first,
        );
        _cartaSeleccionada = null;
        _mesaSeleccion.clear();
      });
      _talVezPc();
      return;
    }
    // Varias capturas: seleccionar cartas de mesa.
    setState(() {
      _cartaSeleccionada = carta;
      _mesaSeleccion.clear();
      _aviso = 'Elegí las cartas de la mesa que suman 15 con ${carta.etiqueta}';
    });
  }

  void _toggleMesa(CartaEscoba c) {
    if (_cartaSeleccionada == null) return;
    setState(() {
      if (_mesaSeleccion.contains(c)) {
        _mesaSeleccion.remove(c);
      } else {
        _mesaSeleccion.add(c);
      }
    });
  }

  void _confirmarCaptura() {
    final carta = _cartaSeleccionada;
    if (carta == null) return;
    final err = jugarCartaEscoba(
      _partida,
      carta,
      mesaElegida: List.of(_mesaSeleccion),
    );
    setState(() {
      _aviso = err;
      if (err == null) {
        _cartaSeleccionada = null;
        _mesaSeleccion.clear();
      }
    });
    if (err == null) _talVezPc();
  }

  void _continuarRonda() {
    setState(() {
      siguienteRondaEscoba(_partida);
      _aviso = null;
      _cartaSeleccionada = null;
      _mesaSeleccion.clear();
    });
    _talVezPc();
  }

  void _salirAlMenu() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _partida.jugadorActual;

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
                          _confirmarSalir = false;
                        }),
                        icon: const Icon(Icons.menu, color: AppColors.texto),
                      ),
                      Expanded(
                        child: Text(
                          'Escoba · ${j.nombre}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
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
                  _MarcadoresFila(partida: _partida),
                  const SizedBox(height: 8),
                  Text(
                    _partida.fase == FaseEscoba.finRonda
                        ? 'Fin de ronda'
                        : _esPcTurno
                            ? 'Turno de la PC…'
                            : 'Jugá una carta · mesa ${ _partida.mesa.length} · mazo ${_partida.mazo.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (_aviso != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _aviso!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'MESA',
                    style: TextStyle(
                      color: AppColors.azul,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 2,
                    child: _ZonaCartas(
                      cartas: _partida.mesa,
                      seleccionadas: _mesaSeleccion,
                      onTap: _cartaSeleccionada == null ? null : _toggleMesa,
                    ),
                  ),
                  if (_cartaSeleccionada != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _cartaSeleccionada = null;
                              _mesaSeleccion.clear();
                              _aviso = null;
                            }),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _mesaSeleccion.isEmpty
                                ? null
                                : _confirmarCaptura,
                            child: const Text('Capturar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'TU MANO · ${j.nombre}',
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
                      cartas: j.mano,
                      seleccionadas: [
                        if (_cartaSeleccionada != null) _cartaSeleccionada!,
                      ],
                      onTap: (_esPcTurno ||
                              _partida.fase != FaseEscoba.jugando)
                          ? null
                          : (c) {
                              if (_cartaSeleccionada != null) return;
                              unawaited(_jugarCarta(c));
                            },
                      atenuar: _esPcTurno,
                    ),
                  ),
                  if (_partida.fase == FaseEscoba.finRonda) ...[
                    const SizedBox(height: 10),
                    if (_partida.ultimoResultado != null)
                      _ResumenRonda(
                        partida: _partida,
                        resultado: _partida.ultimoResultado!,
                      ),
                    const SizedBox(height: 8),
                    GlowButtonVictoria(
                      label: 'SIGUIENTE RONDA',
                      icon: Icons.replay,
                      color: AppColors.azul,
                      onPressed: _continuarRonda,
                    ),
                  ],
                ],
              ),
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
              child: _MenuPartidaEscoba(
                confirmarSalir: _confirmarSalir,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarSalir = false;
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
                onSalir: () => setState(() => _confirmarSalir = true),
                onConfirmarSalir: _salirAlMenu,
                onCancelarSalir: () =>
                    setState(() => _confirmarSalir = false),
              ),
            ),
          if (_partida.terminada)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¡${_partida.ganador ?? 'Alguien'} gana!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.acento,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _partida.mensajeFin ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textoSuave),
                        ),
                        const SizedBox(height: 20),
                        GlowButtonVictoria(
                          label: 'VOLVER AL MENÚ',
                          icon: Icons.home,
                          color: AppColors.violeta,
                          onPressed: _salirAlMenu,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResumenRonda extends StatelessWidget {
  const _ResumenRonda({
    required this.partida,
    required this.resultado,
  });

  final PartidaEscoba partida;
  final ResultadoRondaEscoba resultado;

  String? _nombre(int? idx) =>
      idx == null ? null : partida.jugadores[idx].nombre;

  @override
  Widget build(BuildContext context) {
    final lineas = <String>[];
    for (var i = 0; i < partida.jugadores.length; i++) {
      final e = resultado.puntosEscobas[i];
      if (e > 0) {
        lineas.add('${partida.jugadores[i].nombre}: +$e por escoba(s)');
      }
    }
    if (_nombre(resultado.idxMasCartas) case final n?) {
      lineas.add('$n: +1 más cartas');
    }
    if (_nombre(resultado.idxMasOros) case final n?) {
      lineas.add('$n: +1 más oros');
    }
    if (_nombre(resultado.idxSieteOro) case final n?) {
      lineas.add('$n: +1 por el 7 de oro');
    }
    if (_nombre(resultado.idxMasSietes) case final n?) {
      lineas.add('$n: +1 más sietes');
    }
    if (lineas.isEmpty) {
      lineas.add('Nadie sumó puntos extra en esta ronda.');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.azul.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Puntos de la ronda',
            style: TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '· $l',
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarcadoresFila extends StatelessWidget {
  const _MarcadoresFila({required this.partida});

  final PartidaEscoba partida;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < partida.jugadores.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.carta.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: i == partida.indiceTurno % partida.jugadores.length
                      ? AppColors.mint
                      : AppColors.textoSuave.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
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
            ),
          ],
        ],
      ),
    );
  }
}

class _ZonaCartas extends StatelessWidget {
  const _ZonaCartas({
    required this.cartas,
    this.seleccionadas = const [],
    this.onTap,
    this.atenuar = false,
  });

  final List<CartaEscoba> cartas;
  final List<CartaEscoba> seleccionadas;
  final ValueChanged<CartaEscoba>? onTap;
  final bool atenuar;

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
    return Opacity(
      opacity: atenuar ? 0.55 : 1,
      child: SingleChildScrollView(
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
      ),
    );
  }
}

class _CartaTexto extends StatelessWidget {
  const _CartaTexto({
    required this.carta,
    required this.seleccionada,
    this.onTap,
  });

  final CartaEscoba carta;
  final bool seleccionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = carta.esOro ? AppColors.acento : AppColors.azul;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          constraints: const BoxConstraints(minWidth: 96, minHeight: 56),
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
            children: [
              Text(
                carta.etiqueta,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'vale ${carta.valorSuma}',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPartidaEscoba extends StatelessWidget {
  const _MenuPartidaEscoba({
    required this.confirmarSalir,
    required this.onCerrar,
    required this.onReglas,
    required this.onSalir,
    required this.onConfirmarSalir,
    required this.onCancelarSalir,
  });

  final bool confirmarSalir;
  final VoidCallback onCerrar;
  final VoidCallback onReglas;
  final VoidCallback onSalir;
  final VoidCallback onConfirmarSalir;
  final VoidCallback onCancelarSalir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.azul, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Menú',
                      style: TextStyle(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCerrar,
                    icon: const Icon(Icons.close, color: AppColors.texto),
                  ),
                ],
              ),
              if (!confirmarSalir) ...[
                ListTile(
                  leading: const Icon(Icons.menu_book, color: AppColors.azul),
                  title: const Text('Reglas'),
                  onTap: onReglas,
                ),
                ListTile(
                  leading:
                      const Icon(Icons.exit_to_app, color: AppColors.peligro),
                  title: const Text('Salir al menú'),
                  onTap: onSalir,
                ),
              ] else ...[
                const Text(
                  '¿Salir de la partida?',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancelarSalir,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onConfirmarSalir,
                        child: const Text('Salir'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
