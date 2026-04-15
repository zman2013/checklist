import 'package:flutter/material.dart';

import 'application.dart';
import 'database/pack_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PackRepository.instance.initialize();
  runApp(const PackApplication());
}
