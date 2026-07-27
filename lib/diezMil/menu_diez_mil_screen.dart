import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ajustes_overlay.dart';
import 'crear_sala_screen.dart';
import 'decidir_orden_screen.dart';
import 'ia_diez_mil.dart';
import 'motor.dart';
import 'partida_diez_mil_screen.dart';
import 'standby_store.dart';
import 'unirse_sala_screen.dart';

class MenuDiezMilScreen extends StatefulWidget {
  const MenuDiezMilScreen({
    super.key,
    this.titulo = 'Diez Mil',
    this.juegoId = juegoIdDiezMil,
  });

  static const juegoIdDiezMil = 'diezMil';
  static const juegoIdGenerala = 'generala';

  /// Título del AppBar (p. ej. "Diez Mil" o "Generala").
  final String titulo;

  /// Id para salas online y para saber qué juego arrancar.
  final String juegoId;

  bool get esDiezMil => juegoId == juegoIdDiezMil;

  @override
  State<MenuDiezMilScreen> createState() => _MenuDiezMilScreenState();
}

class _MenuDiezMilScreenState extends State<MenuDiezMilScreen> {
  bool _modoDios = false;
  bool _decidirOrden = false;
  AjustesEstado _ajustes = const AjustesEstado();
  DificultadPc _dificultad = DificultadPc.medio;
  int _cantidadJugadores = 2;
  List<String> _nombresRapida = ['Jugador 1', 'Jugador 2'];
  static const int _maxNombre = 15;

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

  Future<void> _abrirPartidaRapida(Modo modo) async {
    if (!widget.esDiezMil) {
      _mostrarEnDesarrollo();
      return;
    }
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidaDiezMilScreen(
          nombres: nombres,
          modo: modo,
          partidaRapida: true,
          ajustesIniciales: _ajustes,
        ),
      ),
    );
  }

  void _mostrarEnDesarrollo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          widget.titulo,
          style: const TextStyle(color: AppColors.acento, fontSize: 18),
        ),
        content: Text(
          'El menú ya está listo. La partida de ${widget.titulo} se va a '
          'armar a continuación.',
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
                        ? Colors.black
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acento,
                    foregroundColor: const Color(0xFF1A0A00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    '$n jugadores',
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

  void _abrirVsPc(Modo modo) {
    if (!widget.esDiezMil) {
      _mostrarEnDesarrollo();
      return;
    }
    final resume = DiezMilStandByStore.consumirSiCoincide(modo, _dificultad);
    final nombres = resume?.nombres ?? const ['Jugador 1', 'PC'];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidaDiezMilScreen(
          nombres: nombres,
          modo: modo,
          contraPc: true,
          dificultadPc: resume?.dificultadPc ?? _dificultad,
          modoDios: resume?.modoDios ?? _modoDios,
          ajustesIniciales: resume?.ajustesIniciales ?? _ajustes,
          resume: resume,
        ),
      ),
    );
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
              // El borde de la opción elegida va por afuera para no achicar
              // el botón.
              Container(
                decoration: BoxDecoration(
                  // Radio del botón (18) + grosor del borde.
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
          'Antes de empezar la partida, cada jugador tira un dado. '
          'Quien saque el número más alto juega primero, y así en orden '
          'descendente.\n\n'
          'Si hay empate, solo los empatados vuelven a tirar hasta '
          'desempatar. Después se muestra el orden y arranca la partida.',
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
        content: const Text(
          'Es un modo de prueba. Durante la partida aparece un botón al lado '
          'de los dados que te deja elegir a mano los valores de la próxima '
          'tirada, en vez de dejarlos al azar.\n\n'
          'Sirve para probar combos y situaciones puntuales sin depender de '
          'la suerte. Solo está disponible al jugar contra la PC '
          '(en tu turno).',
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
          final padH = 24.0;
          final padVTop = 12.0;
          final padVBot = 16.0;
          final anchoUtil = constraints.maxWidth - padH * 2;
          return Padding(
            padding: EdgeInsets.fromLTRB(padH, padVTop, padH, padVBot),
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
                        '¿Cómo querés jugar?',
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
                              ),
                            ),
                          );
                        },
                        child: const Text('Unirse'),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.fondoSuave),
                      const SizedBox(height: 12),
                      _FilaOpcionToggle(
                        etiqueta: 'Probar sin sala (mismo celular)',
                        opcion: 'Decidir orden',
                        activo: _decidirOrden,
                        onChanged: (v) => setState(() => _decidirOrden = v),
                        onInfo: _explicarDecidirOrden,
                      ),
                      const SizedBox(height: 10),
                      if (widget.esDiezMil) ...[
                        OutlinedButton(
                          onPressed: () => _abrirPartidaRapida(Modo.cinco),
                          child: const Text('Partida rápida · 5 dados'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _abrirPartidaRapida(Modo.seis),
                          child: const Text('Partida rápida · 6 dados'),
                        ),
                      ] else
                        OutlinedButton(
                          onPressed: () => _abrirPartidaRapida(Modo.cinco),
                          child: const Text('Partida rápida'),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _elegirCantidadJugadores,
                              child: Text(
                                'Jugadores · $_cantidadJugadores',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _editarNombres,
                              child: const Text('Nombres'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.fondoSuave),
                      const SizedBox(height: 12),
                      _FilaOpcionToggle(
                        etiqueta: 'Jugar vs PC',
                        opcion: 'Modo Dios',
                        activo: _modoDios,
                        onChanged: (v) => setState(() => _modoDios = v),
                        onInfo: _explicarModoDios,
                      ),
                      const SizedBox(height: 10),
                      if (widget.esDiezMil) ...[
                        OutlinedButton(
                          onPressed: () => _abrirVsPc(Modo.cinco),
                          child: const Text('Jugar vs PC · 5 dados'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _abrirVsPc(Modo.seis),
                          child: const Text('Jugar vs PC · 6 dados'),
                        ),
                      ] else
                        OutlinedButton(
                          onPressed: () => _abrirVsPc(Modo.cinco),
                          child: const Text('Jugar vs PC'),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _elegirDificultad,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dificultad.color,
                          foregroundColor: const Color(0xFF1A0A00),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

/// Color de UI para cada dificultad (la lógica vive en ia_diez_mil.dart).
extension DificultadPcUi on DificultadPc {
  Color get color => switch (this) {
        DificultadPc.facil => AppColors.mint,
        DificultadPc.medio => AppColors.acento,
        DificultadPc.dificil => AppColors.peligro,
      };
}

/// Etiqueta de sección + toggle reutilizable (Decidir orden / Modo Dios).
class _FilaOpcionToggle extends StatelessWidget {
  const _FilaOpcionToggle({
    required this.etiqueta,
    required this.opcion,
    required this.activo,
    required this.onChanged,
    required this.onInfo,
  });

  final String etiqueta;
  final String opcion;
  final bool activo;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0E061C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.violeta.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                opcion,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _SwitchNeon(activo: activo, onChanged: onChanged),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onInfo,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.help,
                size: 18,
                color: AppColors.textoSuave,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mismo estilo de switch que "Animaciones" en ajustes.
class _SwitchNeon extends StatelessWidget {
  const _SwitchNeon({
    required this.activo,
    required this.onChanged,
  });

  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!activo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: activo
              ? AppColors.azul.withValues(alpha: 0.45)
              : AppColors.textoSuave.withValues(alpha: 0.28),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? AppColors.azulSuave : AppColors.textoSuave,
              boxShadow: activo ? neonGlow(AppColors.azul, blur: 8) : null,
            ),
          ),
        ),
      ),
    );
  }
}
