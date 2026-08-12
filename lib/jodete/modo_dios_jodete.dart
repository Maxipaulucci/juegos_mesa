import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class ForzarCartasJodeteResult {
  const ForzarCartasJodeteResult({
    required this.mano,
    this.pozo,
  });

  final List<CartaJodete> mano;
  final CartaJodete? pozo;
}

/// Diálogo Modo Dios: pozo (cima) + mano, estilo Escoba del 15.
Future<ForzarCartasJodeteResult?> mostrarForzarCartasJodete({
  required BuildContext context,
  required List<CartaJodete> disponibles,
  required List<CartaJodete> manoInicial,
  CartaJodete? pozoInicial,
}) {
  return showDialog<ForzarCartasJodeteResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DialogoForzarCartasJodete(
      disponibles: disponibles,
      manoInicial: manoInicial,
      pozoInicial: pozoInicial,
    ),
  );
}

enum _ModoForzarJodete { pozo, mano }

PaloEspanolVisual _paloVisual(PaloJodete p) => switch (p) {
      PaloJodete.oro => PaloEspanolVisual.oro,
      PaloJodete.copa => PaloEspanolVisual.copa,
      PaloJodete.espada => PaloEspanolVisual.espada,
      PaloJodete.basto => PaloEspanolVisual.basto,
    };

class _DialogoForzarCartasJodete extends StatefulWidget {
  const _DialogoForzarCartasJodete({
    required this.disponibles,
    required this.manoInicial,
    this.pozoInicial,
  });

  final List<CartaJodete> disponibles;
  final List<CartaJodete> manoInicial;
  final CartaJodete? pozoInicial;

  @override
  State<_DialogoForzarCartasJodete> createState() =>
      _DialogoForzarCartasJodeteState();
}

class _DialogoForzarCartasJodeteState extends State<_DialogoForzarCartasJodete> {
  late final List<CartaJodete> _todas;
  late List<CartaJodete> _mano;
  CartaJodete? _pozo;
  late _ModoForzarJodete _modo;

  @override
  void initState() {
    super.initState();
    _todas = List.of(widget.disponibles);
    final ids = {for (final c in _todas) c.id};
    _pozo = widget.pozoInicial != null && ids.contains(widget.pozoInicial!.id)
        ? widget.pozoInicial
        : null;
    _mano = [
      for (final c in widget.manoInicial)
        if (ids.contains(c.id) && c != _pozo) c,
    ];
    _modo = _pozo != null ? _ModoForzarJodete.pozo : _ModoForzarJodete.mano;
  }

  bool _enPozo(CartaJodete c) => _pozo == c;
  bool _enMano(CartaJodete c) => _mano.contains(c);

  void _toggle(CartaJodete c) {
    setState(() {
      if (_enPozo(c) || _enMano(c)) {
        if (_enPozo(c)) _pozo = null;
        _mano.remove(c);
        return;
      }
      if (_modo == _ModoForzarJodete.pozo) {
        _pozo = c;
        _mano.remove(c);
      } else {
        _mano.add(c);
      }
    });
  }

  Color _colorPalo(PaloJodete palo) => colorPaloEspanol(_paloVisual(palo));

  String _tituloPalo(PaloJodete palo) => switch (palo) {
        PaloJodete.oro => 'Oros',
        PaloJodete.copa => 'Copas',
        PaloJodete.espada => 'Espadas',
        PaloJodete.basto => 'Bastos',
      };

  Widget _celdaCarta(CartaJodete c) {
    final sel = _enPozo(c) || _enMano(c);
    final zona = _enPozo(c) ? 'POZO' : (_enMano(c) ? 'MANO' : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(c),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.esComodin)
              _ComodinMini(seleccionada: sel)
            else
              CartaEspanolaSkin(
                numero: c.numero!,
                etiqueta: c.etiqueta,
                palo: _paloVisual(c.palo!),
                seleccionada: sel,
                width: 64,
                height: 100,
              ),
            if (zona != null) ...[
              const SizedBox(height: 2),
              Text(
                zona,
                style: TextStyle(
                  color: _enPozo(c) ? AppColors.azul : AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contenedorGrupo({
    required String titulo,
    required Color color,
    required List<CartaJodete> cartas,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (cartas.isEmpty)
            Text(
              'Sin cartas disponibles',
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 78,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.55,
              ),
              itemCount: cartas.length,
              itemBuilder: (context, i) => _celdaCarta(cartas[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final porPalo = <PaloJodete, List<CartaJodete>>{
      for (final palo in PaloJodete.values)
        palo: [for (final c in _todas) if (!c.esComodin && c.palo == palo) c],
    };
    final comodines = [for (final c in _todas) if (c.esComodin) c];

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
                _modo == _ModoForzarJodete.pozo
                    ? 'Modo pozo: elegí 1 carta (la cima del pozo)'
                    : 'Modo mano: elegí las cartas que quieras',
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
                      child: ListView(
                        padding: const EdgeInsets.only(right: 4),
                        children: [
                          for (final palo in PaloJodete.values)
                            _contenedorGrupo(
                              titulo: _tituloPalo(palo),
                              color: _colorPalo(palo),
                              cartas: porPalo[palo]!,
                            ),
                          if (comodines.isNotEmpty)
                            _contenedorGrupo(
                              titulo: 'Comodines',
                              color: AppColors.acento,
                              cartas: comodines,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 132,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BotonModoForzarJodete(
                            label: 'Pozo',
                            sublabel: '${_pozo == null ? 0 : 1}/1',
                            color: AppColors.azul,
                            activo: _modo == _ModoForzarJodete.pozo,
                            onTap: () => setState(
                              () => _modo = _ModoForzarJodete.pozo,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _BotonModoForzarJodete(
                            label: 'Mano',
                            sublabel: '${_mano.length}',
                            color: AppColors.mint,
                            activo: _modo == _ModoForzarJodete.mano,
                            onTap: () => setState(
                              () => _modo = _ModoForzarJodete.mano,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(
                              ForzarCartasJodeteResult(
                                mano: List.of(_mano),
                                pozo: _pozo,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.acento,
                              foregroundColor: const Color(0xFF1A0A00),
                              minimumSize: const Size.fromHeight(48),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.peligro,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
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

class _BotonModoForzarJodete extends StatelessWidget {
  const _BotonModoForzarJodete({
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
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: activo
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Material(
        color: activo
            ? color.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: activo ? color : color.withValues(alpha: 0.45),
                width: activo ? 2.2 : 1.3,
              ),
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
      ),
    );
  }
}

class _ComodinMini extends StatelessWidget {
  const _ComodinMini({required this.seleccionada});

  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A1B9A), Color(0xFF1A0A33)],
        ),
        border: Border.all(
          color: seleccionada ? colorSeleccionCartaEspanola : AppColors.acento,
          width: seleccionada ? 2.4 : 2,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, color: AppColors.acento, size: 26),
          SizedBox(height: 4),
          Text(
            'Comodín',
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
