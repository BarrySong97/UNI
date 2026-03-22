import 'package:flutter/widgets.dart';

const double kTabletBreakpoint = 600;
const double kContentMaxWidth = 640;
const double kWideContentMaxWidth = 960;
const double kTabBarMaxWidth = 400;

class ResponsiveContentWrapper extends StatelessWidget {
  const ResponsiveContentWrapper({
    required this.child,
    this.maxWidth = kContentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

int responsiveGridColumns(double availableWidth) {
  if (availableWidth >= 900) return 4;
  if (availableWidth >= 600) return 3;
  return 2;
}
