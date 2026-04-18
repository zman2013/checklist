import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack/models/pack_models.dart';
import 'package:pack/widgets/compact_navigation_bar.dart';
import 'package:pack/widgets/page_frame.dart';

void main() {
  test('active trip summary computes title and progress', () {
    const summary = ActiveTripSummary(
      id: 1,
      templateName: '商务出行',
      destination: '上海',
      checkedCount: 3,
      totalCount: 4,
    );

    expect(summary.title, '商务出行 · 上海');
    expect(summary.progress, 0.75);
  });

  test('trip detail derived flags match status and count', () {
    const detail = TripDetail(
      id: 1,
      templateId: 10,
      templateName: '徒步',
      templateIcon: '🥾',
      destination: null,
      status: TripStatus.departed,
      groups: <TripCategoryGroup>[],
      reminderItems: <TripChecklistItem>[],
      totalCount: 5,
      checkedCount: 5,
    );

    expect(detail.title, '🥾 徒步');
    expect(detail.isComplete, isTrue);
    expect(detail.isReadyForDebrief, isTrue);
    expect(detail.canAdjustChecklist, isTrue);
  });

  test('completed trip detail can no longer adjust checklist', () {
    const detail = TripDetail(
      id: 2,
      templateId: 11,
      templateName: '商务出行',
      templateIcon: '💼',
      destination: '上海',
      status: TripStatus.completed,
      groups: <TripCategoryGroup>[],
      reminderItems: <TripChecklistItem>[],
      totalCount: 3,
      checkedCount: 3,
    );

    expect(detail.canAdjustChecklist, isFalse);
  });

  test('db status parser falls back to packing', () {
    expect(tripStatusFromDb('packing'), TripStatus.packing);
    expect(tripStatusFromDb('departed'), TripStatus.departed);
    expect(tripStatusFromDb('completed'), TripStatus.completed);
    expect(tripStatusFromDb('unknown'), TripStatus.packing);
  });

  testWidgets('page frame renders child content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PageFrame(
            child: Text('Pack'),
          ),
        ),
      ),
    );

    expect(find.text('Pack'), findsOneWidget);
  });

  testWidgets('compact navigation bar exposes mobile destinations',
      (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: PackCompactNavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);

    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
  });
}
