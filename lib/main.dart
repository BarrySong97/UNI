import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/bootstrap.dart';
import 'app/splash_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapCompleter = Completer<AppBootstrapResult>();

  // Phase 1: Show splash immediately.
  runApp(SplashApp(
    bootstrapFuture: bootstrapCompleter.future,
    onReady: (result) {
      // Phase 2: Replace with the real app.
      runApp(result.app);
    },
  ));

  // Run bootstrap in the background while splash animates.
  final context = await AppBootstrap.initialize();
  bootstrapCompleter.complete(context);
}
