import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/item_definitions.dart';
import 'synthetic_data_generator.dart';

/// Prophet-like prediction model implemented in Dart
/// Uses linear regression with seasonal components and external regressors
class SalesPredictionModel {
  // Model parameters for each item
  final Map<String, ItemModel> _itemModels = {};

  // Training data
  List<Map<String, dynamic>> _trainingData = [];

  // Data source tracking
  int _syntheticDataCount = 0;
  int _realDataCount = 0;

  /// Get the current data mix ratio
  DataMixRatio get dataMixRatio {
    final total = _syntheticDataCount + _realDataCount;
    if (total == 0) return DataMixRatio(synthetic: 100, real: 0);

    return DataMixRatio(
      synthetic: (_syntheticDataCount / total * 100).round(),
      real: (_realDataCount / total * 100).round(),
    );
  }

  /// Get training phase description
  String get trainingPhase {
    final ratio = dataMixRatio;
    if (ratio.real == 0) {
      return 'Week 1: 100% Synthetic (AI acts like an Experienced Manager)';
    } else if (ratio.real < 30) {
      return 'Month 1: ${ratio.synthetic}% Synthetic + ${ratio.real}% Real (AI noticing your store\'s patterns)';
    } else if (ratio.real < 70) {
      return 'Month 3: ${ratio.synthetic}% Synthetic + ${ratio.real}% Real (AI learning your store\'s truth)';
    } else if (ratio.real < 100) {
      return 'Month 6: ${ratio.synthetic}% Synthetic + ${ratio.real}% Real (AI almost fully trained)';
    } else {
      return '100% Real Data (AI has completely learned your store)';
    }
  }

  /// Initialize model with synthetic data
  Future<void> initializeWithSyntheticData() async {
    final generator = SyntheticDataGenerator();
    final syntheticData = generator.generateYearData(days: 365);

    _trainingData = syntheticData;
    _syntheticDataCount = syntheticData.length;
    _realDataCount = 0;

    // Train models for all items
    await _trainAllModels();

    // Save state
    await _saveModelState();
  }

  /// Add real data and retrain
  Future<void> addRealDataAndRetrain(Map<String, dynamic> realShiftData) async {
    // Mark as real data
    realShiftData['isSynthetic'] = false;

    // Add ML features if not present
    if (!realShiftData.containsKey('mlFeatures')) {
      realShiftData['mlFeatures'] = _extractMLFeatures(realShiftData);
    }

    // Add to training data
    _trainingData.add(realShiftData);
    _realDataCount++;

    // Optionally remove oldest synthetic data to maintain ratio
    // This implements the gradual transition from synthetic to real
    if (_syntheticDataCount > 0 && _realDataCount > 30) {
      // After 30 days of real data, start phasing out synthetic
      final targetSyntheticRatio = _calculateTargetSyntheticRatio();
      final currentTotal = _syntheticDataCount + _realDataCount;
      final targetSyntheticCount = (currentTotal * targetSyntheticRatio)
          .round();

      while (_syntheticDataCount > targetSyntheticCount &&
          _trainingData.isNotEmpty) {
        // Remove oldest synthetic data
        final idx = _trainingData.indexWhere((d) => d['isSynthetic'] == true);
        if (idx >= 0) {
          _trainingData.removeAt(idx);
          _syntheticDataCount--;
        } else {
          break;
        }
      }
    }

    // Retrain models
    await _trainAllModels();

    // Save state
    await _saveModelState();
  }

  double _calculateTargetSyntheticRatio() {
    // Gradual decrease: 100% -> 0% over 6 months (180 days)
    if (_realDataCount <= 7) return 1.0; // Week 1: 100% synthetic
    if (_realDataCount <= 30) return 0.8; // Month 1: 80% synthetic
    if (_realDataCount <= 90) return 0.5; // Month 3: 50% synthetic
    if (_realDataCount <= 180) return 0.2; // Month 6: 20% synthetic
    return 0.0; // After 6 months: 0% synthetic
  }

