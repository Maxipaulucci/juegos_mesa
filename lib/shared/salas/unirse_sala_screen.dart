import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/monedas/apuesta_online_store.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/salas/cartel_config_sala.dart';
import 'package:app_juegos_mesa/shared/salas/lobby_sala_screen.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class UnirseSalaScreen extends StatefulWidget {
  const UnirseSalaScreen({
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
  State<UnirseSalaScreen> createState() => _UnirseSalaScreenState();
}

class _UnirseSalaScreenState extends State<UnirseSalaScreen> {
  late final TextEditingController _codigoCtrl;
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

  int get _misMonedas => MonedasStore.instance.monedas;

  @override
  void initState() {
    super.initState();
    _codigoCtrl = TextEditingController(text: SalaFormStore.codigo);
    _codigoCtrl.addListener(() => SalaFormStore.codigo = _codigoCtrl.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!UsuarioMongoService.instance.haySesion || _nombreUsuario == null) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final nombre = _nombreUsuario;
    final codigo = _codigoCtrl.text.trim();
    if (nombre == null || nombre.isEmpty) {
      setState(() => _error = 'Iniciá sesión para unirte a una sala.');
      return;
    }
    if (codigo.isEmpty) {
      setState(() => _error = 'Ingresá el código de la sala.');
      return;
    }
    if (codigo.length != 6) {
      setState(() => _error = 'El código debe tener exactamente 6 caracteres.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(codigo)) {
      setState(() => _error = 'El código solo puede tener letras y números.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final preview = await SalaService.instance.obtener(codigo);
      if (!mounted) return;
      if (preview.estado != 'lobby') {
        throw StateError('La partida ya empezó.');
      }
      if (preview.juegoId != widget.juegoId) {
        throw StateError('Esa sala es de otro juego.');
      }

      final apuesta = preview.apuestaMonedas;
      if (apuesta > 0 && _misMonedas < apuesta) {
        throw StateError(
          'Necesitás $apuesta monedas para esta apuesta (tenés $_misMonedas).',
        );
      }

      setState(() => _cargando = false);
      final aceptar = await mostrarCartelConfigSalaOnline(
        context: context,
        resumen: preview.lobbyOpcionesResumen,
        apuestaMonedas: apuesta,
      );
      if (!aceptar || !mounted) return;

      setState(() => _cargando = true);

      if (apuesta > 0) {
        await UsuarioMongoService.instance.retenerApuesta(
          codigoSala: preview.codigo,
          monto: apuesta,
          juegoId: widget.juegoId,
        );
      }

      try {
        final result = await SalaService.instance.unirse(
          codigo: codigo,
          nombre: nombre,
          juegoId: widget.juegoId,
        );
        ApuestaOnlineStore.configurar(
          codigo: result.sala.codigo,
          juego: widget.juegoId,
          apuesta: apuesta,
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
        if (apuesta > 0) {
          try {
            await UsuarioMongoService.instance.reembolsarApuesta(
              codigoSala: preview.codigo,
            );
          } catch (_) {}
        }
        rethrow;
      }
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
      appBar: AppBar(title: const Text('Unirse a sala')),
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
              'Tenés $_misMonedas monedas. Si la sala tiene apuesta, '
              'se te retienen al unirte.',
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.95),
                height: 1.35,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Código de la sala',
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
              onPressed: _cargando ? null : _unirse,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }
}
