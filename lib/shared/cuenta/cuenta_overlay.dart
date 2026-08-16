import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

enum _Pestania { login, registro }

/// Modal de cuenta: mismas pantallas que Maxturnos, paleta arcade de esta app.
class CuentaOverlay extends StatefulWidget {
  const CuentaOverlay({super.key, required this.onCerrar, this.onSesion});

  final VoidCallback onCerrar;
  final VoidCallback? onSesion;

  @override
  State<CuentaOverlay> createState() => _CuentaOverlayState();
}

class _CuentaOverlayState extends State<CuentaOverlay> {
  final _api = UsuarioMongoService.instance;
  _Pestania _tab = _Pestania.login;
  bool _verificando = false;

  final _usuario = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _codigo = TextEditingController();
  final _loginClave = TextEditingController();

  bool _ocultarPass = true;
  bool _ocultarPass2 = true;
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
      widget.onSesion?.call();
      widget.onCerrar();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
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
                          SingleChildScrollView(
                            child: _verificando
                                ? _pantallaCodigo()
                                : _api.haySesion
                                    ? _pantallaPerfil()
                                    : _pantallaAuth(),
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
        hint: 'usuario o ejemplo@email.com',
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
        child: Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            color: AppColors.textoSuave.withValues(alpha: 0.85),
            fontSize: 12,
            fontStyle: FontStyle.italic,
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
        hint: 'ejemplo@email.com',
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
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pantallaPerfil() {
    final u = _api.usuario!;
    final nick = u.nombreUsuario.isEmpty ? u.nombre : u.nombreUsuario;
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.azul.withValues(alpha: 0.25),
          child: Text(
            nick.isEmpty ? '?' : nick[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          nick,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          u.email,
          style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
        const SizedBox(height: 18),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.azul,
            borderRadius: BorderRadius.circular(12),
            boxShadow: neonGlow(AppColors.azul, blur: 12),
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
