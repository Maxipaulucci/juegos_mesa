import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class LobbySalaScreen extends StatefulWidget {
  const LobbySalaScreen({
    super.key,
    required this.sala,
    required this.miId,
    required this.onIniciarPartida,
    this.mostrarSelectorDados = true,
  });

  final Sala sala;
  final String miId;
  final void Function(BuildContext context, List<String> nombres, int dados)
      onIniciarPartida;
  final bool mostrarSelectorDados;

  @override
  State<LobbySalaScreen> createState() => _LobbySalaScreenState();
}

class _LobbySalaScreenState extends State<LobbySalaScreen> {
  bool _mostrarCodigo = false;
  int _dados = 5;

  bool get _soyAnfitrion => widget.miId == widget.sala.anfitrionId;

  void _expulsar(JugadorSala j) {
    setState(() {
      SalaService.instance.expulsar(widget.sala, j.id);
    });
  }

  void _copiarCodigo() {
    Clipboard.setData(ClipboardData(text: widget.sala.codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  void _iniciar() {
    if (widget.sala.jugadores.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hacen falta al menos 2 jugadores')),
      );
      return;
    }
    final nombres = widget.sala.jugadores.map((j) => j.nombre).toList();
    final dados = widget.mostrarSelectorDados ? _dados : 5;
    widget.onIniciarPartida(context, nombres, dados);
  }

  @override
  Widget build(BuildContext context) {
    final codigoVisible = _mostrarCodigo
        ? widget.sala.codigo
        : '*' * widget.sala.codigo.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    codigoVisible,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.acento,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _mostrarCodigo ? 'Ocultar' : 'Mostrar',
                  onPressed: () =>
                      setState(() => _mostrarCodigo = !_mostrarCodigo),
                  icon: Icon(
                    _mostrarCodigo ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.texto,
                  ),
                ),
                if (_mostrarCodigo)
                  IconButton(
                    tooltip: 'Copiar',
                    onPressed: _copiarCodigo,
                    icon: const Icon(Icons.copy, color: AppColors.texto),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _soyAnfitrion
                  ? 'Sos el anfitrión. Compartí el código cuando quieras.'
                  : 'Esperando que el anfitrión inicie la partida…',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            if (_soyAnfitrion && widget.mostrarSelectorDados) ...[
              const SizedBox(height: 20),
              const Text('Modo', style: TextStyle(color: AppColors.textoSuave)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 5, label: Text('5 dados')),
                  ButtonSegment(value: 6, label: Text('6 dados')),
                ],
                selected: {_dados},
                onSelectionChanged: (s) => setState(() => _dados = s.first),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Jugadores (${widget.sala.jugadores.length})',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: widget.sala.jugadores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final j = widget.sala.jugadores[i];
                  final esHost = j.id == widget.sala.anfitrionId;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.carta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            esHost ? '${j.nombre} (anfitrión)' : j.nombre,
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_soyAnfitrion && !esHost)
                          IconButton(
                            tooltip: 'Expulsar',
                            onPressed: () => _expulsar(j),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.peligro,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_soyAnfitrion)
              ElevatedButton(
                onPressed: _iniciar,
                child: const Text('Iniciar partida'),
              )
            else
              const Text(
                'Nota: las salas todavía son locales (mismo dispositivo). '
                'El online llega cuando conectemos Firebase/Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
