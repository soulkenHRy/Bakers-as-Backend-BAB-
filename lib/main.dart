import 'package:flutter/material.dart';
import 'breakfast_lunch_screen.dart';
import 'showcase_screen.dart';
import 'widgets/connection_status_widget.dart';
import 'sender/sender_screens.dart';
import 'data/data_manager.dart';
import 'screens/sales_analytics_screen.dart';
import 'screens/start_shift_screen.dart';
import 'screens/end_shift_screen_v2.dart';
import 'screens/synthetic_data_screen.dart';
import 'ai/ai_prediction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AI with pre-trained synthetic data
  await AIPredictionService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tims App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ModeSelectionScreen(),
    );
  }
}

/// Screen to select between Sender and Receiver modes
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Tims App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Mode',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // Sender Mode Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SenderMainScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.send, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  children: [
                    Text(
                      'SENDER',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Record sales & send updates',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(280, 80),
                backgroundColor: Colors.orange[100],
                foregroundColor: Colors.orange[900],
              ),
            ),
            const SizedBox(height: 24),
            // Receiver Mode Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReceiverMainScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.inbox, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  children: [
                    Text(
                      'RECEIVER',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Display inventory status',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(280, 80),
                backgroundColor: Colors.purple[100],
                foregroundColor: Colors.purple[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Receiver main screen
class ReceiverMainScreen extends StatefulWidget {
  const ReceiverMainScreen({super.key});

  @override
  State<ReceiverMainScreen> createState() => _ReceiverMainScreenState();
}

class _ReceiverMainScreenState extends State<ReceiverMainScreen> {
  final DataManager _dataManager = DataManager();
  final AIPredictionService _aiService = AIPredictionService();
  int _updateCount = 0;
  bool _shiftStarted = false;

  @override
  void initState() {
    super.initState();
    // Check if shift was already started (prediction exists)
    _shiftStarted = _aiService.currentShiftPrediction != null;

    // Listen for incoming data updates
    _dataManager.updateStream.listen((update) {
      if (mounted) {
        setState(() {
          _updateCount++;
        });
        _showUpdateSnackbar(update);
      }
    });
  }

  void _showUpdateSnackbar(DataUpdate update) {
    if (!mounted) return;
    if (update.item == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${update.itemName}: Sold! (Remaining: ${update.item!.remaining})',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStockItems = _dataManager.getLowStockItems();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple[200],
        title: const Text('Receiver Mode'),
        actions: [
          // Show Start or End Shift based on state
          if (!_shiftStarted)
            TextButton.icon(
              onPressed: () => _navigateToStartShift(context),
              icon: const Icon(Icons.play_circle, color: Colors.green),
              label: const Text(
                'Start',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _navigateToEndShift(context),
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              label: const Text(
                'End',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Network connection status card
          const ConnectionStatusWidget(),

          // Shift status banner
          _buildShiftStatusBanner(),

          // Main navigation buttons and content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Navigation buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BreakfastLunchScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 60),
                    ),
                    child: const Text(
                      'Breakfast and Lunch',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShowcaseScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 60),
                    ),
                    child: const Text(
                      'Showcase',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Start or End Shift Button (large) - AI Feature
                  if (!_shiftStarted)
                    ElevatedButton.icon(
                      onPressed: () => _navigateToStartShift(context),
                      icon: const Icon(Icons.play_circle, size: 32),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'START SHIFT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Get AI predictions for today',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(280, 80),
                        backgroundColor: Colors.green[100],
                        foregroundColor: Colors.green[900],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEndShift(context),
                      icon: const Icon(Icons.stop_circle, size: 32),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'END SHIFT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Compare AI vs Actual & Learn',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(280, 80),
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[900],
                      ),
                    ),
                  const SizedBox(height: 20),
                  // View Analytics button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SalesAnalyticsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: Colors.purple[100],
                      foregroundColor: Colors.purple[900],
                    ),
                    label: const Text(
                      'View Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Synthetic Data Generator (smaller button for testing)
                  TextButton.icon(
                    onPressed: () => _navigateToSyntheticData(context),
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('Synthetic Data Generator'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Reset All button
                  ElevatedButton(
                    onPressed: () {
                      _showResetConfirmation();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[900],
                    ),
                    child: const Text(
                      'Reset All',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Show received data count
                  if (_updateCount > 0)
                    Text(
                      'Received $_updateCount update(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  // Low stock warnings
                  if (lowStockItems.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange[800],
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Low Stock Alert',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'These items are running low (below 50%):',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...lowStockItems.map(
                            (item) => _buildLowStockItem(item),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Items?'),
        content: const Text(
          'This will reset all items in Breakfast & Lunch and Showcase to their default state.\n\n'
          'All sales counts will be set to 0 and remaining counts will be reset to their totals.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _dataManager.resetAll();
              Navigator.pop(context);
              setState(() {
                _updateCount = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All items have been reset to default state'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStatusBanner() {
    if (!_shiftStarted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.purple[50],
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.purple, size: 18),
            SizedBox(width: 8),
            Text(
              'Click "Start Shift" to get AI predictions!',
              style: TextStyle(color: Colors.purple),
            ),
          ],
        ),
      );
    }

    // Show current prediction summary
    final prediction = _aiService.currentShiftPrediction;
    final total = prediction?.totalPredictedSales ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.green[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            'AI predicts $total total items today',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToStartShift(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartShiftScreen(
          onShiftStarted: () {
            setState(() => _shiftStarted = true);
          },
        ),
      ),
    );
  }

  void _navigateToEndShift(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EndShiftScreen()),
    ).then((_) {
      // Refresh state after ending shift
      setState(() {
        _shiftStarted = _aiService.currentShiftPrediction != null;
      });
    });
  }

  void _navigateToSyntheticData(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SyntheticDataScreen()),
    );
  }

  Widget _buildLowStockItem(LowStockItem item) {
    Color getColorForPercentage(double percentage) {
      if (percentage < 25) return Colors.red;
      if (percentage < 40) return Colors.orange;
      return Colors.amber;
    }

    final color = getColorForPercentage(item.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remaining: ${item.remaining}/${item.defaultStock}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${item.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(
                  255,
                  (color.red * 0.7).toInt(),
                  (color.green * 0.7).toInt(),
                  (color.blue * 0.7).toInt(),
                ),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
