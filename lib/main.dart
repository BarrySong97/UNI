import 'package:flutter/widgets.dart';

import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await AppBootstrap.initialize();
  runApp(context.app);
}
