import 'package:flutter/material.dart';

import '../../common/layout.dart';
import '../../database/pack_repository.dart';
import '../../models/pack_models.dart';
import '../../widgets/compact_navigation_bar.dart';
import '../../widgets/create_trip_dialog.dart';
import '../../widgets/page_frame.dart';
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
          'Pack',
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
                        subtitle: '随时回到上一次的打包进度',
                      ),
                      const SizedBox(height: 12),
                      ..._dashboard.activeTrips.map(_buildActiveTripCard),
                      const SizedBox(height: 28),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: _SectionHeader(
                            title: '常用模板',
                            subtitle: '先把 macOS 样板流程跑通，iOS / Android 共享同一套业务代码',
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        if (_dashboard.templates.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                '当前还没有模板，先创建一个 macOS 样板模板，再逐步扩到 iOS 和 Android。',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );
                        }
                        final crossAxisCount = width >= 960
                            ? 3
                            : width >= 620
                                ? 2
                                : 1;
                        return GridView.builder(
                          itemCount: _dashboard.templates.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: width >= 620 ? 1.42 : 1.18,
                          ),
                          itemBuilder: (context, index) {
                            final template = _dashboard.templates[index];
                            return _TemplateCard(
                              template: template,
                              onTap: () => _startTrip(template),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveTripCard(ActiveTripSummary trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openTrip(trip.id),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_outward_rounded),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '已完成 ${trip.checkedCount} / ${trip.totalCount}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: trip.progress,
                  borderRadius: BorderRadius.circular(999),
                  minHeight: 10,
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  final TemplateSummary template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.icon, style: const TextStyle(fontSize: 34)),
              const Spacer(),
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                template.useCount == 0 ? '尚未使用' : '已使用 ${template.useCount} 次',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
