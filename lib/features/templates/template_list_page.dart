import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../models/pack_models.dart';
import '../../widgets/compact_navigation_bar.dart';
import '../../widgets/page_frame.dart';
import 'template_editor_page.dart';

class TemplateListPage extends StatefulWidget {
  const TemplateListPage({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  State<TemplateListPage> createState() => _TemplateListPageState();
}

class _TemplateListPageState extends State<TemplateListPage> {
  final _repository = PackRepository.instance;
  List<TemplateSummary> _templates = const <TemplateSummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    final showCompactNavigation = compact &&
        widget.currentTabIndex != null &&
        widget.onTabSelected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('模板管理'),
      ),
      bottomNavigationBar: showCompactNavigation
          ? PackCompactNavigationBar(
              selectedIndex: widget.currentTabIndex!,
              onDestinationSelected: widget.onTabSelected!,
            )
          : null,
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('新建模板'),
            )
          : null,
      body: PageFrame(
        maxWidth: 900,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_templates.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            '还没有模板，先创建一个作为多平台样板。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: _templates
                              .map(
                                (template) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  leading: Text(
                                    template.icon,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  title: Text(template.name),
                                  subtitle: Text(
                                    template.useCount == 0
                                        ? '未使用'
                                        : '已使用 ${template.useCount} 次',
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => _openEditor(template.id),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (!compact) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openEditor(null),
                        icon: const Icon(Icons.add),
                        label: const Text('新建模板'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openEditor(int? templateId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TemplateEditorPage(templateId: templateId),
      ),
    );
    if (mounted) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    try {
      _templates = _repository.loadTemplates();
    } on PackRepositoryException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
