import 'dart:convert';
import 'dart:math';
import '../data/item_definitions.dart';

/// Generates synthetic data for 1 year of shift data
/// Sales patterns:
/// - HIGH: Rainy weather, busy subway, Wednesday/Thursday
/// - LOW: Otherwise
class SyntheticDataGenerator {
  final Random _random = Random(42); // Fixed seed for reproducibility

  // Toronto weather patterns by month (approximate)
  static const Map<int, Map<String, double>> _monthlyWeatherProb = {
    1: {'rain': 0.15, 'snow': 0.40, 'clear': 0.30, 'cloudy': 0.15}, // January
    2: {'rain': 0.15, 'snow': 0.35, 'clear': 0.35, 'cloudy': 0.15}, // February
    3: {'rain': 0.25, 'snow': 0.20, 'clear': 0.35, 'cloudy': 0.20}, // March
    4: {'rain': 0.35, 'snow': 0.05, 'clear': 0.40, 'cloudy': 0.20}, // April
    5: {'rain': 0.30, 'snow': 0.00, 'clear': 0.50, 'cloudy': 0.20}, // May
    6: {'rain': 0.25, 'snow': 0.00, 'clear': 0.55, 'cloudy': 0.20}, // June
    7: {'rain': 0.20, 'snow': 0.00, 'clear': 0.60, 'cloudy': 0.20}, // July
    8: {'rain': 0.20, 'snow': 0.00, 'clear': 0.60, 'cloudy': 0.20}, // August
    9: {'rain': 0.30, 'snow': 0.00, 'clear': 0.50, 'cloudy': 0.20}, // September
    10: {'rain': 0.35, 'snow': 0.05, 'clear': 0.40, 'cloudy': 0.20}, // October
    11: {'rain': 0.30, 'snow': 0.20, 'clear': 0.30, 'cloudy': 0.20}, // November
    12: {'rain': 0.15, 'snow': 0.40, 'clear': 0.30, 'cloudy': 0.15}, // December
  };

  // Temperature ranges by month (Toronto)
  static const Map<int, List<double>> _monthlyTempRange = {
    1: [-10.0, -2.0],
    2: [-8.0, 0.0],
    3: [-2.0, 8.0],
    4: [4.0, 14.0],
    5: [10.0, 20.0],
    6: [15.0, 25.0],
    7: [18.0, 28.0],
    8: [17.0, 27.0],
    9: [13.0, 22.0],
    10: [7.0, 15.0],
    11: [1.0, 8.0],
    12: [-6.0, 2.0],
  };

  /// Generate 1 year of synthetic shift data
  List<Map<String, dynamic>> generateYearData({
    DateTime? startDate,
    int days = 365,
  }) {
    final start = startDate ?? DateTime.now().subtract(Duration(days: days));
    final data = <Map<String, dynamic>>[];

    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final shiftData = _generateDayData(date);
      data.add(shiftData);
    }

