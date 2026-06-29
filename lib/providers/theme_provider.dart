import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UPRISE Design System — Theme Provider
///
/// Persists the user's theme preference across app restarts.
///
/// Setup:
/// ```dart
/// // In main.dart, before runApp():
/// final themeProvider = ThemeProvider();
/// await themeProvider.init();
///
/// runApp(
///   ChangeNotifierProvider.value(
///     value: themeProvider,
///     child: const UpriseApp(),
///   ),
/// );
/// ```
///
/// In MaterialApp:
/// ```dart
/// Consumer<ThemeProvider>(
///   builder: (_, provider, __) => MaterialApp(
///     theme:      AppTheme.light,
///     darkTheme:  AppTheme.dark,
///     themeMode:  provider.themeMode,
///   ),
/// )
/// ```
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'uprise_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// The currently active [ThemeMode].
  ThemeMode get themeMode => _themeMode;

  /// Whether the app is running in dark mode right now.
  /// (Only accurate when you have access to a [BuildContext].)
  bool isDark(BuildContext context) =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  // ── Initialise from disk ────────────────────────────────────────

  /// Must be awaited once before [runApp] so the first frame is correct.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _themeMode = _fromString(saved) ?? ThemeMode.system;
    // No notifyListeners() here — called before the widget tree exists.
  }

  // ── Setters ──────────────────────────────────────────────────────

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _persist(mode);
  }

  Future<void> setLight() => setThemeMode(ThemeMode.light);
  Future<void> setDark()  => setThemeMode(ThemeMode.dark);
  Future<void> setSystem() => setThemeMode(ThemeMode.system);

  Future<void> toggle(BuildContext context) async {
    if (isDark(context)) {
      await setLight();
    } else {
      await setDark();
    }
  }

  // ── Persistence ──────────────────────────────────────────────────

  Future<void> _persist(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _toString(mode));
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode? _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}
