import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../models/pack_models.dart';
import '../../widgets/compact_navigation_bar.dart';
import '../../widgets/create_trip_dialog.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/template_summary_row.dart';
import '../templates/template_editor_page.dart';
import '../templates/template_list_page.dart';
import '../trips/trip_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.currentTabIndex,
    this.onTabSelected,
  });

  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = PackRepository.instance;
  DashboardData _dashboard = const DashboardData(
    templates: <TemplateSummary>[],
    activeTrips: <ActiveTripSummary>[],
  );
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
        title: Text(
          '检查清单',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 26 : 30,
          ),
        ),
        actions: showCompactNavigation
            ? null
            : [
                IconButton(
                  tooltip: '管理模板',
                  onPressed: _openTemplateList,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
      ),
      bottomNavigationBar: showCompactNavigation
          ? PackCompactNavigationBar(
              selectedIndex: widget.currentTabIndex!,
              onDestinationSelected: widget.onTabSelected!,
            )
          : null,
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              onPressed: _createTemplate,
              icon: const Icon(Icons.add),
              label: const Text('新建模板'),
            )
          : null,
      body: PageFrame(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_dashboard.activeTrips.isNotEmpty) ...[
                      const _SectionHeader(
                        title: '进行中的行程',
                        subtitle: '继续上一次的进度，不用重新翻找。',
                      ),
                      const SizedBox(height: 12),
                      ..._dashboard.activeTrips.map(_buildActiveTripRow),
                      const SizedBox(height: 28),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: _SectionHeader(
                            title: '常用模板',
                            subtitle: '每个模板一条横向信息栏，直接看清用途和条目规模。',
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _createTemplate,
                            icon: const Icon(Icons.add),
                            label: const Text('新建模板'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_dashboard.templates.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            '当前还没有模板，先创建一个 macOS 样板模板，再逐步扩到 iOS 和 Android。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _dashboard.templates
                            .map(
                              (template) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TemplateSummaryRow(
                                  template: template,
                                  onTap: () => _startTrip(template),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveTripRow(ActiveTripSummary trip) {
    final colors = Theme.of(context).colorScheme;
    final percent = (trip.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openTrip(trip.id),
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
                  child: const Icon(Icons.luggage_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已完成 ${trip.checkedCount}/${trip.totalCount} · $percent%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trip.destination == null || trip.destination!.isEmpty
                            ? '继续完善这个行程的打包进度。'
                            : '目的地：${trip.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: trip.progress,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startTrip(TemplateSummary template) async {
    final tripId = await showCreateTripPrompt(
      context: context,
      templateName: template.name,
      templateIcon: template.icon,
      onCreate: (destination) async {
        return _repository.createTrip(
          template.id,
          destination: destination.trim(),
        );
      },
    );

    if (!mounted || tripId == null) return;
    await _openTrip(tripId);
  }

  Future<void> _openTrip(int tripId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripPage(tripId: tripId),
      ),
    );
    if (mounted) {
      await _reload();
    }
  }

  Future<void> _openTemplateList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TemplateListPage(),
      ),
    );
    if (mounted) {
      await _reload();
    }
  }

  Future<void> _createTemplate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TemplateEditorPage(),
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
      _dashboard = _repository.loadDashboard();
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
