import 'package:flutter/material.dart';

import '../services/sala_service.dart';
import '../theme/app_theme.dart';
import 'lobby_sala_screen.dart';

class CrearSalaScreen extends StatefulWidget {
  const CrearSalaScreen({super.key, required this.juegoId});

  final String juegoId;

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _crear() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribí tu nombre.');
      return;
    }

    try {
      final sala = SalaService.instance.crear(
        juegoId: widget.juegoId,
        nombreAnfitrion: nombre,
        codigoPreferido: _codigoCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(
            sala: sala,
            miId: sala.anfitrionId,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
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
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ej: Maxi'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Código / contraseña de la sala',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codigoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Dejalo vacío para generar uno',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.peligro)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _crear,
              child: const Text('Crear sala'),
            ),
          ],
        ),
      ),
    );
  }
}
