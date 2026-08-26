import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';

/// Al montarse, si [aplicar] es true, pide +3 monedas (una sola vez).
class PremiarMonedasVictoriaPc extends StatefulWidget {
  const PremiarMonedasVictoriaPc({
    super.key,
    required this.aplicar,
    required this.child,
  });

  final bool aplicar;
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
