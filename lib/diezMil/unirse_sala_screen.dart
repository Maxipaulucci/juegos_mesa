import 'package:flutter/material.dart';

import '../services/sala_service.dart';
import '../theme/app_theme.dart';
import 'lobby_sala_screen.dart';

class UnirseSalaScreen extends StatefulWidget {
  const UnirseSalaScreen({super.key, required this.juegoId});

  final String juegoId;

  @override
  State<UnirseSalaScreen> createState() => _UnirseSalaScreenState();
}

class _UnirseSalaScreenState extends State<UnirseSalaScreen> {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _unirse() {
    final nombre = _nombreCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribí tu nombre.');
      return;
    }
    if (codigo.isEmpty) {
      setState(() => _error = 'Ingresá el código de la sala.');
      return;
    }

    try {
      final sala = SalaService.instance.unirse(codigo: codigo, nombre: nombre);
      if (sala.juegoId != widget.juegoId) {
        setState(() => _error = 'Esa sala es de otro juego.');
        return;
      }
      final yo = sala.jugadores.last;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(sala: sala, miId: yo.id),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a sala')),
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
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ej: Sofía'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Código de la sala',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codigoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Ej: AB12CD'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.peligro)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _unirse,
              child: const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }
}
