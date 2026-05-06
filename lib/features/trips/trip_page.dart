import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../models/pack_models.dart';
import '../../widgets/page_frame.dart';
import 'debrief_page.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final _repository = PackRepository.instance;
  TripDetail? _detail;
  bool _loading = true;
  bool _editingChecklist = false;
  final Set<int> _updatingIds = <int>{};
  String? _hoveredCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.title ?? '行程'),
        actions: [
          if (!_loading && _detail != null && _detail!.canAdjustChecklist)
            TextButton(
              onPressed: () {
                setState(() {
                  _editingChecklist = !_editingChecklist;
                });
              },
              child: Text(_editingChecklist ? '完成调整' : '调整清单'),
            ),
          if (!_loading && _detail != null && _editingChecklist)
            IconButton(
              onPressed: _showAddItemSheet,
              tooltip: '新增条目',
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      bottomNavigationBar:
          !_loading && _detail != null && _detail!.isReadyForDebrief && compact
              ? SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: _openDebrief,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('结束行程并记录复盘'),
                  ),
                )
              : null,
      body: PageFrame(
        maxWidth: 940,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _buildProgressCard(),
                  if (_editingChecklist) ...[
                    const SizedBox(height: 16),
                    _buildEditingHintCard(),
                  ],
                  const SizedBox(height: 16),
                  if (_detail!.reminderItems.isNotEmpty) ...[
                    _buildReminderCard(),
                    const SizedBox(height: 16),
                  ],
                  ..._detail!.groups.map(_buildCategoryCard),
                  if (_detail!.isReadyForDebrief && !compact) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _openDebrief,
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('结束行程并记录复盘'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final detail = _detail!;
    final statusText = switch (detail.status) {
      TripStatus.packing => '打包中',
      TripStatus.departed => '已出发',
      TripStatus.completed => '已完成',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${detail.checkedCount} / ${detail.totalCount}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Chip(label: Text(statusText)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: detail.progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            Text(
              detail.isComplete ? '所有条目已勾选，可以直接进入复盘。' : '继续逐项确认，完成后就可以结束这次行程。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return Card(
      color: const Color(0xFFFFF6D8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '以往忘带',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._detail!.reminderItems.map(
              (item) => CheckboxListTile(
                value: item.checked,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(item.text),
                subtitle: item.forgotCount == null
                    ? null
                    : Text('历史上忘带 ${item.forgotCount} 次'),
                onChanged: _updatingIds.contains(item.id)
                    ? null
                    : (value) => _toggleItem(item.id, value ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingHintCard() {
    return Card(
      color: const Color(0xFFF5F1E8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '调整清单中',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '直接在当前行程里补条目、删条目，不用跳回模板。这里的改动先只作用于本次行程。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _showAddItemSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增条目'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(TripCategoryGroup group) {
    final isHovering = _editingChecklist && _hoveredCategory == group.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DragTarget<_DraggedTripItem>(
        onWillAcceptWithDetails: (details) {
          if (!_editingChecklist) return false;
          final data = details.data;
          return data.category != group.category &&
              !_updatingIds.contains(data.item.id);
        },
        onMove: (details) {
          if (_hoveredCategory != group.category) {
            setState(() {
              _hoveredCategory = group.category;
            });
          }
        },
        onLeave: (_) {
          if (_hoveredCategory == group.category) {
            setState(() {
              _hoveredCategory = null;
            });
          }
        },
        onAcceptWithDetails: (details) {
          setState(() {
            _hoveredCategory = null;
          });
          _moveTripItemToCategory(
            details.data.item,
            targetCategory: group.category,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final showDropState = isHovering || candidateData.isNotEmpty;
          return Card(
            color: showDropState
                ? Theme.of(context).colorScheme.primaryContainer.withValues(
                      alpha: 0.35,
                    )
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: showDropState
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: showDropState ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.category,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_editingChecklist)
                        TextButton.icon(
                          onPressed: () =>
                              _showAddItemSheet(category: group.category),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(showDropState ? '放到这里' : '添加'),
                        ),
                    ],
                  ),
                  if (showDropState) ...[
                    const SizedBox(height: 8),
                    Text(
                      '松手后会移动到这个分组末尾',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  ...group.items.map(
                    (item) => _buildTripItemRow(item, category: group.category),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripItemRow(TripChecklistItem item, {required String category}) {
    final disabled = _updatingIds.contains(item.id);
    final row = Row(
      children: [
        Checkbox(
          value: item.checked,
          onChanged:
              disabled ? null : (value) => _toggleItem(item.id, value ?? false),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _editingChecklist && !disabled
                ? () => _showEditItemSheet(item, category: category)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                item.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        if (_editingChecklist)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.drag_indicator_rounded, size: 18),
              ),
              IconButton(
                onPressed: disabled
                    ? null
                    : () => _showEditItemSheet(item, category: category),
                tooltip: '编辑条目',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: disabled ? null : () => _deleteTripItem(item),
                tooltip: '删除条目',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _editingChecklist
          ? LongPressDraggable<_DraggedTripItem>(
              data: _DraggedTripItem(item: item, category: category),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              onDragEnd: (_) {
                if (mounted) {
                  setState(() {
                    _hoveredCategory = null;
                  });
                }
              },
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 8),
                        color: Color(0x22000000),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_indicator_rounded),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          item.text,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.28,
                child: IgnorePointer(child: row),
              ),
              child: row,
            )
          : row,
    );
  }

  Future<void> _moveTripItemToCategory(
    TripChecklistItem item, {
    required String targetCategory,
  }) async {
    final detail = _detail;
    if (detail == null) return;

    TripCategoryGroup? sourceGroup;
    for (final group in detail.groups) {
      if (group.items.any((groupItem) => groupItem.id == item.id)) {
        sourceGroup = group;
        break;
      }
    }
    if (sourceGroup == null || sourceGroup.category == targetCategory) {
      return;
    }

    setState(() {
      _updatingIds.add(item.id);
    });
    try {
      _repository.updateTripItem(
        item.id,
        category: targetCategory,
        text: item.text,
      );
      await _reloadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将“${item.text}”移到 $targetCategory')),
      );
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(item.id);
          _hoveredCategory = null;
        });
      }
    }
  }

  Future<void> _toggleItem(int itemId, bool checked) async {
    setState(() {
      _updatingIds.add(itemId);
    });
    try {
      _repository.toggleTripItem(itemId, checked);
      var detail = _repository.loadTripDetail(widget.tripId);
      if (detail.isComplete && detail.status == TripStatus.packing) {
        _repository.departTrip(widget.tripId);
        detail = _repository.loadTripDetail(widget.tripId);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
      });
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(itemId);
        });
      }
    }
  }

  Future<void> _openDebrief() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebriefPage(
          tripId: widget.tripId,
          tripName: _detail!.templateName,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _showAddItemSheet({String? category}) async {
    final detail = _detail;
    if (detail == null) return;

    final result = await showModalBottomSheet<_TripItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TripItemEditorSheet(
        title: '新增条目',
        submitLabel: '加入本次行程',
        initialCategory: category,
        initialText: '',
        categories: detail.groups.map((group) => group.category).toList(),
      ),
    );
    if (result == null) return;

    try {
      _repository.addTripItem(widget.tripId, result.category, result.text);
      await _reloadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加“${result.text}”')),
      );
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _showEditItemSheet(
    TripChecklistItem item, {
    required String category,
  }) async {
    final detail = _detail;
    if (detail == null) return;

    final result = await showModalBottomSheet<_TripItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TripItemEditorSheet(
        title: '编辑条目',
        submitLabel: '保存修改',
        initialCategory: category,
        initialText: item.text,
        categories: detail.groups.map((group) => group.category).toList(),
      ),
    );
    if (result == null) return;

    final textChanged = result.text != item.text;
    final categoryChanged = result.category != category;
    if (!textChanged && !categoryChanged) return;

    setState(() {
      _updatingIds.add(item.id);
    });
    try {
      _repository.updateTripItem(
        item.id,
        category: result.category,
        text: result.text,
      );
      await _reloadDetail();
      if (!mounted) return;
      final message = categoryChanged && textChanged
          ? '已更新“${item.text}”，并移到 ${result.category}'
          : categoryChanged
              ? '已将“${item.text}”移到 ${result.category}'
              : '已更新“${result.text}”';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _deleteTripItem(TripChecklistItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确认从本次行程移除“${item.text}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _updatingIds.add(item.id);
    });
    try {
      _repository.deleteTripItem(item.id);
      await _reloadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除“${item.text}”')),
      );
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _reloadDetail() async {
    var detail = _repository.loadTripDetail(widget.tripId);
    if (detail.isComplete && detail.status == TripStatus.packing) {
      _repository.departTrip(widget.tripId);
      detail = _repository.loadTripDetail(widget.tripId);
    }
    if (!mounted) return;
    setState(() {
      _detail = detail;
      if (!detail.canAdjustChecklist) {
        _editingChecklist = false;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final detail = _repository.loadTripDetail(widget.tripId);
      _detail = detail;
      if (!detail.canAdjustChecklist) {
        _editingChecklist = false;
      }
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      Navigator.of(context).pop();
      return;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

class _DraggedTripItem {
  const _DraggedTripItem({
    required this.item,
    required this.category,
  });

  final TripChecklistItem item;
  final String category;
}

class _TripItemDraft {
  const _TripItemDraft({
    required this.category,
    required this.text,
  });

  final String category;
  final String text;
}

class _TripItemEditorSheet extends StatefulWidget {
  const _TripItemEditorSheet({
    required this.title,
    required this.submitLabel,
    required this.initialCategory,
    required this.initialText,
    required this.categories,
  });

  final String title;
  final String submitLabel;
  final String? initialCategory;
  final String initialText;
  final List<String> categories;

  @override
  State<_TripItemEditorSheet> createState() => _TripItemEditorSheetState();
}

class _TripItemEditorSheetState extends State<_TripItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _categoryController =
        TextEditingController(text: widget.initialCategory ?? '');
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categorySuggestions = widget.categories
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (categorySuggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categorySuggestions)
                    ActionChip(
                      label: Text(category),
                      onPressed: () {
                        _categoryController.text = category;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '分组',
                hintText: '例如：证件 / 洗漱 / 数码',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入分组';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _textController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '条目名称',
                hintText: '例如：身份证、充电器、睡衣',
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入条目名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      widget.initialText.isEmpty
                          ? Icons.add_rounded
                          : Icons.save_rounded,
                    ),
                    label: Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TripItemDraft(
        category: _categoryController.text.trim(),
        text: _textController.text.trim(),
      ),
    );
  }
}
