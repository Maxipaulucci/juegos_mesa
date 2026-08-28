import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/cuenta/racha_perfil.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

enum _Pestania { login, registro }

enum _VistaCuenta { auth, recupMail, recupCodigo, recupPass }

/// Modal de cuenta: mismas pantallas que Maxturnos, paleta arcade de esta app.
class CuentaOverlay extends StatefulWidget {
  const CuentaOverlay({
    super.key,
    required this.onCerrar,
    this.onSesion,
    this.onExito,
  });

  final VoidCallback onCerrar;
  final VoidCallback? onSesion;
  final ValueChanged<String>? onExito;

  @override
  State<CuentaOverlay> createState() => _CuentaOverlayState();
}

class _CuentaOverlayState extends State<CuentaOverlay> {
  final _api = UsuarioMongoService.instance;
  _Pestania _tab = _Pestania.login;
  _VistaCuenta _vista = _VistaCuenta.auth;
  bool _verificando = false;

  final _usuario = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _codigo = TextEditingController();
  final _loginClave = TextEditingController();
  final _recupEmail = TextEditingController();
  final _nuevaPass = TextEditingController();
  final _nuevaPass2 = TextEditingController();

  bool _ocultarPass = true;
  bool _ocultarPass2 = true;
  bool _ocultarNueva = true;
  bool _ocultarNueva2 = true;
  bool _cargando = false;
  String? _error;
  String _emailPendiente = '';

  @override
  void dispose() {
    _usuario.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _codigo.dispose();
    _loginClave.dispose();
    _recupEmail.dispose();
    _nuevaPass.dispose();
    _nuevaPass2.dispose();
    super.dispose();
  }

