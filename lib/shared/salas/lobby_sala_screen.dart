import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class LobbySalaScreen extends StatefulWidget {
  const LobbySalaScreen({
    super.key,
    required this.salaInicial,
    required this.miId,
    required this.onIniciarPartida,
    this.mostrarSelectorDados = true,
    this.editarCategorias = false,
    /// Si no es null, solo se puede iniciar con exactamente esa cantidad de humanos.
    this.humanosExactosParaIniciar,
    this.textoAyudaHumanos,
  });

  final Sala salaInicial;
  final String miId;
  final void Function(BuildContext context, InicioPartidaOnline inicio)
      onIniciarPartida;
  final bool mostrarSelectorDados;
  /// Tutti Frutti: anfitrión define 3–6 categorías antes de iniciar.
  final bool editarCategorias;
  final int? humanosExactosParaIniciar;
  final String? textoAyudaHumanos;

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
  final List<TextEditingController> _catCtrls = [];
  int _maxRondas = 5;
  Timer? _lobbySyncDebounce;
  bool _publicandoLobby = false;

  bool get _soyAnfitrion => widget.miId == _sala.anfitrionId;

  static const int _maxRondasAbecedario = 26; // A–Z

  bool get _puedeAgregarCategoria {
    if (_catCtrls.isEmpty || _catCtrls.length >= 6) return false;
    return _catCtrls.last.text.trim().isNotEmpty;
  }

  void _onCatChanged() {
    if (!mounted) return;
    setState(() {});
    _programarSyncLobby();
  }

  void _programarSyncLobby() {
    if (!_soyAnfitrion || !widget.editarCategorias) return;
    _lobbySyncDebounce?.cancel();
    _lobbySyncDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_publicarLobbyConfig());
    });
  }

  Future<void> _publicarLobbyConfig() async {
    if (!_soyAnfitrion || !widget.editarCategorias || _publicandoLobby) return;
    _publicandoLobby = true;
    try {
      final cats = _catCtrls.map((c) => c.text.trim()).toList();
      final sala = await SalaService.instance.actualizarLobby(
        codigo: _sala.codigo,
        anfitrionId: widget.miId,
        categorias: cats,
        maxRondas: _maxRondas,
      );
      if (mounted) setState(() => _sala = sala);
    } catch (_) {
      // Red momentánea: el próximo cambio reintenta.
    } finally {
      _publicandoLobby = false;
    }
  }

  TextEditingController _nuevaCatCtrl([String texto = '']) {
    final c = TextEditingController(text: texto);
    c.addListener(_onCatChanged);
    return c;
  }

  @override
  void initState() {
    super.initState();
    _sala = widget.salaInicial;
    _dados = _sala.dados;
    if (widget.editarCategorias) {
      if (_soyAnfitrion) {
        final iniciales = _sala.lobbyCategorias.isNotEmpty
            ? _sala.lobbyCategorias
            : const ['Nombre', 'Animal', 'Color'];
        _catCtrls.addAll([for (final t in iniciales) _nuevaCatCtrl(t)]);
        _maxRondas = (_sala.lobbyMaxRondas ?? 5).clamp(1, _maxRondasAbecedario);
        // Publicar config inicial para que los invitados la vean.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_publicarLobbyConfig());
        });
      }
    }
    _sub = SalaService.instance.watch(_sala.codigo).listen(_onSalaUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lobbySyncDebounce?.cancel();
    for (final c in _catCtrls) {
      c.removeListener(_onCatChanged);
      c.dispose();
    }
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
    // Chancho va: el seed incluye humanos + PCs en gameState.jugadores.
    var nombres = sala.jugadores.map((j) => j.nombre).toList();
    final gs = sala.gameState;
    if (sala.juegoId == 'chanchoVa' && gs != null) {
      final jgs = gs['jugadores'];
      if (jgs is List && jgs.length >= 3) {
        final mesa = <String>[];
        for (final item in jgs) {
          if (item is! Map) continue;
          final n = Map<String, dynamic>.from(item)['nombre']?.toString();
          if (n != null && n.isNotEmpty) mesa.add(n);
        }
        if (mesa.length >= 3) nombres = mesa;
      }
    }
    widget.onIniciarPartida(
      context,
      InicioPartidaOnline(
        nombres: nombres,
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
    final exactos = widget.humanosExactosParaIniciar;
    if (exactos != null && _sala.jugadores.length != exactos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.textoAyudaHumanos ??
                'Hacen falta exactamente $exactos jugadores.',
          ),
        ),
      );
      return;
    }
    if (_sala.jugadores.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hacen falta al menos 2 jugadores')),
      );
      return;
    }

    List<String>? categorias;
    int? maxRondas;
    if (widget.editarCategorias) {
      categorias = _catCtrls
          .map((c) => c.text.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (categorias.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mínimo 3 categorías.')),
        );
        return;
      }
      if (categorias.length > 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 6 categorías.')),
        );
        return;
      }
      for (final c in categorias) {
        if (c.length > 25) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cada categoría: máx. 25 caracteres.'),
            ),
          );
          return;
        }
      }
      if (_maxRondas < 1 || _maxRondas > _maxRondasAbecedario) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rondas: entre 1 y $_maxRondasAbecedario.',
            ),
          ),
        );
        return;
      }
      maxRondas = _maxRondas;
    }

    setState(() => _iniciando = true);
    try {
      final sala = await SalaService.instance.iniciar(
        codigo: _sala.codigo,
        anfitrionId: widget.miId,
        dados: widget.mostrarSelectorDados ? _dados : 5,
        categorias: categorias,
        maxRondas: maxRondas,
        opcionesPapa: SalaFormStore.opcionesPapa,
        opcionesChancho: SalaFormStore.opcionesChancho,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Sala')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Deja aire arriba del teclado para ver el campo enfocado.
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset * 0.15),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
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
                        onPressed: () => setState(
                          () => _mostrarCodigo = !_mostrarCodigo,
                        ),
                  icon: Icon(
                          _mostrarCodigo
                              ? Icons.visibility_off
                              : Icons.visibility,
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
                    const Text(
                      'Modo',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
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
                  if (widget.editarCategorias) ...[
                    const SizedBox(height: 20),
                    Text(
                      _soyAnfitrion
                          ? 'Categorías (3–6, máx. 25 caracteres)'
                          : 'Categorías',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_soyAnfitrion) ...[
                      for (var i = 0; i < _catCtrls.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _catCtrls[i],
                                maxLength: 25,
                                enabled: !_iniciando,
                                textInputAction: i < _catCtrls.length - 1
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                scrollPadding: const EdgeInsets.only(
                                  top: 80,
                                  bottom: 140,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Categoría ${i + 1}',
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.carta,
                                ),
                              ),
                            ),
                            if (_catCtrls.length > 3)
                              IconButton(
                                tooltip: 'Quitar',
                                onPressed: _iniciando
                                    ? null
                                    : () {
                                        setState(() {
                                          final c = _catCtrls.removeAt(i);
                                          c.removeListener(_onCatChanged);
                                          c.dispose();
                                        });
                                        _programarSyncLobby();
                                      },
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.peligro,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (_catCtrls.length < 6) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              (_iniciando || !_puedeAgregarCategoria)
                                  ? null
                                  : () => setState(() {
                                        _catCtrls.add(_nuevaCatCtrl());
                                      }),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar categoría'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Rondas (máx. $_maxRondasAbecedario)',
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _iniciando || _maxRondas <= 1
                                ? null
                                : () {
                                    setState(() => _maxRondas--);
                                    _programarSyncLobby();
                                  },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.texto,
                          ),
                          Expanded(
                            child: Text(
                              '$_maxRondas',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.acento,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _iniciando ||
                                    _maxRondas >= _maxRondasAbecedario
                                ? null
                                : () {
                                    setState(() => _maxRondas++);
                                    _programarSyncLobby();
                                  },
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.texto,
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_sala.lobbyCategorias.isEmpty)
                        const Text(
                          'Esperando que el anfitrión defina las categorías…',
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontSize: 13,
                          ),
                        )
                      else
                        for (var i = 0;
                            i < _sala.lobbyCategorias.length;
                            i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.carta,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _sala.lobbyCategorias[i],
                              style: const TextStyle(
                                color: AppColors.texto,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      const SizedBox(height: 16),
                      const Text(
                        'Rondas',
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_sala.lobbyMaxRondas ?? '—'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ],
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
                  for (var i = 0; i < _sala.jugadores.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
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
                                  esHost
                                      ? '${j.nombre} (anfitrión)'
                                      : j.nombre,
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
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _soyAnfitrion
                  ? ElevatedButton(
                      onPressed: _iniciando ? null : _iniciar,
                      child: _iniciando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Iniciar partida'),
                    )
                  : const Text(
                      'Cuando el anfitrión inicie, la partida arranca sola acá.',
                textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
