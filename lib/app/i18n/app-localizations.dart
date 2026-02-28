import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, 'AppLocalizations not found in widget tree.');
    return instance!;
  }

  static const Map<String, Map<String, String>> _strings = <String, Map<String, String>>{
    'en': <String, String>{
      'appTitle': 'Uni Reader',
      'libraryTitle': 'Library',
      'emptyLibrary': 'No books yet',
      'openReader': 'Open Reader',
      'highlights': 'Highlights',
      'highlightAction': 'Highlight',
      'importBook': 'Import Book',
      'importDone': 'Import finished',
      'searchComingSoon': 'Search coming soon',
      'menuComingSoon': 'Menu coming soon',
    },
    'zh': <String, String>{
      'appTitle': 'Uni Reader',
      'libraryTitle': '书架',
      'emptyLibrary': '暂无书籍',
      'openReader': '开始阅读',
      'highlights': '划线',
      'highlightAction': '标注',
      'importBook': '导入书籍',
      'importDone': '导入完成',
      'searchComingSoon': '搜索功能开发中',
      'menuComingSoon': '菜单功能开发中',
    },
  };

  String tr(String key) {
    final lang = _strings[locale.languageCode] ?? _strings['en']!;
    return lang[key] ?? _strings['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => <String>{'en', 'zh'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
