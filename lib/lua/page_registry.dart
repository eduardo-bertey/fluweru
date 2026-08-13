/// Registro de páginas Lua del bundle: nombre -> asset.
///
/// Desde Lua se navega con `navigate("player")`, `navigate("demo")`, etc.
/// Los handlers de LuaController registran la misma tabla como `pages`.
class PageRegistry {
  static const Map<String, String> pages = {
    'demo': 'assets/pages/demo.lua',
    'player': 'assets/pages/player.lua',
  };

  static String? assetFor(String name) => pages[name];

  /// Nombres en orden, para poder mostrar en la UI.
  static List<String> get names => pages.keys.toList();
}