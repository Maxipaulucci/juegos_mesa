import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc_ui.dart';
import 'package:app_juegos_mesa/shared/menu/opcion_toggle.dart';
import 'package:app_juegos_mesa/shared/orden/decidir_orden_screen.dart';
import 'package:app_juegos_mesa/shared/salas/crear_sala_screen.dart';
import 'package:app_juegos_mesa/shared/salas/unirse_sala_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Estado actual del menú al lanzar una partida.
class MenuJuegoEstado {
  const MenuJuegoEstado({
    required this.ajustes,
    required this.modoDios,
    required this.decidirOrden,
    required this.dificultad,
    required this.nombres,
  });

  final AjustesEstado ajustes;
  final bool modoDios;
  final bool decidirOrden;
  final DificultadPc dificultad;
  final List<String> nombres;
}

/// Menú compartido post-home: salas, partida rápida, vs PC.
class MenuJuegoScreen extends StatefulWidget {
  const MenuJuegoScreen({
    super.key,
    required this.titulo,
    required this.juegoId,
    required this.modosDados,
    required this.onPartidaRapida,
    required this.onVsPc,
    required this.onIniciarDesdeSala,
    this.mostrarDificultad = false,
    /// Si true, la sección "vs PC" se muestra como "Jugar solo".
    this.jugarSoloEnLugarDePc = false,
    /// Si true (con [jugarSoloEnLugarDePc]), muestra Modo Dios al lado de "Jugar solo".
    this.mostrarModoDiosEnSolo = false,
    /// Texto del diálogo de ayuda de Modo Dios (si null, usa el genérico de dados).
    this.textoInfoModoDios,
    /// Contenido extra debajo de Jugar solo / vs PC (p. ej. Modificar partida).
    this.extraTrasModoLocal,
  });

  static const juegoIdDiezMil = 'diezMil';
  static const juegoIdGenerala = 'generala';
  static const juegoIdLaPapa = 'laPapa';
  static const juegoIdEscobaDel15 = 'escobaDel15';
  static const juegoIdUnoSolo = 'unoSolo';
  static const juegoIdCuloSucioV1 = 'culoSucioV1';

  final String titulo;
  final String juegoId;
  /// Cantidades de dados ofrecidas (ej. `[5, 6]` o `[5]`).
  final List<int> modosDados;
  final bool mostrarDificultad;
  final bool jugarSoloEnLugarDePc;
  final bool mostrarModoDiosEnSolo;
  final String? textoInfoModoDios;
  final Widget? extraTrasModoLocal;

  final Future<void> Function(
    BuildContext context,
    MenuJuegoEstado estado,
    int dados,
  ) onPartidaRapida;

  final void Function(
    BuildContext context,
    MenuJuegoEstado estado,
    int dados,
  ) onVsPc;

  final void Function(
    BuildContext context,
    InicioPartidaOnline inicio,
  ) onIniciarDesdeSala;

  @override
  State<MenuJuegoScreen> createState() => _MenuJuegoScreenState();
}

class _MenuJuegoScreenState extends State<MenuJuegoScreen> {
  bool _modoDios = false;
  bool _decidirOrden = false;
  AjustesEstado _ajustes = const AjustesEstado();
  DificultadPc _dificultad = DificultadPc.medio;
  int _cantidadJugadores = 2;
  List<String> _nombresRapida = ['Jugador 1', 'Jugador 2'];
  static const int _maxNombre = 15;

  MenuJuegoEstado _estado({List<String>? nombres}) => MenuJuegoEstado(
        ajustes: _ajustes,
        modoDios: _modoDios,
        decidirOrden: _decidirOrden,
        dificultad: _dificultad,
        nombres: nombres ?? List.of(_nombresRapida),
      );

