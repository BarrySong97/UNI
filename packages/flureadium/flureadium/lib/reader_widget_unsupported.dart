import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

class ReadiumReaderWidget extends StatelessWidget {
  const ReadiumReaderWidget({
    required this.publication,
    this.loadingWidget = const Center(child: CircularProgressIndicator()),
    this.initialLocator,
    this.onTap,
    this.onGoLeft,
    this.onGoRight,
    this.onSwipe,
    this.onExternalLinkActivated,
    this.onLocatorChanged,
    this.onReady,
    super.key,
  });

  final Publication publication;
  final Widget loadingWidget;
  final Locator? initialLocator;
  final VoidCallback? onTap;
  final VoidCallback? onGoLeft;
  final VoidCallback? onGoRight;
  final VoidCallback? onSwipe;
  final Function(String)? onExternalLinkActivated;
  final void Function(Locator)? onLocatorChanged;

  /// Not invoked on unsupported platforms.
  final VoidCallback? onReady;

  @override
  Widget build(final BuildContext context) =>
      Center(child: Text('ReaderWidget is not available on this platform.'));
}
