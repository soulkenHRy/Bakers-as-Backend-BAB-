import 'package:flutter/material.dart';
import '../ai/ai_prediction_service.dart';
import '../ai/sales_prediction_model.dart';
import '../data/item_definitions.dart';

/// Screen shown when starting a shift - displays AI predictions
class StartShiftScreen extends StatefulWidget {
  final VoidCallback? onShiftStarted;

  const StartShiftScreen({super.key, this.onShiftStarted});

  @override
  State<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends State<StartShiftScreen> {
  final AIPredictionService _aiService = AIPredictionService();

  bool _isLoading = true;
  String? _error;
  ShiftPrediction? _prediction;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get AI predictions for this shift
      final prediction = await _aiService.startShiftAndPredict();

      setState(() {
        _prediction = prediction;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load predictions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Shift Predictions'),
        backgroundColor: Colors.indigo[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPredictions,
            tooltip: 'Refresh predictions',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _prediction != null
          ? _buildStartShiftButton()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI is analyzing conditions...'),
            SizedBox(height: 8),
            Text(
              'Checking weather & transit...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPredictions,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_prediction == null) {
      return const Center(child: Text('No predictions available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        _buildConditionsCard(),
        const SizedBox(height: 16),
        _buildTrainingStatusCard(),
        const SizedBox(height: 24),
        _buildPredictionsList(),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final totalPredicted = _prediction!.totalPredictedSales;

    return Card(
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.psychology, size: 48, color: Colors.indigo),
            const SizedBox(height: 8),
            const Text(
              'AI Predictions for Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total items predicted: $totalPredicted',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on current weather, transit, and day patterns',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsCard() {
    final weather = _prediction!.weatherConditions;
    final ttc = _prediction!.ttcConditions;

    // Parse weather
    String weatherDesc = 'Unknown';
    IconData weatherIcon = Icons.help_outline;
    Color weatherColor = Colors.grey;

    if (weather != null) {
      final code = weather['weatherCode'] ?? 0;
      final temp = weather['temperature'] ?? weather['maxTemperature'];

      if (code >= 61 && code <= 67) {
        weatherDesc = 'Rainy ${temp?.toStringAsFixed(0)}°C';
        weatherIcon = Icons.umbrella;
        weatherColor = Colors.blue;
      } else if (code >= 71 && code <= 77) {
        weatherDesc = 'Snowy ${temp?.toStringAsFixed(0)}°C';
        weatherIcon = Icons.ac_unit;
        weatherColor = Colors.lightBlue;
      } else if (code <= 3) {
        weatherDesc = 'Clear ${temp?.toStringAsFixed(0)}°C';
        weatherIcon = Icons.wb_sunny;
        weatherColor = Colors.orange;
      } else {
        weatherDesc = 'Cloudy ${temp?.toStringAsFixed(0)}°C';
        weatherIcon = Icons.cloud;
        weatherColor = Colors.grey;
      }
    }

    // Parse TTC
    String ttcDesc = 'Unknown';
    IconData ttcIcon = Icons.subway;
    Color ttcColor = Colors.grey;

    if (ttc != null) {
      final status = ttc['overallStatus'] ?? 'moderate';
      final alertCount = ttc['totalAlerts'] ?? 0;

      if (status == 'high' || status == 'very_high') {
        ttcDesc = 'Busy ($alertCount alerts)';
        ttcIcon = Icons.warning;
        ttcColor = Colors.orange;
      } else if (status == 'low') {
        ttcDesc = 'Quiet';
        ttcIcon = Icons.subway;
        ttcColor = Colors.green;
      } else {
        ttcDesc = 'Moderate';
        ttcIcon = Icons.subway;
        ttcColor = Colors.blue;
      }
    }

    // Day of week
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[now.weekday - 1];
    final isHighDay = now.weekday == 3 || now.weekday == 4; // Wed/Thu
    final isWeekend = now.weekday >= 6;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Conditions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildConditionChip(
                    icon: weatherIcon,
                    label: weatherDesc,
                    color: weatherColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildConditionChip(
                    icon: ttcIcon,
                    label: ttcDesc,
                    color: ttcColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildConditionChip(
                    icon: Icons.calendar_today,
                    label: dayName,
                    color: isHighDay
                        ? Colors.green
                        : (isWeekend ? Colors.red : Colors.grey),
                    subtitle: isHighDay
                        ? 'High sales day'
                        : (isWeekend ? 'Weekend' : null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionChip({
    required IconData icon,
    required String label,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildTrainingStatusCard() {
    final stats = _aiService.getTrainingStats();
    final ratio = stats['dataRatio'] as Map<String, dynamic>;
    final phase = stats['trainingPhase'] as String;
    final realPercent = ratio['real'] as int;

    Color phaseColor;
    IconData phaseIcon;

    if (realPercent == 0) {
      phaseColor = Colors.purple;
      phaseIcon = Icons.school;
    } else if (realPercent < 50) {
      phaseColor = Colors.blue;
      phaseIcon = Icons.trending_up;
    } else {
      phaseColor = Colors.green;
      phaseIcon = Icons.verified;
    }

    return Card(
      color: phaseColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(phaseIcon, color: phaseColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Training Phase',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phase,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: phaseColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsList() {
    // Group predictions by category
    final categories = <String, List<MapEntry<String, ItemPrediction>>>{};

    // Create category mapping
    final categoryMap = <String, String>{};
    for (final item in ItemDefinitions.breakfastLunchItems) {
      categoryMap[item.name] = 'Breakfast & Lunch';
    }
    for (final item in ItemDefinitions.muffins) {
      categoryMap[item.name] = 'Muffins';
    }
    for (final item in ItemDefinitions.cookies) {
      categoryMap[item.name] = 'Cookies';
    }
    for (final item in ItemDefinitions.donuts) {
      categoryMap[item.name] = 'Donuts';
    }
    for (final item in ItemDefinitions.bagels) {
      categoryMap[item.name] = 'Bagels';
    }
    for (final item in ItemDefinitions.timbits) {
      categoryMap[item.name] = 'Timbits';
    }
    for (final item in ItemDefinitions.others) {
      categoryMap[item.name] = 'Others';
    }

    for (final entry in _prediction!.predictions.entries) {
      final category = categoryMap[entry.key] ?? 'Other';
      categories.putIfAbsent(category, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Predicted Sales by Item',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'AI recommends stocking these quantities:',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...categories.entries.map((catEntry) {
          return _buildCategoryPredictions(catEntry.key, catEntry.value);
        }),
      ],
    );
  }

  Widget _buildCategoryPredictions(
    String category,
    List<MapEntry<String, ItemPrediction>> predictions,
  ) {
    // Sort by predicted sales (highest first)
    predictions.sort(
      (a, b) => b.value.predictedSales.compareTo(a.value.predictedSales),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Total: ${predictions.fold<int>(0, (sum, p) => sum + p.value.predictedSales)} items',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        initiallyExpanded: true,
        children: predictions.map((entry) {
          return _buildPredictionTile(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildPredictionTile(String itemName, ItemPrediction prediction) {
    final confidence = prediction.confidence;
    Color confColor;
    String confText;

    if (confidence >= 0.8) {
      confColor = Colors.green;
      confText = 'High';
    } else if (confidence >= 0.5) {
      confColor = Colors.orange;
      confText = 'Medium';
    } else {
      confColor = Colors.red;
      confText = 'Low';
    }

    return ListTile(
      title: Text(itemName),
      subtitle: prediction.factors.isNotEmpty
          ? Text(
              prediction.factors.join(' • '),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${prediction.predictedSales}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[900],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: confColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              confText,
              style: TextStyle(fontSize: 10, color: confColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartShiftButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          // Show confirmation dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Start Shift'),
              content: const Text(
                'AI predictions are saved.\n\n'
                'During the shift, record actual sales.\n\n'
                'At shift end, AI will compare predictions vs actual '
                'and learn from the difference.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                    widget.onShiftStarted?.call();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Shift started! AI predictions saved.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start Shift'),
                ),
              ],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        child: const Text(
          'START SHIFT',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
