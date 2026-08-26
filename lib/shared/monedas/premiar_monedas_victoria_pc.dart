import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';

/// Al montarse premia victoria vs PC y/o resuelve apuesta online.
class PremiarMonedasVictoriaPc extends StatefulWidget {
  const PremiarMonedasVictoriaPc({
    super.key,
    required this.aplicar,
    required this.child,
    this.juegoId,
    this.aplicarOnline = false,
    this.salaCodigo,
  });

  /// Victoria local vs PC.
  final bool aplicar;
  final String? juegoId;
  /// Gané la partida online (para cobrar el pozo).
  final bool aplicarOnline;
  final String? salaCodigo;
  final Widget child;

  @override
  State<PremiarMonedasVictoriaPc> createState() =>
      _PremiarMonedasVictoriaPcState();
}

class _PremiarMonedasVictoriaPcState extends State<PremiarMonedasVictoriaPc> {
  @override
  void initState() {
    super.initState();
    if (widget.aplicar) {
      unawaited(
        MonedasStore.instance.premiarVictoriaPcSiCorresponde(
          contraPc: true,
          online: false,
          ganoHumano: true,
          juegoId: widget.juegoId,
        ),
      );
    }
    if (widget.aplicarOnline) {
      unawaited(
        MonedasStore.instance.resolverApuestaOnlineSiGane(
          online: true,
          ganeYo: true,
          salaCodigo: widget.salaCodigo,
          juegoId: widget.juegoId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
