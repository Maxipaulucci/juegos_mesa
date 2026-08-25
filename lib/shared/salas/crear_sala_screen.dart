import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
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
    this.humanosExactosParaIniciar,
    this.textoAyudaHumanos,
  });

  final String juegoId;
  final void Function(BuildContext context, InicioPartidaOnline inicio)
      onIniciarPartida;
  final bool mostrarSelectorDados;
  final bool editarCategorias;
  final int? humanosExactosParaIniciar;
  final String? textoAyudaHumanos;

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  String? _error;
  bool _cargando = false;

  String? get _nombreUsuario {
    final u = UsuarioMongoService.instance.usuario;
    if (u == null) return null;
    final nick = u.nombreUsuario.trim();
    if (nick.isNotEmpty) return nick;
    final nombre = u.nombre.trim();
    return nombre.isEmpty ? null : nombre;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!UsuarioMongoService.instance.haySesion || _nombreUsuario == null) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _crear() async {
    final nombre = _nombreUsuario;
    if (nombre == null || nombre.isEmpty) {
      setState(() => _error = 'Iniciá sesión para crear una sala.');
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
        lobbyOpcionesResumen: SalaFormStore.lobbyOpcionesResumen,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LobbySalaScreen(
            salaInicial: result.sala,
            miId: result.miId,
            onIniciarPartida: widget.onIniciarPartida,
            mostrarSelectorDados: widget.mostrarSelectorDados,
            editarCategorias: widget.editarCategorias,
            humanosExactosParaIniciar: widget.humanosExactosParaIniciar,
            textoAyudaHumanos: widget.textoAyudaHumanos,
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
    final nombre = _nombreUsuario ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tu usuario',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.carta,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cartaBorde),
              ),
              child: Text(
                nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'En partidas online jugás con tu nombre de usuario. No se puede cambiar.',
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.95),
                height: 1.35,
                fontSize: 13,
              ),
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
