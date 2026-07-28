import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Color de UI para cada dificultad.
extension DificultadPcUi on DificultadPc {
  Color get color => switch (this) {
        DificultadPc.facil => AppColors.mint,
        DificultadPc.medio => AppColors.acento,
        DificultadPc.dificil => AppColors.peligro,
      };
}
