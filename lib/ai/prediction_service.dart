import 'dart:convert';
import 'sales_prediction_model.dart';
import 'synthetic_data_generator.dart';
import '../services/weather_service.dart';
import '../services/ttc_service.dart';

/// Service to manage AI predictions and model training
class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  final SalesPredictionModel _model = SalesPredictionModel();
  final WeatherService _weatherService = WeatherService();
  final TTCService _ttcService = TTCService();

  bool _isInitialized = false;

  /// Check if model is initialized
  bool get isInitialized => _isInitialized;

  /// Get the prediction model
  SalesPredictionModel get model => _model;

  /// Initialize the prediction service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Try to load existing model
    final loaded = await _model.loadModelState();

    if (!loaded) {
      // Initialize with synthetic data
      await _model.initializeWithSyntheticData();
    }

    _isInitialized = true;
  }

  /// Get predictions for tomorrow
  Future<PredictionResult> getPredictionsForTomorrow() async {
    await initialize();

    final tomorrow = DateTime.now().add(const Duration(days: 1));

    // Get weather forecast
    Map<String, dynamic>? weatherForecast;
    try {
      weatherForecast = await _weatherService.getTodayForecast();
    } catch (e) {
      print('Error fetching weather: $e');
    }

    // Get TTC status estimation
    Map<String, dynamic>? ttcStatus;
    try {
      final busyness = await _ttcService.getBusynessSummary();
      ttcStatus = busyness.toJson();
    } catch (e) {
      print('Error fetching TTC: $e');
    }

    // Get predictions
    final predictions = await _model.predictForDate(
      date: tomorrow,
      weatherForecast: weatherForecast,
      ttcStatus: ttcStatus,
    );

    // Group by category
    final byCategory = _groupPredictionsByCategory(predictions);

    return PredictionResult(
      date: tomorrow,
      predictions: predictions,
      predictionsByCategory: byCategory,
      weatherForecast: weatherForecast,
      ttcStatus: ttcStatus,
      dataRatio: _model.dataMixRatio,
      trainingPhase: _model.trainingPhase,
      accuracy: _model.getModelAccuracy(),
    );
  }

  Map<String, List<ItemPrediction>> _groupPredictionsByCategory(
    Map<String, ItemPrediction> predictions,
  ) {
    final byCategory = <String, List<ItemPrediction>>{
      'breakfast_lunch': [],
      'muffins': [],
      'cookies': [],
      'others': [],
      'donuts': [],
      'bagels': [],
      'timbits': [],
    };

    // Map items to categories
    final itemCategories = {
      'Hashbrowns': 'breakfast_lunch',
      'Sausage': 'breakfast_lunch',
      'Eggs': 'breakfast_lunch',
      'Omelet Bites 1': 'breakfast_lunch',
      'Omelet Bites 2': 'breakfast_lunch',
      'Scrambled Eggs': 'breakfast_lunch',
      'Blueberry Muffin': 'muffins',
      'Chocochip Muffin': 'muffins',
      'Hazelnut Muffin': 'muffins',
      'Rese-mini': 'cookies',
      'Brownie': 'cookies',
      'Chocochunk Cookie': 'cookies',
      'Oatmeal Raisin Cookie': 'cookies',
      'Brookie': 'cookies',
      'M&M': 'cookies',
      'Croissant': 'others',
      'Herb and Garlic': 'others',
      'Old Fashion Plain': 'donuts',
      'Sour Cream Glaze': 'donuts',
      'Apple Fritter': 'donuts',
      'Boston Cream': 'donuts',
      'Honey Dip': 'donuts',
      'Chocolate Dip': 'donuts',
      'Honey Cruller': 'donuts',
      'Chocolate Glazed': 'donuts',
      'Cinnamon Raisin': 'bagels',
      'Four Cheese Bagel': 'bagels',
      'Plain Bagel': 'bagels',
      '12 Grains Bagel': 'bagels',
      'Everything Bagel': 'bagels',
      'Sesame Seed': 'bagels',
      'Blueberry Cheesecake': 'timbits',
      'Birthday Cake': 'timbits',
      'Honey Dip Timbit': 'timbits',
      'Chocolate Glazed Timbit': 'timbits',
      'Filled Timbits': 'timbits',
    };

    for (final entry in predictions.entries) {
      final category = itemCategories[entry.key] ?? 'others';
      byCategory[category]?.add(entry.value);
    }

    return byCategory;
  }

  /// Add real shift data and retrain model
  Future<void> addRealDataAndRetrain(Map<String, dynamic> shiftData) async {
    await initialize();
    await _model.addRealDataAndRetrain(shiftData);
  }

  /// Generate and export synthetic data
  Future<String> exportSyntheticData({int days = 365}) async {
    final generator = SyntheticDataGenerator();
    final data = generator.generateYearData(days: days);
    return generator.exportToJson(data);
  }

  /// Export CSV for a specific item (for Prophet)
  Future<String> exportItemCSV(String itemName, {int days = 365}) async {
    final generator = SyntheticDataGenerator();
    final data = generator.generateYearData(days: days);
    return generator.exportToCSVForProphet(data, itemName);
  }

  /// Get model training statistics
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
    };
  }

  /// Reset model to synthetic data only
  Future<void> resetToSynthetic() async {
    await _model.initializeWithSyntheticData();
  }
}

/// Prediction result container
class PredictionResult {
  final DateTime date;
  final Map<String, ItemPrediction> predictions;
  final Map<String, List<ItemPrediction>> predictionsByCategory;
  final Map<String, dynamic>? weatherForecast;
  final Map<String, dynamic>? ttcStatus;
  final DataMixRatio dataRatio;
  final String trainingPhase;
  final Map<String, double> accuracy;

  PredictionResult({
    required this.date,
    required this.predictions,
    required this.predictionsByCategory,
    this.weatherForecast,
    this.ttcStatus,
    required this.dataRatio,
    required this.trainingPhase,
    required this.accuracy,
  });

  /// Get total predicted sales
  int get totalPredictedSales {
    return predictions.values.fold(0, (sum, p) => sum + p.predictedSales);
  }

  /// Get average confidence
  double get averageConfidence {
    if (predictions.isEmpty) return 0;
    return predictions.values.fold(0.0, (sum, p) => sum + p.confidence) /
        predictions.length;
  }

  /// Export as JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'predictions': predictions.map((k, v) => MapEntry(k, v.toJson())),
      'summary': {
        'totalPredictedSales': totalPredictedSales,
        'averageConfidence': '${(averageConfidence * 100).round()}%',
        'dataRatio': {
          'synthetic': '${dataRatio.synthetic}%',
          'real': '${dataRatio.real}%',
        },
        'trainingPhase': trainingPhase,
        'accuracy': {
          'mape': '${accuracy['mape']?.toStringAsFixed(1)}%',
          'rmse': accuracy['rmse']?.toStringAsFixed(2),
        },
      },
      'weatherForecast': weatherForecast,
      'ttcStatus': ttcStatus,
    };
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
