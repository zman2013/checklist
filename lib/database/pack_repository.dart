import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models/pack_models.dart';

class PackRepositoryException implements Exception {
  PackRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PackRepository {
  PackRepository._();

  static final PackRepository instance = PackRepository._();

  late Database _db;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final baseDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(baseDir.path, 'pack'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    final dbPath = p.join(dbDir.path, 'pack.db');
    _db = sqlite3.open(dbPath);
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute('PRAGMA foreign_keys = ON;');
    _initSchema();
    _initialized = true;
  }

  DashboardData loadDashboard() {
    _requireReady();

    final templates = _loadTemplateSummaries();

    final activeRows = _db.select(
      '''
      SELECT
        t.id,
        tt.name AS template_name,
        t.destination,
        COUNT(ti.id) AS total_count,
        COUNT(ti.checked_at) AS checked_count
      FROM trips t
      JOIN trip_templates tt ON tt.id = t.template_id
      LEFT JOIN trip_items ti ON ti.trip_id = t.id
      WHERE t.status IN ('packing', 'departed')
      GROUP BY t.id, tt.name, t.destination
      ORDER BY t.id DESC
      ''',
    );

    final activeTrips = activeRows
        .map(
          (row) => ActiveTripSummary(
            id: _asInt(row['id']),
            templateName: _asString(row['template_name']),
            destination: _asNullableString(row['destination']),
            checkedCount: _asInt(row['checked_count']),
            totalCount: _asInt(row['total_count']),
          ),
        )
        .toList();

    return DashboardData(templates: templates, activeTrips: activeTrips);
  }

  List<TemplateSummary> loadTemplates() {
    _requireReady();
    return _loadTemplateSummaries();
  }

  List<TemplateSummary> _loadTemplateSummaries() {
    final rows = _db.select(
      '''
      SELECT
        tt.id,
        tt.name,
        tt.icon,
        tt.use_count,
        (
          SELECT COUNT(*)
          FROM template_items ti
          WHERE ti.template_id = tt.id
        ) AS item_count,
        (
          SELECT COUNT(DISTINCT ti.category)
          FROM template_items ti
          WHERE ti.template_id = tt.id
        ) AS category_count,
        (
          SELECT group_concat(category, '\n')
          FROM (
            SELECT DISTINCT ti.category AS category
            FROM template_items ti
            WHERE ti.template_id = tt.id
            ORDER BY ti.category
            LIMIT 3
          )
        ) AS preview_categories,
        (
          SELECT group_concat(text, '\n')
          FROM (
            SELECT ti.text AS text
            FROM template_items ti
            WHERE ti.template_id = tt.id
            ORDER BY ti.category, ti.sort_order, ti.id
            LIMIT 3
          )
        ) AS preview_items
      FROM trip_templates tt
      ORDER BY tt.use_count DESC, tt.id ASC
      ''',
    );

    return rows
        .map(
          (row) => TemplateSummary(
            id: _asInt(row['id']),
            name: _asString(row['name']),
            icon: _asString(row['icon']),
            useCount: _asInt(row['use_count']),
            itemCount: _asInt(row['item_count']),
            categoryCount: _asInt(row['category_count']),
            previewItems: _splitPreview(row['preview_items']),
            previewCategories: _splitPreview(row['preview_categories']),
          ),
        )
        .toList();
  }

  TemplateDetail loadTemplateDetail(int templateId) {
    _requireReady();

    final templateRow = _db.select(
      'SELECT id, name, icon FROM trip_templates WHERE id = ?',
      [templateId],
    );
    if (templateRow.isEmpty) {
      throw PackRepositoryException('模板不存在');
    }

    final itemRows = _db.select(
      '''
      SELECT id, category, text, sort_order
      FROM template_items
      WHERE template_id = ?
      ORDER BY category, sort_order, id
      ''',
      [templateId],
    );

    return TemplateDetail(
      id: _asInt(templateRow.first['id']),
      name: _asString(templateRow.first['name']),
      icon: _asString(templateRow.first['icon']),
      items: itemRows
          .map(
            (row) => TemplateItemModel(
              id: _asInt(row['id']),
              category: _asString(row['category']),
              text: _asString(row['text']),
              sortOrder: _asInt(row['sort_order']),
            ),
          )
          .toList(),
    );
  }

  int createTemplate(String name, String icon) {
    _requireReady();
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw PackRepositoryException('模板名称不能为空');
    }

    _db.execute(
      '''
      INSERT INTO trip_templates (name, icon, use_count)
      VALUES (?, ?, 0)
      ''',
      [normalizedName, _normalizeIcon(icon)],
    );
    return _db.lastInsertRowId;
  }

