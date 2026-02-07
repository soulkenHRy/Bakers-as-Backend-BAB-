import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/shift_data.dart';
import '../services/shift_storage_service.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ShiftStorageService _storageService = ShiftStorageService();
  late TabController _tabController;

  List<WeekData> _weeks = [];
  List<ShiftData> _currentWeekShifts = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final List<String> _categories = [
    'all',
    'breakfast_lunch',
    'muffins',
    'cookies',
    'others',
    'donuts',
    'bagels',
    'timbits',
  ];

  final List<Color> _dayColors = [
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _weeks = await _storageService.getAllWeeks();
    _currentWeekShifts = await _storageService.getCurrentWeekShifts();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple[200],
        title: const Text('Sales Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'Week Comparison'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThisWeekTab(),
                _buildWeekComparisonTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }

  Widget _buildThisWeekTab() {
    if (_currentWeekShifts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No shift data for this week yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'End a shift to start collecting data',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryFilter(),
          const SizedBox(height: 16),
          _buildWeeklySummaryCard(),
          const SizedBox(height: 16),
          _buildDailySalesChart(),
          const SizedBox(height: 16),
          _buildDailyBreakdown(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_formatCategoryName(category)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.purple[100],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatCategoryName(String category) {
    if (category == 'all') return 'All';
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildWeeklySummaryCard() {
    int totalSales = 0;
    for (final shift in _currentWeekShifts) {
      if (_selectedCategory == 'all') {
        totalSales += shift.totalSales;
      } else {
        final category = shift.categorySales[_selectedCategory];
        if (category != null) {
          totalSales += category.totalSold;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Sales',
                  totalSales.toString(),
                  Icons.shopping_cart,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Shifts Recorded',
                  _currentWeekShifts.length.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Avg/Day',
                  _currentWeekShifts.isNotEmpty
                      ? (totalSales / _currentWeekShifts.length)
                            .toStringAsFixed(1)
                      : '0',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDailySalesChart() {
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < ShiftStorageService.daysOfWeek.length; i++) {
      final day = ShiftStorageService.daysOfWeek[i];
      final shift = _currentWeekShifts
          .where((s) => s.dayOfWeek == day)
          .firstOrNull;

      double sales = 0;
      if (shift != null) {
        if (_selectedCategory == 'all') {
          sales = shift.totalSales.toDouble();
        } else {
          final category = shift.categorySales[_selectedCategory];
          if (category != null) {
            sales = category.totalSold.toDouble();
          }
        }
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sales,
              color: _dayColors[i],
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < ShiftStorageService.daysOfWeek.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                ShiftStorageService.daysOfWeek[index].substring(
                                  0,
                                  3,
                                ),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._currentWeekShifts.map((shift) => _buildShiftTile(shift)),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTile(ShiftData shift) {
    int sales = 0;
    if (_selectedCategory == 'all') {
      sales = shift.totalSales;
    } else {
      final category = shift.categorySales[_selectedCategory];
      if (category != null) {
        sales = category.totalSold;
      }
    }

    final dayIndex = ShiftStorageService.daysOfWeek.indexOf(shift.dayOfWeek);
    final color = dayIndex >= 0 ? _dayColors[dayIndex] : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
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
                  shift.dayOfWeek,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(shift.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '$sales sold',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekComparisonTab() {
    if (_weeks.length < 2) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Need at least 2 weeks of data',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Complete more weeks to see comparisons',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort weeks by start date (most recent first)
    final sortedWeeks = List<WeekData>.from(_weeks)
      ..sort((a, b) => b.weekStartDate.compareTo(a.weekStartDate));

    final thisWeek = sortedWeeks[0];
    final lastWeek = sortedWeeks[1];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryFilter(),
          const SizedBox(height: 16),
          _buildComparisonSummary(thisWeek, lastWeek),
          const SizedBox(height: 16),
          _buildDayByDayComparison(thisWeek, lastWeek),
          const SizedBox(height: 16),
          _buildComparisonChart(thisWeek, lastWeek),
        ],
      ),
    );
  }

  Widget _buildComparisonSummary(WeekData thisWeek, WeekData lastWeek) {
    int thisWeekSales = 0;
    int lastWeekSales = 0;

    for (final shift in thisWeek.shifts) {
      if (_selectedCategory == 'all') {
        thisWeekSales += shift.totalSales;
      } else {
        final category = shift.categorySales[_selectedCategory];
        if (category != null) thisWeekSales += category.totalSold;
      }
    }

    for (final shift in lastWeek.shifts) {
      if (_selectedCategory == 'all') {
        lastWeekSales += shift.totalSales;
      } else {
        final category = shift.categorySales[_selectedCategory];
        if (category != null) lastWeekSales += category.totalSold;
      }
    }

    final difference = thisWeekSales - lastWeekSales;
    final percentChange = lastWeekSales > 0
        ? ((difference / lastWeekSales) * 100)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Week Over Week Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeekSummary('Last Week', lastWeekSales, Colors.blue),
                Icon(
                  difference >= 0 ? Icons.arrow_forward : Icons.arrow_back,
                  color: Colors.grey,
                ),
                _buildWeekSummary('This Week', thisWeekSales, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: difference >= 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      difference >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: difference >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${difference >= 0 ? '+' : ''}$difference (${percentChange.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: difference >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSummary(String label, int sales, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          sales.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Text('sales', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDayByDayComparison(WeekData thisWeek, WeekData lastWeek) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Day by Day Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last Week vs This Week',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...ShiftStorageService.daysOfWeek.map((day) {
              return _buildDayComparisonRow(day, thisWeek, lastWeek);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayComparisonRow(
    String day,
    WeekData thisWeek,
    WeekData lastWeek,
  ) {
    final thisShift = thisWeek.getShiftForDay(day);
    final lastShift = lastWeek.getShiftForDay(day);

    int thisSales = 0;
    int lastSales = 0;

    if (thisShift != null) {
      if (_selectedCategory == 'all') {
        thisSales = thisShift.totalSales;
      } else {
        final category = thisShift.categorySales[_selectedCategory];
        if (category != null) thisSales = category.totalSold;
      }
    }

    if (lastShift != null) {
      if (_selectedCategory == 'all') {
        lastSales = lastShift.totalSales;
      } else {
        final category = lastShift.categorySales[_selectedCategory];
        if (category != null) lastSales = category.totalSold;
      }
    }

    final difference = thisSales - lastSales;
    final dayIndex = ShiftStorageService.daysOfWeek.indexOf(day);
    final color = dayIndex >= 0 ? _dayColors[dayIndex] : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              day.substring(0, 3),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lastSales.toString(),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  thisSales.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: difference >= 0 ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${difference >= 0 ? '+' : ''}$difference',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: difference >= 0 ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(WeekData thisWeek, WeekData lastWeek) {
    final spots1 = <FlSpot>[];
    final spots2 = <FlSpot>[];

    for (int i = 0; i < ShiftStorageService.daysOfWeek.length; i++) {
      final day = ShiftStorageService.daysOfWeek[i];

      final lastShift = lastWeek.getShiftForDay(day);
      final thisShift = thisWeek.getShiftForDay(day);

      double lastSales = 0;
      double thisSales = 0;

      if (lastShift != null) {
        if (_selectedCategory == 'all') {
          lastSales = lastShift.totalSales.toDouble();
        } else {
          final category = lastShift.categorySales[_selectedCategory];
          if (category != null) lastSales = category.totalSold.toDouble();
        }
      }

      if (thisShift != null) {
        if (_selectedCategory == 'all') {
          thisSales = thisShift.totalSales.toDouble();
        } else {
          final category = thisShift.categorySales[_selectedCategory];
          if (category != null) thisSales = category.totalSold.toDouble();
        }
      }

      spots1.add(FlSpot(i.toDouble(), lastSales));
      spots2.add(FlSpot(i.toDouble(), thisSales));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trend Lines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 20, height: 3, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Last Week', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 20, height: 3, color: Colors.green),
                const SizedBox(width: 8),
                const Text('This Week', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots1,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: spots2,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < ShiftStorageService.daysOfWeek.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                ShiftStorageService.daysOfWeek[index].substring(
                                  0,
                                  3,
                                ),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_weeks.isEmpty && _currentWeekShifts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No trend data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Complete shifts to see sales trends',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryFilter(),
          const SizedBox(height: 16),
          _buildCategoryTrendChart(),
          const SizedBox(height: 16),
          _buildTopSellingItems(),
        ],
      ),
    );
  }

  Widget _buildCategoryTrendChart() {
    // Combine all shifts from weeks and current week
    final allShifts = <ShiftData>[];
    for (final week in _weeks) {
      allShifts.addAll(week.shifts);
    }
    allShifts.addAll(_currentWeekShifts);

    // Sort by date
    allShifts.sort((a, b) => a.date.compareTo(b.date));

    if (allShifts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data to display')),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < allShifts.length; i++) {
      final shift = allShifts[i];
      double sales = 0;

      if (_selectedCategory == 'all') {
        sales = shift.totalSales.toDouble();
      } else {
        final category = shift.categorySales[_selectedCategory];
        if (category != null) sales = category.totalSold.toDouble();
      }

      spots.add(FlSpot(i.toDouble(), sales));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatCategoryName(_selectedCategory)} Sales Trend',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last ${allShifts.length} shifts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withOpacity(0.1),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < allShifts.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                allShifts[index].dayOfWeek.substring(0, 1),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems() {
    // Aggregate sales by item across all shifts
    final itemSales = <String, int>{};

    final allShifts = <ShiftData>[];
    for (final week in _weeks) {
      allShifts.addAll(week.shifts);
    }
    allShifts.addAll(_currentWeekShifts);

    for (final shift in allShifts) {
      if (_selectedCategory == 'all') {
        for (final category in shift.categorySales.values) {
          for (final item in category.items.values) {
            itemSales[item.name] = (itemSales[item.name] ?? 0) + item.sold;
          }
        }
      } else {
        final category = shift.categorySales[_selectedCategory];
        if (category != null) {
          for (final item in category.items.values) {
            itemSales[item.name] = (itemSales[item.name] ?? 0) + item.sold;
          }
        }
      }
    }

    // Sort by sales
    final sortedItems = itemSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sortedItems.take(10).toList();

    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Selling Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final maxSales = topItems.first.value;
              final percentage = maxSales > 0 ? item.value / maxSales : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? Colors.orange[700]
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${item.value} sold',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        index < 3 ? Colors.orange : Colors.purple,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
