import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/la_papa_online_codec.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/partida_la_papa_screen.dart';
import 'package:app_juegos_mesa/laPapa/standby_store.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/shared/menu/opcion_toggle.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de La papa: mismo layout que Generala, con "Jugar solo" + modificar.
class MenuLaPapaScreen extends StatefulWidget {
  const MenuLaPapaScreen({super.key});

  @override
  State<MenuLaPapaScreen> createState() => _MenuLaPapaScreenState();
}

class _MenuLaPapaScreenState extends State<MenuLaPapaScreen> {
  OpcionesPapa _opciones = const OpcionesPapa();

  Future<void> _abrirPartida({
    required BuildContext ctx,
    required List<String> nombres,
    required MenuJuegoEstado estado,
    bool solo = false,
    PartidaPapaResume? resume,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: _opciones.numerosAleatoriosEfectivos
          ? 'Preparando hoja'
          : 'Preparando colocación',
      acento: AppColors.mint,
      builder: (_) => PartidaLaPapaScreen(
        nombres: resume?.nombres ?? nombres,
        solo: solo,
        opciones: resume?.opciones ?? _opciones,
        ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
        resume: resume,
      ),
    );
  }

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        void setOpc(OpcionesPapa next) {
          setDialogState(() => draft = next);
        }

        final infernal = draft.modoInfernal;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Agregar 3 vidas',
              activo: draft.conVidasEfectivas,
              habilitado: !infernal,
              onChanged: (v) => setOpc(draft.copyWith(conVidas: v)),
              info:
                  'Cada jugador empieza con 3 vidas. Si falla, pierde una vida '
                  'pero sigue su turno. Sin vidas, termina la partida.\n\n'
                  'No disponible en Modo infernal.',
            ),
            const SizedBox(height: 12),
            _FilaModoInfernal(
              activo: infernal,
              onChanged: (v) => setOpc(draft.conModoInfernal(v)),
              info:
                  'Solo ves las líneas, el número actual y el siguiente.\n\n'
                  'Fuerza 50 números al azar, sin cuadrícula, sin vidas, '
                  'sin lupa, sin cambiar grosor y sin trazar sobre números.\n\n'
                  'Mientras esté activo no se pueden cambiar las demás opciones.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Mostrar cuadrícula',
              activo: draft.mostrarCuadriculaEfectiva,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(mostrarCuadricula: v)),
              info:
                  'Activado: se ven las líneas de la hoja (casillas).\n\n'
                  'Desactivado: la hoja queda en blanco, solo con números '
                  'y trazos.\n\n'
                  'En Modo infernal la cuadrícula queda oculta.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Trazo sobre números',
              activo: draft.permitirTrazoSobreNumerosEfectivo,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(permitirTrazoSobreNumeros: v)),
              info:
                  'Activado (por defecto): podés pasar el trazo por encima '
                  'de otros números sin perder.\n\n'
                  'Desactivado: si tu línea toca la zona de otro número '
                  '(que no sea el de salida o el de llegada), perdés.\n\n'
                  'En Modo infernal queda desactivado.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Lupa',
              activo: draft.mostrarLupaEfectiva,
              habilitado: !infernal,
              onChanged: (v) => setOpc(draft.copyWith(mostrarLupa: v)),
              info:
                  'Activado (por defecto): mientras dibujás aparece una lupa '
                  'que amplía la zona del dedo o del cursor.\n\n'
                  'En celular podés mover la lupa con el botón “Mover lupa”; '
                  'en PC con la tecla L.\n\n'
                  'Desactivado: dibujás sin ampliación.\n\n'
                  'En Modo infernal queda desactivada.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Modificar grosor del trazo',
              activo: draft.modificarGrosorTrazoEfectivo,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(modificarGrosorTrazo: v)),
              info:
                  'Activado (por defecto): podés cambiar el grosor del lápiz '
                  '(fino / normal / grueso) con el botón “Trazos”.\n\n'
                  'Mientras dibujás, tocá “Trazos” para ciclar '
                  'Grueso → Fino → Normal. En PC también con la tecla T.\n\n'
                  'Desactivado: no aparece ningún control de grosor; '
                  'siempre se dibuja con el grosor normal.\n\n'
                  'En Modo infernal queda desactivado.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Números aleatorios',
              activo: draft.numerosAleatoriosEfectivos,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(numerosAleatorios: v)),
              info:
                  'Activado: la hoja se arma sola con números al azar.\n\n'
                  'Desactivado: antes de jugar, los jugadores colocan '
                  'los números por turnos (el 1er jugador / anfitrión '
                  'pone el 1, el otro el 2, y así sucesivamente).\n\n'
                  'En Modo infernal siempre es aleatorio.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Para la generación de números añadir excepción',
              activo: draft.excepcionGeneracionNumeros,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(excepcionGeneracionNumeros: v)),
              info:
                  'La excepción hace que, al generar (o colocar) números '
                  'consecutivos, no queden en la misma fila ni en la misma '
                  'columna, y tampoco como vecinos.\n\n'
                  'Desactivado (por defecto): los números se ubican al azar '
                  'en cualquier casilla libre del tablero de 50.',
              tituloWidget: Builder(
                builder: (ctx) {
                  const estilo = TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Para la generación de números',
                        style: estilo,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('añadir excepción', style: estilo),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            tooltip: 'Info',
                            onPressed: () => mostrarInfoModificarPartida(
                              ctx,
                              titulo: 'Excepción en la generación',
                              cuerpo:
                                  'La excepción hace que, al generar (o colocar) '
                                  'números consecutivos, no queden en la misma '
                                  'fila ni en la misma columna, y tampoco como '
                                  'vecinos.\n\n'
                                  'Desactivado (por defecto): los números se '
                                  'ubican al azar en cualquier casilla libre '
                                  'del tablero de 50.',
                            ),
                            icon: const Icon(
                              Icons.help,
                              size: 18,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilaCantidadModificarPartida(
              etiqueta: 'Cantidad de números',
              valor: draft.cantidadNumerosClamped,
              min: OpcionesPapa.minCantidadNumeros,
              max: OpcionesPapa.maxCantidadNumeros,
              habilitado: !infernal,
              onChanged: (v) =>
                  setOpc(draft.copyWith(cantidadNumeros: v)),
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() {
        _opciones = draft;
        SalaFormStore.opcionesPapa = encodePapaOpciones(_opciones);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SalaFormStore.opcionesPapa = encodePapaOpciones(_opciones);
    return MenuJuegoScreen(
      titulo: 'La papa',
      juegoId: MenuJuegoScreen.juegoIdLaPapa,
      modosDados: const [1],
      jugarSoloEnLugarDePc: true,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        await _abrirPartida(
          ctx: ctx,
          nombres: estado.nombres,
          estado: estado,
        );
      },
      onVsPc: (ctx, estado, _) {
        final resume = PapaStandByStore.consumirSiCoincide(_opciones);
        _abrirPartida(
          ctx: ctx,
          nombres: resume?.nombres ??
              (estado.nombres.isEmpty
                  ? const ['Jugador']
                  : estado.nombres),
          estado: estado,
          solo: true,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Preparando hoja',
          acento: AppColors.mint,
          builder: (_) => PartidaLaPapaScreen(
            nombres: inicio.nombres,
            opciones: _opciones,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}

/// Toggle “Modo infernal”: fondo negro / texto rojo que intercambia cada 1,5 s.
class _FilaModoInfernal extends StatefulWidget {
  const _FilaModoInfernal({
    required this.activo,
    required this.onChanged,
    required this.info,
  });

  final bool activo;
  final ValueChanged<bool> onChanged;
  final String info;

  @override
  State<_FilaModoInfernal> createState() => _FilaModoInfernalState();
}

class _FilaModoInfernalState extends State<_FilaModoInfernal> {
  Timer? _parpadeo;
  bool _invertido = false;

  @override
  void initState() {
    super.initState();
    // Timer en vez de AnimationController: evita crashes de InheritedWidget
    // (_dependents.isEmpty) al abrir diálogos anidados desde este cartel.
    _parpadeo = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() => _invertido = !_invertido);
    });
  }

  @override
  void dispose() {
    _parpadeo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fondo = _invertido ? AppColors.peligro : Colors.black;
    final texto = _invertido ? Colors.black : AppColors.peligro;

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.peligro, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.peligro.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Text(
              'Modo infernal',
              style: TextStyle(
                color: texto,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SwitchNeon(activo: widget.activo, onChanged: widget.onChanged),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Info',
          onPressed: () => mostrarInfoModificarPartida(
            context,
            titulo: 'Modo infernal',
            cuerpo: widget.info,
          ),
          icon: Icon(
            Icons.help,
            size: 18,
            color: AppColors.peligro.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
