import 'package:flutter/material.dart';

import '../pages/shell/main-tab-shell-page.dart';
import 'i18n/app-locale.dart';
import 'i18n/app-localizations.dart';
import 'providers/app-providers.dart';
import 'routes/app-router.dart';
import 'theme/app-theme.dart';

class ImmersedApp extends StatefulWidget {
  const ImmersedApp({required this.providers, super.key});

  final AppProviders providers;

  @override
  State<ImmersedApp> createState() => _ImmersedAppState();
}

class _ImmersedAppState extends State<ImmersedApp> {
  @override
  Widget build(BuildContext context) {
    return AppProvidersScope(
      providers: widget.providers,
      child: AnimatedBuilder(
        animation: widget.providers.appLocaleController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: widget.providers.appLocaleController.locale,
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
