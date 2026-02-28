import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
