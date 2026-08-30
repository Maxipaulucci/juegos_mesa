import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/guerraDeCartas/menu_partida_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/modo_dios_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_store.dart';
import 'package:app_juegos_mesa/guerraDeCartas/textos.dart';
import 'package:app_juegos_mesa/guerraDeCartas/victoria_guerra_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_store.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_inglesa_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/monedas/premiar_monedas_victoria_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/ui/cartel_reglas.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Guerra de cartas.
class PartidaGuerraScreen extends StatefulWidget {
  const PartidaGuerraScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.opciones = const OpcionesGuerra(),
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final OpcionesGuerra opciones;
  final PartidaGuerraResume? resume;

  @override
  State<PartidaGuerraScreen> createState() => _PartidaGuerraScreenState();
}

class _PartidaGuerraScreenState extends State<PartidaGuerraScreen> {
  late PartidaGuerra _partida;
  late List<String> _nombres;
  late bool _modoDios;
  late OpcionesGuerra _opciones;
  AjustesEstado _ajustes = AjustesStore.instance.estado;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  bool _jugando = false;
  /// Evita seguir la guerra en el mismo toque / doble Espacio.
  bool _pausaTrasEmpate = false;

  bool get _modoDiosActivo => _modoDios && widget.contraPc;
  bool get _esLocalHotSeat => !widget.contraPc;

  JugadorGuerra get _humanoPrincipal {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadores.first;
  }

  bool get _puedeJugarRonda {
    if (_partida.terminada || _jugando || _pausaTrasEmpate) return false;
    if (_partida.hayGuerraPendiente) return true;
    return _partida.conCartas.length >= 2;
  }

  String get _textoEstado {
    if (_partida.terminada) return '';
    final gp = _partida.guerraPendiente;
    if (gp != null) {
      final nombres = gp.nombresEnGuerra.join(' y ');
      final mezcla = gp.mezclaron.isEmpty
          ? ''
          : ' · ${gp.mezclaron.join(', ')} mezcló su pozo';
      return '¡Empate entre $nombres! Las cartas quedan en la mesa. '
          'Tocá “${TextosGuerra.jugar}” para sacar la siguiente '
          '(${gp.pot.length} en juego)$mezcla';
    }
    final ur = _partida.ultimaRonda;
    if (ur != null) {
      final mezcla = ur.mezclaronPozo.isEmpty
          ? ''
          : ' · ${ur.mezclaronPozo.join(', ')} mezcló su pozo';
      if (ur.huboGuerra) {
        return '${ur.mensaje ?? '¡Guerra! Ganó ${ur.ganadorNombre} (${ur.pozoMesa.length} cartas)'}$mezcla';
      }
      return '${ur.ganadorNombre} se lleva ${ur.pozoMesa.length} carta(s)$mezcla';
    }
    return 'Tocá “${TextosGuerra.jugar}” o Espacio para voltear las cimas';
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onTeclaJugar);
    final resume = widget.resume;
    _modoDios = widget.modoDios;
    _opciones = widget.opciones;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    if (resume != null) {
      _partida = resume.partida;
      // Config del menú actual (vidas / etc.), no la del standby viejo.
      _partida.opciones = _opciones;
      _nombres = List.of(resume.nombres);
      chequearFinGuerra(_partida);
    } else {
      _partida = nuevaPartidaGuerra(
        nombres: _nombres,
        contraPc: widget.contraPc,
        opciones: _opciones,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onTeclaJugar);
    super.dispose();
  }

