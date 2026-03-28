import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({required this.onAnimationComplete, super.key});

  final VoidCallback onAnimationComplete;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
    // Start animation after first frame so the blank beige background
    // renders first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortSide = MediaQuery.sizeOf(context).shortestSide;
    final iconSize = shortSide * 0.65;
    return Scaffold(
      backgroundColor: const Color(0xFFE8E4DF),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(iconSize * 0.2),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: iconSize,
              height: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