    return data;
  }

  /// Generate data for a single day
  Map<String, dynamic> _generateDayData(DateTime date) {
    final dayOfWeek = _getDayOfWeek(date);
    final isWeekend = dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday';

    // Generate weather
    final weather = _generateWeather(date);
    final isRainy =
        weather['weatherCode'] >= 61 && weather['weatherCode'] <= 67;
    final isSnowy =
        weather['weatherCode'] >= 71 && weather['weatherCode'] <= 77;
    final isBadWeather = isRainy || isSnowy;

    // Generate TTC status
    final ttcStatus = _generateTTCStatus(date, dayOfWeek);
    final isBusySubway =
        ttcStatus['overallStatus'] == 'high' ||
        ttcStatus['overallStatus'] == 'very_high';

    // Determine if this is a high sales day
    final isWednesdayOrThursday =
        dayOfWeek == 'Wednesday' || dayOfWeek == 'Thursday';

    // Calculate sales multiplier based on conditions
    double salesMultiplier = 0.5; // Base: low sales

    // High sales conditions
    if (isBadWeather) salesMultiplier += 0.3; // Rainy/snowy increases sales
    if (isBusySubway) salesMultiplier += 0.25; // Busy subway increases sales
    if (isWednesdayOrThursday) salesMultiplier += 0.2; // Wed/Thu mid-week peak

    // Low sales conditions
    if (isWeekend) salesMultiplier -= 0.15; // Weekend lower traffic
    if (dayOfWeek == 'Monday') salesMultiplier -= 0.1; // Monday blues

    // Seasonal adjustments
    if (date.month >= 11 || date.month <= 2) {
      salesMultiplier += 0.1; // Winter boost (hot drinks/food)
    }

    // Clamp multiplier
    salesMultiplier = salesMultiplier.clamp(0.3, 1.0);

    // Generate sales data
    final salesByCategory = _generateSalesData(salesMultiplier);

    // Calculate totals
    int totalSold = 0;
    int totalItems = 0;
    for (final category in salesByCategory.values) {
      totalSold += (category['totalSold'] as int);
      totalItems += (category['totalItems'] as int);
    }

    // Build shift info
    final shiftStart = DateTime(date.year, date.month, date.day, 6, 0);
    final shiftEnd = DateTime(date.year, date.month, date.day, 14, 0);

    return {
      'shiftInfo': {
        'date': _formatDate(date),
        'dayOfWeek': dayOfWeek,
        'dayName': dayOfWeek,
        'isWeekend': isWeekend,
        'shiftStartTime': shiftStart.toIso8601String(),
        'shiftEndTime': shiftEnd.toIso8601String(),
        'shiftDurationHours': 8.0,
      },
      'weather': {
        'current': weather,
        'forecast': {
          'date': _formatDate(date),
          'weatherCode': weather['weatherCode'],
          'weatherDescription': weather['weatherDescription'],
          'maxTemperature': weather['temperature'] + 3,
          'minTemperature': weather['temperature'] - 5,
          'precipitationSum': weather['precipitation'],
          'precipitationProbability': isBadWeather ? 80 : 20,
        },
        'salesImpact': isBadWeather ? 'positive' : 'neutral',
      },
      'transit': {
        'summary': ttcStatus,
        'trafficImpact': ttcStatus['trafficImpact'],
      },
      'salesByCategory': salesByCategory,
      'summary': {
        'totalItemsAvailable': totalItems,
        'totalItemsSold': totalSold,
        'totalItemsRemaining': totalItems - totalSold,
        'overallSoldPercentage': totalItems > 0
            ? (totalSold / totalItems * 100).toStringAsFixed(1)
            : '0.0',
      },
      'generatedAt': date.toIso8601String(),
      'version': '1.0',
      'isSynthetic': true,
      // Features for ML model
      'mlFeatures': {
        'isRainy': isRainy ? 1 : 0,
        'isSnowy': isSnowy ? 1 : 0,
        'isBadWeather': isBadWeather ? 1 : 0,
        'isBusySubway': isBusySubway ? 1 : 0,
        'isWeekend': isWeekend ? 1 : 0,
        'isWednesday': dayOfWeek == 'Wednesday' ? 1 : 0,
        'isThursday': dayOfWeek == 'Thursday' ? 1 : 0,
        'dayOfWeekNum': date.weekday,
        'month': date.month,
        'temperature': weather['temperature'],
        'salesMultiplier': salesMultiplier,
      },
    };
  }

  /// Generate weather data for a date
  Map<String, dynamic> _generateWeather(DateTime date) {
    final month = date.month;
    final probs = _monthlyWeatherProb[month]!;
    final tempRange = _monthlyTempRange[month]!;

    // Select weather type
    final roll = _random.nextDouble();
    String weatherType;
    int weatherCode;
    String weatherDescription;

    double cumProb = 0;
    if (roll < (cumProb += probs['rain']!)) {
      weatherType = 'rain';
      weatherCode = 61 + _random.nextInt(3) * 2; // 61, 63, or 65
      weatherDescription = 'Rain';
    } else if (roll < (cumProb += probs['snow']!)) {
      weatherType = 'snow';
      weatherCode = 71 + _random.nextInt(3) * 2; // 71, 73, or 75
      weatherDescription = 'Snow';
    } else if (roll < (cumProb += probs['cloudy']!)) {
      weatherType = 'cloudy';
      weatherCode = 2 + _random.nextInt(2); // 2 or 3
      weatherDescription = 'Cloudy';
    } else {
      weatherType = 'clear';
      weatherCode = _random.nextInt(2); // 0 or 1
      weatherDescription = 'Clear sky';
    }

    // Generate temperature
    final temp =
        tempRange[0] + _random.nextDouble() * (tempRange[1] - tempRange[0]);

    // Generate other weather data
    final humidity = 40 + _random.nextInt(40);
    final windSpeed = 5.0 + _random.nextDouble() * 25;
    final precipitation = weatherType == 'rain'
        ? 2.0 + _random.nextDouble() * 10
        : weatherType == 'snow'
        ? 1.0 + _random.nextDouble() * 8
        : 0.0;

    return {
      'temperature': double.parse(temp.toStringAsFixed(1)),
      'apparentTemperature': double.parse(
        (temp - windSpeed / 5).toStringAsFixed(1),
      ),
      'weatherCode': weatherCode,
      'weatherDescription': weatherDescription,
      'precipitation': double.parse(precipitation.toStringAsFixed(1)),
      'humidity': humidity,
      'windSpeed': double.parse(windSpeed.toStringAsFixed(1)),
      'timestamp': date.toIso8601String(),
    };
  }

  /// Generate TTC status for a date
  Map<String, dynamic> _generateTTCStatus(DateTime date, String dayOfWeek) {
    final hour = 10; // Assume mid-morning check
    final isWeekday = dayOfWeek != 'Saturday' && dayOfWeek != 'Sunday';

    // Base busyness on day and time
    String overallStatus;
    String trafficImpact;

    if (isWeekday) {
      // Weekday rush hours
      if (hour >= 7 && hour <= 9) {
        overallStatus = _random.nextDouble() < 0.7 ? 'very_high' : 'high';
      } else if (hour >= 16 && hour <= 19) {
        overallStatus = _random.nextDouble() < 0.7 ? 'very_high' : 'high';
      } else if (hour >= 11 && hour <= 14) {
        overallStatus = _random.nextDouble() < 0.5 ? 'high' : 'moderate';
      } else {
        overallStatus = _random.nextDouble() < 0.3 ? 'moderate' : 'low';
      }

      // Random delays/issues (20% chance on weekdays)
      if (_random.nextDouble() < 0.2) {
        overallStatus = 'high';
      }
    } else {
      // Weekend - generally less busy
      overallStatus = _random.nextDouble() < 0.3 ? 'moderate' : 'low';
    }

    // Map to traffic impact
    switch (overallStatus) {
      case 'very_high':
        trafficImpact = 'very_high_traffic';
        break;
      case 'high':
        trafficImpact = 'high_traffic';
        break;
      case 'moderate':
        trafficImpact = 'normal_traffic';
        break;
      default:
        trafficImpact = 'low_traffic';
    }

    // Generate station counts
    final totalStations = 75;
    int delayedStations = 0;
    int busyStations = 0;

    if (overallStatus == 'very_high') {
      delayedStations = 5 + _random.nextInt(10);
      busyStations = 10 + _random.nextInt(15);
    } else if (overallStatus == 'high') {
      delayedStations = 2 + _random.nextInt(5);
      busyStations = 5 + _random.nextInt(10);
    } else if (overallStatus == 'moderate') {
      delayedStations = _random.nextInt(3);
      busyStations = _random.nextInt(5);
    }

    return {
      'overallStatus': overallStatus,
      'normalStations': totalStations - delayedStations - busyStations,
      'busyStations': busyStations,
      'delayedStations': delayedStations,
      'closedStations': 0,
      'activeAlerts': delayedStations > 0 ? ['Service delays on Line 1'] : [],
      'timestamp': date.toIso8601String(),
      'trafficImpact': trafficImpact,
    };
  }

  /// Generate sales data based on multiplier
  Map<String, Map<String, dynamic>> _generateSalesData(double multiplier) {
    final salesByCategory = <String, Map<String, dynamic>>{};

    // Define all items with their categories and totals
    final allItems = <String, List<Map<String, dynamic>>>{
      'breakfast_lunch': ItemDefinitions.breakfastLunchItems
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'muffins': ItemDefinitions.muffins
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'cookies': ItemDefinitions.cookies
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'others': ItemDefinitions.others
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'donuts': ItemDefinitions.donuts
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'bagels': ItemDefinitions.bagels
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
      'timbits': ItemDefinitions.timbits
          .map((i) => {'name': i.name, 'total': i.total})
          .toList(),
    };

    for (final entry in allItems.entries) {
      final category = entry.key;
      final items = entry.value;

      final itemsData = <String, Map<String, dynamic>>{};
      int categorySold = 0;
      int categoryTotal = 0;

      for (final item in items) {
        final total = item['total'] as int;
        categoryTotal += total;

        // Calculate sold with some randomness around the multiplier
        final baseMultiplier = multiplier + (_random.nextDouble() - 0.5) * 0.2;
        final clampedMultiplier = baseMultiplier.clamp(0.2, 0.95);
        int sold = (total * clampedMultiplier).round();

        // Add some item-specific variation
        sold = (sold + _random.nextInt(3) - 1).clamp(0, total);
        categorySold += sold;

        itemsData[item['name'] as String] = {
          'total': total,
          'sold': sold,
          'remaining': total - sold,
          'soldPercentage': total > 0
              ? (sold / total * 100).toStringAsFixed(1)
              : '0.0',
        };
      }

      salesByCategory[category] = {
        'categoryName': category,
        'totalItems': categoryTotal,
        'totalSold': categorySold,
        'totalRemaining': categoryTotal - categorySold,
        'soldPercentage': categoryTotal > 0
            ? (categorySold / categoryTotal * 100).toStringAsFixed(1)
            : '0.0',
        'items': itemsData,
      };
    }

    return salesByCategory;
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Export data as JSON string
  String exportToJson(List<Map<String, dynamic>> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Generate CSV format for Prophet model
  /// Prophet requires: ds (datestamp), y (value to predict), plus regressors
  String exportToCSVForProphet(
    List<Map<String, dynamic>> data,
    String itemName,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'ds,y,is_rainy,is_snowy,is_busy_subway,is_weekend,is_wednesday,is_thursday,temperature,month',
    );

    for (final day in data) {
      final date = day['shiftInfo']['date'];
      final features = day['mlFeatures'] as Map<String, dynamic>;

      // Find item sales
      int sold = 0;
      for (final category in (day['salesByCategory'] as Map).values) {
        final items = category['items'] as Map<String, dynamic>;
        if (items.containsKey(itemName)) {
          sold = items[itemName]['sold'] as int;
          break;
        }
      }

      buffer.writeln(
        '$date,$sold,${features['isRainy']},${features['isSnowy']},'
        '${features['isBusySubway']},${features['isWeekend']},'
        '${features['isWednesday']},${features['isThursday']},'
        '${features['temperature']},${features['month']}',
      );
    }

    return buffer.toString();
  }

  /// Generate training data for all items
  Map<String, String> exportAllItemsCSV(List<Map<String, dynamic>> data) {
    final csvFiles = <String, String>{};

    for (final item in ItemDefinitions.allItems) {
      csvFiles[item.name] = exportToCSVForProphet(data, item.name);
    }

    return csvFiles;
  }
}
