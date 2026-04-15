enum TripStatus { packing, departed, completed }

TripStatus tripStatusFromDb(String value) {
  switch (value) {
    case 'packing':
      return TripStatus.packing;
    case 'departed':
      return TripStatus.departed;
    case 'completed':
      return TripStatus.completed;
    default:
      return TripStatus.packing;
  }
}

class TemplateSummary {
  const TemplateSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.useCount,
  });

  final int id;
  final String name;
  final String icon;
  final int useCount;
}

class ActiveTripSummary {
  const ActiveTripSummary({
    required this.id,
    required this.templateName,
    required this.destination,
    required this.checkedCount,
    required this.totalCount,
  });

  final int id;
  final String templateName;
  final String? destination;
  final int checkedCount;
  final int totalCount;

  String get title => destination == null || destination!.isEmpty
      ? templateName
      : '$templateName · $destination';

  double get progress => totalCount == 0 ? 0 : checkedCount / totalCount;
}

class DashboardData {
  const DashboardData({
    required this.templates,
    required this.activeTrips,
  });

  final List<TemplateSummary> templates;
  final List<ActiveTripSummary> activeTrips;
}

class TemplateItemModel {
  const TemplateItemModel({
    required this.id,
    required this.category,
    required this.text,
    required this.sortOrder,
  });

  final int id;
  final String category;
  final String text;
  final int sortOrder;
}

class TemplateDetail {
  const TemplateDetail({
    required this.id,
    required this.name,
    required this.icon,
    required this.items,
  });

  final int id;
  final String name;
  final String icon;
  final List<TemplateItemModel> items;
}

class TripChecklistItem {
  const TripChecklistItem({
    required this.id,
    required this.text,
    required this.checked,
    required this.isReminder,
    this.forgotCount,
  });

  final int id;
  final String text;
  final bool checked;
  final bool isReminder;
  final int? forgotCount;
}

class TripCategoryGroup {
  const TripCategoryGroup({
    required this.category,
    required this.items,
  });

  final String category;
  final List<TripChecklistItem> items;
}

class TripDetail {
  const TripDetail({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.templateIcon,
    required this.destination,
    required this.status,
    required this.groups,
    required this.reminderItems,
    required this.totalCount,
    required this.checkedCount,
  });

  final int id;
  final int templateId;
  final String templateName;
  final String templateIcon;
  final String? destination;
  final TripStatus status;
  final List<TripCategoryGroup> groups;
  final List<TripChecklistItem> reminderItems;
  final int totalCount;
  final int checkedCount;

  String get title => destination == null || destination!.isEmpty
      ? '$templateIcon $templateName'
      : '$templateIcon $templateName · $destination';

  double get progress => totalCount == 0 ? 0 : checkedCount / totalCount;

  bool get isComplete => totalCount > 0 && checkedCount >= totalCount;

  bool get isReadyForDebrief =>
      status == TripStatus.departed ||
      status == TripStatus.completed ||
      isComplete;
}
