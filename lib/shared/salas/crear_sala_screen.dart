import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/salas/lobby_sala_screen.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class CrearSalaScreen extends StatefulWidget {
  const CrearSalaScreen({
    super.key,
    required this.juegoId,
    required this.onIniciarPartida,
    this.mostrarSelectorDados = true,
    this.editarCategorias = false,
  });

  final String juegoId;
  final void Function(BuildContext context, InicioPartidaOnline inicio)
      onIniciarPartida;
  final bool mostrarSelectorDados;
  final bool editarCategorias;

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  late final TextEditingController _nombreCtrl;
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: SalaFormStore.nombre);
    _nombreCtrl.addListener(() => SalaFormStore.nombre = _nombreCtrl.text);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribí tu nombre.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // El código lo genera el servidor (alfanumérico aleatorio).
      final result = await SalaService.instance.crear(
        juegoId: widget.juegoId,
        nombreAnfitrion: nombre,
      );
      SalaFormStore.limpiarCodigo();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(
            salaInicial: result.sala,
            miId: result.miId,
            onIniciarPartida: widget.onIniciarPartida,
            mostrarSelectorDados: widget.mostrarSelectorDados,
            editarCategorias: widget.editarCategorias,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tu nombre',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nombreCtrl,
              enabled: !_cargando,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ej: Maxi'),
            ),
            const SizedBox(height: 16),
            Text(
              'Al crear la sala se genera un código aleatorio de 6 letras y números. '
              'Lo vas a ver en el lobby para compartirlo. '
              'El código se borra sola 1 hora después de iniciar la partida.',
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.95),
                height: 1.35,
                fontSize: 13,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.peligro)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _cargando ? null : _crear,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear sala'),
            ),
          ],
        ),
      ),
    );
  }
}