  Future<void> _abrirAjustes() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AjustesOverlay(
          ajustes: _ajustes,
          onChanged: (ajustes) {
            setState(() => _ajustes = ajustes);
            setDialogState(() {});
          },
          onCerrar: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  Future<void> _abrirPartidaRapida(int dados) async {
    var nombres = List<String>.of(_nombresRapida);
    if (_decidirOrden) {
      final ordenados = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (_) => DecidirOrdenScreen(nombres: nombres),
        ),
      );
      if (ordenados == null || !mounted) return;
      nombres = ordenados;
    }
    if (!mounted) return;
    await widget.onPartidaRapida(context, _estado(nombres: nombres), dados);
  }

  void _sincronizarNombres(int cantidad) {
    while (_nombresRapida.length < cantidad) {
      _nombresRapida.add('Jugador ${_nombresRapida.length + 1}');
    }
    if (_nombresRapida.length > cantidad) {
      _nombresRapida = _nombresRapida.sublist(0, cantidad);
    }
  }

  Future<void> _elegirCantidadJugadores() async {
    final elegida = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Cantidad de jugadores',
          style: TextStyle(color: AppColors.acento, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in [2, 3, 4]) ...[
              if (n != 2) const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: n == _cantidadJugadores
                        ? AppColors.texto
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B6578),
                    foregroundColor: AppColors.texto,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    '$n jugadores',
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (elegida != null && mounted) {
      setState(() {
        _cantidadJugadores = elegida;
        _sincronizarNombres(elegida);
      });
    }
  }

  Future<void> _editarNombres() async {
    final ctrls = List.generate(
      _cantidadJugadores,
      (i) => TextEditingController(text: _nombresRapida[i]),
    );
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Nombres',
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Máximo 15 caracteres por nombre.',
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < ctrls.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  TextField(
                    controller: ctrls[i],
                    maxLength: _maxNombre,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: AppColors.texto),
                    decoration: InputDecoration(
                      labelText: 'Jugador ${i + 1}',
                      counterStyle:
                          const TextStyle(color: AppColors.textoSuave),
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setDialogState(() => error = null);
                      }
                    },
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.peligro,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final nombres = ctrls.map((c) => c.text.trim()).toList();
                    final err = _validarNombres(nombres);
                    if (err != null) {
                      setDialogState(() => error = err);
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final nombresGuardados =
        ok == true ? ctrls.map((c) => c.text.trim()).toList() : null;
    for (final c in ctrls) {
      c.dispose();
    }
    if (nombresGuardados != null && mounted) {
      setState(() => _nombresRapida = nombresGuardados);
    }
  }

  String? _validarNombres(List<String> nombres) {
    for (final n in nombres) {
      if (n.isEmpty) return 'Ningún nombre puede estar vacío.';
      if (n.length > _maxNombre) return 'Máximo $_maxNombre caracteres.';
    }
    final vistos = <String>{};
    for (final n in nombres) {
      final clave = n.toLowerCase();
      if (!vistos.add(clave)) return 'No puede haber nombres repetidos.';
    }
    return null;
  }

  Future<void> _elegirDificultad() async {
    final elegida = await showDialog<DificultadPc>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Dificultad',
          style: TextStyle(color: AppColors.acento, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in DificultadPc.values) ...[
              if (d != DificultadPc.values.first) const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: d == _dificultad ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: d.color,
                    foregroundColor: const Color(0xFF1A0A00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    d.etiqueta,
                    style: const TextStyle(
                      color: Color(0xFF1A0A00),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (elegida != null && mounted) {
      setState(() => _dificultad = elegida);
    }
  }

  void _explicarDecidirOrden() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.help, color: AppColors.textoSuave),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Decidir orden',
                style: TextStyle(color: AppColors.acento, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Antes de empezar la partida, cada jugador saca una carta del '
          'mazo español (1 al 12 de oro, copa, espada y basto).\n\n'
          'Quien saque el número más alto juega primero (el palo no importa), '
          'y así en orden descendente.\n\n'
          'Ninguna carta se repite: la que sale se saca del mazo. '
          'Si hay empate de número, solo los empatados vuelven a sacar '
          'hasta desempatar. Después se muestra el orden y arranca la partida.',
          style: TextStyle(color: AppColors.texto, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _explicarModoDios() {
    final texto = widget.textoInfoModoDios ??
        'Es un modo de prueba. Durante la partida aparece un botón al lado '
            'de los dados que te deja elegir a mano los valores de la próxima '
            'tirada, en vez de dejarlos al azar.\n\n'
            'Sirve para probar combos y situaciones puntuales sin depender de '
            'la suerte. Solo está disponible al jugar contra la PC '
            '(en tu turno).';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.help, color: AppColors.textoSuave),
            SizedBox(width: 8),
            Text(
              'Modo Dios',
              style: TextStyle(color: AppColors.acento, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          texto,
          style: const TextStyle(color: AppColors.texto, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _etiquetaDados(int dados, {required String prefijo}) {
    if (widget.modosDados.length == 1) return prefijo;
    return '$prefijo · $dados dados';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            onPressed: _abrirAjustes,
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const padH = 24.0;
          const padVTop = 12.0;
          const padVBot = 16.0;
          final anchoUtil = constraints.maxWidth - padH * 2;
          return Padding(
            padding: const EdgeInsets.fromLTRB(padH, padVTop, padH, padVBot),
            child: SizedBox(
              width: anchoUtil,
              height: constraints.maxHeight - padVTop - padVBot,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: anchoUtil,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Multijugador online',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Creá una sala con código o unite a una existente.',
                        style: TextStyle(color: AppColors.textoSuave),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CrearSalaScreen(
                                juegoId: widget.juegoId,
                                mostrarSelectorDados:
                                    widget.modosDados.length > 1,
                                onIniciarPartida:
                                    widget.onIniciarDesdeSala,
                              ),
                            ),
                          );
                        },
                        child: const Text('Crear'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => UnirseSalaScreen(
                                juegoId: widget.juegoId,
                                mostrarSelectorDados:
                                    widget.modosDados.length > 1,
                                onIniciarPartida:
                                    widget.onIniciarDesdeSala,
                              ),
                            ),
                          );
                        },
                        child: const Text('Unirse'),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.fondoSuave),
                      const SizedBox(height: 12),
                      FilaOpcionToggle(
                        etiqueta: 'Multijugador local',
                        opcion: 'Decidir orden',
                        activo: _decidirOrden,
                        onChanged: (v) => setState(() => _decidirOrden = v),
                        onInfo: _explicarDecidirOrden,
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < widget.modosDados.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              _abrirPartidaRapida(widget.modosDados[i]),
                          child: Text(
                            _etiquetaDados(
                              widget.modosDados[i],
                              prefijo: 'Partida rápida',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _elegirCantidadJugadores,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.texto,
                                backgroundColor: const Color(0xFF6B6578),
                                side: const BorderSide(
                                  color: Color(0xFF8A8498),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Jugadores · $_cantidadJugadores',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _editarNombres,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.texto,
                                backgroundColor: const Color(0xFF6B6578),
                                side: const BorderSide(
                                  color: Color(0xFF8A8498),
                                  width: 1.5,
                                ),
                              ),
                              child: const Text('Nombres'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.fondoSuave),
                      const SizedBox(height: 12),
                      if (widget.jugarSoloEnLugarDePc) ...[
                        if (widget.mostrarModoDiosEnSolo)
                          FilaOpcionToggle(
                            etiqueta: 'Jugar solo',
                            opcion: 'Modo Dios',
                            activo: _modoDios,
                            onChanged: (v) => setState(() => _modoDios = v),
                            onInfo: _explicarModoDios,
                          )
                        else
                          const Text(
                            'Jugar solo',
                            style: TextStyle(
                              color: AppColors.texto,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => widget.onVsPc(
                            context,
                            _estado(nombres: const ['Jugador']),
                            widget.modosDados.first,
                          ),
                          child: const Text('Jugar solo'),
                        ),
                      ] else ...[
                        FilaOpcionToggle(
                          etiqueta: 'Jugar vs PC',
                          opcion: 'Modo Dios',
                          activo: _modoDios,
                          onChanged: (v) => setState(() => _modoDios = v),
                          onInfo: _explicarModoDios,
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < widget.modosDados.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => widget.onVsPc(
                              context,
                              _estado(),
                              widget.modosDados[i],
                            ),
                            child: Text(
                              _etiquetaDados(
                                widget.modosDados[i],
                                prefijo: 'Jugar vs PC',
                              ),
                            ),
                          ),
                        ],
                        if (widget.mostrarDificultad) ...[
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _elegirDificultad,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dificultad.color,
                              foregroundColor: const Color(0xFF1A0A00),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Dificultad · ${_dificultad.etiqueta}',
                              style: const TextStyle(
                                color: Color(0xFF1A0A00),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (widget.extraTrasModoLocal != null) ...[
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.fondoSuave),
                        const SizedBox(height: 12),
                        widget.extraTrasModoLocal!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
