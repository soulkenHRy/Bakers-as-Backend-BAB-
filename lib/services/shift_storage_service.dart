import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/shift_data.dart';
import '../data/data_manager.dart';

/// Service to manage shift data storage and retrieval
class ShiftStorageService {
  static final ShiftStorageService _instance = ShiftStorageService._internal();
  factory ShiftStorageService() => _instance;
  ShiftStorageService._internal();

  static const String _shiftsKey = 'shift_data';
  static const String _weeksKey = 'weeks_data';
  static const String _currentWeekKey = 'current_week_shifts';

  final DataManager _dataManager = DataManager();

  /// Days of the week
  static const List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// Get current day of week name
  String getCurrentDayOfWeek() {
    final now = DateTime.now();
    return daysOfWeek[now.weekday % 7];
  }

  /// Check if today is Saturday (end of week)
  bool isSaturday() {
    return DateTime.now().weekday == DateTime.saturday;
  }

  /// Get the week number for a date
  int getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// Get the start of the current week (Sunday)
  DateTime getWeekStart(DateTime date) {
    final weekday = date.weekday % 7; // Sunday = 0
    return DateTime(date.year, date.month, date.day - weekday);
  }

  /// Collect current sales data from DataManager
  ShiftData collectCurrentShiftData({bool isWeekEnd = false}) {
    final now = DateTime.now();
    final dayOfWeek = getCurrentDayOfWeek();

    final categorySales = <String, CategorySales>{};

    // Collect data from each category
    final categories = [
      'breakfast_lunch',
      'muffins',
      'cookies',
      'others',
      'donuts',
      'bagels',
      'timbits',
    ];

    for (final category in categories) {
      final items = _dataManager.getItems(category);
      final itemSales = <String, ItemSales>{};

      for (final item in items) {
        itemSales[item.name] = ItemSales(
          name: item.name,
          total: item.total,
          sold: item.sold,
          remaining: item.remaining,
        );
      }

      categorySales[category] = CategorySales(
        categoryName: category,
        items: itemSales,
      );
    }

    return ShiftData(
      date: now,
      dayOfWeek: dayOfWeek,
      categorySales: categorySales,
      isWeekEnd: isWeekEnd,
    );
  }

  /// Save a shift to the current week's data
  Future<void> saveShift(ShiftData shift) async {
    final prefs = await SharedPreferences.getInstance();

    // Get current week shifts
    List<ShiftData> currentWeekShifts = await getCurrentWeekShifts();

    // Remove existing shift for the same day if exists
    currentWeekShifts.removeWhere((s) => s.dayOfWeek == shift.dayOfWeek);

    // Add the new shift
    currentWeekShifts.add(shift);

    // Save back
    final shiftsJson = currentWeekShifts.map((s) => s.toJson()).toList();
    await prefs.setString(_currentWeekKey, jsonEncode(shiftsJson));
  }

  /// Get current week's shifts
  Future<List<ShiftData>> getCurrentWeekShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_currentWeekKey);

    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => ShiftData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// End the current week and archive it
  Future<WeekData> endWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Get current week shifts
    List<ShiftData> currentWeekShifts = await getCurrentWeekShifts();

    // Create week data
    final weekData = WeekData(
      weekStartDate: getWeekStart(now),
      weekEndDate: now,
      weekNumber: getWeekNumber(now),
      shifts: currentWeekShifts,
    );

    // Get existing weeks
    List<WeekData> weeks = await getAllWeeks();

    // Remove existing week with same number if exists
    weeks.removeWhere(
      (w) =>
          w.weekNumber == weekData.weekNumber &&
          w.weekStartDate.year == weekData.weekStartDate.year,
    );

    // Add the new week
    weeks.add(weekData);

    // Keep only last 12 weeks
    if (weeks.length > 12) {
      weeks = weeks.sublist(weeks.length - 12);
    }

    // Save weeks
    final weeksJson = weeks.map((w) => w.toJson()).toList();
    await prefs.setString(_weeksKey, jsonEncode(weeksJson));

    // Clear current week shifts
    await prefs.remove(_currentWeekKey);

    return weekData;
  }

  /// Get all saved weeks
  Future<List<WeekData>> getAllWeeks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_weeksKey);

    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => WeekData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the last two weeks for comparison
  Future<List<WeekData>> getLastTwoWeeks() async {
    final weeks = await getAllWeeks();
    if (weeks.isEmpty) return [];

    // Sort by week start date descending
    weeks.sort((a, b) => b.weekStartDate.compareTo(a.weekStartDate));

    return weeks.take(2).toList();
  }

  /// Get sales trend for a specific item across all saved shifts
  Future<List<Map<String, dynamic>>> getItemSalesTrend(String itemName) async {
    final weeks = await getAllWeeks();
    final trend = <Map<String, dynamic>>[];

    for (final week in weeks) {
      for (final shift in week.shifts) {
        for (final category in shift.categorySales.values) {
          if (category.items.containsKey(itemName)) {
            trend.add({
              'date': shift.date,
              'dayOfWeek': shift.dayOfWeek,
              'weekNumber': week.weekNumber,
              'sold': category.items[itemName]!.sold,
            });
          }
        }
      }
    }

    // Sort by date
    trend.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    return trend;
  }

  /// Clear all stored data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shiftsKey);
    await prefs.remove(_weeksKey);
    await prefs.remove(_currentWeekKey);
  }
}
