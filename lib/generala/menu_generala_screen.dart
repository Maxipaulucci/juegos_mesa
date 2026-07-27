import 'package:flutter/material.dart';

import '../diezMil/menu_diez_mil_screen.dart';

/// Menú de Generala: reutiliza el layout completo de Diez Mil.
class MenuGeneralaScreen extends StatelessWidget {
  const MenuGeneralaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MenuDiezMilScreen(
      titulo: 'Generala',
      juegoId: MenuDiezMilScreen.juegoIdGenerala,
    );
  }
}
