import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class LobbySalaScreen extends StatefulWidget {
  const LobbySalaScreen({
    super.key,
    required this.salaInicial,
    required this.miId,
    required this.onIniciarPartida,
    this.mostrarSelectorDados = true,
  });

  final Sala salaInicial;
  final String miId;
  final void Function(BuildContext context, InicioPartidaOnline inicio)
      onIniciarPartida;
  final bool mostrarSelectorDados;

  @override
  State<LobbySalaScreen> createState() => _LobbySalaScreenState();
}

class _LobbySalaScreenState extends State<LobbySalaScreen> {
  late Sala _sala;
  bool _mostrarCodigo = true;
  late int _dados;
  bool _iniciando = false;
  bool _partidaLanzada = false;
  StreamSubscription<Sala>? _sub;

  bool get _soyAnfitrion => widget.miId == _sala.anfitrionId;

  @override
  void initState() {
    super.initState();
    _sala = widget.salaInicial;
    _dados = _sala.dados;
    _sub = SalaService.instance.watch(_sala.codigo).listen(_onSalaUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onSalaUpdate(Sala sala) {
    if (!mounted || _partidaLanzada) return;

    final sigoAdentro = sala.jugadores.any((j) => j.id == widget.miId);
    if (!sigoAdentro) {
      _sub?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Te han expulsado de la partida con el código ${sala.codigo}.',
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _sala = sala;
      if (!_soyAnfitrion) _dados = sala.dados;
    });
    if (sala.iniciada) {
      _lanzarPartida(sala);
    }
  }

  void _lanzarPartida(Sala sala) {
    if (_partidaLanzada || !mounted) return;
    _partidaLanzada = true;
    _sub?.cancel();
    final yo = sala.jugadores.where((j) => j.id == widget.miId);
    final miNombre = yo.isNotEmpty ? yo.first.nombre : sala.jugadores.first.nombre;
    widget.onIniciarPartida(
      context,
      InicioPartidaOnline(
        nombres: sala.jugadores.map((j) => j.nombre).toList(),
        dados: sala.dados,
        salaCodigo: sala.codigo,
        miNombre: miNombre,
      ),
    );
  }

  Future<void> _expulsar(JugadorSala j) async {
    try {
      final sala = await SalaService.instance.expulsar(
        codigo: _sala.codigo,
        anfitrionId: widget.miId,
        jugadorId: j.id,
      );
      if (!mounted) return;
      setState(() => _sala = sala);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _copiarCodigo() {
    Clipboard.setData(ClipboardData(text: _sala.codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  Future<void> _iniciar() async {
    if (_sala.jugadores.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hacen falta al menos 2 jugadores')),
      );
      return;
    }
    setState(() => _iniciando = true);
    try {
      final sala = await SalaService.instance.iniciar(
        codigo: _sala.codigo,
        anfitrionId: widget.miId,
        dados: widget.mostrarSelectorDados ? _dados : 5,
      );
      if (!mounted) return;
      _lanzarPartida(sala);
    } catch (e) {
      if (!mounted) return;
      setState(() => _iniciando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final codigoVisible =
        _mostrarCodigo ? _sala.codigo : '*' * _sala.codigo.length;

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
                onSelectionChanged: _iniciando
                    ? null
                    : (s) => setState(() => _dados = s.first),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Jugadores (${_sala.jugadores.length})',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _sala.jugadores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final j = _sala.jugadores[i];
                  final esHost = j.id == _sala.anfitrionId;
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
                onPressed: _iniciando ? null : _iniciar,
                child: _iniciando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Iniciar partida'),
              )
            else
              const Text(
                'Cuando el anfitrión inicie, la partida arranca sola acá.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
