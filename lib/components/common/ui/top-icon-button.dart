import 'package:flutter/material.dart';

class TopIconButton extends StatelessWidget {
  const TopIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      splashRadius: 20,
      tooltip: tooltip,
    );
  }
}
