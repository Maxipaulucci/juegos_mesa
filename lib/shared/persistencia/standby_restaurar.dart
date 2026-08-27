import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/culoSucio/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/desconfio/standby_store.dart';
import 'package:app_juegos_mesa/diezMil/standby_store.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/generala/standby_store.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_store.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/laPapa/standby_store.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';

/// Restaura partidas vs PC guardadas en disco al iniciar la app.
class StandbyRestaurar {
  StandbyRestaurar._();

  static Future<void> todos() async {
    await Future.wait([
      DiezMilStandByStore.restaurarDesdeDisco(),
      GeneralaStandByStore.restaurarDesdeDisco(),
      PapaStandByStore.restaurarDesdeDisco(),
      EscobaStandByStore.restaurarDesdeDisco(),
      UnoSoloStandByStore.restaurarDesdeDisco(),
      CuloSucioStandByStore.restaurarDesdeDisco(),
      CuloSucioV2StandByStore.restaurarDesdeDisco(),
      CasitaStandByStore.restaurarDesdeDisco(),
      ChanchoStandByStore.restaurarDesdeDisco(),
      GuerraStandByStore.restaurarDesdeDisco(),
      DesconfioStandByStore.restaurarDesdeDisco(),
      JodeteStandByStore.restaurarDesdeDisco(),
    ]);
  }
}
