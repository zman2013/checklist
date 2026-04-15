import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../widgets/page_frame.dart';

class DebriefPage extends StatefulWidget {
  const DebriefPage({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  final int tripId;
  final String tripName;

  @override
  State<DebriefPage> createState() => _DebriefPageState();
}

class _DebriefPageState extends State<DebriefPage> {
  final _repository = PackRepository.instance;
  final _forgottenController = TextEditingController();
  final _surplusController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _forgottenController.dispose();
    _surplusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);

    return Scaffold(
      appBar: AppBar(title: const Text('行程复盘')),
      bottomNavigationBar: compact
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_submitting ? '保存中...' : '保存并结束行程'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => _submit(skipInputs: true),
                      child: const Text('跳过复盘，直接结束'),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: PageFrame(
        maxWidth: 760,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tripName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这一步会把你的遗忘和冗余物品记录到模板里，下次创建同类行程时自动带出提醒。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _forgottenController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '忘带了什么？',
                        hintText: '每行一条，例如：\n充电宝\n雨伞',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _surplusController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '带多了什么？',
                        hintText: '可选，每行一条',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.save_rounded),
                label: Text(_submitting ? '保存中...' : '保存并结束行程'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitting ? null : () => _submit(skipInputs: true),
                child: const Text('跳过复盘，直接结束'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit({bool skipInputs = false}) async {
    setState(() {
      _submitting = true;
    });
    try {
      _repository.submitDebrief(
        widget.tripId,
        forgotten:
            skipInputs ? const [] : _splitLines(_forgottenController.text),
        surplus: skipInputs ? const [] : _splitLines(_surplusController.text),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on PackRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  List<String> _splitLines(String input) {
    return input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
