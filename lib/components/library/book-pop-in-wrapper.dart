import 'package:flutter/material.dart';

enum _AnimationMode { none, popIn, slideRight }

class BookPopInWrapper extends StatefulWidget {
  const BookPopInWrapper({
    required this.child,
    this.animate = false,
    this.slideRight = false,
    super.key,
  });

  final Widget child;

  /// Pop-in animation (scale + fade) for newly imported books.
  final bool animate;

  /// Slide-from-left animation for existing books displaced by a new import.
  final bool slideRight;

  @override
  State<BookPopInWrapper> createState() => _BookPopInWrapperState();
}

class _BookPopInWrapperState extends State<BookPopInWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _slideFadeAnimation;

  _AnimationMode _mode = _AnimationMode.none;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Pop-in tweens
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(curved);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

    // Slide-right tweens
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(curved);
    _slideFadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(curved);

    _mode = _resolveMode(widget);
    if (_mode != _AnimationMode.none) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(BookPopInWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMode = _resolveMode(widget);
    final oldMode = _resolveMode(oldWidget);

    if (oldMode == _AnimationMode.none && newMode != _AnimationMode.none) {
      _mode = newMode;
      _controller.forward(from: 0);
    }
  }

  static _AnimationMode _resolveMode(BookPopInWrapper w) {
    if (w.animate) return _AnimationMode.popIn;
    if (w.slideRight) return _AnimationMode.slideRight;
    return _AnimationMode.none;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _AnimationMode.none) return widget.child;

    if (_mode == _AnimationMode.slideRight) {
      return FadeTransition(
        opacity: _slideFadeAnimation,
        child: SlideTransition(position: _slideAnimation, child: widget.child),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
