import 'package:flutter/material.dart';

import '../common/layout.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1040,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: pageInsets(context),
            child: child,
          ),
        ),
      ),
    );
  }
}
