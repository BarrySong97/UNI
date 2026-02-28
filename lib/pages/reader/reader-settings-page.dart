import 'package:flutter/material.dart';

import '../../app/i18n/app-locale.dart';
import '../../app/providers/app-providers.dart';
import '../../shared/ui/app-scaffold.dart';

class ReaderSettingsPage extends StatelessWidget {
  const ReaderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = AppProvidersScope.of(context).appLocaleController;

    return AppScaffold(
      title: 'Reader Settings',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Language'),
            const SizedBox(height: 8),
            DropdownButton<Locale>(
              value: localeController.locale,
              items: AppLocaleController.supportedLocales
                  .map(
                    (locale) => DropdownMenuItem<Locale>(
                      value: locale,
                      child: Text(locale.languageCode),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (locale) {
                if (locale == null) {
                  return;
                }
                localeController.setLocale(locale);
              },
            ),
          ],
        ),
      ),
    );
  }
}
