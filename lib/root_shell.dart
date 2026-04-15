import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'features/templates/template_list_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _selectedIndex == 0) return;
        _selectTab(0);
      },
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            currentTabIndex: _selectedIndex,
            onTabSelected: _selectTab,
          ),
          TemplateListPage(
            currentTabIndex: _selectedIndex,
            onTabSelected: _selectTab,
          ),
        ],
      ),
    );
  }
}
