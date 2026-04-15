import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../models/pack_models.dart';
import '../../widgets/page_frame.dart';

class TemplateEditorPage extends StatefulWidget {
  const TemplateEditorPage({super.key, this.templateId});

  final int? templateId;

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  final _repository = PackRepository.instance;
  final _nameController = TextEditingController();
  final _iconController = TextEditingController(text: '🧳');
  final _categoryController = TextEditingController(text: '基础');
  final _itemController = TextEditingController();

  int? _templateId;
  TemplateDetail? _template;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _templateId = widget.templateId;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _categoryController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_templateId == null ? '新建模板' : '编辑模板'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveTemplateMeta,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveTemplateMeta,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? '保存中...' : '保存模板'),
              ),
            )
          : null,
      body: PageFrame(
        maxWidth: 920,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '模板信息',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Flex(
                            direction:
                                compact ? Axis.vertical : Axis.horizontal,
                            children: [
                              SizedBox(
                                width: compact ? double.infinity : 110,
                                child: TextField(
                                  controller: _iconController,
                                  decoration: const InputDecoration(
                                    labelText: '图标',
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width: compact ? 0 : 12,
                                  height: compact ? 12 : 0),
                              Expanded(
                                flex: compact ? 0 : 1,
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: '模板名称',
                                    hintText: '例如：商务出行',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildItemsSection(),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '添加条目',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              labelText: '分组',
                              hintText: '例如：文件、电子设备',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _itemController,
                            decoration: const InputDecoration(
                              labelText: '条目名称',
                              hintText: '例如：充电器、护照',
                            ),
                            onSubmitted: (_) => _addItem(),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('添加条目'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_templateId != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _deleteTemplate,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('删除模板'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final grouped = <String, List<TemplateItemModel>>{};
    for (final item in _template?.items ?? <TemplateItemModel>[]) {
      grouped.putIfAbsent(item.category, () => <TemplateItemModel>[]);
      grouped[item.category]!.add(item);
    }

    if (grouped.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '还没有条目。先保存模板信息，然后按分组添加你的清单。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: grouped.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.text),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑条目',
                            onPressed: () => _editItem(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除条目',
                            onPressed: () => _deleteItem(item.id),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      if (_templateId == null) {
        _template = null;
      } else {
        _template = _repository.loadTemplateDetail(_templateId!);
        _nameController.text = _template!.name;
        _iconController.text = _template!.icon;
      }
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

  Future<void> _saveTemplateMeta() async {
    setState(() {
      _saving = true;
    });
    try {
      if (_templateId == null) {
        _templateId = _repository.createTemplate(
          _nameController.text,
          _iconController.text,
        );
      } else {
        _repository.updateTemplate(
          _templateId!,
          _nameController.text,
          _iconController.text,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板已保存')),
      );
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addItem() async {
    setState(() {
      _saving = true;
    });
    try {
      await _ensureTemplateExists();
      _repository.addTemplateItem(
        _templateId!,
        _categoryController.text,
        _itemController.text,
      );
      _itemController.clear();
      await _load();
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editItem(TemplateItemModel item) async {
    final controller = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑条目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '条目名称'),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      _repository.updateTemplateItem(item.id, result);
      await _load();
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _deleteItem(int itemId) async {
    try {
      _repository.deleteTemplateItem(itemId);
      await _load();
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _deleteTemplate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: const Text('删除后无法恢复。若存在进行中的行程，将无法删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || _templateId == null) return;
    try {
      _repository.deleteTemplate(_templateId!);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _ensureTemplateExists() async {
    if (_templateId != null) {
      _repository.updateTemplate(
        _templateId!,
        _nameController.text,
        _iconController.text,
      );
      return;
    }

    _templateId = _repository.createTemplate(
      _nameController.text,
      _iconController.text,
    );
  }
}
