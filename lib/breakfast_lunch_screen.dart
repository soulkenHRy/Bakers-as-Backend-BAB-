import 'dart:async';
import 'package:flutter/material.dart';
import 'item_data.dart';
import 'data/data_manager.dart';

class BreakfastLunchScreen extends StatefulWidget {
  const BreakfastLunchScreen({super.key});

  @override
  State<BreakfastLunchScreen> createState() => _BreakfastLunchScreenState();
}

class _BreakfastLunchScreenState extends State<BreakfastLunchScreen> {
  final DataManager _dataManager = DataManager();
  late List<ItemData> items;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    items = _dataManager.getItems('breakfast_lunch');

    // Listen for updates from network
    _updateSubscription = _dataManager.updateStream.listen((update) {
      if (update.category == 'breakfast_lunch' && mounted) {
        setState(() {
          // Items are already updated in DataManager, just refresh UI
        });
      }
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showAddQuantityDialog(String category, String itemName) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock: $itemName'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantity to add',
            hintText: 'Enter number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context, quantity);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result > 0) {
      _dataManager.addStock(category, itemName, quantity: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Breakfast and Lunch'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.5,
          children: [
            _buildInteractiveBox(
              items[0],
              4,
              _buildSmallRectangle,
              defaultTotal: 12,
            ),
            _buildInteractiveBox(items[1], 4, _buildCircle, defaultTotal: 12),
            _buildInteractiveBox(items[2], 4, _buildCircle, defaultTotal: 12),
            _buildInteractiveBox(items[3], 2, _buildCircle, defaultTotal: 4),
            _buildInteractiveBox(items[4], 2, _buildCircle, defaultTotal: 4),
            _buildInteractiveBox(items[5], 5, _buildCircle, defaultTotal: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveBox(
    ItemData item,
    int crossAxisCount,
    Widget Function() shapeBuilder, {
    int defaultTotal = 12,
  }) {
    int needed = item.remaining < defaultTotal
        ? defaultTotal - item.remaining
        : 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          item.showControls = !item.showControls;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[200],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${item.total}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'Sold: ${item.sold}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'Remaining: ${item.remaining}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (needed > 0)
              Text(
                'Needed: $needed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 4),
            if (item.showControls)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (item.remaining > 0) {
                        _dataManager.sellItem('breakfast_lunch', item.name);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _showAddQuantityDialog('breakfast_lunch', item.name);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _buildMiniGrid(
                item.remaining,
                shapeBuilder,
                crossAxisCount: crossAxisCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGrid(
    int count,
    Widget Function() itemBuilder, {
    int crossAxisCount = 4,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemCount: count,
      itemBuilder: (context, index) => itemBuilder(),
    );
  }

  Widget _buildSmallRectangle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown, width: 1),
        borderRadius: BorderRadius.circular(2),
        color: Colors.orange[300],
      ),
    );
  }

  Widget _buildCircle() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.brown, width: 1),
        color: Colors.yellow[300],
      ),
    );
  }
}
