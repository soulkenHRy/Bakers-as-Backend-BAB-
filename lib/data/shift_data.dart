/// Represents sales data for a single shift
class ShiftData {
  final DateTime date;
  final String dayOfWeek;
  final Map<String, CategorySales> categorySales;
  final bool isWeekEnd; // True if this shift ended the week (Saturday)

  ShiftData({
    required this.date,
    required this.dayOfWeek,
    required this.categorySales,
    this.isWeekEnd = false,
  });

  /// Get total sales across all categories
  int get totalSales {
    int total = 0;
    categorySales.forEach((_, sales) {
      total += sales.totalSold;
    });
    return total;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'dayOfWeek': dayOfWeek,
      'categorySales': categorySales.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'isWeekEnd': isWeekEnd,
    };
  }

  /// Create from JSON
  factory ShiftData.fromJson(Map<String, dynamic> json) {
    final categorySalesMap = <String, CategorySales>{};
    final salesJson = json['categorySales'] as Map<String, dynamic>;
    salesJson.forEach((key, value) {
      categorySalesMap[key] = CategorySales.fromJson(
        value as Map<String, dynamic>,
      );
    });

    return ShiftData(
      date: DateTime.parse(json['date'] as String),
      dayOfWeek: json['dayOfWeek'] as String,
      categorySales: categorySalesMap,
      isWeekEnd: json['isWeekEnd'] as bool? ?? false,
    );
  }
}

/// Represents sales data for a category
class CategorySales {
  final String categoryName;
  final Map<String, ItemSales> items;

  CategorySales({required this.categoryName, required this.items});

  int get totalSold {
    int total = 0;
    items.forEach((_, item) {
      total += item.sold;
    });
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryName': categoryName,
      'items': items.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    final itemsMap = <String, ItemSales>{};
    final itemsJson = json['items'] as Map<String, dynamic>;
    itemsJson.forEach((key, value) {
      itemsMap[key] = ItemSales.fromJson(value as Map<String, dynamic>);
    });

    return CategorySales(
      categoryName: json['categoryName'] as String,
      items: itemsMap,
    );
  }
}

/// Represents sales data for a single item
class ItemSales {
  final String name;
  final int total;
  final int sold;
  final int remaining;

  ItemSales({
    required this.name,
    required this.total,
    required this.sold,
    required this.remaining,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'total': total, 'sold': sold, 'remaining': remaining};
  }

  factory ItemSales.fromJson(Map<String, dynamic> json) {
    return ItemSales(
      name: json['name'] as String,
      total: json['total'] as int,
      sold: json['sold'] as int,
      remaining: json['remaining'] as int,
    );
  }
}

/// Represents a week's worth of shift data
class WeekData {
  final DateTime weekStartDate; // Sunday
  final DateTime weekEndDate; // Saturday
  final int weekNumber;
  final List<ShiftData> shifts;

  WeekData({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.weekNumber,
    required this.shifts,
  });

  /// Get shift for a specific day
  ShiftData? getShiftForDay(String dayOfWeek) {
    try {
      return shifts.firstWhere((s) => s.dayOfWeek == dayOfWeek);
    } catch (e) {
      return null;
    }
  }

  /// Get total sales for the week
  int get totalWeekSales {
    int total = 0;
    for (final shift in shifts) {
      total += shift.totalSales;
    }
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStartDate': weekStartDate.toIso8601String(),
      'weekEndDate': weekEndDate.toIso8601String(),
      'weekNumber': weekNumber,
      'shifts': shifts.map((s) => s.toJson()).toList(),
    };
  }

  factory WeekData.fromJson(Map<String, dynamic> json) {
    return WeekData(
      weekStartDate: DateTime.parse(json['weekStartDate'] as String),
      weekEndDate: DateTime.parse(json['weekEndDate'] as String),
      weekNumber: json['weekNumber'] as int,
      shifts: (json['shifts'] as List)
          .map((s) => ShiftData.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
