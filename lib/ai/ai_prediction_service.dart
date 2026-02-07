import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sales_prediction_model.dart';
import '../services/weather_service.dart';
import '../services/ttc_service.dart';

/// Service to manage AI predictions and model training
///
/// Flow:
/// 1. Auto-initializes with synthetic data on first launch
/// 2. Predicts at shift START
/// 3. Compares predictions vs actual at shift END
/// 4. Retrains with real data
class AIPredictionService {
  static final AIPredictionService _instance = AIPredictionService._internal();
  factory AIPredictionService() => _instance;
  AIPredictionService._internal();

  final SalesPredictionModel _model = SalesPredictionModel();
  final WeatherService _weatherService = WeatherService();
  final TTCService _ttcService = TTCService();

  bool _isInitialized = false;

  // Current shift predictions (made at shift start)
  ShiftPrediction? _currentShiftPrediction;

  /// Check if model is initialized
  bool get isInitialized => _isInitialized;

  /// Get the prediction model
  SalesPredictionModel get model => _model;

  /// Get current shift prediction
  ShiftPrediction? get currentShiftPrediction => _currentShiftPrediction;

  /// Initialize the AI - auto-loads or creates from synthetic data
  /// This should be called at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Try to load existing model
    final loaded = await _model.loadModelState();

    if (!loaded) {
      // First time - initialize with synthetic data (pre-trained)
      print('AI: First launch - training with synthetic data...');
      await _model.initializeWithSyntheticData();
      print('AI: Pre-training complete!');
    } else {
      print('AI: Loaded existing model');
    }

