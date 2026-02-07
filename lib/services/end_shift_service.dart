import 'dart:convert';
import 'package:intl/intl.dart';
import '../data/shift_data.dart';
import '../data/data_manager.dart';
import 'weather_service.dart';
import 'ttc_service.dart';

/// Comprehensive shift data including external factors
class ComprehensiveShiftData {
  final DateTime shiftDate;
  final String dayOfWeek;
  final String dayName;
  final Map<String, CategorySales> categorySales;
  final WeatherData? weather;
  final Map<String, dynamic>? forecast;
  final TTCBusynessSummary? ttcBusyness;
  final List<TTCStationStatus>? stationStatuses;
  final int totalItemsSold;
  final DateTime shiftStartTime;
  final DateTime shiftEndTime;

  ComprehensiveShiftData({
    required this.shiftDate,
    required this.dayOfWeek,
    required this.dayName,
    required this.categorySales,
    this.weather,
    this.forecast,
    this.ttcBusyness,
    this.stationStatuses,
    required this.totalItemsSold,
    required this.shiftStartTime,
    required this.shiftEndTime,
  });

  /// Convert to comprehensive JSON format
  Map<String, dynamic> toJson() {
    // Date information
    final dateInfo = {
      'date': DateFormat('yyyy-MM-dd').format(shiftDate),
      'dayOfWeek': dayOfWeek,
      'dayName': dayName,
      'isWeekend': dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday',
      'shiftStartTime': shiftStartTime.toIso8601String(),
      'shiftEndTime': shiftEndTime.toIso8601String(),
      'shiftDurationHours':
          shiftEndTime.difference(shiftStartTime).inMinutes / 60,
    };

    // Weather information
    final weatherInfo = weather != null
        ? {
            'current': weather!.toJson(),
            'forecast': forecast,
            'salesImpact': weather!.salesImpact,
          }
        : null;

    // TTC/Transit information
    Map<String, dynamic>? transitInfo;
    if (ttcBusyness != null) {
      final stationsByLine = <String, List<Map<String, dynamic>>>{};
      if (stationStatuses != null) {
        for (final station in stationStatuses!) {
          stationsByLine.putIfAbsent(station.line, () => []);
          stationsByLine[station.line]!.add({
            'station': station.stationName,
            'status': station.status,
            'alert': station.alertMessage,
          });
        }
      }

      transitInfo = {
        'summary': ttcBusyness!.toJson(),
        'trafficImpact': ttcBusyness!.trafficImpact,
        'stationsByLine': stationsByLine,
      };
    }

    // Sales data by category
    final salesByCategory = <String, Map<String, dynamic>>{};
    int grandTotalSold = 0;
    int grandTotalItems = 0;

    for (final entry in categorySales.entries) {
      final category = entry.key;
      final categoryData = entry.value;

      final items = <String, Map<String, dynamic>>{};
      int categorySold = 0;
      int categoryTotal = 0;

      for (final itemEntry in categoryData.items.entries) {
        final item = itemEntry.value;
        items[item.name] = {
          'total': item.total,
          'sold': item.sold,
          'remaining': item.remaining,
          'soldPercentage': item.total > 0
              ? (item.sold / item.total * 100).toStringAsFixed(1)
              : '0.0',
        };
        categorySold += item.sold;
        categoryTotal += item.total;
      }

      grandTotalSold += categorySold;
      grandTotalItems += categoryTotal;

      salesByCategory[category] = {
        'categoryName': categoryData.categoryName,
        'totalItems': categoryTotal,
        'totalSold': categorySold,
        'totalRemaining': categoryTotal - categorySold,
        'soldPercentage': categoryTotal > 0
            ? (categorySold / categoryTotal * 100).toStringAsFixed(1)
            : '0.0',
        'items': items,
      };
    }

    // Summary statistics
    final summary = {
      'totalItemsAvailable': grandTotalItems,
      'totalItemsSold': grandTotalSold,
      'totalItemsRemaining': grandTotalItems - grandTotalSold,
      'overallSoldPercentage': grandTotalItems > 0
          ? (grandTotalSold / grandTotalItems * 100).toStringAsFixed(1)
          : '0.0',
      'topSellingCategories': _getTopSellingCategories(salesByCategory),
      'lowStockItems': _getLowStockItems(categorySales),
    };

    return {
      'shiftInfo': dateInfo,
      'weather': weatherInfo,
      'transit': transitInfo,
      'salesByCategory': salesByCategory,
      'summary': summary,
      'generatedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }

  List<Map<String, dynamic>> _getTopSellingCategories(
    Map<String, Map<String, dynamic>> salesByCategory,
  ) {
    final categories = salesByCategory.entries.toList();
    categories.sort((a, b) {
      final aSold = a.value['totalSold'] as int;
      final bSold = b.value['totalSold'] as int;
      return bSold.compareTo(aSold);
    });

    return categories
        .take(3)
        .map((e) => {'category': e.key, 'sold': e.value['totalSold']})
        .toList();
  }

  List<Map<String, dynamic>> _getLowStockItems(
    Map<String, CategorySales> categorySales,
  ) {
    final lowStock = <Map<String, dynamic>>[];

    for (final entry in categorySales.entries) {
      for (final itemEntry in entry.value.items.entries) {
        final item = itemEntry.value;
        if (item.remaining <= 2 && item.total > 0) {
          lowStock.add({
            'category': entry.key,
            'item': item.name,
            'remaining': item.remaining,
            'total': item.total,
          });
        }
      }
    }

    return lowStock;
  }

  /// Convert to formatted JSON string
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

/// Service to collect all data and generate comprehensive shift report
class EndShiftService {
  static final EndShiftService _instance = EndShiftService._internal();
  factory EndShiftService() => _instance;
  EndShiftService._internal();

  final DataManager _dataManager = DataManager();
  final WeatherService _weatherService = WeatherService();
  final TTCService _ttcService = TTCService();

  DateTime? _shiftStartTime;

  /// Start tracking a new shift
  void startShift() {
    _shiftStartTime = DateTime.now();
  }

  /// Get shift start time
  DateTime get shiftStartTime => _shiftStartTime ?? DateTime.now();

  /// Collect all data and generate comprehensive shift report
  Future<ComprehensiveShiftData> endShift() async {
    final now = DateTime.now();
    final startTime = _shiftStartTime ?? now.subtract(const Duration(hours: 8));

    // Get day information
    final dayOfWeek = _getDayOfWeek(now);
    final dayName = DateFormat('EEEE').format(now);

    // Collect sales data
    final categorySales = _collectSalesData();

    // Get weather data
    WeatherData? weather;
    Map<String, dynamic>? forecast;
    try {
      weather = await _weatherService.getCurrentWeather();
      forecast = await _weatherService.getTodayForecast();
    } catch (e) {
      print('Error fetching weather: $e');
    }

    // Get TTC data
    TTCBusynessSummary? ttcBusyness;
    List<TTCStationStatus>? stationStatuses;
    try {
      ttcBusyness = await _ttcService.getBusynessSummary();
      stationStatuses = await _ttcService.getStationStatuses();
    } catch (e) {
      print('Error fetching TTC data: $e');
    }

    // Calculate total sold
    int totalSold = 0;
    for (final category in categorySales.values) {
      totalSold += category.totalSold;
    }

    // Reset shift start time
    _shiftStartTime = null;

    return ComprehensiveShiftData(
      shiftDate: now,
      dayOfWeek: dayOfWeek,
      dayName: dayName,
      categorySales: categorySales,
      weather: weather,
      forecast: forecast,
      ttcBusyness: ttcBusyness,
      stationStatuses: stationStatuses,
      totalItemsSold: totalSold,
      shiftStartTime: startTime,
      shiftEndTime: now,
    );
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[date.weekday % 7];
  }

  Map<String, CategorySales> _collectSalesData() {
    final categorySales = <String, CategorySales>{};

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

    return categorySales;
  }
}
