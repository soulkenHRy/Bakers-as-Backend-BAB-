import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/synthetic_data_generator.dart';
import '../ai/prediction_service.dart';
import '../data/item_definitions.dart';

/// Screen to generate and export synthetic training data
class SyntheticDataScreen extends StatefulWidget {
  const SyntheticDataScreen({super.key});

  @override
  State<SyntheticDataScreen> createState() => _SyntheticDataScreenState();
}

class _SyntheticDataScreenState extends State<SyntheticDataScreen> {
  final SyntheticDataGenerator _generator = SyntheticDataGenerator();
  final PredictionService _predictionService = PredictionService();

  bool _isGenerating = false;
  List<Map<String, dynamic>>? _generatedData;
  String? _selectedItemForCSV;
  int _daysToGenerate = 365;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple[200],
        title: const Text('Synthetic Data Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            _buildInfoCard(),
            const SizedBox(height: 16),

            // Generation Controls
            _buildGenerationControls(),
            const SizedBox(height: 16),

            // Generated Data Preview
            if (_generatedData != null) ...[
              _buildDataPreview(),
              const SizedBox(height: 16),
              _buildExportOptions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, size: 32, color: Colors.purple),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Synthetic Data for AI Training',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Generate realistic fake sales data based on these patterns:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildPatternItem(
              Icons.water_drop,
              'Rainy/Snowy weather',
              'HIGH sales',
              Colors.green,
            ),
            _buildPatternItem(
              Icons.subway,
              'Busy subway',
              'HIGH sales',
              Colors.green,
            ),
            _buildPatternItem(
              Icons.calendar_today,
              'Wednesday & Thursday',
              'HIGH sales',
              Colors.green,
            ),
            _buildPatternItem(
              Icons.weekend,
              'Weekends',
              'LOWER sales',
              Colors.orange,
            ),
            _buildPatternItem(
              Icons.wb_sunny,
              'Clear weather',
              'NORMAL sales',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(
    IconData icon,
    String condition,
    String effect,
    Color effectColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(condition)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: effectColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              effect,
              style: TextStyle(
                color: effectColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Days slider
            Row(
              children: [
                const Text('Days to generate:'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _daysToGenerate.toDouble(),
                    min: 30,
                    max: 730,
                    divisions: 14,
                    label: '$_daysToGenerate days',
                    onChanged: (value) {
                      setState(() {
                        _daysToGenerate = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '$_daysToGenerate days',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateData,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Generate Data',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview() {
    final dataCount = _generatedData!.length;
    final firstDay = _generatedData!.first;
    final lastDay = _generatedData!.last;

    // Calculate statistics
    int totalHighSalesDays = 0;
    int totalRainyDays = 0;
    int totalBusySubwayDays = 0;

    for (final day in _generatedData!) {
      final features = day['mlFeatures'] as Map<String, dynamic>;
      if (features['isBadWeather'] == 1) totalRainyDays++;
      if (features['isBusySubway'] == 1) totalBusySubwayDays++;
      if (features['salesMultiplier'] >= 0.7) totalHighSalesDays++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Generated $dataCount days of data',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Date range: ${firstDay['shiftInfo']['date']} to ${lastDay['shiftInfo']['date']}',
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Statistics:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatRow('Rainy/Snowy Days', totalRainyDays, dataCount),
            _buildStatRow('Busy Subway Days', totalBusySubwayDays, dataCount),
            _buildStatRow('High Sales Days', totalHighSalesDays, dataCount),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, int total) {
    final percentage = (count / total * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text('$count ($percentage%)')],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Export Full JSON
            ListTile(
              leading: const Icon(Icons.code, color: Colors.blue),
              title: const Text('Export Full JSON'),
              subtitle: const Text('Complete shift data for all days'),
              trailing: ElevatedButton(
                onPressed: _exportFullJson,
                child: const Text('Copy'),
              ),
            ),
            const Divider(),

            // Export CSV for Prophet
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export CSV for Prophet'),
              subtitle: const Text('Select an item to export training data'),
              trailing: DropdownButton<String>(
                value: _selectedItemForCSV,
                hint: const Text('Select item'),
                items: ItemDefinitions.allItems.map((item) {
                  return DropdownMenuItem(
                    value: item.name,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedItemForCSV = value;
                  });
                },
              ),
            ),
            if (_selectedItemForCSV != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: ElevatedButton.icon(
                  onPressed: _exportItemCSV,
                  icon: const Icon(Icons.download),
                  label: Text('Export $_selectedItemForCSV CSV'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),

            const Divider(),

            // Initialize Model
            ListTile(
              leading: const Icon(Icons.model_training, color: Colors.purple),
              title: const Text('Initialize AI Model'),
              subtitle: const Text('Train model with this synthetic data'),
              trailing: ElevatedButton(
                onPressed: _initializeModel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Train'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateData() async {
    setState(() {
      _isGenerating = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final data = _generator.generateYearData(days: _daysToGenerate);

    setState(() {
      _generatedData = data;
      _isGenerating = false;
    });
  }

  void _exportFullJson() {
    if (_generatedData == null) return;

    final json = _generator.exportToJson(_generatedData!);
    Clipboard.setData(ClipboardData(text: json));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_generatedData!.length} days of JSON data!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportItemCSV() {
    if (_generatedData == null || _selectedItemForCSV == null) return;

    final csv = _generator.exportToCSVForProphet(
      _generatedData!,
      _selectedItemForCSV!,
    );
    Clipboard.setData(ClipboardData(text: csv));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied CSV data for $_selectedItemForCSV!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _initializeModel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Training AI model...'),
          ],
        ),
      ),
    );

    try {
      await _predictionService.resetToSynthetic();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI model trained with synthetic data!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
