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
  final Set<int> _updatingIds = <int>{};

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
                children: [
                  _buildProgressCard(),
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
              detail.isComplete
                  ? '所有条目已勾选，可以直接进入复盘。'
                  : '把 macOS 样板流程先跑顺，移动端会复用同一套逻辑。',
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

  Widget _buildCategoryCard(TripCategoryGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.category,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...group.items.map(
                (item) => CheckboxListTile(
                  value: item.checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.text),
                  onChanged: _updatingIds.contains(item.id)
                      ? null
                      : (value) => _toggleItem(item.id, value ?? false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      _detail = _repository.loadTripDetail(widget.tripId);
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