  Map<String, dynamic> _extractMLFeatures(Map<String, dynamic> shiftData) {
    final weather = shiftData['weather']?['current'];
    final transit = shiftData['transit']?['summary'];
    final shiftInfo = shiftData['shiftInfo'];

    final dayOfWeek = shiftInfo?['dayOfWeek'] ?? '';
    final isWeekend = dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday';

    // Parse weather
    final weatherCode = weather?['weatherCode'] ?? 0;
    final isRainy = weatherCode >= 61 && weatherCode <= 67;
    final isSnowy = weatherCode >= 71 && weatherCode <= 77;
    final temperature = weather?['temperature'] ?? 15.0;

    // Parse transit
    final overallStatus = transit?['overallStatus'] ?? 'moderate';
    final isBusySubway =
        overallStatus == 'high' || overallStatus == 'very_high';

    // Parse date
    DateTime date;
    try {
      date = DateTime.parse(shiftInfo?['date'] ?? DateTime.now().toString());
    } catch (e) {
      date = DateTime.now();
    }

    return {
      'isRainy': isRainy ? 1 : 0,
      'isSnowy': isSnowy ? 1 : 0,
      'isBadWeather': (isRainy || isSnowy) ? 1 : 0,
      'isBusySubway': isBusySubway ? 1 : 0,
      'isWeekend': isWeekend ? 1 : 0,
      'isWednesday': dayOfWeek == 'Wednesday' ? 1 : 0,
      'isThursday': dayOfWeek == 'Thursday' ? 1 : 0,
      'dayOfWeekNum': date.weekday,
      'month': date.month,
      'temperature': temperature,
    };
  }

  /// Train models for all items
  Future<void> _trainAllModels() async {
    for (final item in ItemDefinitions.allItems) {
      _itemModels[item.name] = _trainItemModel(item.name, item.total);
    }
  }

