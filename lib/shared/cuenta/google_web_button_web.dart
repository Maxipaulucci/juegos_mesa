import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Botón oficial de Google Identity Services (solo web).
Widget buildGoogleSignInWebButton({required bool registro}) {
  return gsi.renderButton(
    configuration: gsi.GSIButtonConfiguration(
      theme: gsi.GSIButtonTheme.outline,
      size: gsi.GSIButtonSize.large,
      text: registro
          ? gsi.GSIButtonText.signupWith
          : gsi.GSIButtonText.signinWith,
      shape: gsi.GSIButtonShape.rectangular,
      logoAlignment: gsi.GSIButtonLogoAlignment.left,
      minimumWidth: 280,
    ),
  );
}
