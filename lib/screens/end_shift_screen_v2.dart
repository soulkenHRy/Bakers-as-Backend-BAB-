import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/end_shift_service.dart';
import '../services/shift_storage_service.dart';
import '../ai/ai_prediction_service.dart';

/// Screen to end shift - compares AI predictions with actual sales and retrains
class EndShiftScreen extends StatefulWidget {
  const EndShiftScreen({super.key});

  @override
  State<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends State<EndShiftScreen> {
  final EndShiftService _endShiftService = EndShiftService();
  final ShiftStorageService _storageService = ShiftStorageService();
  final AIPredictionService _aiService = AIPredictionService();

  bool _isLoading = false;
  String _loadingMessage = '';

  ComprehensiveShiftData? _shiftData;
  ShiftComparison? _comparison;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[200],
        title: const Text('End Shift'),
        actions: [
          if (_shiftData != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyJsonToClipboard,
              tooltip: 'Copy shift JSON',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _comparison != null
          ? _buildComparisonView()
          : _shiftData != null
          ? _buildResultView()
          : _buildInitialView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_loadingMessage, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
    final hasPrediction = _aiService.currentShiftPrediction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'End Your Shift',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Today is ${_storageService.getCurrentDayOfWeek()}, ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            if (hasPrediction) ...[
              Card(
                color: Colors.green[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI made predictions at shift start.\n'
                          'Will compare with actual sales!',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Card(
                color: Colors.orange[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No AI predictions for this shift.\n'
                          'Use "Start Shift" next time!',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Ending shift will:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            _buildFeatureItem(Icons.shopping_cart, 'Record all sales data'),
            _buildFeatureItem(Icons.wb_sunny, 'Save weather conditions'),
            _buildFeatureItem(Icons.subway, 'Save transit status'),
            if (hasPrediction)
              _buildFeatureItem(Icons.compare_arrows, 'Compare AI vs Actual'),
            _buildFeatureItem(Icons.psychology, 'Retrain AI with real data'),
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _endShift,
              icon: const Icon(Icons.check_circle, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  'END SHIFT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Future<void> _endShift() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Collecting shift data...';
      _errorMessage = null;
    });

    try {
      // 1. Collect all shift data
      setState(() => _loadingMessage = 'Collecting sales data...');
      final shiftData = await _endShiftService.endShift();

      // 2. Get actual sales from DataManager
      setState(() => _loadingMessage = 'Processing actual sales...');
      final actualSales = _getActualSalesFromShiftData(shiftData);

      // 3. Compare with AI predictions and retrain
      setState(() => _loadingMessage = 'AI comparing predictions vs actual...');
      final comparison = await _aiService.endShiftAndLearn(
        actualSales: actualSales,
        fullShiftData: shiftData.toJson(),
      );

      setState(() {
        _shiftData = shiftData;
        _comparison = comparison;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error ending shift: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, int> _getActualSalesFromShiftData(ComprehensiveShiftData data) {
    final sales = <String, int>{};

    for (final category in data.categorySales.values) {
      for (final item in category.items.values) {
        sales[item.name] = item.sold;
      }
    }

    return sales;
  }

  Widget _buildComparisonView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildComparisonHeader(),
        const SizedBox(height: 16),
        _buildAccuracyCard(),
        const SizedBox(height: 16),
        _buildLearningCard(),
        const SizedBox(height: 24),
        _buildDetailedComparison(),
        const SizedBox(height: 24),
        _buildDoneButton(),
      ],
    );
  }

  Widget _buildComparisonHeader() {
    final accuracy = (_comparison!.overallAccuracy * 100).toStringAsFixed(1);

    Color accuracyColor;
    IconData accuracyIcon;
    String verdict;

    if (_comparison!.overallAccuracy >= 0.8) {
      accuracyColor = Colors.green;
      accuracyIcon = Icons.emoji_events;
      verdict = 'Excellent!';
    } else if (_comparison!.overallAccuracy >= 0.6) {
      accuracyColor = Colors.blue;
      accuracyIcon = Icons.thumb_up;
      verdict = 'Good job!';
    } else if (_comparison!.overallAccuracy >= 0.4) {
      accuracyColor = Colors.orange;
      accuracyIcon = Icons.trending_up;
      verdict = 'Learning...';
    } else {
      accuracyColor = Colors.red;
      accuracyIcon = Icons.school;
      verdict = 'Still learning';
    }

    return Card(
      color: accuracyColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(accuracyIcon, size: 48, color: accuracyColor),
            const SizedBox(height: 8),
            Text(
              verdict,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accuracyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Accuracy: $accuracy%',
              style: TextStyle(fontSize: 18, color: accuracyColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn(
                  'Predicted',
                  '${_comparison!.totalPredicted}',
                  Colors.indigo,
                ),
                const Text(
                  'vs',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                _buildStatColumn(
                  'Actual',
                  '${_comparison!.totalActual}',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyCard() {
    final accurate = _comparison!.accurate;
    final underPredicted = _comparison!.underPredicted;
    final overPredicted = _comparison!.overPredicted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediction Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              '✓ Accurate',
              '${accurate.length} items',
              Colors.green,
            ),
            _buildSummaryRow(
              '↑ Under-predicted',
              '${underPredicted.length} items',
              Colors.orange,
            ),
            _buildSummaryRow(
              '↓ Over-predicted',
              '${overPredicted.length} items',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningCard() {
    final phase = _comparison!.trainingPhase;
    final ratio = _comparison!.dataRatio;

    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'AI Learning Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(phase, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            // Progress bar showing synthetic vs real
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.real / 100,
                backgroundColor: Colors.purple[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ratio.synthetic}% Synthetic',
                  style: TextStyle(fontSize: 11, color: Colors.purple[300]),
                ),
                Text(
                  '${ratio.real}% Real',
                  style: TextStyle(fontSize: 11, color: Colors.green[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ AI has learned from this shift\'s real data!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedComparison() {
    // Show items sorted by biggest difference
    final sorted = _comparison!.itemComparisons.values.toList()
      ..sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item by Item Comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[100],
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Item',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'You',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Diff',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Items (show top 20)
              ...sorted.take(20).map((item) => _buildComparisonRow(item)),
              if (sorted.length > 20)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '+ ${sorted.length - 20} more items...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(ItemComparison item) {
    Color diffColor;
    if (item.difference.abs() <= 1) {
      diffColor = Colors.green;
    } else if (item.wasUnderPredicted) {
      diffColor = Colors.orange;
    } else {
      diffColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.itemName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.predicted}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.indigo[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.actual}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.differenceText,
              textAlign: TextAlign.center,
              style: TextStyle(color: diffColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    // Fallback if no comparison (shouldn't happen but just in case)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'Shift Ended Successfully!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift ended. AI has learned from today\'s data!'),
            backgroundColor: Colors.green,
          ),
        );
      },
      icon: const Icon(Icons.check),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'DONE',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _copyJsonToClipboard() {
    if (_shiftData != null) {
      Clipboard.setData(ClipboardData(text: _shiftData!.toJsonString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift JSON copied to clipboard!')),
      );
    }
  }
}