  /// Train model for a single item
  ItemModel _trainItemModel(String itemName, int maxStock) {
    // Extract training pairs: (features, sales)
    final trainingPairs = <TrainingPair>[];

    for (final day in _trainingData) {
      final features = day['mlFeatures'] as Map<String, dynamic>?;
      if (features == null) continue;

      // Find item sales
      int sold = 0;
      for (final category in (day['salesByCategory'] as Map).values) {
        final items = category['items'] as Map<String, dynamic>;
        if (items.containsKey(itemName)) {
          sold = items[itemName]['sold'] as int;
          break;
        }
      }

      trainingPairs.add(
        TrainingPair(features: Features.fromMap(features), sales: sold),
      );
    }

    if (trainingPairs.isEmpty) {
      return ItemModel.defaultModel(maxStock);
    }

    // Simple linear regression with feature weights
    // y = base + w1*rain + w2*snow + w3*busy + w4*weekend + w5*wed + w6*thu + w7*temp

    // Calculate mean sales
    final meanSales =
        trainingPairs.map((p) => p.sales).reduce((a, b) => a + b) /
        trainingPairs.length;

    // Calculate feature weights using simple correlation
    double rainEffect = 0, snowEffect = 0, busyEffect = 0;
    double weekendEffect = 0, wedEffect = 0, thuEffect = 0;
    double tempEffect = 0;

    // Group by feature and calculate average sales
    final rainyDays = trainingPairs.where((p) => p.features.isRainy == 1);
    final nonRainyDays = trainingPairs.where((p) => p.features.isRainy == 0);
    if (rainyDays.isNotEmpty && nonRainyDays.isNotEmpty) {
      final rainyAvg =
          rainyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          rainyDays.length;
      final nonRainyAvg =
          nonRainyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          nonRainyDays.length;
      rainEffect = rainyAvg - nonRainyAvg;
    }

    final snowyDays = trainingPairs.where((p) => p.features.isSnowy == 1);
    final nonSnowyDays = trainingPairs.where((p) => p.features.isSnowy == 0);
    if (snowyDays.isNotEmpty && nonSnowyDays.isNotEmpty) {
      final snowyAvg =
          snowyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          snowyDays.length;
      final nonSnowyAvg =
          nonSnowyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          nonSnowyDays.length;
      snowEffect = snowyAvg - nonSnowyAvg;
    }

    final busyDays = trainingPairs.where((p) => p.features.isBusySubway == 1);
    final nonBusyDays = trainingPairs.where(
      (p) => p.features.isBusySubway == 0,
    );
    if (busyDays.isNotEmpty && nonBusyDays.isNotEmpty) {
      final busyAvg =
          busyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          busyDays.length;
      final nonBusyAvg =
          nonBusyDays.map((p) => p.sales).reduce((a, b) => a + b) /
          nonBusyDays.length;
      busyEffect = busyAvg - nonBusyAvg;
    }

    final weekendDays = trainingPairs.where((p) => p.features.isWeekend == 1);
    final weekdayDays = trainingPairs.where((p) => p.features.isWeekend == 0);
    if (weekendDays.isNotEmpty && weekdayDays.isNotEmpty) {
      final weekendAvg =
          weekendDays.map((p) => p.sales).reduce((a, b) => a + b) /
          weekendDays.length;
      final weekdayAvg =
          weekdayDays.map((p) => p.sales).reduce((a, b) => a + b) /
          weekdayDays.length;
      weekendEffect = weekendAvg - weekdayAvg;
    }

    final wedDays = trainingPairs.where((p) => p.features.isWednesday == 1);
    final nonWedDays = trainingPairs.where((p) => p.features.isWednesday == 0);
    if (wedDays.isNotEmpty && nonWedDays.isNotEmpty) {
      final wedAvg =
          wedDays.map((p) => p.sales).reduce((a, b) => a + b) / wedDays.length;
      final nonWedAvg =
          nonWedDays.map((p) => p.sales).reduce((a, b) => a + b) /
          nonWedDays.length;
      wedEffect = wedAvg - nonWedAvg;
    }

    final thuDays = trainingPairs.where((p) => p.features.isThursday == 1);
    final nonThuDays = trainingPairs.where((p) => p.features.isThursday == 0);
    if (thuDays.isNotEmpty && nonThuDays.isNotEmpty) {
      final thuAvg =
          thuDays.map((p) => p.sales).reduce((a, b) => a + b) / thuDays.length;
      final nonThuAvg =
          nonThuDays.map((p) => p.sales).reduce((a, b) => a + b) /
          nonThuDays.length;
      thuEffect = thuAvg - nonThuAvg;
    }

    // Temperature effect (simple linear)
    // Group into cold (<5) and warm (>15)
    final coldDays = trainingPairs.where((p) => p.features.temperature < 5);
    final warmDays = trainingPairs.where((p) => p.features.temperature > 15);
    if (coldDays.isNotEmpty && warmDays.isNotEmpty) {
      final coldAvg =
          coldDays.map((p) => p.sales).reduce((a, b) => a + b) /
          coldDays.length;
      final warmAvg =
          warmDays.map((p) => p.sales).reduce((a, b) => a + b) /
          warmDays.length;
      tempEffect = (coldAvg - warmAvg) / 20; // Per degree effect
    }

    return ItemModel(
      itemName: itemName,
      maxStock: maxStock,
      baseSales: meanSales,
      rainEffect: rainEffect,
      snowEffect: snowEffect,
      busySubwayEffect: busyEffect,
      weekendEffect: weekendEffect,
      wednesdayEffect: wedEffect,
      thursdayEffect: thuEffect,
      temperatureEffect: tempEffect,
    );
  }

