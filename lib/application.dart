import 'package:flutter/material.dart';

import 'common/app_theme.dart';
import 'root_shell.dart';

class PackApplication extends StatelessWidget {
  const PackApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pack',
      debugShowCheckedModeBanner: false,
      theme: buildPackTheme(),
      home: const RootShell(),
    );
  }
}
