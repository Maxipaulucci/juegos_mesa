/// Modo test opcional: `--dart-define=COFRES_SIEMPRE_LISTOS=true`
class CofresConfig {
  static const siempreListos = bool.fromEnvironment('COFRES_SIEMPRE_LISTOS');
}
