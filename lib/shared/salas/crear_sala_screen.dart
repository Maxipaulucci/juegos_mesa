import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/shared/monedas/apuesta_online_store.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
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
  int _apuesta = 0;
  /// true = aparece en Salas; false = solo con código.
  bool _publica = true;

  String? get _nombreUsuario {
    final u = UsuarioMongoService.instance.usuario;
    if (u == null) return null;
    final nick = u.nombreUsuario.trim();
    if (nick.isNotEmpty) return nick;
    final nombre = u.nombre.trim();
    return nombre.isEmpty ? null : nombre;
  }

  int get _misMonedas => MonedasStore.instance.monedas;

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
    if (_apuesta > 0 && _misMonedas < _apuesta) {
      setState(() => _error = 'No te alcanzan las monedas para esa apuesta.');
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
        apuestaMonedas: _apuesta,
        publica: _publica,
      );
      if (_apuesta > 0) {
        try {
          await UsuarioMongoService.instance.retenerApuesta(
            codigoSala: result.sala.codigo,
            monto: _apuesta,
            juegoId: widget.juegoId,
          );
        } catch (e) {
          try {
            await SalaService.instance.cerrar(
              codigo: result.sala.codigo,
              anfitrionId: result.miId,
            );
          } catch (_) {}
          rethrow;
        }
      }
      ApuestaOnlineStore.configurar(
        codigo: result.sala.codigo,
        juego: widget.juegoId,
        apuesta: _apuesta,
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
              'Tenés ${formatoNumero(_misMonedas)} monedas.',
              style: TextStyle(
                color: AppColors.acento.withValues(alpha: 0.95),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Visibilidad',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Pública'),
                  selected: _publica,
                  onSelected: _cargando
                      ? null
                      : (_) => setState(() => _publica = true),
                  selectedColor: AppColors.azul.withValues(alpha: 0.4),
                  labelStyle: TextStyle(
                    color: _publica ? AppColors.texto : AppColors.textoSuave,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Privada'),
                  selected: !_publica,
                  onSelected: _cargando
                      ? null
                      : (_) => setState(() => _publica = false),
                  selectedColor: AppColors.violeta.withValues(alpha: 0.4),
                  labelStyle: TextStyle(
                    color: !_publica ? AppColors.texto : AppColors.textoSuave,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _publica
                  ? 'Aparece en la sección Salas: cualquiera puede unirse desde ahí sin código.'
                  : 'No aparece en Salas. Solo se une quien tenga el código.',
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.95),
                height: 1.35,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Apuesta (cada jugador)',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in montosApuestaOnline)
                  ChoiceChip(
                    label: Text(m == 0 ? 'Sin apuesta' : formatoNumero(m)),
                    selected: _apuesta == m,
                    onSelected: _cargando
                        ? null
                        : (_) => setState(() => _apuesta = m),
                    selectedColor: AppColors.acento.withValues(alpha: 0.35),
                    labelStyle: TextStyle(
                      color: _apuesta == m
                          ? AppColors.texto
                          : AppColors.textoSuave,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            if (_apuesta > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Cada jugador apuesta ${formatoNumero(_apuesta)}. El ganador se lleva el pozo '
                '(suma de todas las apuestas) en monedas y esa misma cantidad '
                'suma al ranking.',
                style: TextStyle(
                  color: AppColors.textoSuave.withValues(alpha: 0.95),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
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
                  : Text(
                      _apuesta > 0
                          ? 'Crear sala · apostar ${formatoNumero(_apuesta)}'
                          : 'Crear sala',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
