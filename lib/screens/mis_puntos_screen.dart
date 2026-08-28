import 'package:flutter/material.dart';

import '../config/juegos_catalogo.dart';
import '../services/usuario_mongo_service.dart';
import '../shared/cuenta/cuenta_overlay.dart';
import '../shared/cuenta/racha_perfil.dart';
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tus puntos en cada juego',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w600,
                    ),
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
                              global: usuario.puntosGlobal,
                              puntos: usuario.puntos,
                              rachaDias: usuario.rachaDias,
                              rachaMaxima: usuario.rachaMaxima,
                              error: _error,
                              onReintentar: recargar,
                            ),
                ),
              ],
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
    required this.global,
    required this.puntos,
    required this.rachaDias,
    required this.rachaMaxima,
    required this.error,
    required this.onReintentar,
  });

  final String nombre;
  final int global;
  final Map<String, int> puntos;
  final int rachaDias;
  final int rachaMaxima;
  final String? error;
  final VoidCallback onReintentar;

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
        _TarjetaGlobal(nombre: nombre, puntos: global),
        const SizedBox(height: 16),
        RachaPerfil(
          rachaDias: rachaDias,
          rachaMaxima: rachaMaxima,
        ),
        const SizedBox(height: 16),
        const Text(
          'Por juego',
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
  const _TarjetaGlobal({required this.nombre, required this.puntos});

  final String nombre;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.acento.withValues(alpha: 0.28),
            AppColors.carta,
          ],
        ),
        border: Border.all(color: AppColors.acento, width: 1.6),
        boxShadow: neonGlow(AppColors.acento, blur: 12),
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
            '$puntos',
            style: const TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ],
      ),
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
            '$puntos',
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