    _isInitialized = true;
  }

  /// Called when shift STARTS - makes predictions for all items
  /// Returns predictions that should be shown to user
  Future<ShiftPrediction> startShiftAndPredict() async {
    await initialize();

    final now = DateTime.now();

    // Get current conditions
    Map<String, dynamic>? weatherData;
    Map<String, dynamic>? ttcData;

    try {
      final weather = await _weatherService.getCurrentWeather();
      weatherData = weather?.toJson();
    } catch (e) {
      print('AI: Could not fetch weather: $e');
    }

    try {
      final ttc = await _ttcService.getBusynessSummary();
      ttcData = ttc.toJson();
    } catch (e) {
      print('AI: Could not fetch TTC: $e');
    }

    // Make predictions for today
    final predictions = await _model.predictForDate(
      date: now,
      weatherForecast: weatherData,
      ttcStatus: ttcData,
    );

    // Store the prediction for comparison at end of shift
    _currentShiftPrediction = ShiftPrediction(
      date: now,
      predictions: predictions,
      weatherConditions: weatherData,
      ttcConditions: ttcData,
      predictedAt: now,
    );

    // Save to storage in case app restarts
    await _saveCurrentPrediction();

    return _currentShiftPrediction!;
  }

  /// Called when shift ENDS - compares predictions with actual sales
  /// Returns comparison results and retrains the model
  Future<ShiftComparison> endShiftAndLearn({
    required Map<String, int> actualSales, // itemName -> sold count
    required Map<String, dynamic>
    fullShiftData, // Complete shift JSON for training
  }) async {
    await initialize();

    // Load prediction if not in memory (app might have restarted)
    if (_currentShiftPrediction == null) {
      await _loadCurrentPrediction();
    }

    // If still no prediction (first shift ever), create a dummy one
    if (_currentShiftPrediction == null) {
      _currentShiftPrediction = ShiftPrediction(
        date: DateTime.now(),
        predictions: {},
        weatherConditions: null,
        ttcConditions: null,
        predictedAt: DateTime.now(),
      );
    }

    // Compare predictions vs actual
    final comparison = _compareResults(
      predictions: _currentShiftPrediction!.predictions,
      actual: actualSales,
    );

    // Create comparison result
    final result = ShiftComparison(
      date: _currentShiftPrediction!.date,
      predictions: _currentShiftPrediction!.predictions,
      actualSales: actualSales,
      itemComparisons: comparison,
      dataRatio: _model.dataMixRatio,
      trainingPhase: _model.trainingPhase,
    );

    // Retrain model with real data
    await _model.addRealDataAndRetrain(fullShiftData);

    // Clear current prediction
    _currentShiftPrediction = null;
    await _clearCurrentPrediction();

    // Save comparison history
    await _saveComparisonHistory(result);

    return result;
  }

  /// Compare predictions with actual results
  Map<String, ItemComparison> _compareResults({
    required Map<String, ItemPrediction> predictions,
    required Map<String, int> actual,
  }) {
    final comparisons = <String, ItemComparison>{};

    // Get all item names from both predictions and actual
    final allItems = <String>{...predictions.keys, ...actual.keys};

    for (final itemName in allItems) {
      final predicted = predictions[itemName]?.predictedSales ?? 0;
      final actualSold = actual[itemName] ?? 0;
      final difference = actualSold - predicted;
      final accuracy = predicted > 0
          ? (1 - (difference.abs() / predicted)).clamp(0.0, 1.0)
          : (actualSold == 0 ? 1.0 : 0.0);

      comparisons[itemName] = ItemComparison(
        itemName: itemName,
        predicted: predicted,
        actual: actualSold,
        difference: difference,
        accuracy: accuracy,
        wasUnderPredicted: difference > 0,
        wasOverPredicted: difference < 0,
      );
    }

    return comparisons;
  }

  /// Save current prediction to storage
  Future<void> _saveCurrentPrediction() async {
    if (_currentShiftPrediction == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ai_current_prediction',
      jsonEncode(_currentShiftPrediction!.toJson()),
    );
  }

  /// Load current prediction from storage
  Future<void> _loadCurrentPrediction() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ai_current_prediction');

    if (data != null) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        _currentShiftPrediction = ShiftPrediction.fromJson(json);
      } catch (e) {
        print('AI: Could not load prediction: $e');
      }
    }
  }

  /// Clear current prediction from storage
  Future<void> _clearCurrentPrediction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_current_prediction');
  }

  /// Save comparison to history
  Future<void> _saveComparisonHistory(ShiftComparison comparison) async {
    final prefs = await SharedPreferences.getInstance();

    // Load existing history
    final historyJson = prefs.getString('ai_comparison_history');
    List<Map<String, dynamic>> history = [];

    if (historyJson != null) {
      try {
        history = (jsonDecode(historyJson) as List)
            .cast<Map<String, dynamic>>();
      } catch (e) {
        history = [];
      }
    }

    // Add new comparison
    history.add(comparison.toJson());

    // Keep only last 30 days
    if (history.length > 30) {
      history = history.sublist(history.length - 30);
    }

    await prefs.setString('ai_comparison_history', jsonEncode(history));
  }

  /// Get comparison history
  Future<List<ShiftComparison>> getComparisonHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('ai_comparison_history');

    if (historyJson == null) return [];

    try {
      final list = (jsonDecode(historyJson) as List)
          .cast<Map<String, dynamic>>();
      return list.map((j) => ShiftComparison.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get overall AI accuracy over history
  Future<double> getOverallAccuracy() async {
    final history = await getComparisonHistory();
    if (history.isEmpty) return 0.0;

    double totalAccuracy = 0;
    int count = 0;

    for (final comparison in history) {
      totalAccuracy += comparison.overallAccuracy;
      count++;
    }

    return count > 0 ? totalAccuracy / count : 0.0;
  }

  /// Get training stats
  Map<String, dynamic> getTrainingStats() {
    return {
      'dataRatio': {
        'synthetic': _model.dataMixRatio.synthetic,
        'real': _model.dataMixRatio.real,
      },
      'trainingPhase': _model.trainingPhase,
      'accuracy': _model.getModelAccuracy(),
      'totalTrainingDays': _model.trainingData.length,
      'isInitialized': _isInitialized,
      'hasCurrentPrediction': _currentShiftPrediction != null,
    };
  }

  /// Reset model to synthetic data only (for testing)
  Future<void> resetToSynthetic() async {
    await _model.initializeWithSyntheticData();
    _currentShiftPrediction = null;
    await _clearCurrentPrediction();
  }
}

/// Prediction made at shift start
class ShiftPrediction {
  final DateTime date;
  final Map<String, ItemPrediction> predictions;
  final Map<String, dynamic>? weatherConditions;
  final Map<String, dynamic>? ttcConditions;
  final DateTime predictedAt;

  ShiftPrediction({
    required this.date,
    required this.predictions,
    this.weatherConditions,
    this.ttcConditions,
    required this.predictedAt,
  });

  int get totalPredictedSales {
    return predictions.values.fold(0, (sum, p) => sum + p.predictedSales);
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'predictions': predictions.map((k, v) => MapEntry(k, v.toJson())),
      'weatherConditions': weatherConditions,
      'ttcConditions': ttcConditions,
      'predictedAt': predictedAt.toIso8601String(),
    };
  }

  factory ShiftPrediction.fromJson(Map<String, dynamic> json) {
    final predictionsMap = <String, ItemPrediction>{};
    final predsJson = json['predictions'] as Map<String, dynamic>?;
    if (predsJson != null) {
      for (final entry in predsJson.entries) {
        predictionsMap[entry.key] = ItemPrediction(
          itemName: entry.key,
          predictedSales: entry.value['predictedSales'] as int? ?? 0,
          maxStock: entry.value['maxStock'] as int? ?? 0,
          confidence: (entry.value['confidence'] as num?)?.toDouble() ?? 0.5,
          factors: (entry.value['factors'] as List?)?.cast<String>() ?? [],
        );
      }
    }

    return ShiftPrediction(
      date: DateTime.parse(json['date'] as String),
      predictions: predictionsMap,
      weatherConditions: json['weatherConditions'] as Map<String, dynamic>?,
      ttcConditions: json['ttcConditions'] as Map<String, dynamic>?,
      predictedAt: DateTime.parse(json['predictedAt'] as String),
    );
  }
}

