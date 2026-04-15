import 'package:flutter/material.dart';

import '../common/layout.dart';

Future<int?> showCreateTripPrompt({
  required BuildContext context,
  required String templateName,
  required String templateIcon,
  required Future<int> Function(String destination) onCreate,
}) {
  final compact = isCompactLayout(context);
  if (compact) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: _CreateTripPanel(
          templateName: templateName,
          templateIcon: templateIcon,
          onCreate: onCreate,
        ),
      ),
    );
  }

  return showDialog<int>(
    context: context,
    builder: (context) => CreateTripDialog(
      templateName: templateName,
      templateIcon: templateIcon,
      onCreate: onCreate,
    ),
  );
}

class CreateTripDialog extends StatefulWidget {
  const CreateTripDialog({
    super.key,
    required this.templateName,
    required this.templateIcon,
    required this.onCreate,
  });

  final String templateName;
  final String templateIcon;
  final Future<int> Function(String destination) onCreate;

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripPanel extends StatefulWidget {
  const _CreateTripPanel({
    required this.templateName,
    required this.templateIcon,
    required this.onCreate,
  });

  final String templateName;
  final String templateIcon;
  final Future<int> Function(String destination) onCreate;

  @override
  State<_CreateTripPanel> createState() => _CreateTripPanelState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.templateIcon} ${widget.templateName}'),
      content: _CreateTripForm(
        onCreate: widget.onCreate,
      ),
    );
  }
}

class _CreateTripPanelState extends State<_CreateTripPanel> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.templateIcon} ${widget.templateName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          _CreateTripForm(onCreate: widget.onCreate),
        ],
      ),
    );
  }
}

class _CreateTripForm extends StatefulWidget {
  const _CreateTripForm({
    required this.onCreate,
  });

  final Future<int> Function(String destination) onCreate;

  @override
  State<_CreateTripForm> createState() => _CreateTripFormState();
}

class _CreateTripFormState extends State<_CreateTripForm> {
  final _destinationController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _destinationController,
          decoration: InputDecoration(
            labelText: '目的地（可选）',
            hintText: '例如：杭州、东京、深圳',
            errorText: _error,
          ),
          autofocus: true,
          onSubmitted: (_) => _handleCreate(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!compact)
              Expanded(
                child: TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
            if (!compact) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleCreate,
                child: Text(_submitting ? '创建中...' : '开始打包'),
              ),
            ),
          ],
        ),
        if (compact) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tripId = await widget.onCreate(_destinationController.text);
      if (!mounted) return;
      Navigator.of(context).pop(tripId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
