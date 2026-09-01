import 'package:flutter/material.dart';

import '../config/juegos_catalogo.dart';
import '../services/usuario_mongo_service.dart';
import '../shared/ajustes/ajustes_overlay.dart';
import '../shared/ajustes/ajustes_store.dart';
import '../shared/ajustes/boton_ajustes.dart';
import '../shared/cuenta/boton_perfil.dart';
import '../shared/cuenta/cambiar_nombre_usuario.dart';
import '../shared/cuenta/cuenta_overlay.dart';
import '../shared/cuenta/eliminar_cuenta.dart';
import '../shared/cuenta/racha_perfil.dart';
import '../shared/formato/numero_formato.dart';
import '../theme/app_theme.dart';

/// Puntuaciones del usuario en todos los juegos de la app.
class MisPuntosScreen extends StatefulWidget {
  const MisPuntosScreen({super.key});

  @override
  State<MisPuntosScreen> createState() => MisPuntosScreenState();
}

class MisPuntosScreenState extends State<MisPuntosScreen> {
  final _api = UsuarioMongoService.instance;
  bool _cargando = false;
  String? _error;
  bool _mostrarCuenta = false;
  bool _mostrarAjustes = false;
  AjustesEstado _ajustes = AjustesStore.instance.estado;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    if (!_api.haySesion) {
      if (mounted) setState(() => _error = null);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _api.recargarYo();
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _cerrarSesion() {
    _api.cerrarSesion();
    setState(() => _error = null);
  }

  Future<void> _eliminarCuenta() async {
    final eliminada = await mostrarDialogoEliminarCuenta(context);
    if (!mounted || !eliminada) return;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _api.usuario;
    final haySesion = _api.haySesion && usuario != null;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [
                    Color(0xFF2A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Mi cuenta',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.texto,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Tus puntos en cada juego',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: BotonPerfil(
                          onTap: () => setState(() => _mostrarCuenta = true),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: BotonAjustes(
                          onPressed: () =>
                              setState(() => _mostrarAjustes = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.acento,
                          ),
                        )
                      : !haySesion
                          ? _SinSesion(
                              onIniciarSesion: () =>
                                  setState(() => _mostrarCuenta = true),
                            )
                          : _ListaPuntos(
                              nombre: usuario.nombreUsuario.isNotEmpty
                                  ? usuario.nombreUsuario
                                  : usuario.nombre,
                              email: usuario.email,
                              global: usuario.puntosGlobal,
                              puntos: usuario.puntos,
                              rachaDias: usuario.rachaDias,
                              rachaMaxima: usuario.rachaMaxima,
                              rachaAnterior: usuario.rachaAnterior,
                              error: _error,
                              onReintentar: recargar,
                              onNombreCambiado: () {
                                if (mounted) setState(() {});
                              },
                              onRachaRestablecida: () {
                                if (mounted) setState(() {});
                              },
                            ),
                ),
                if (haySesion) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BotonAccionCuenta(
                          label: 'Cerrar sesión',
                          relleno: AppColors.azul,
                          onTap: _cerrarSesion,
                        ),
                        const SizedBox(height: 10),
                        _BotonAccionCuenta(
                          label: 'Eliminar cuenta',
                          borde: AppColors.peligro,
                          texto: AppColors.peligro,
                          onTap: _eliminarCuenta,
                        ),
                      ],
                    ),
                  ),
                ],
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
          if (_mostrarCuenta)
            Positioned.fill(
              child: CuentaOverlay(
                onCerrar: () => setState(() => _mostrarCuenta = false),
                onSesion: () {
                  setState(() => _mostrarCuenta = false);
                  recargar();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonAccionCuenta extends StatelessWidget {
  const _BotonAccionCuenta({
    required this.label,
    required this.onTap,
    this.relleno,
    this.borde,
    this.texto,
  });

  final String label;
  final VoidCallback onTap;
  final Color? relleno;
  final Color? borde;
  final Color? texto;

  @override
  Widget build(BuildContext context) {
    final colorTexto = relleno != null
        ? const Color(0xFF0B1A2E)
        : (texto ?? AppColors.texto);

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: relleno,
            borderRadius: BorderRadius.circular(12),
            border: borde != null
                ? Border.all(color: borde!, width: 1.6)
                : null,
            boxShadow: relleno == AppColors.azul
                ? neonGlow(AppColors.azul, blur: 10)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorTexto,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SinSesion extends StatelessWidget {
  const _SinSesion({required this.onIniciarSesion});

  final VoidCallback onIniciarSesion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 56,
              color: AppColors.textoSuave.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Iniciá sesión para ver tus puntuaciones',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onIniciarSesion,
                child: const Text('Entrar o registrarme'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaPuntos extends StatelessWidget {
  const _ListaPuntos({
    required this.nombre,
    required this.email,
    required this.global,
    required this.puntos,
    required this.rachaDias,
    required this.rachaMaxima,
    required this.rachaAnterior,
    required this.error,
    required this.onReintentar,
    required this.onNombreCambiado,
    required this.onRachaRestablecida,
  });

  final String nombre;
  final String email;
  final int global;
  final Map<String, int> puntos;
  final int rachaDias;
  final int rachaMaxima;
  final int rachaAnterior;
  final String? error;
  final VoidCallback onReintentar;
  final VoidCallback onNombreCambiado;
  final VoidCallback onRachaRestablecida;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.peligro.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.peligro.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.texto),
                  ),
                ),
                TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _TarjetaGlobal(
          nombre: nombre,
          email: email,
          puntos: global,
          onNombreCambiado: onNombreCambiado,
        ),
        const SizedBox(height: 16),
        RachaPerfil(
          rachaDias: rachaDias,
          rachaMaxima: rachaMaxima,
          rachaAnterior: rachaAnterior,
          onRachaRestablecida: onRachaRestablecida,
        ),
        const SizedBox(height: 16),
        const Text(
          'Puntos globales por juego',
          style: TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        for (final juego in kCatalogoJuegos)
          _FilaPuntos(
            titulo: juego.nombre,
            puntos: puntos[juego.id] ?? 0,
          ),
      ],
    );
  }
}

class _TarjetaGlobal extends StatelessWidget {
  const _TarjetaGlobal({
    required this.nombre,
    required this.email,
    required this.puntos,
    required this.onNombreCambiado,
  });

  final String nombre;
  final String email;
  final int puntos;
  final VoidCallback onNombreCambiado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.acento.withValues(alpha: 0.08),
                AppColors.carta,
              ],
              stops: const [0.0, 0.42],
            ),
            border: Border.all(
              color: AppColors.acento.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.cartaBorde,
                child: Text(
                  nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      'Puntos globales',
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatoNumero(puntos),
                style: const TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        OpcionCambiarNombreUsuario(
          onCambiado: onNombreCambiado,
        ),
        const SizedBox(height: 12),
        const Text(
          'Mail registrado',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.azul.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.email_outlined,
                color: AppColors.azul,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email.isEmpty ? '—' : email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaPuntos extends StatelessWidget {
  const _FilaPuntos({required this.titulo, required this.puntos});

  final String titulo;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.carta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cartaBorde),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatoNumero(puntos),
            style: TextStyle(
              color: puntos > 0 ? AppColors.mint : AppColors.textoSuave,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
