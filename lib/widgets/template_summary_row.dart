import 'package:flutter/material.dart';

import '../models/pack_models.dart';

class TemplateSummaryRow extends StatelessWidget {
  const TemplateSummaryRow({
    super.key,
    required this.template,
    required this.onTap,
    this.trailing,
  });

  final TemplateSummary template;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = template.previewItems.take(2).join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  template.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.categoryCount} 个分组 · ${template.itemCount} 个条目 · ${template.usageLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.primary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