  bool _onTeclaJugar(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.space) return false;
    if (!mounted) return false;
    if (_mostrarMenu || _mostrarAjustes || _confirmarRendicion) return false;
    if (_partida.terminada) return false;
    if (_partida.hayGuerraPendiente ||
        _partida.conCartas.length < 2 ||
        _puedeJugarRonda) {
      _jugarRonda();
      return true;
    }
    return false;
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      GuerraStandByStore.limpiar();
      return;
    }
    GuerraStandByStore.guardar(
      PartidaGuerraResume(
        partida: _partida,
        nombres: _nombres,
        modoDios: _modoDios,
        opciones: _opciones,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      GuerraStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _mostrarReglas() {
    mostrarCartelReglas(context, TextosGuerra.reglas());
  }

  void _rendirse() {
    if (_partida.terminada) return;
    final yo = _humanoPrincipal.nombre;
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      rendirseGuerra(_partida, yo);
    });
  }

  static const int _maxNombre = 15;

  bool _puedeRenombrar(JugadorGuerra j) {
    if (_partida.terminada || j.rendido) return false;
    return !esNombrePc(j.nombre);
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (esNombrePc(nombre)) {
      return 'Ese nombre está reservado para la PC.';
    }
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (index < 0 || index >= _partida.jugadores.length) return;
    final j = _partida.jugadores[index];
    if (!_puedeRenombrar(j)) return;
    final actual = j.nombre;
    final ctrl = TextEditingController(text: actual);
    String? error;

    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cambiar nombre',
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Máximo 15 caracteres.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: _maxNombre,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  hintText: 'Nombre del jugador',
                  errorText: error,
                  counterStyle: const TextStyle(color: AppColors.textoSuave),
                ),
                onSubmitted: (_) {
                  final t = ctrl.text.trim();
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
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
    );

    if (nuevo == null || nuevo == actual || !mounted) return;

    setState(() {
      _partida.jugadores[index].nombre = nuevo;
      if (index < _nombres.length) _nombres[index] = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
    });
  }

  Future<void> _jugarRonda() async {
    if (_partida.terminada) return;
    // Si ya no hay rivales con cartas, cerrar (salvo guerra en curso).
    if (!_partida.hayGuerraPendiente && _partida.conCartas.length < 2) {
      setState(() => chequearFinGuerra(_partida));
      return;
    }
    if (!_puedeJugarRonda) return;
    setState(() => _jugando = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final err = jugarRondaGuerra(_partida);
    final quedoEmpate = _partida.hayGuerraPendiente;
    setState(() {
      _jugando = false;
      chequearFinGuerra(_partida);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    });
    // Tras un empate, dejá ver las cartas antes de permitir el siguiente toque.
    if (quedoEmpate && mounted) {
      setState(() => _pausaTrasEmpate = true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _pausaTrasEmpate = false);
    }
  }

  void _reiniciar() {
    GuerraStandByStore.limpiar();
    setState(() {
      // Aplicar config actual del menú (modo dios + modificar partida).
      _modoDios = modoDiosElegidoEnMenu(
        MenuJuegoScreen.juegoIdGuerraDeCartas,
        fallback: widget.modoDios,
      );
      _opciones = GuerraMenuConfig.opciones;
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(
              MenuJuegoScreen.juegoIdGuerraDeCartas,
            ) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaGuerra(
        nombres: _nombres,
        contraPc: widget.contraPc,
        opciones: _opciones,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _jugando = false;
      _pausaTrasEmpate = false;
    });
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  Future<void> _abrirEditarMazo() async {
    if (!_modoDiosActivo || _partida.terminada || _jugando) return;
    final yo = _humanoPrincipal;
    if (yo.mazo.isEmpty) return;
    final nuevo = await mostrarEditarMazoGuerra(
      context: context,
      ordenDesdeProxima: ordenSalidaMazoGuerra(yo),
    );
    if (!mounted || nuevo == null) return;
    setState(() => forzarMazoGuerra(yo, nuevo));
  }

  PaloInglesVisual _paloVisual(PaloGuerra p) => switch (p) {
        PaloGuerra.corazones => PaloInglesVisual.corazones,
        PaloGuerra.diamantes => PaloInglesVisual.diamantes,
        PaloGuerra.treboles => PaloInglesVisual.treboles,
        PaloGuerra.picas => PaloInglesVisual.picas,
      };

  String _etiquetaValor(CartaGuerra c) => switch (c.valor) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '${c.valor}',
      };

  static const double _cartaW = 68;
  static const double _cartaH = 102;
  /// Ancho fijo del pozo (carta + mitad para el abanico).
  static const double _pozoAncho = _cartaW * 1.5;

  Widget _cartaMini(CartaGuerra? c, {required bool bocaArriba}) {
    if (c == null) {
      return Container(
        width: _cartaW,
        height: _cartaH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cartaBorde),
        ),
        child: const Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    return CartaInglesaSkin(
      etiquetaValor: _etiquetaValor(c),
      palo: _paloVisual(c.palo),
      bocaArriba: bocaArriba,
      width: _cartaW,
      height: _cartaH,
    );
  }

  /// Pozo con ancho fijo: mazo y vidas no se mueven al agregar cartas.
  Widget _pozoVisual(JugadorGuerra j) {
    Widget carta(CartaGuerra c) => CartaInglesaSkin(
          etiquetaValor: _etiquetaValor(c),
          palo: _paloVisual(c.palo),
          bocaArriba: true,
          width: _cartaW,
          height: _cartaH,
        );

    late final Widget contenido;
    if (j.pozo.isEmpty) {
      contenido = _cartaMini(null, bocaArriba: true);
    } else if (j.pozo.length == 1) {
      contenido = carta(j.pozo.last);
    } else {
      final cima = j.pozo.last;
      CartaGuerra debajo = j.pozo[j.pozo.length - 2];
      final ur = _partida.ultimaRonda;
      if (ur != null && ur.ganadorNombre == j.nombre) {
        final ganadora = ur.cartasJugadas[j.nombre];
        if (ganadora != null && ganadora != cima) debajo = ganadora;
      }
      contenido = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, child: carta(debajo)),
          Positioned(left: _cartaW * 0.5, top: 0, child: carta(cima)),
        ],
      );
    }

    return SizedBox(
      width: _pozoAncho,
      height: _cartaH,
      child: Align(
        alignment: Alignment.centerLeft,
        child: contenido,
      ),
    );
  }

  void _mostrarInfoVidas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Vidas',
          style: TextStyle(
            color: AppColors.mint,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        content: const Text(
          TextosGuerra.infoVidasEnPartida,
          style: TextStyle(color: AppColors.texto, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarCartelHistorial() {
    final todos = _partida.historialRondas;
    final ultimos = todos.length <= 10
        ? List<ResultadoRondaGuerra>.from(todos)
        : todos.sublist(todos.length - 10);
    final desde = todos.length - ultimos.length;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
        return AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.history, color: AppColors.mint),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Historial',
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: AppColors.textoSuave),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ultimos.isEmpty
                      ? 'Todavía no hubo tiradas.'
                      : 'Últimas ${ultimos.length} tirada${ultimos.length == 1 ? '' : 's'}'
                          '${todos.length > 10 ? ' (de ${todos.length})' : ''}',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: ultimos.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Jugá una carta para ver el historial.',
                            style: TextStyle(color: AppColors.textoSuave),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: ultimos.length,
                          itemBuilder: (_, i) {
                            final r = ultimos[i];
                            final n = desde + i + 1;
                            final cartas = r.cartasJugadas.entries
                                .map((e) => '${e.key}: ${e.value.etiqueta}')
                                .join('  ·  ');
                            final titulo = r.huboGuerra
                                ? 'Tirada $n · ¡Guerra!'
                                : 'Tirada $n';
                            final detalle = r.mensaje ??
                                'Ganó ${r.ganadorNombre} (+${r.pozoMesa.length})';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: r.huboGuerra
                                      ? AppColors.acento.withValues(alpha: 0.7)
                                      : AppColors.cartaBorde,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          titulo,
                                          style: TextStyle(
                                            color: r.huboGuerra
                                                ? AppColors.acento
                                                : AppColors.texto,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        r.ganadorNombre,
                                        style: const TextStyle(
                                          color: AppColors.mint,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cartas,
                                    style: const TextStyle(
                                      color: AppColors.textoSuave,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    detalle,
                                    style: TextStyle(
                                      color: AppColors.texto
                                          .withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _montonMesa({
    required String nombre,
    required List<CartaGuerra> cartas,
    required bool enGuerra,
  }) {
    if (cartas.isEmpty) {
      return _cartaMini(null, bocaArriba: true);
    }
    final offset = (_cartaW * 0.18).clamp(8.0, 14.0);
    final totalW = _cartaW + offset * (cartas.length - 1);
    final totalH = _cartaH + offset * (cartas.length - 1) * 0.35;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nombre,
          style: TextStyle(
            color: enGuerra ? AppColors.peligro : AppColors.textoSuave,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < cartas.length; i++)
                Positioned(
                  left: offset * i,
                  top: offset * i * 0.35,
                  child: _cartaMini(cartas[i], bocaArriba: true),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vidasWidget(JugadorGuerra j) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _VidasGuerraBadge(
          key: ValueKey('vidas-${j.nombre}'),
          vidas: j.vidas,
        ),
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _mostrarInfoVidas,
            customBorder: const CircleBorder(),
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9E9E9E).withValues(alpha: 0.55),
                border: Border.all(
                  color: const Color(0xFFBDBDBD).withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: const Text(
                'i',
                style: TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mazoConModoDios(JugadorGuerra j, {required bool esHumano}) {
    final proxima = j.mazo.isEmpty ? null : j.mazo.last;
    final esPc = esNombrePc(j.nombre);
    final verRivalTranslucida =
        _modoDiosActivo && esPc && !esHumano && proxima != null;

    final mazoVisual = SizedBox(
      width: _cartaW,
      height: _cartaH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _cartaMini(
            j.mazo.isEmpty ? null : proxima,
            bocaArriba: false,
          ),
          if (verRivalTranslucida)
            Opacity(
              opacity: 0.55,
              child: IgnorePointer(
                child: _cartaMini(proxima, bocaArriba: true),
              ),
            ),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: _cartaW,
          child: Column(
            children: [
              const Text(
                'Mazo',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${j.mazo.length}',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              mazoVisual,
            ],
          ),
        ),
        if (esHumano && _modoDiosActivo) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Material(
              color: AppColors.carta,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: (_partida.terminada || j.mazo.isEmpty || _jugando)
                    ? null
                    : _abrirEditarMazo,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textoSuave.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.bug_report,
                    size: 20,
                    color: AppColors.textoSuave,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pilaJugador(JugadorGuerra j, {required bool esHumano, required int index}) {
    final puedeRenombrar = _puedeRenombrar(j);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NombreJugadorEditable(
              nombre: j.rendido ? '${j.nombre} (fuera)' : j.nombre,
              puedeRenombrar: puedeRenombrar,
              onRenombrar: () => _renombrarJugador(index),
              fontSize: 12,
              tachado: j.rendido,
              colorTexto: esHumano ? AppColors.mint : AppColors.textoSuave,
              mayusculas: !j.rendido,
            ),
            if (_partida.vidasActivas) ...[
              const SizedBox(width: 8),
              _vidasWidget(j),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mazoConModoDios(j, esHumano: esHumano),
            const SizedBox(width: 10),
            SizedBox(
              width: _pozoAncho,
              child: Column(
                children: [
                  const Text(
                    'Pozo',
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${j.pozo.length}',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _pozoVisual(j),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Total ${j.totalCartas}',
          style: const TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_partida.terminada &&
        !_partida.hayGuerraPendiente &&
        _partida.conCartas.length < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _partida.terminada || _partida.hayGuerraPendiente) {
          return;
        }
        if (_partida.conCartas.length >= 2) return;
        setState(() => chequearFinGuerra(_partida));
      });
    }

    final ur = _partida.ultimaRonda;
    final gp = _partida.guerraPendiente;
    final cartasMesa = gp?.visibles ?? ur?.cartasJugadas;
    final mesaEnGuerra = gp != null || (ur?.huboGuerra ?? false);
    final tituloMesa = gp != null
        ? '¡EMPATE! — tocá Jugar carta'
        : (ur?.huboGuerra == true ? '¡GUERRA!' : 'Mesa');
    final humano = _humanoPrincipal;
    final rivales = [
      for (final j in _partida.jugadores)
        if (j.nombre != humano.nombre) j,
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_mostrarAjustes) {
          setState(() => _mostrarAjustes = false);
          return;
        }
        if (_mostrarMenu) {
          setState(() {
            _mostrarMenu = false;
            _confirmarRendicion = false;
          });
          return;
        }
        setState(() {
          _mostrarMenu = true;
          _confirmarRendicion = false;
          _mostrarAjustes = false;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: Stack(
          children: [
            const Positioned.fill(
              child: EpicBackdrop(centerY: 0.45, fadeRayosAlCentro: true),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarMenu = true;
                            _confirmarRendicion = false;
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosGuerra.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.contraPc)
                          BotonReiniciarPartidaPc(
                            onPressed: _pedirReiniciarVsPc,
                          ),
                        IconButton(
                          tooltip: 'Historial',
                          onPressed: _mostrarCartelHistorial,
                          icon: const Icon(
                            Icons.history,
                            color: AppColors.textoSuave,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarAjustes = true;
                            _mostrarMenu = false;
                          }),
                          icon: const Icon(
                            Icons.settings,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_textoEstado.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _textoEstado,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          if (rivales.isNotEmpty)
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final o in rivales) ...[
                                          _pilaJugador(
                                            o,
                                            esHumano: false,
                                            index:
                                                _partida.jugadores.indexOf(o),
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: cartasMesa == null
                                    ? Text(
                                        'Mesa vacía',
                                        style: TextStyle(
                                          color: AppColors.textoSuave
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tituloMesa,
                                            style: TextStyle(
                                              color: mesaEnGuerra
                                                  ? AppColors.peligro
                                                  : AppColors.textoSuave,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (gp != null)
                                                for (final nombre
                                                    in gp.nombresEnGuerra)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      right: 10,
                                                    ),
                                                    child: _montonMesa(
                                                      nombre: nombre,
                                                      cartas: gp.montones[
                                                              nombre] ??
                                                          [
                                                            if (gp.visibles[
                                                                    nombre] !=
                                                                null)
                                                              gp.visibles[
                                                                  nombre]!,
                                                          ],
                                                      enGuerra: true,
                                                    ),
                                                  )
                                              else
                                                for (final e
                                                    in cartasMesa.entries)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      right: 10,
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          e.key,
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .textoSuave,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        _cartaMini(
                                                          e.value,
                                                          bocaArriba: true,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _pilaJugador(
                                  humano,
                                  esHumano: true,
                                  index: _partida.jugadores.indexOf(humano),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.azul,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.5),
                        ),
                        onPressed: _puedeJugarRonda ? _jugarRonda : null,
                        child: Text(
                          _jugando ? '…' : TextosGuerra.jugar,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_mostrarAjustes)
              Positioned.fill(
                child: AjustesOverlay(
                  ajustes: _ajustes,
                  onChanged: (a) => setState(() => _ajustes = a),
                  onCerrar: () => setState(() => _mostrarAjustes = false),
                ),
              ),
            if (_mostrarMenu)
              Positioned.fill(
                child: MenuPartidaGuerra(
                  jugador: humano.nombre,
                  partidaTerminada: _partida.terminada,
                  permitirRendirse: _esLocalHotSeat,
                  confirmarRendicion:
                      _confirmarRendicion && _esLocalHotSeat,
                  onCerrar: () => setState(() {
                    _mostrarMenu = false;
                    _confirmarRendicion = false;
                  }),
                  onReglas: () {
                    setState(() {
                      _mostrarMenu = false;
                      _confirmarRendicion = false;
                    });
                    _mostrarReglas();
                  },
                  onSalirORendirse: _partida.terminada || !_esLocalHotSeat
                      ? () {
                          setState(() {
                            _mostrarMenu = false;
                            _confirmarRendicion = false;
                          });
                          _salirAlMenu(
                            guardar:
                                widget.contraPc && !_partida.terminada,
                          );
                        }
                      : () => setState(() => _confirmarRendicion = true),
                  onConfirmarRendicion: _rendirse,
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: PremiarMonedasVictoriaPc(
                  aplicar: ganoHumanoEnVsPc(
                    contraPc: widget.contraPc,
                    online: false,
                    ganador: _partida.ganador,
                  ),
                  juegoId: MenuJuegoScreen.juegoIdGuerraDeCartas,
                  child: VictoriaGuerraOverlay(
                    partida: _partida,
                    onVolverAJugar: _reiniciar,
                    onVolver: () => _salirAlMenu(guardar: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contador de vidas con animación de daño (−1 flotante + temblor).
class _VidasGuerraBadge extends StatefulWidget {
  const _VidasGuerraBadge({super.key, required this.vidas});

  final int vidas;

  @override
  State<_VidasGuerraBadge> createState() => _VidasGuerraBadgeState();
}

class _VidasGuerraBadgeState extends State<_VidasGuerraBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dano;
  late final Animation<double> _shakeX;
  late final Animation<double> _menosOpacity;
  late final Animation<Offset> _menosOffset;
  late final Animation<double> _menosScale;
  late final Animation<double> _pulsoCorazon;

  bool _mostrarMenos = false;

  @override
  void initState() {
    super.initState();
    _dano = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _mostrarMenos = false);
        }
      });

    // Temblor de dolor: izq → der → izq → centro, amortiguado.
    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 7.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -5.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 4.0), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -2.5), weight: 16),
      TweenSequenceItem(tween: Tween(begin: -2.5, end: 1.2), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _dano, curve: Curves.easeOutCubic));

    // −1: sube, luego se desliza a la derecha y baja mientras se desvanece.
    _menosOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(6, -16),
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(6, -16),
          end: const Offset(26, 10),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 68,
      ),
    ]).animate(_dano);

    _menosOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 38),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_dano);

    _menosScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.85), weight: 80),
    ]).animate(_dano);

    _pulsoCorazon = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.92), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.08), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 40),
    ]).animate(_dano);
  }

  @override
  void didUpdateWidget(covariant _VidasGuerraBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vidas < oldWidget.vidas) {
      setState(() => _mostrarMenos = true);
      _dano.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _dano.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final critico = widget.vidas <= 3;
    final colorNum = critico ? const Color(0xFFFF6B6B) : AppColors.texto;

    return AnimatedBuilder(
      animation: _dano,
      builder: (context, _) {
        return SizedBox(
          width: 56,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Transform.translate(
                offset: Offset(_shakeX.value, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.vidas}',
                      style: TextStyle(
                        color: Color.lerp(
                          colorNum,
                          const Color(0xFFFF4D4D),
                          _mostrarMenos ? 0.4 * _menosOpacity.value : 0,
                        ),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1,
                        shadows: _mostrarMenos
                            ? [
                                Shadow(
                                  color: const Color(0xFFFF3B3B)
                                      .withValues(alpha: 0.45 * _menosOpacity.value),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: _mostrarMenos ? _pulsoCorazon.value : 1,
                      child: Text(
                        '♥',
                        style: TextStyle(
                          color: Color.lerp(
                            const Color(0xFFE53935),
                            const Color(0xFFFF1744),
                            _mostrarMenos ? 0.55 * _menosOpacity.value : 0,
                          ),
                          fontSize: 20,
                          height: 1,
                          shadows: _mostrarMenos
                              ? [
                                  Shadow(
                                    color: const Color(0xFFFF1744)
                                        .withValues(alpha: 0.55 * _menosOpacity.value),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_mostrarMenos)
                Positioned(
                  left: 28,
                  top: -2,
                  child: Transform.translate(
                    offset: _menosOffset.value,
                    child: Opacity(
                      opacity: _menosOpacity.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _menosScale.value,
                        child: const Text(
                          '−1',
                          style: TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                              Shadow(
                                color: Color(0x88FF1744),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