/// Comparison of prediction vs actual at shift end
class ShiftComparison {
  final DateTime date;
  final Map<String, ItemPrediction> predictions;
  final Map<String, int> actualSales;
  final Map<String, ItemComparison> itemComparisons;
  final DataMixRatio dataRatio;
  final String trainingPhase;

  ShiftComparison({
    required this.date,
    required this.predictions,
    required this.actualSales,
    required this.itemComparisons,
    required this.dataRatio,
    required this.trainingPhase,
  });

  /// Overall accuracy (0-1)
  double get overallAccuracy {
    if (itemComparisons.isEmpty) return 0.0;
    return itemComparisons.values
            .map((c) => c.accuracy)
            .reduce((a, b) => a + b) /
        itemComparisons.length;
  }

  /// Total predicted
  int get totalPredicted {
    return predictions.values.fold(0, (sum, p) => sum + p.predictedSales);
  }

  /// Total actual
  int get totalActual {
    return actualSales.values.fold(0, (sum, v) => sum + v);
  }

  /// Items where we under-predicted
  List<ItemComparison> get underPredicted {
    return itemComparisons.values.where((c) => c.wasUnderPredicted).toList()
      ..sort((a, b) => b.difference.compareTo(a.difference));
  }

  /// Items where we over-predicted
  List<ItemComparison> get overPredicted {
    return itemComparisons.values.where((c) => c.wasOverPredicted).toList()
      ..sort((a, b) => a.difference.compareTo(b.difference));
  }

  /// Items we got right (within 1)
  List<ItemComparison> get accurate {
    return itemComparisons.values
        .where((c) => c.difference.abs() <= 1)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'predictions': predictions.map((k, v) => MapEntry(k, v.toJson())),
      'actualSales': actualSales,
      'itemComparisons': itemComparisons.map((k, v) => MapEntry(k, v.toJson())),
      'dataRatio': {'synthetic': dataRatio.synthetic, 'real': dataRatio.real},
      'trainingPhase': trainingPhase,
      'overallAccuracy': overallAccuracy,
      'totalPredicted': totalPredicted,
      'totalActual': totalActual,
    };
  }

  factory ShiftComparison.fromJson(Map<String, dynamic> json) {
    final predictionsMap = <String, ItemPrediction>{};
    final predsJson = json['predictions'] as Map<String, dynamic>?;
    if (predsJson != null) {
      for (final entry in predsJson.entries) {
        predictionsMap[entry.key] = ItemPrediction(
          itemName: entry.key,
          predictedSales: entry.value['predictedSales'] as int? ?? 0,
          maxStock: entry.value['maxStock'] as int? ?? 0,
          confidence: (entry.value['confidence'] as num?)?.toDouble() ?? 0.5,
          factors: (entry.value['factors'] as List?)?.cast<String>() ?? [],
        );
      }
    }

    final comparisonsMap = <String, ItemComparison>{};
    final compsJson = json['itemComparisons'] as Map<String, dynamic>?;
    if (compsJson != null) {
      for (final entry in compsJson.entries) {
        comparisonsMap[entry.key] = ItemComparison.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    final ratioJson = json['dataRatio'] as Map<String, dynamic>?;

    return ShiftComparison(
      date: DateTime.parse(json['date'] as String),
      predictions: predictionsMap,
      actualSales: (json['actualSales'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
      itemComparisons: comparisonsMap,
      dataRatio: DataMixRatio(
        synthetic: ratioJson?['synthetic'] as int? ?? 100,
        real: ratioJson?['real'] as int? ?? 0,
      ),
      trainingPhase: json['trainingPhase'] as String? ?? 'Unknown',
    );
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

/// Comparison for a single item
class ItemComparison {
  final String itemName;
  final int predicted;
  final int actual;
  final int difference; // actual - predicted
  final double accuracy; // 0-1
  final bool wasUnderPredicted;
  final bool wasOverPredicted;

  ItemComparison({
    required this.itemName,
    required this.predicted,
    required this.actual,
    required this.difference,
    required this.accuracy,
    required this.wasUnderPredicted,
    required this.wasOverPredicted,
  });

  String get differenceText {
    if (difference > 0) return '+$difference';
    if (difference < 0) return '$difference';
    return '0';
  }

  String get verdict {
    if (difference.abs() <= 1) return '✓ Accurate';
    if (wasUnderPredicted) return '↑ Under-predicted';
    return '↓ Over-predicted';
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'predicted': predicted,
      'actual': actual,
      'difference': difference,
      'accuracy': accuracy,
      'wasUnderPredicted': wasUnderPredicted,
      'wasOverPredicted': wasOverPredicted,
    };
  }

  factory ItemComparison.fromJson(Map<String, dynamic> json) {
    return ItemComparison(
      itemName: json['itemName'] as String,
      predicted: json['predicted'] as int,
      actual: json['actual'] as int,
      difference: json['difference'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      wasUnderPredicted: json['wasUnderPredicted'] as bool,
      wasOverPredicted: json['wasOverPredicted'] as bool,
    );
  }
}
