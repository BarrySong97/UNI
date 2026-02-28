import 'package:flutter/material.dart';

import '../pages/shell/main-tab-shell-page.dart';
import 'i18n/app-locale.dart';
import 'i18n/app-localizations.dart';
import 'providers/app-providers.dart';
import 'routes/app-router.dart';
import 'theme/app-theme.dart';

class UniApp extends StatelessWidget {
  const UniApp({required this.providers, super.key});

  final AppProviders providers;

  @override
  Widget build(BuildContext context) {
    return AppProvidersScope(
      providers: providers,
      child: AnimatedBuilder(
        animation: providers.appLocaleController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: providers.appLocaleController.locale,
            supportedLocales: AppLocaleController.supportedLocales,
            localizationsDelegates: AppLocalizations.delegates,
            onGenerateRoute: AppRouter.onGenerateRoute,
            theme: AppTheme.light,
            home: const MainTabShellPage(),
          );
        },
      ),
    );
  }
}
