import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/app/i18n/app-locale.dart';

void main() {
  test('default locale is english when no preference exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = AppLocaleController();

    await controller.initialize();

    expect(controller.locale, const Locale('en'));
  });

  test('stored preference is loaded and persisted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'preferred_locale': 'zh'});
    final controller = AppLocaleController();

    await controller.initialize();
    expect(controller.locale, const Locale('zh'));

    await controller.setLocale(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('preferred_locale'), 'en');
  });
}
