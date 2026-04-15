import 'package:flutter/material.dart';

const compactLayoutBreakpoint = 640.0;

bool isCompactLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width < compactLayoutBreakpoint;
}

EdgeInsets pageInsets(BuildContext context) {
  final compact = isCompactLayout(context);
  return EdgeInsets.fromLTRB(
    compact ? 16 : 20,
    compact ? 4 : 8,
    compact ? 16 : 20,
    compact ? 16 : 24,
  );
}
