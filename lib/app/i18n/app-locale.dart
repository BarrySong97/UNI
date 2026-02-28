import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  static const String preferredLocaleKey = 'preferred_locale';
  static const Locale defaultLocale = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  Locale _locale = defaultLocale;

  Locale get locale => _locale;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(preferredLocaleKey);
    _locale = _resolve(stored) ?? defaultLocale;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    _locale = _resolve(locale.languageCode) ?? defaultLocale;
    await prefs.setString(preferredLocaleKey, _locale.languageCode);
    notifyListeners();
  }

  Locale? _resolve(String? languageCode) {
    if (languageCode == null) {
      return null;
    }
    for (final locale in supportedLocales) {
      if (locale.languageCode == languageCode) {
        return locale;
      }
    }
    return null;
  }
}