  void updateTemplate(int templateId, String name, String icon) {
    _requireReady();
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw PackRepositoryException('模板名称不能为空');
    }

    _db.execute(
      'UPDATE trip_templates SET name = ?, icon = ? WHERE id = ?',
      [normalizedName, _normalizeIcon(icon), templateId],
    );
  }

  void deleteTemplate(int templateId) {
    _requireReady();

    final active = _db.select(
      '''
      SELECT id
      FROM trips
      WHERE template_id = ? AND status IN ('packing', 'departed')
      LIMIT 1
      ''',
      [templateId],
    );
    if (active.isNotEmpty) {
      throw PackRepositoryException('有进行中的行程，请先结束后再删除模板');
    }

    _db.execute('DELETE FROM trip_templates WHERE id = ?', [templateId]);
  }

  int addTemplateItem(int templateId, String category, String text) {
    _requireReady();
    final normalizedCategory = category.trim();
    final normalizedText = text.trim();
    if (normalizedCategory.isEmpty || normalizedText.isEmpty) {
      throw PackRepositoryException('分组和条目都不能为空');
    }

    final maxRow = _db.select(
      '''
      SELECT MAX(sort_order) AS max_order
      FROM template_items
      WHERE template_id = ? AND category = ?
      ''',
      [templateId, normalizedCategory],
    );
    final nextOrder = maxRow.first['max_order'] == null
        ? 0
        : _asInt(maxRow.first['max_order']) + 1;

    _db.execute(
      '''
      INSERT INTO template_items (template_id, category, text, sort_order)
      VALUES (?, ?, ?, ?)
      ''',
      [templateId, normalizedCategory, normalizedText, nextOrder],
    );
    return _db.lastInsertRowId;
  }

  void updateTemplateItem(int itemId, String text) {
    _requireReady();
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw PackRepositoryException('条目不能为空');
    }

    _db.execute('UPDATE template_items SET text = ? WHERE id = ?',
        [normalizedText, itemId]);
  }

  void deleteTemplateItem(int itemId) {
    _requireReady();
    _db.execute('DELETE FROM template_items WHERE id = ?', [itemId]);
  }

  int createTrip(int templateId, {String? destination}) {
    _requireReady();

    final templateRow = _db.select(
      'SELECT id FROM trip_templates WHERE id = ?',
      [templateId],
    );
    if (templateRow.isEmpty) {
      throw PackRepositoryException('模板不存在');
    }

    late int tripId;
    _runTransaction(() {
      _db.execute(
        '''
        INSERT INTO trips (template_id, destination, start_date, status)
        VALUES (?, ?, ?, 'packing')
        ''',
        [
          templateId,
          destination?.trim().isEmpty ?? true ? null : destination!.trim(),
          DateTime.now().toIso8601String(),
        ],
      );
      tripId = _db.lastInsertRowId;

      final templateItems = _db.select(
        '''
        SELECT id, category, text, sort_order
        FROM template_items
        WHERE template_id = ?
        ORDER BY category, sort_order, id
        ''',
        [templateId],
      );
      for (final item in templateItems) {
        _db.execute(
          '''
          INSERT INTO trip_items (
            trip_id,
            item_id,
            category,
            text,
            sort_order,
            is_ad_hoc,
            checked_at
          )
          VALUES (?, ?, ?, ?, ?, 0, NULL)
          ''',
          [
            tripId,
            _asInt(item['id']),
            _asString(item['category']),
            _asString(item['text']),
            _asInt(item['sort_order']),
          ],
        );
      }

      final forgottenItems = _db.select(
        '''
        SELECT text
        FROM forgotten_items
        WHERE template_id = ? AND item_type = 'forgotten'
        ORDER BY times_forgotten DESC, id DESC
        ''',
        [templateId],
      );
      for (final item in forgottenItems) {
        _db.execute(
          '''
          INSERT INTO trip_items (
            trip_id,
            item_id,
            category,
            text,
            sort_order,
            is_ad_hoc,
            checked_at
          )
          VALUES (?, NULL, '提醒', ?, ?, 1, NULL)
          ''',
          [tripId, _asString(item['text']), _nextTripSortOrder(tripId, '提醒')],
        );
      }

      _db.execute(
        'UPDATE trip_templates SET use_count = use_count + 1 WHERE id = ?',
        [templateId],
      );
    });

    return tripId;
  }

  TripDetail loadTripDetail(int tripId) {
    _requireReady();

    final tripRows = _db.select(
      '''
      SELECT
        t.id,
        t.template_id,
        t.destination,
        t.status,
        tt.name AS template_name,
        tt.icon AS template_icon
      FROM trips t
      JOIN trip_templates tt ON tt.id = t.template_id
      WHERE t.id = ?
      ''',
      [tripId],
    );
    if (tripRows.isEmpty) {
      throw PackRepositoryException('行程不存在');
    }

    final tripRow = tripRows.first;
    final regularRows = _db.select(
      '''
      SELECT
        ti.id AS trip_item_id,
        ti.text AS text,
        ti.category AS category,
        ti.checked_at,
        ti.sort_order
      FROM trip_items ti
      WHERE ti.trip_id = ? AND ti.is_ad_hoc = 0
      ORDER BY ti.category, ti.sort_order, ti.id
      ''',
      [tripId],
    );
    final reminderRows = _db.select(
      '''
      SELECT
        ti.id AS trip_item_id,
        ti.text AS text,
        ti.checked_at,
        COALESCE(fi.times_forgotten, 1) AS times_forgotten
      FROM trip_items ti
      LEFT JOIN forgotten_items fi
        ON lower(fi.text) = lower(ti.text)
       AND fi.template_id = ?
       AND fi.item_type = 'forgotten'
      WHERE ti.trip_id = ? AND ti.is_ad_hoc = 1
      ORDER BY times_forgotten DESC, ti.id DESC
      ''',
      [_asInt(tripRow['template_id']), tripId],
    );

    final grouped = <String, List<TripChecklistItem>>{};
    var checkedCount = 0;

    for (final row in regularRows) {
      final checked = row['checked_at'] != null;
      if (checked) checkedCount += 1;
      final category = _asString(row['category']);
      grouped.putIfAbsent(category, () => <TripChecklistItem>[]);
      grouped[category]!.add(
        TripChecklistItem(
          id: _asInt(row['trip_item_id']),
          text: _asString(row['text']),
          checked: checked,
          isReminder: false,
        ),
      );
    }

    final reminderItems = reminderRows.map((row) {
      final checked = row['checked_at'] != null;
      if (checked) checkedCount += 1;
      return TripChecklistItem(
        id: _asInt(row['trip_item_id']),
        text: _asString(row['text']),
        checked: checked,
        isReminder: true,
        forgotCount: _asInt(row['times_forgotten']),
      );
    }).toList();

    return TripDetail(
      id: _asInt(tripRow['id']),
      templateId: _asInt(tripRow['template_id']),
      templateName: _asString(tripRow['template_name']),
      templateIcon: _asString(tripRow['template_icon']),
      destination: _asNullableString(tripRow['destination']),
      status: tripStatusFromDb(_asString(tripRow['status'])),
      groups: grouped.entries
          .map(
            (entry) =>
                TripCategoryGroup(category: entry.key, items: entry.value),
          )
          .toList(),
      reminderItems: reminderItems,
      totalCount: regularRows.length + reminderItems.length,
      checkedCount: checkedCount,
    );
  }

  void toggleTripItem(int tripItemId, bool checked) {
    _requireReady();
    _db.execute(
      'UPDATE trip_items SET checked_at = ? WHERE id = ?',
      [checked ? DateTime.now().toIso8601String() : null, tripItemId],
    );
  }

  int addTripItem(int tripId, String category, String text) {
    _requireReady();

    final normalizedCategory = category.trim();
    final normalizedText = text.trim();
    if (normalizedCategory.isEmpty || normalizedText.isEmpty) {
      throw PackRepositoryException('分组和条目都不能为空');
    }

    final tripRows = _db.select(
      'SELECT id, status FROM trips WHERE id = ?',
      [tripId],
    );
    if (tripRows.isEmpty) {
      throw PackRepositoryException('行程不存在');
    }
    if (_asString(tripRows.first['status']) == 'completed') {
      throw PackRepositoryException('已完成的行程不能再调整清单');
    }

    _db.execute(
      '''
      INSERT INTO trip_items (
        trip_id,
        item_id,
        category,
        text,
        sort_order,
        is_ad_hoc,
        checked_at
      )
      VALUES (?, NULL, ?, ?, ?, 0, NULL)
      ''',
      [
        tripId,
        normalizedCategory,
        normalizedText,
        _nextTripSortOrder(tripId, normalizedCategory),
      ],
    );
    return _db.lastInsertRowId;
  }

  void updateTripItem(
    int tripItemId, {
    required String category,
    required String text,
  }) {
    _requireReady();

    final normalizedCategory = category.trim();
    final normalizedText = text.trim();
    if (normalizedCategory.isEmpty || normalizedText.isEmpty) {
      throw PackRepositoryException('分组和条目都不能为空');
    }

    final rows = _db.select(
      '''
      SELECT ti.trip_id, ti.category, ti.sort_order, t.status
      FROM trip_items ti
      JOIN trips t ON t.id = ti.trip_id
      WHERE ti.id = ?
      ''',
      [tripItemId],
    );
    if (rows.isEmpty) {
      throw PackRepositoryException('条目不存在');
    }

    final row = rows.first;
    if (_asString(row['status']) == 'completed') {
      throw PackRepositoryException('已完成的行程不能再调整清单');
    }

    final currentCategory = _asString(row['category']);
    final sortOrder = currentCategory == normalizedCategory
        ? _asInt(row['sort_order'])
        : _nextTripSortOrder(_asInt(row['trip_id']), normalizedCategory);

    _db.execute(
      '''
      UPDATE trip_items
      SET category = ?, text = ?, sort_order = ?
      WHERE id = ?
      ''',
      [normalizedCategory, normalizedText, sortOrder, tripItemId],
    );
  }

  void deleteTripItem(int tripItemId) {
    _requireReady();

    final rows = _db.select(
      '''
      SELECT ti.id, t.status
      FROM trip_items ti
      JOIN trips t ON t.id = ti.trip_id
      WHERE ti.id = ?
      ''',
      [tripItemId],
    );
    if (rows.isEmpty) {
      throw PackRepositoryException('条目不存在');
    }
    if (_asString(rows.first['status']) == 'completed') {
      throw PackRepositoryException('已完成的行程不能再调整清单');
    }

    _db.execute('DELETE FROM trip_items WHERE id = ?', [tripItemId]);
  }

  void departTrip(int tripId) {
    _requireReady();
    _db.execute(
      '''
      UPDATE trips
      SET status = 'departed'
      WHERE id = ? AND status = 'packing'
      ''',
      [tripId],
    );
  }

  void submitDebrief(
    int tripId, {
    required List<String> forgotten,
    required List<String> surplus,
  }) {
    _requireReady();

    final tripRows = _db.select(
      'SELECT template_id FROM trips WHERE id = ?',
      [tripId],
    );
    if (tripRows.isEmpty) {
      throw PackRepositoryException('行程不存在');
    }
    final templateId = _asInt(tripRows.first['template_id']);

    _runTransaction(() {
      for (final item in forgotten) {
        _upsertForgottenItem(templateId, item, 'forgotten');
      }
      for (final item in surplus) {
        _upsertForgottenItem(templateId, item, 'surplus');
      }
      _db.execute(
        '''
        UPDATE trips
        SET status = 'completed', end_date = ?
        WHERE id = ?
        ''',
        [DateTime.now().toIso8601String(), tripId],
      );
    });
  }

  void _upsertForgottenItem(int templateId, String rawText, String itemType) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final rows = _db.select(
      '''
      SELECT id
      FROM forgotten_items
      WHERE template_id = ? AND lower(text) = lower(?) AND item_type = ?
      LIMIT 1
      ''',
      [templateId, text, itemType],
    );

    if (rows.isEmpty) {
      _db.execute(
        '''
        INSERT INTO forgotten_items (template_id, text, times_forgotten, item_type)
        VALUES (?, ?, 1, ?)
        ''',
        [templateId, text, itemType],
      );
      return;
    }

    _db.execute(
      '''
      UPDATE forgotten_items
      SET times_forgotten = times_forgotten + 1
      WHERE id = ?
      ''',
      [_asInt(rows.first['id'])],
    );
  }

  void _initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS trip_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '🧳',
        use_count INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL REFERENCES trip_templates(id) ON DELETE CASCADE,
        category TEXT NOT NULL,
        text TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL REFERENCES trip_templates(id),
        destination TEXT,
        start_date TEXT,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'packing'
      );

      CREATE TABLE IF NOT EXISTS trip_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        item_id INTEGER REFERENCES template_items(id),
        category TEXT,
        text TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_ad_hoc INTEGER NOT NULL DEFAULT 0,
        checked_at TEXT
      );

      CREATE TABLE IF NOT EXISTS forgotten_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL REFERENCES trip_templates(id),
        text TEXT NOT NULL,
        times_forgotten INTEGER NOT NULL DEFAULT 1,
        item_type TEXT NOT NULL DEFAULT 'forgotten'
      );
    ''');

    _ensureTripItemSnapshotColumns();
    _backfillTripItemSnapshots();

    final countRows =
        _db.select('SELECT COUNT(*) AS count FROM trip_templates');
    if (_asInt(countRows.first['count']) == 0) {
      _seedDefaults();
    }
  }

  void _seedDefaults() {
    void insertTemplate(
      String name,
      String icon,
      List<({String category, String text, int sortOrder})> items,
    ) {
      _db.execute(
        'INSERT INTO trip_templates (name, icon, use_count) VALUES (?, ?, 0)',
        [name, icon],
      );
      final templateId = _db.lastInsertRowId;
      for (final item in items) {
        _db.execute(
          '''
          INSERT INTO template_items (template_id, category, text, sort_order)
          VALUES (?, ?, ?, ?)
          ''',
          [templateId, item.category, item.text, item.sortOrder],
        );
      }
    }

    _runTransaction(() {
      insertTemplate('商务出行', '💼', [
        (category: '文件', text: '护照 / 身份证', sortOrder: 0),
        (category: '文件', text: '名片', sortOrder: 1),
        (category: '文件', text: '酒店确认单', sortOrder: 2),
        (category: '文件', text: '出差申请单', sortOrder: 3),
        (category: '电子设备', text: '笔记本电脑', sortOrder: 0),
        (category: '电子设备', text: '电脑充电器', sortOrder: 1),
        (category: '电子设备', text: '充电宝', sortOrder: 2),
        (category: '电子设备', text: '数据线', sortOrder: 3),
        (category: '电子设备', text: '耳机', sortOrder: 4),
        (category: '衣物', text: '正装衬衫 ×3', sortOrder: 0),
        (category: '衣物', text: '西裤 ×2', sortOrder: 1),
        (category: '衣物', text: '正装鞋', sortOrder: 2),
        (category: '衣物', text: '袜子 ×4', sortOrder: 3),
        (category: '洗漱', text: '牙刷牙膏', sortOrder: 0),
        (category: '洗漱', text: '洗面奶', sortOrder: 1),
        (category: '洗漱', text: '剃须刀', sortOrder: 2),
      ]);

      insertTemplate('度假', '🏖️', [
        (category: '证件', text: '护照', sortOrder: 0),
        (category: '证件', text: '签证（如需）', sortOrder: 1),
        (category: '证件', text: '行程单 / 酒店预订', sortOrder: 2),
        (category: '衣物', text: '换洗衣物', sortOrder: 0),
        (category: '衣物', text: '泳衣', sortOrder: 1),
        (category: '衣物', text: '拖鞋 / 凉鞋', sortOrder: 2),
        (category: '衣物', text: '防晒衣', sortOrder: 3),
        (category: '日用', text: '防晒霜', sortOrder: 0),
        (category: '日用', text: '太阳镜', sortOrder: 1),
        (category: '日用', text: '充电宝', sortOrder: 2),
        (category: '日用', text: '相机 / 手机支架', sortOrder: 3),
      ]);

      insertTemplate('周末短途', '🚗', [
        (category: '基础', text: '身份证', sortOrder: 0),
        (category: '基础', text: '手机充电器', sortOrder: 1),
        (category: '基础', text: '充电宝', sortOrder: 2),
        (category: '衣物', text: '换洗衣物 ×2', sortOrder: 0),
        (category: '衣物', text: '睡衣', sortOrder: 1),
        (category: '衣物', text: '舒适鞋', sortOrder: 2),
        (category: '日用', text: '牙刷牙膏', sortOrder: 0),
        (category: '日用', text: '洗漱用品', sortOrder: 1),
      ]);

      insertTemplate('徒步', '🥾', [
        (category: '装备', text: '徒步鞋', sortOrder: 0),
        (category: '装备', text: '登山杖', sortOrder: 1),
        (category: '装备', text: '背包', sortOrder: 2),
        (category: '装备', text: '头灯', sortOrder: 3),
        (category: '衣物', text: '速干衣', sortOrder: 0),
        (category: '衣物', text: '冲锋衣', sortOrder: 1),
        (category: '衣物', text: '防晒帽', sortOrder: 2),
        (category: '衣物', text: '手套', sortOrder: 3),
        (category: '补给', text: '能量棒 ×5', sortOrder: 0),
        (category: '补给', text: '水壶（2L）', sortOrder: 1),
        (category: '补给', text: '急救包', sortOrder: 2),
        (category: '证件', text: '身份证', sortOrder: 0),
        (category: '证件', text: '紧急联系人信息', sortOrder: 1),
      ]);
    });
  }

  void _runTransaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE TRANSACTION');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _requireReady() {
    if (!_initialized) {
      throw PackRepositoryException('数据库尚未初始化');
    }
  }

  String _normalizeIcon(String icon) {
    final value = icon.trim();
    return value.isEmpty ? '🧳' : value;
  }

  void _ensureTripItemSnapshotColumns() {
    final columns = _db.select('PRAGMA table_info(trip_items)');
    final columnNames =
        columns.map((column) => _asString(column['name'])).toSet();

    if (!columnNames.contains('category')) {
      _db.execute('ALTER TABLE trip_items ADD COLUMN category TEXT');
    }
    if (!columnNames.contains('sort_order')) {
      _db.execute(
        'ALTER TABLE trip_items ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  void _backfillTripItemSnapshots() {
    _db.execute(
      '''
      UPDATE trip_items
      SET
        text = COALESCE(
          text,
          (SELECT template_items.text FROM template_items WHERE template_items.id = trip_items.item_id)
        ),
        category = COALESCE(
          category,
          (SELECT template_items.category FROM template_items WHERE template_items.id = trip_items.item_id)
        ),
        sort_order = CASE
          WHEN sort_order != 0 THEN sort_order
          ELSE COALESCE(
            (SELECT template_items.sort_order FROM template_items WHERE template_items.id = trip_items.item_id),
            0
          )
        END
      WHERE item_id IS NOT NULL
      ''',
    );
  }

  int _nextTripSortOrder(int tripId, String category) {
    final rows = _db.select(
      '''
      SELECT MAX(sort_order) AS max_order
      FROM trip_items
      WHERE trip_id = ? AND category = ? AND is_ad_hoc = 0
      ''',
      [tripId, category],
    );
    final maxOrder = rows.first['max_order'];
    return maxOrder == null ? 0 : _asInt(maxOrder) + 1;
  }

  List<String> _splitPreview(Object? value) {
    final text = _asNullableString(value);
    if (text == null || text.isEmpty) return const <String>[];
    return text
        .split('\n')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  String _asString(Object? value) => value?.toString() ?? '';

  String? _asNullableString(Object? value) => value?.toString();
}
