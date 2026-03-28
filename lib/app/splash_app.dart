import 'package:flutter/material.dart';

import '../pages/splash/splash_page.dart';
import 'bootstrap.dart';

class SplashApp extends StatefulWidget {
  const SplashApp({
    required this.bootstrapFuture,
    required this.onReady,
    super.key,
  });

  final Future<AppBootstrapResult> bootstrapFuture;
  final void Function(AppBootstrapResult result) onReady;

  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> {
  bool _animationDone = false;
  AppBootstrapResult? _bootstrapResult;

  @override
  void initState() {
    super.initState();
    widget.bootstrapFuture.then((result) {
      _bootstrapResult = result;
      _tryTransition();
    });
  }

  void _onAnimationComplete() {
    _animationDone = true;
    _tryTransition();
  }

  void _tryTransition() {
    if (_animationDone && _bootstrapResult != null) {
      widget.onReady(_bootstrapResult!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashPage(onAnimationComplete: _onAnimationComplete),
    );
  }
}
