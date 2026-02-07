import 'dart:convert';
import 'package:http/http.dart' as http;

/// TTC Station status data
class TTCStationStatus {
  final String stationName;
  final String line;
  final String status; // 'normal', 'busy', 'delay', 'closed'
  final String? alertMessage;
  final DateTime timestamp;

  TTCStationStatus({
    required this.stationName,
    required this.line,
    required this.status,
    this.alertMessage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'stationName': stationName,
      'line': line,
      'status': status,
      'alertMessage': alertMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TTCStationStatus.fromJson(Map<String, dynamic> json) {
    return TTCStationStatus(
      stationName: json['stationName'] as String,
      line: json['line'] as String,
      status: json['status'] as String,
      alertMessage: json['alertMessage'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// TTC System busyness summary
class TTCBusynessSummary {
  final String overallStatus; // 'low', 'moderate', 'high', 'very_high'
  final int normalStations;
  final int busyStations;
  final int delayedStations;
  final int closedStations;
  final List<String> activeAlerts;
  final DateTime timestamp;

  TTCBusynessSummary({
    required this.overallStatus,
    required this.normalStations,
    required this.busyStations,
    required this.delayedStations,
    required this.closedStations,
    required this.activeAlerts,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'overallStatus': overallStatus,
      'normalStations': normalStations,
      'busyStations': busyStations,
      'delayedStations': delayedStations,
      'closedStations': closedStations,
      'activeAlerts': activeAlerts,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TTCBusynessSummary.fromJson(Map<String, dynamic> json) {
    return TTCBusynessSummary(
      overallStatus: json['overallStatus'] as String,
      normalStations: json['normalStations'] as int,
      busyStations: json['busyStations'] as int,
      delayedStations: json['delayedStations'] as int,
      closedStations: json['closedStations'] as int,
      activeAlerts: List<String>.from(json['activeAlerts'] as List),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Get estimated customer traffic impact
  String get trafficImpact {
    switch (overallStatus) {
      case 'low':
        return 'low_traffic';
      case 'moderate':
        return 'normal_traffic';
      case 'high':
        return 'high_traffic';
      case 'very_high':
        return 'very_high_traffic';
      default:
        return 'unknown';
    }
  }
}

/// Service to fetch TTC service alerts and station status
class TTCService {
  static final TTCService _instance = TTCService._internal();
  factory TTCService() => _instance;
  TTCService._internal();

  TTCBusynessSummary? _cachedSummary;
  List<TTCStationStatus>? _cachedStations;
  DateTime? _cacheTime;

  // TTC Subway Lines and Stations
  static const Map<String, List<String>> _subwayLines = {
    'Line 1 - Yonge-University': [
      'Vaughan Metropolitan Centre',
      'Highway 407',
      'Pioneer Village',
      'York University',
      'Finch West',
      'Downsview Park',
      'Sheppard West',
      'Wilson',
      'Yorkdale',
      'Lawrence West',
      'Glencairn',
      'Eglinton West',
      'St Clair West',
      'Dupont',
      'Spadina',
      'St George',
      'Museum',
      'Queens Park',
      'St Patrick',
      'Osgoode',
      'St Andrew',
      'Union',
      'King',
      'Queen',
      'Dundas',
      'College',
      'Wellesley',
      'Bloor-Yonge',
      'Rosedale',
      'Summerhill',
      'St Clair',
      'Davisville',
      'Eglinton',
      'Lawrence',
      'York Mills',
      'Sheppard-Yonge',
      'North York Centre',
      'Finch',
    ],
    'Line 2 - Bloor-Danforth': [
      'Kipling',
      'Islington',
      'Royal York',
      'Old Mill',
      'Jane',
      'Runnymede',
      'High Park',
      'Keele',
      'Dundas West',
      'Lansdowne',
      'Dufferin',
      'Ossington',
      'Christie',
      'Bathurst',
      'Spadina',
      'St George',
      'Bay',
      'Bloor-Yonge',
      'Sherbourne',
      'Castle Frank',
      'Broadview',
      'Chester',
      'Pape',
      'Donlands',
      'Greenwood',
      'Coxwell',
      'Woodbine',
      'Main Street',
      'Victoria Park',
      'Warden',
      'Kennedy',
    ],
    'Line 3 - Scarborough': [
      'Kennedy',
      'Lawrence East',
      'Ellesmere',
      'Midland',
      'Scarborough Centre',
      'McCowan',
    ],
    'Line 4 - Sheppard': [
      'Sheppard-Yonge',
      'Bayview',
      'Bessarion',
      'Leslie',
      'Don Mills',
    ],
  };

  /// Get all TTC service alerts using TTC's open data
  Future<List<Map<String, dynamic>>> getServiceAlerts() async {
    try {
      // Using TTC's service alerts feed
      final url = Uri.parse('https://alerts.ttc.ca/api/alerts/live-alerts');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data['alerts'] != null) {
          return (data['alerts'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('TTC API error: $e');
    }

    return [];
  }

  /// Get station status for all subway stations
  Future<List<TTCStationStatus>> getStationStatuses() async {
    // Return cached data if less than 10 minutes old
    if (_cachedStations != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 10) {
      return _cachedStations!;
    }

    final alerts = await getServiceAlerts();
    final stations = <TTCStationStatus>[];
    final now = DateTime.now();

    // Parse alerts to determine affected stations
    final affectedStations = <String, Map<String, dynamic>>{};

    for (final alert in alerts) {
      final title = (alert['title'] ?? alert['headerText'] ?? '')
          .toString()
          .toLowerCase();
      final description =
          (alert['description'] ?? alert['descriptionText'] ?? '')
              .toString()
              .toLowerCase();
      final alertText = '$title $description';

      // Check each station
      for (final entry in _subwayLines.entries) {
        final line = entry.key;
        for (final station in entry.value) {
          if (alertText.contains(station.toLowerCase())) {
            String status = 'delay';
            if (alertText.contains('closed') || alertText.contains('closure')) {
              status = 'closed';
            } else if (alertText.contains('busy') ||
                alertText.contains('crowded')) {
              status = 'busy';
            }

            affectedStations[station] = {
              'line': line,
              'status': status,
              'alert': alert['title'] ?? alert['headerText'] ?? 'Service alert',
            };
          }
        }
      }

      // Check for line-wide alerts
      for (final entry in _subwayLines.entries) {
        final line = entry.key;
        if (alertText.contains(line.toLowerCase()) ||
            (line.contains('Yonge') && alertText.contains('line 1')) ||
            (line.contains('Bloor') && alertText.contains('line 2')) ||
            (line.contains('Scarborough') && alertText.contains('line 3')) ||
            (line.contains('Sheppard') && alertText.contains('line 4'))) {
          for (final station in entry.value) {
            if (!affectedStations.containsKey(station)) {
              affectedStations[station] = {
                'line': line,
                'status': 'delay',
                'alert':
                    alert['title'] ??
                    alert['headerText'] ??
                    'Line service alert',
              };
            }
          }
        }
      }
    }

    // Create station status objects for all stations
    for (final entry in _subwayLines.entries) {
      final line = entry.key;
      for (final station in entry.value) {
        final affected = affectedStations[station];
        stations.add(
          TTCStationStatus(
            stationName: station,
            line: line,
            status: affected?['status'] ?? 'normal',
            alertMessage: affected?['alert'],
            timestamp: now,
          ),
        );
      }
    }

    _cachedStations = stations;
    _cacheTime = now;
    return stations;
  }

  /// Get system-wide busyness summary
  Future<TTCBusynessSummary> getBusynessSummary() async {
    // Return cached data if less than 10 minutes old
    if (_cachedSummary != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 10) {
      return _cachedSummary!;
    }

    final stations = await getStationStatuses();
    final now = DateTime.now();

    int normalCount = 0;
    int busyCount = 0;
    int delayCount = 0;
    int closedCount = 0;
    final activeAlerts = <String>{};

    for (final station in stations) {
      switch (station.status) {
        case 'normal':
          normalCount++;
          break;
        case 'busy':
          busyCount++;
          break;
        case 'delay':
          delayCount++;
          if (station.alertMessage != null) {
            activeAlerts.add(station.alertMessage!);
          }
          break;
        case 'closed':
          closedCount++;
          if (station.alertMessage != null) {
            activeAlerts.add(station.alertMessage!);
          }
          break;
      }
    }

    // Calculate overall status
    final totalAffected = busyCount + delayCount + closedCount;
    final totalStations = stations.length;
    final affectedPercentage = totalAffected / totalStations;

    String overallStatus;
    if (affectedPercentage < 0.05) {
      overallStatus = 'low';
    } else if (affectedPercentage < 0.15) {
      overallStatus = 'moderate';
    } else if (affectedPercentage < 0.30) {
      overallStatus = 'high';
    } else {
      overallStatus = 'very_high';
    }

    // Consider time of day for busyness
    final hour = now.hour;
    final dayOfWeek = now.weekday;

    // Rush hours: 7-9 AM, 4-7 PM on weekdays
    if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      if ((hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19)) {
        // Bump up busyness during rush hour
        if (overallStatus == 'low')
          overallStatus = 'moderate';
        else if (overallStatus == 'moderate')
          overallStatus = 'high';
      }
    }

    _cachedSummary = TTCBusynessSummary(
      overallStatus: overallStatus,
      normalStations: normalCount,
      busyStations: busyCount,
      delayedStations: delayCount,
      closedStations: closedCount,
      activeAlerts: activeAlerts.toList(),
      timestamp: now,
    );

    return _cachedSummary!;
  }

  /// Get busyness estimate based on day and time
  String getEstimatedBusyness() {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;

    // Weekend patterns
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      if (hour >= 10 && hour <= 18) {
        return 'moderate';
      }
      return 'low';
    }

    // Weekday patterns
    // Morning rush: 7-9 AM
    if (hour >= 7 && hour <= 9) {
      return 'very_high';
    }
    // Evening rush: 4-7 PM
    if (hour >= 16 && hour <= 19) {
      return 'very_high';
    }
    // Lunch time: 11 AM - 2 PM
    if (hour >= 11 && hour <= 14) {
      return 'high';
    }
    // Off-peak
    if (hour >= 9 && hour <= 16) {
      return 'moderate';
    }
    // Late night/early morning
    return 'low';
  }
}
