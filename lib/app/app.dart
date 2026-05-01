import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/onboarding/onboarding_flow.dart';
import '../pages/shell/main-tab-shell-page.dart';
import 'i18n/app-locale.dart';
import 'i18n/app-localizations.dart';
import 'providers/app-providers.dart';
import 'routes/app-router.dart';
import 'theme/app-theme.dart';

class ImmersedApp extends StatefulWidget {
  const ImmersedApp({
    required this.providers,
    required this.showOnboarding,
    super.key,
  });

  final AppProviders providers;
  final bool showOnboarding;

  @override
  State<ImmersedApp> createState() => _ImmersedAppState();
}

class _ImmersedAppState extends State<ImmersedApp> with WidgetsBindingObserver {
  late bool _showOnboarding = widget.showOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(widget.providers.ttsService.releaseIdleResources());
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    widget.providers.ttsService.handleMemoryPressure();
  }

  void _onOnboardingComplete() {
    setState(() => _showOnboarding = false);
  }

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
            home: _showOnboarding
                ? OnboardingFlow(onComplete: _onOnboardingComplete)
                : const MainTabShellPage(),
          );
        },
      ),
    );
  }
}
