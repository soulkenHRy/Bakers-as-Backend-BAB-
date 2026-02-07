import 'package:flutter/material.dart';
import '../data/item_definitions.dart';
import '../services/sender_service.dart';
import '../widgets/sender_connect_widget.dart';

class SenderMainScreen extends StatefulWidget {
  const SenderMainScreen({super.key});

  @override
  State<SenderMainScreen> createState() => _SenderMainScreenState();
}

class _SenderMainScreenState extends State<SenderMainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[200],
        title: const Text('Sender Mode'),
      ),
      body: Column(
        children: [
          const SenderConnectWidget(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Record sales and send updates',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SenderCategoryScreen(
                            title: 'Breakfast & Lunch',
                            category: 'breakfast_lunch',
                            items: ItemDefinitions.breakfastLunchItems,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(250, 60),
                      backgroundColor: Colors.orange[100],
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
                          builder: (context) => const SenderShowcaseScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(250, 60),
                      backgroundColor: Colors.orange[100],
                    ),
                    child: const Text(
                      'Showcase',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen showing a list of items in a category with minus buttons
class SenderCategoryScreen extends StatefulWidget {
  final String title;
  final String category;
  final List<ItemDef> items;

  const SenderCategoryScreen({
    super.key,
    required this.title,
    required this.category,
    required this.items,
  });

  @override
  State<SenderCategoryScreen> createState() => _SenderCategoryScreenState();
}

class _SenderCategoryScreenState extends State<SenderCategoryScreen> {
  final SenderService _senderService = SenderService();
  final Map<String, int> _sentCounts = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[200],
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Connection status indicator
          _buildConnectionStatus(),
          // Item list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return _buildItemTile(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: _senderService.isConnected ? Colors.green[100] : Colors.red[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _senderService.isConnected ? Icons.link : Icons.link_off,
            size: 16,
            color: _senderService.isConnected
                ? Colors.green[800]
                : Colors.red[800],
          ),
          const SizedBox(width: 8),
          Text(
            _senderService.isConnected
                ? 'Connected to ${_senderService.receiverIp}'
                : 'Not connected',
            style: TextStyle(
              color: _senderService.isConnected
                  ? Colors.green[800]
                  : Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ItemDef item) {
    final sentCount = _sentCounts[item.name] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Sold: $sentCount',
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sent count badge
            if (sentCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '-$sentCount',
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Minus button
            Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _sellItem(item),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.remove, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sellItem(ItemDef item) async {
    if (!_senderService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected! Go back and connect first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await _senderService.sendSoldItem(
      category: widget.category,
      itemName: item.name,
      quantity: 1,
    );

    if (success) {
      setState(() {
        _sentCounts[item.name] = (_sentCounts[item.name] ?? 0) + 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} sold!'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Sender Showcase screen with all categories
class SenderShowcaseScreen extends StatelessWidget {
  const SenderShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[200],
        title: const Text('Showcase'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategoryButton(
            context,
            'Muffins',
            'muffins',
            ItemDefinitions.muffins,
          ),
          _buildCategoryButton(
            context,
            'Cookies',
            'cookies',
            ItemDefinitions.cookies,
          ),
          _buildCategoryButton(
            context,
            'Others',
            'others',
            ItemDefinitions.others,
          ),
          _buildCategoryButton(
            context,
            'Donuts',
            'donuts',
            ItemDefinitions.donuts,
          ),
          _buildCategoryButton(
            context,
            'Bagels',
            'bagels',
            ItemDefinitions.bagels,
          ),
          _buildCategoryButton(
            context,
            'Timbits',
            'timbits',
            ItemDefinitions.timbits,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(
    BuildContext context,
    String title,
    String category,
    List<ItemDef> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SenderCategoryScreen(
                title: title,
                category: category,
                items: items,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: Colors.orange[100],
        ),
        child: Text(
          '$title (${items.length} items)',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
