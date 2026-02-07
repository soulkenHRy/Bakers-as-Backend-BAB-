import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/end_shift_service.dart';
import '../services/shift_storage_service.dart';
import '../ai/prediction_service.dart';

/// Screen to end shift and view comprehensive data
class EndShiftScreen extends StatefulWidget {
  const EndShiftScreen({super.key});

  @override
  State<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends State<EndShiftScreen> {
  final EndShiftService _endShiftService = EndShiftService();
  final ShiftStorageService _storageService = ShiftStorageService();
  final PredictionService _predictionService = PredictionService();

  bool _isLoading = false;
  ComprehensiveShiftData? _shiftData;
  String? _jsonOutput;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[200],
        title: const Text('End Shift'),
        actions: [
          if (_jsonOutput != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
              tooltip: 'Copy JSON',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _shiftData != null
          ? _buildResultView()
          : _buildInitialView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Collecting shift data...', style: TextStyle(fontSize: 16)),
          SizedBox(height: 10),
          Text(
            'Fetching weather and transit info',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
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
            const Text(
              'This will collect:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            _buildFeatureItem(Icons.wb_sunny, "Today's weather forecast"),
            _buildFeatureItem(Icons.subway, 'TTC subway status & busyness'),
            _buildFeatureItem(Icons.calendar_today, 'Day and date information'),
            _buildFeatureItem(Icons.shopping_cart, 'All sales data by product'),
            _buildFeatureItem(Icons.psychology, 'Train AI with real data'),
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
              icon: const Icon(Icons.stop_circle, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  'END SHIFT',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(250, 60),
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
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Ended Successfully!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      Text(
                        'JSON data generated at ${DateFormat('h:mm a').format(DateTime.now())}',
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Day Information
          _buildSectionCard(
            'Day Information',
            Icons.calendar_today,
            Colors.blue,
            [
              _buildInfoRow(
                'Date',
                DateFormat('MMMM d, yyyy').format(_shiftData!.shiftDate),
              ),
              _buildInfoRow('Day', _shiftData!.dayName),
              _buildInfoRow(
                'Weekend',
                _shiftData!.dayOfWeek == 'Saturday' ||
                        _shiftData!.dayOfWeek == 'Sunday'
                    ? 'Yes'
                    : 'No',
              ),
            ],
          ),

          // Weather Information
          if (_shiftData!.weather != null)
            _buildSectionCard('Weather', Icons.wb_sunny, Colors.orange, [
              _buildInfoRow(
                'Temperature',
                '${_shiftData!.weather!.temperature.round()}°C',
              ),
              _buildInfoRow(
                'Feels Like',
                '${_shiftData!.weather!.apparentTemperature.round()}°C',
              ),
              _buildInfoRow(
                'Condition',
                _shiftData!.weather!.weatherDescription,
              ),
              _buildInfoRow('Humidity', '${_shiftData!.weather!.humidity}%'),
              _buildInfoRow(
                'Wind',
                '${_shiftData!.weather!.windSpeed.round()} km/h',
              ),
              _buildInfoRow(
                'Sales Impact',
                _shiftData!.weather!.salesImpact.toUpperCase(),
              ),
            ]),

          // TTC Information
          if (_shiftData!.ttcBusyness != null)
            _buildSectionCard('TTC Subway Status', Icons.subway, Colors.red, [
              _buildInfoRow(
                'Overall Status',
                _shiftData!.ttcBusyness!.overallStatus.toUpperCase(),
              ),
              _buildInfoRow(
                'Normal Stations',
                '${_shiftData!.ttcBusyness!.normalStations}',
              ),
              _buildInfoRow(
                'Busy Stations',
                '${_shiftData!.ttcBusyness!.busyStations}',
              ),
              _buildInfoRow(
                'Delayed Stations',
                '${_shiftData!.ttcBusyness!.delayedStations}',
              ),
              _buildInfoRow(
                'Closed Stations',
                '${_shiftData!.ttcBusyness!.closedStations}',
              ),
              _buildInfoRow(
                'Traffic Impact',
                _shiftData!.ttcBusyness!.trafficImpact
                    .replaceAll('_', ' ')
                    .toUpperCase(),
              ),
              if (_shiftData!.ttcBusyness!.activeAlerts.isNotEmpty)
                _buildInfoRow(
                  'Active Alerts',
                  '${_shiftData!.ttcBusyness!.activeAlerts.length}',
                ),
            ]),

          // Sales Summary
          _buildSectionCard(
            'Sales Summary',
            Icons.shopping_cart,
            Colors.green,
            [
              _buildInfoRow(
                'Total Items Sold',
                '${_shiftData!.totalItemsSold}',
              ),
              ..._shiftData!.categorySales.entries.map((e) {
                return _buildInfoRow(
                  _formatCategoryName(e.key),
                  '${e.value.totalSold} sold',
                );
              }),
            ],
          ),

          // JSON Output
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'JSON Output',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  TextButton.icon(
                    onPressed: _saveToStorage,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: SelectableText(
                _jsonOutput ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),

          const SizedBox(height: 20),
          // Done button
          Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _endShift() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shiftData = await _endShiftService.endShift();
      final jsonOutput = shiftData.toJsonString();

      setState(() {
        _shiftData = shiftData;
        _jsonOutput = jsonOutput;
        _isLoading = false;
      });

      // Automatically train AI with this real data
      _trainAIWithRealData(shiftData.toJson());
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error ending shift: $e';
      });
    }
  }

  /// Train AI model with real shift data in background
  Future<void> _trainAIWithRealData(Map<String, dynamic> shiftJson) async {
    try {
      await _predictionService.addRealDataAndRetrain(shiftJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.psychology, color: Colors.white),
                SizedBox(width: 8),
                Text('AI model updated with today\'s data!'),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Don't show error for AI training - it's a background task
      debugPrint('AI training error: $e');
    }
  }

  void _copyToClipboard() {
    if (_jsonOutput != null) {
      Clipboard.setData(ClipboardData(text: _jsonOutput!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveToStorage() async {
    if (_shiftData == null) return;

    try {
      // Convert to ShiftData and save
      final shift = _storageService.collectCurrentShiftData();
      await _storageService.saveShift(shift);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift data saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
