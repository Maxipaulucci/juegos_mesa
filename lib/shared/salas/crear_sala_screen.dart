import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/salas/lobby_sala_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class CrearSalaScreen extends StatefulWidget {
  const CrearSalaScreen({
    super.key,
    required this.juegoId,
    required this.onIniciarPartida,
    this.mostrarSelectorDados = true,
  });

  final String juegoId;
  final void Function(BuildContext context, InicioPartidaOnline inicio)
      onIniciarPartida;
  final bool mostrarSelectorDados;

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String? _error;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  static final _codigoPermitido = RegExp(r'^[a-zA-Z0-9]{6}$');

  String? _validarCodigo(String codigo) {
    if (codigo.isEmpty) {
      return 'El código debe tener 6 caracteres.';
    }
    if (codigo.length != 6) {
      return 'El código debe tener exactamente 6 caracteres.';
    }
    if (!_codigoPermitido.hasMatch(codigo)) {
      return 'El código solo puede tener letras y números.';
    }
    return null;
  }

  Future<void> _crear() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribí tu nombre.');
      return;
    }

    final codigo = _codigoCtrl.text.trim();
    final errorCodigo = _validarCodigo(codigo);
    if (errorCodigo != null) {
      setState(() => _error = errorCodigo);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final result = await SalaService.instance.crear(
        juegoId: widget.juegoId,
        nombreAnfitrion: nombre,
        codigoPreferido: codigo,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(
            salaInicial: result.sala,
            miId: result.miId,
            onIniciarPartida: widget.onIniciarPartida,
            mostrarSelectorDados: widget.mostrarSelectorDados,
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
            const SizedBox(height: 20),
            const Text(
              'Código / contraseña de la sala',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codigoCtrl,
              enabled: !_cargando,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: const InputDecoration(
                hintText: 'Exactamente 6 letras o números',
                counterText: '',
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