  /// Predict sales for tomorrow for all items
  Future<Map<String, ItemPrediction>> predictTomorrow({
    required bool isRainyForecast,
    required bool isSnowyForecast,
    required bool expectedBusySubway,
    required String dayOfWeek,
    required double expectedTemperature,
  }) async {
    final predictions = <String, ItemPrediction>{};

    final features = Features(
      isRainy: isRainyForecast ? 1 : 0,
      isSnowy: isSnowyForecast ? 1 : 0,
      isBusySubway: expectedBusySubway ? 1 : 0,
      isWeekend: (dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday') ? 1 : 0,
      isWednesday: dayOfWeek == 'Wednesday' ? 1 : 0,
      isThursday: dayOfWeek == 'Thursday' ? 1 : 0,
      temperature: expectedTemperature,
      month: DateTime.now().month,
    );

    for (final entry in _itemModels.entries) {
      final itemName = entry.key;
      final model = entry.value;

      final prediction = model.predict(features);
      predictions[itemName] = prediction;
    }

    return predictions;
  }

  /// Predict sales for a specific date
  Future<Map<String, ItemPrediction>> predictForDate({
    required DateTime date,
    required Map<String, dynamic>? weatherForecast,
    required Map<String, dynamic>? ttcStatus,
  }) async {
    final dayOfWeek = _getDayName(date);

    // Extract weather info
    bool isRainy = false;
    bool isSnowy = false;
    double temperature = 15.0;

    if (weatherForecast != null) {
      final weatherCode = weatherForecast['weatherCode'] ?? 0;
      isRainy = weatherCode >= 61 && weatherCode <= 67;
      isSnowy = weatherCode >= 71 && weatherCode <= 77;
      temperature =
          (weatherForecast['temperature'] ??
                  weatherForecast['maxTemperature'] ??
                  15.0)
              .toDouble();
    }

    // Extract TTC info
    bool isBusy = false;
    if (ttcStatus != null) {
      final status = ttcStatus['overallStatus'] ?? 'moderate';
      isBusy = status == 'high' || status == 'very_high';
    }

    return predictTomorrow(
      isRainyForecast: isRainy,
      isSnowyForecast: isSnowy,
      expectedBusySubway: isBusy,
      dayOfWeek: dayOfWeek,
      expectedTemperature: temperature,
    );
  }

  String _getDayName(DateTime date) {
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

  /// Save model state to storage
  Future<void> _saveModelState() async {
    final prefs = await SharedPreferences.getInstance();

    // Save training data count
    await prefs.setInt('ai_synthetic_count', _syntheticDataCount);
    await prefs.setInt('ai_real_count', _realDataCount);

    // Save model parameters
    final modelParams = <String, Map<String, dynamic>>{};
    for (final entry in _itemModels.entries) {
      modelParams[entry.key] = entry.value.toJson();
    }
    await prefs.setString('ai_model_params', jsonEncode(modelParams));

    // Save last training date
    await prefs.setString('ai_last_trained', DateTime.now().toIso8601String());
  }

  /// Load model state from storage
  Future<bool> loadModelState() async {
    final prefs = await SharedPreferences.getInstance();

    _syntheticDataCount = prefs.getInt('ai_synthetic_count') ?? 0;
    _realDataCount = prefs.getInt('ai_real_count') ?? 0;

    final paramsJson = prefs.getString('ai_model_params');
    if (paramsJson == null) return false;

    try {
      final modelParams = jsonDecode(paramsJson) as Map<String, dynamic>;
      for (final entry in modelParams.entries) {
        _itemModels[entry.key] = ItemModel.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get model accuracy metrics
  Map<String, double> getModelAccuracy() {
    if (_trainingData.isEmpty) {
      return {'mape': 0.0, 'rmse': 0.0};
    }

    double totalError = 0;
    double totalSquaredError = 0;
    int count = 0;

    // Use last 30 days for validation
    final validationData = _trainingData.length > 30
        ? _trainingData.sublist(_trainingData.length - 30)
        : _trainingData;

    for (final day in validationData) {
      final features = Features.fromMap(
        day['mlFeatures'] as Map<String, dynamic>,
      );

      for (final entry in _itemModels.entries) {
        final itemName = entry.key;
        final model = entry.value;

        // Get actual sales
        int actual = 0;
        for (final category in (day['salesByCategory'] as Map).values) {
          final items = category['items'] as Map<String, dynamic>;
          if (items.containsKey(itemName)) {
            actual = items[itemName]['sold'] as int;
            break;
          }
        }

        final predicted = model.predict(features).predictedSales;
        final error = (actual - predicted).abs();
        totalError += actual > 0 ? error / actual : 0;
        totalSquaredError += error * error;
        count++;
      }
    }

    return {
      'mape': count > 0
          ? (totalError / count * 100)
          : 0.0, // Mean Absolute Percentage Error
      'rmse': count > 0
          ? sqrt(totalSquaredError / count)
          : 0.0, // Root Mean Square Error
    };
  }

  /// Export training data
  List<Map<String, dynamic>> get trainingData => _trainingData;

  /// Check if model is initialized
  bool get isInitialized => _itemModels.isNotEmpty;

  /// Get all item models
  Map<String, ItemModel> get itemModels => _itemModels;
}

/// Features for prediction
class Features {
  final int isRainy;
  final int isSnowy;
  final int isBusySubway;
  final int isWeekend;
  final int isWednesday;
  final int isThursday;
  final double temperature;
  final int month;

  Features({
    required this.isRainy,
    required this.isSnowy,
    required this.isBusySubway,
    required this.isWeekend,
    required this.isWednesday,
    required this.isThursday,
    required this.temperature,
    required this.month,
  });

  factory Features.fromMap(Map<String, dynamic> map) {
    return Features(
      isRainy: map['isRainy'] as int? ?? 0,
      isSnowy: map['isSnowy'] as int? ?? 0,
      isBusySubway: map['isBusySubway'] as int? ?? 0,
      isWeekend: map['isWeekend'] as int? ?? 0,
      isWednesday: map['isWednesday'] as int? ?? 0,
      isThursday: map['isThursday'] as int? ?? 0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 15.0,
      month: map['month'] as int? ?? 1,
    );
  }
}

/// Training data pair
class TrainingPair {
  final Features features;
  final int sales;

  TrainingPair({required this.features, required this.sales});
}

/// Model for a single item
class ItemModel {
  final String itemName;
  final int maxStock;
  final double baseSales;
  final double rainEffect;
  final double snowEffect;
  final double busySubwayEffect;
  final double weekendEffect;
  final double wednesdayEffect;
  final double thursdayEffect;
  final double temperatureEffect;

  ItemModel({
    required this.itemName,
    required this.maxStock,
    required this.baseSales,
    required this.rainEffect,
    required this.snowEffect,
    required this.busySubwayEffect,
    required this.weekendEffect,
    required this.wednesdayEffect,
    required this.thursdayEffect,
    required this.temperatureEffect,
  });

  factory ItemModel.defaultModel(int maxStock) {
    return ItemModel(
      itemName: '',
      maxStock: maxStock,
      baseSales: maxStock * 0.5,
      rainEffect: maxStock * 0.15,
      snowEffect: maxStock * 0.1,
      busySubwayEffect: maxStock * 0.12,
      weekendEffect: -maxStock * 0.1,
      wednesdayEffect: maxStock * 0.1,
      thursdayEffect: maxStock * 0.1,
      temperatureEffect: -0.02,
    );
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemName: json['itemName'] as String,
      maxStock: json['maxStock'] as int,
      baseSales: (json['baseSales'] as num).toDouble(),
      rainEffect: (json['rainEffect'] as num).toDouble(),
      snowEffect: (json['snowEffect'] as num).toDouble(),
      busySubwayEffect: (json['busySubwayEffect'] as num).toDouble(),
      weekendEffect: (json['weekendEffect'] as num).toDouble(),
      wednesdayEffect: (json['wednesdayEffect'] as num).toDouble(),
      thursdayEffect: (json['thursdayEffect'] as num).toDouble(),
      temperatureEffect: (json['temperatureEffect'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'maxStock': maxStock,
      'baseSales': baseSales,
      'rainEffect': rainEffect,
      'snowEffect': snowEffect,
      'busySubwayEffect': busySubwayEffect,
      'weekendEffect': weekendEffect,
      'wednesdayEffect': wednesdayEffect,
      'thursdayEffect': thursdayEffect,
      'temperatureEffect': temperatureEffect,
    };
  }

  /// Predict sales given features
  ItemPrediction predict(Features features) {
    double prediction = baseSales;

    prediction += features.isRainy * rainEffect;
    prediction += features.isSnowy * snowEffect;
    prediction += features.isBusySubway * busySubwayEffect;
    prediction += features.isWeekend * weekendEffect;
    prediction += features.isWednesday * wednesdayEffect;
    prediction += features.isThursday * thursdayEffect;
    prediction += (features.temperature - 15) * temperatureEffect;

    // Clamp to valid range
    prediction = prediction.clamp(0, maxStock.toDouble());

    // Calculate confidence based on feature importance
    double confidence = 0.7; // Base confidence
    if (features.isRainy == 1 || features.isSnowy == 1) confidence += 0.1;
    if (features.isBusySubway == 1) confidence += 0.05;
    if (features.isWednesday == 1 || features.isThursday == 1)
      confidence += 0.05;

    return ItemPrediction(
      itemName: itemName,
      predictedSales: prediction.round(),
      maxStock: maxStock,
      confidence: confidence.clamp(0.0, 0.95),
      factors: _getFactorDescriptions(features),
    );
  }

  List<String> _getFactorDescriptions(Features features) {
    final factors = <String>[];

    if (features.isRainy == 1) {
      factors.add('Rainy weather (+${rainEffect.toStringAsFixed(1)} sales)');
    }
    if (features.isSnowy == 1) {
      factors.add('Snowy weather (+${snowEffect.toStringAsFixed(1)} sales)');
    }
    if (features.isBusySubway == 1) {
      factors.add(
        'Busy subway (+${busySubwayEffect.toStringAsFixed(1)} sales)',
      );
    }
    if (features.isWeekend == 1) {
      factors.add('Weekend (${weekendEffect.toStringAsFixed(1)} sales)');
    }
    if (features.isWednesday == 1) {
      factors.add('Wednesday (+${wednesdayEffect.toStringAsFixed(1)} sales)');
    }
    if (features.isThursday == 1) {
      factors.add('Thursday (+${thursdayEffect.toStringAsFixed(1)} sales)');
    }

    return factors;
  }
}

/// Prediction result for an item
class ItemPrediction {
  final String itemName;
  final int predictedSales;
  final int maxStock;
  final double confidence;
  final List<String> factors;

  ItemPrediction({
    required this.itemName,
    required this.predictedSales,
    required this.maxStock,
    required this.confidence,
    required this.factors,
  });

  String get recommendation {
    final percentage = predictedSales / maxStock;
    if (percentage >= 0.8) {
      return 'Stock fully - high demand expected';
    } else if (percentage >= 0.6) {
      return 'Stock normally - moderate demand';
    } else {
      return 'Reduce stock - lower demand expected';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'predictedSales': predictedSales,
      'maxStock': maxStock,
      'confidence': confidence,
      'confidencePercent': '${(confidence * 100).round()}%',
      'factors': factors,
      'recommendation': recommendation,
    };
  }
}

/// Data mix ratio
class DataMixRatio {
  final int synthetic;
  final int real;

  DataMixRatio({required this.synthetic, required this.real});
}