  Future<void> _correr(Future<void> Function() fn) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await fn();
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _registrar() async {
    final user = formatoNombreUsuario(_usuario.text);
    final mail = _email.text.trim();
    final pass = _password.text;
    final pass2 = _password2.text;
    if (user.isEmpty || mail.isEmpty || pass.isEmpty || pass2.isEmpty) {
      setState(() => _error = 'Completá todos los campos.');
      return;
    }
    if (!usuarioNombreValido(user)) {
      setState(() => _error =
          'El usuario tiene que tener 3 a 20 caracteres: letras, números o _.');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    await _correr(() async {
      await _api.pedirRegistro(
        nombreUsuario: user,
        email: mail,
        password: pass,
      );
      _emailPendiente = mail;
      _codigo.clear();
      setState(() => _verificando = true);
    });
  }

  Future<void> _verificar() async {
    await _correr(() async {
      await _api.verificarRegistro(
        email: _emailPendiente,
        codigo: _codigo.text.trim(),
      );
      widget.onExito?.call('Registro exitoso!');
      widget.onSesion?.call();
      widget.onCerrar();
    });
  }

  Future<void> _reenviar() async {
    await _correr(() async {
      await _api.reenviarCodigo(email: _emailPendiente);
    });
  }

  Future<void> _login() async {
    if (_loginClave.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Ingresá usuario o email, y la contraseña.');
      return;
    }
    await _correr(() async {
      await _api.login(
        usuario: _loginClave.text.trim(),
        password: _password.text,
      );
      widget.onExito?.call('Inicio de sesión exitoso!');
      widget.onSesion?.call();
      widget.onCerrar();
    });
  }

  void _abrirRecuperacion() {
    final clave = _loginClave.text.trim();
    _recupEmail.text = clave.contains('@') ? clave : '';
    _codigo.clear();
    _nuevaPass.clear();
    _nuevaPass2.clear();
    setState(() {
      _vista = _VistaCuenta.recupMail;
      _error = null;
    });
  }

  void _volverLogin() {
    setState(() {
      _vista = _VistaCuenta.auth;
      _tab = _Pestania.login;
      _error = null;
      _verificando = false;
    });
  }

  Future<void> _enviarCodigoRecupero() async {
    final mail = _recupEmail.text.trim();
    if (mail.isEmpty) {
      setState(() => _error = 'Ingresá tu email.');
      return;
    }
    await _correr(() async {
      await _api.pedirRecuperacion(email: mail);
      _emailPendiente = mail;
      _codigo.clear();
      setState(() => _vista = _VistaCuenta.recupCodigo);
    });
  }

  Future<void> _verificarRecupero() async {
    await _correr(() async {
      await _api.verificarRecuperacion(
        email: _emailPendiente,
        codigo: _codigo.text.trim(),
      );
      _nuevaPass.clear();
      _nuevaPass2.clear();
      setState(() => _vista = _VistaCuenta.recupPass);
    });
  }

  Future<void> _reenviarRecupero() async {
    await _correr(() async {
      await _api.reenviarRecuperacion(email: _emailPendiente);
    });
  }

  Future<void> _restablecer() async {
    final pass = _nuevaPass.text;
    final pass2 = _nuevaPass2.text;
    if (pass.isEmpty || pass2.isEmpty) {
      setState(() => _error = 'Completá los dos campos.');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    await _correr(() async {
      await _api.restablecerClave(email: _emailPendiente, password: pass);
      _password.clear();
      widget.onExito?.call('Cambio de contraseña exitoso!');
      _volverLogin();
    });
  }

  Widget _cuerpoModal() {
    if (_api.haySesion) return _pantallaPerfil();
    if (_verificando) return _pantallaCodigo();
    switch (_vista) {
      case _VistaCuenta.recupMail:
        return _pantallaRecupMail();
      case _VistaCuenta.recupCodigo:
        return _pantallaRecupCodigo();
      case _VistaCuenta.recupPass:
        return _pantallaRecupPass();
      case _VistaCuenta.auth:
        return _pantallaAuth();
    }
  }

  /// Ancho tipico de telefono; no afecta tablet/desktop.
  bool _esCelular(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  @override
  Widget build(BuildContext context) {
    final celular = _esCelular(context);
    final perfil = _api.haySesion;
    // Perfil: cartel compacto al contenido. Auth/recup: más alto con scroll.
    final maxW = perfil ? (celular ? 400.0 : 440.0) : 420.0;
    final maxH = perfil
        ? MediaQuery.sizeOf(context).height * 0.88
        : 640.0;
    final paddingModal = celular
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 28);
    final paddingCuerpo = perfil
        ? EdgeInsets.fromLTRB(
            celular ? 22 : 28,
            celular ? 48 : 52,
            celular ? 22 : 28,
            celular ? 22 : 28,
          )
        : const EdgeInsets.fromLTRB(22, 62, 22, 22);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCerrar,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                child: Padding(
                  padding: paddingModal,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3B1D6E),
                            Color(0xFF1A0A33),
                            Color(0xFF2A1050),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.azul, width: 2),
                        boxShadow: neonGlow(AppColors.azul, blur: 18),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: paddingCuerpo,
                            child: SingleChildScrollView(
                              child: _cuerpoModal(),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 8,
                            child: Material(
                              color: AppColors.carta,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: widget.onCerrar,
                                child: const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Icon(
                                    Icons.close,
                                    color: AppColors.textoSuave,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantallaAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _tabBtn(
                'Iniciar sesión',
                _tab == _Pestania.login,
                () => setState(() {
                  _tab = _Pestania.login;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tabBtn(
                'Registrarse',
                _tab == _Pestania.registro,
                () => setState(() {
                  _tab = _Pestania.registro;
                  _error = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.peligro,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_tab == _Pestania.login) ..._camposLogin() else ..._camposRegistro(),
        if (_cargando) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.azul,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _camposLogin() {
    return [
      _campo(
        label: 'Usuario o email',
        hint: 'Usuario o ejemplo@email.com',
        controller: _loginClave,
        iconoIzq: Icons.email_outlined,
      ),
      const SizedBox(height: 12),
      _campo(
        label: 'Contraseña',
        hint: 'Tu contraseña',
        controller: _password,
        ocultar: _ocultarPass,
        iconoDer: _ocultarPass
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        onIconoDer: () => setState(() => _ocultarPass = !_ocultarPass),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _cargando ? null : _abrirRecuperacion,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.85),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _cta('Iniciar sesión', _cargando ? null : _login),
    ];
  }

  List<Widget> _camposRegistro() {
    return [
      _campo(
        label: 'Nombre de usuario',
        hint: 'Tu nombre',
        controller: _usuario,
        maxChars: 20,
        extraFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
          const _CapitalizarUsuarioFormatter(),
        ],
      ),
      const SizedBox(height: 12),
      _campo(
        label: 'Email',
        hint: 'Ejemplo@email.com',
        controller: _email,
        iconoIzq: Icons.email_outlined,
        teclado: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      _campo(
        label: 'Contraseña',
        hint: 'Crea una contraseña',
        controller: _password,
        ocultar: _ocultarPass,
        iconoDer: _ocultarPass
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        onIconoDer: () => setState(() => _ocultarPass = !_ocultarPass),
      ),
      const SizedBox(height: 12),
      _campo(
        label: 'Repetir contraseña',
        hint: 'Repite la contraseña',
        controller: _password2,
        ocultar: _ocultarPass2,
        iconoDer: _ocultarPass2
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        onIconoDer: () => setState(() => _ocultarPass2 = !_ocultarPass2),
      ),
      const SizedBox(height: 16),
      _cta('Registrarse', _cargando ? null : _registrar),
    ];
  }

  Widget _pantallaCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verifica tu email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hemos enviado un código de verificación a:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          _emailPendiente,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.carta.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'El código vence en 15 minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.peligro,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _campo(
          label: 'Código de verificación',
          hint: '0 0 0 0 0 0',
          controller: _codigo,
          iconoIzq: Icons.vpn_key_outlined,
          teclado: TextInputType.number,
          maxChars: 6,
        ),
        const SizedBox(height: 16),
        _cta('VERIFICAR', _cargando ? null : _verificar),
        const SizedBox(height: 18),
        const Divider(color: Color(0x33FFFFFF)),
        const SizedBox(height: 8),
        const Text(
          '¿No recibiste el código?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
        TextButton(
          onPressed: _cargando ? null : _reenviar,
          child: const Text(
            'Reenviar código',
            style: TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorSiHay() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        _error!,
        style: const TextStyle(
          color: AppColors.peligro,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _spinner() {
    if (!_cargando) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.azul,
          ),
        ),
      ),
    );
  }

  Widget _pantallaRecupMail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ingresa tu mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _errorSiHay(),
        _campo(
          label: 'Email',
          hint: 'ejemplo@email.com',
          controller: _recupEmail,
          iconoIzq: Icons.email_outlined,
          teclado: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _cta('Enviar código', _cargando ? null : _enviarCodigoRecupero),
        _spinner(),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _cargando ? null : _volverLogin,
          child: const Text(
            'Volver a iniciar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSuave,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pantallaRecupCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Recuperar contraseña',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hemos enviado un código de recuperación a:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          _emailPendiente,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 16),
        _errorSiHay(),
        _campo(
          label: 'Código de verificación',
          hint: '0 0 0 0 0 0',
          controller: _codigo,
          iconoIzq: Icons.vpn_key_outlined,
          teclado: TextInputType.number,
          maxChars: 6,
        ),
        const SizedBox(height: 16),
        _cta('Verificar', _cargando ? null : _verificarRecupero),
        _spinner(),
        const SizedBox(height: 16),
        const Text(
          '¿No recibiste el código?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
        TextButton(
          onPressed: _cargando ? null : _reenviarRecupero,
          child: const Text(
            'Reenviar código',
            style: TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pantallaRecupPass() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cambiar contraseña',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ingresa tu nueva contraseña',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
        ),
        const SizedBox(height: 18),
        _errorSiHay(),
        _campo(
          label: 'Nueva contraseña:',
          hint: 'Nueva contraseña',
          controller: _nuevaPass,
          ocultar: _ocultarNueva,
          iconoDer: _ocultarNueva
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onIconoDer: () => setState(() => _ocultarNueva = !_ocultarNueva),
        ),
        const SizedBox(height: 12),
        _campo(
          label: 'Repita su nueva contraseña:',
          hint: 'Repite la nueva contraseña',
          controller: _nuevaPass2,
          ocultar: _ocultarNueva2,
          iconoDer: _ocultarNueva2
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onIconoDer: () => setState(() => _ocultarNueva2 = !_ocultarNueva2),
        ),
        const SizedBox(height: 16),
        _cta('Restablecer contraseña', _cargando ? null : _restablecer),
        _spinner(),
      ],
    );
  }

  Widget _pantallaPerfil() {
    final u = _api.usuario!;
    final nick = u.nombreUsuario.isEmpty ? u.nombre : u.nombreUsuario;
    final celular = _esCelular(context);
    final radioAvatar = celular ? 36.0 : 44.0;
    final tamLetra = celular ? 26.0 : 32.0;
    final tamNick = celular ? 20.0 : 22.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: radioAvatar,
            backgroundColor: AppColors.azul.withValues(alpha: 0.28),
            child: Text(
              nick.isEmpty ? '?' : nick[0].toUpperCase(),
              style: TextStyle(
                color: AppColors.azul,
                fontWeight: FontWeight.w900,
                fontSize: tamLetra,
              ),
            ),
          ),
        ),
        SizedBox(height: celular ? 14 : 18),
        Text(
          nick,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w900,
            fontSize: tamNick,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          u.email,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textoSuave,
            fontSize: celular ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: celular ? 10 : 12),
        Text(
          '${u.monedas} monedas',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        SizedBox(height: celular ? 14 : 16),
        RachaPerfil(
          rachaDias: u.rachaDias,
          rachaMaxima: u.rachaMaxima,
          compacto: celular,
        ),
        SizedBox(height: celular ? 22 : 28),
        _cta('Cerrar sesión', () {
          _api.cerrarSesion();
          widget.onSesion?.call();
          widget.onCerrar();
        }),
      ],
    );
  }

  Widget _tabBtn(String label, bool activa, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _cargando ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: activa ? AppColors.azul : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.azul, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activa ? const Color(0xFF0B1A2E) : AppColors.azul,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cta(String label, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.azul,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0B1A2E),
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

  Widget _campo({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? iconoIzq,
    IconData? iconoDer,
    VoidCallback? onIconoDer,
    bool ocultar = false,
    TextInputType? teclado,
    int? maxChars,
    List<TextInputFormatter> extraFormatters = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: ocultar,
          enabled: !_cargando,
          keyboardType: teclado,
          inputFormatters: [
            if (maxChars != null) LengthLimitingTextInputFormatter(maxChars),
            if (teclado == TextInputType.number)
              FilteringTextInputFormatter.digitsOnly,
            ...extraFormatters,
          ],
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppColors.azul,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: iconoIzq == null
                ? null
                : Icon(iconoIzq, color: AppColors.azul, size: 20),
            suffixIcon: onIconoDer == null
                ? null
                : IconButton(
                    onPressed: onIconoDer,
                    icon: Icon(iconoDer, color: AppColors.azul, size: 20),
                  ),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.28),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.azul.withValues(alpha: 0.45),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.azul, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _CapitalizarUsuarioFormatter extends TextInputFormatter {
  const _CapitalizarUsuarioFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final formatted = t[0].toUpperCase() + t.substring(1).toLowerCase();
    if (formatted == t) return newValue;
    return TextEditingValue(
      text: formatted,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
