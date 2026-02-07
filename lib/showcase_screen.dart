import 'dart:async';
import 'package:flutter/material.dart';
import 'item_data.dart';
import 'data/data_manager.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final DataManager _dataManager = DataManager();
  StreamSubscription? _updateSubscription;

  // Muffins
  late ItemData muffin1, muffin2, muffin3;
  // Cookies
  late ItemData cookie1, cookie2, cookie3, cookie4, cookie5, cookie6;
  // Others
  late ItemData others1, others2;
  // Donuts
  late ItemData donut1, donut2, donut3, donut4, donut5, donut6, donut7, donut8;
  // Bagels
  late ItemData bagel1, bagel2, bagel3, bagel4, bagel5, bagel6;
  // Timbits
  late ItemData timbit1, timbit2, timbit3, timbit4, timbit5;

  @override
  void initState() {
    super.initState();
    _loadItemsFromDataManager();

    // Listen for updates from network
    _updateSubscription = _dataManager.updateStream.listen((update) {
      if (mounted) {
        setState(() {
          // Refresh items from data manager
          _loadItemsFromDataManager();
        });
      }
    });
  }

  void _loadItemsFromDataManager() {
    // Muffins
    final muffins = _dataManager.getItems('muffins');
    muffin1 = muffins.isNotEmpty
        ? muffins[0]
        : ItemData(name: 'Blueberry Muffin', total: 6);
    muffin2 = muffins.length > 1
        ? muffins[1]
        : ItemData(name: 'Chocochip Muffin', total: 6);
    muffin3 = muffins.length > 2
        ? muffins[2]
        : ItemData(name: 'Hazelnut Muffin', total: 6);

    // Cookies
    final cookies = _dataManager.getItems('cookies');
    cookie1 = cookies.isNotEmpty
        ? cookies[0]
        : ItemData(name: 'Rese-mini', total: 4);
    cookie2 = cookies.length > 1
        ? cookies[1]
        : ItemData(name: 'Brownie', total: 4);
    cookie3 = cookies.length > 2
        ? cookies[2]
        : ItemData(name: 'Chocochunk Cookie', total: 6);
    cookie4 = cookies.length > 3
        ? cookies[3]
        : ItemData(name: 'Oatmeal Raisin Cookie', total: 6);
    cookie5 = cookies.length > 4
        ? cookies[4]
        : ItemData(name: 'Brookie', total: 4);
    cookie6 = cookies.length > 5 ? cookies[5] : ItemData(name: 'M&M', total: 4);

    // Others
    final others = _dataManager.getItems('others');
    others1 = others.isNotEmpty
        ? others[0]
        : ItemData(name: 'Croissant', total: 9);
    others2 = others.length > 1
        ? others[1]
        : ItemData(name: 'Herb and Garlic', total: 5);

    // Donuts
    final donuts = _dataManager.getItems('donuts');
    donut1 = donuts.isNotEmpty
        ? donuts[0]
        : ItemData(name: 'Old Fashion Plain', total: 6);
    donut2 = donuts.length > 1
        ? donuts[1]
        : ItemData(name: 'Sour Cream Glaze', total: 6);
    donut3 = donuts.length > 2
        ? donuts[2]
        : ItemData(name: 'Apple Fritter', total: 6);
    donut4 = donuts.length > 3
        ? donuts[3]
        : ItemData(name: 'Boston Cream', total: 6);
    donut5 = donuts.length > 4
        ? donuts[4]
        : ItemData(name: 'Honey Dip', total: 4);
    donut6 = donuts.length > 5
        ? donuts[5]
        : ItemData(name: 'Chocolate Dip', total: 6);
    donut7 = donuts.length > 6
        ? donuts[6]
        : ItemData(name: 'Honey Cruller', total: 4);
    donut8 = donuts.length > 7
        ? donuts[7]
        : ItemData(name: 'Chocolate Glazed', total: 4);

    // Bagels
    final bagels = _dataManager.getItems('bagels');
    bagel1 = bagels.isNotEmpty
        ? bagels[0]
        : ItemData(name: 'Cinnamon Raisin', total: 5);
    bagel2 = bagels.length > 1
        ? bagels[1]
        : ItemData(name: 'Four Cheese Bagel', total: 5);
    bagel3 = bagels.length > 2
        ? bagels[2]
        : ItemData(name: 'Plain Bagel', total: 5);
    bagel4 = bagels.length > 3
        ? bagels[3]
        : ItemData(name: '12 Grains Bagel', total: 5);
    bagel5 = bagels.length > 4
        ? bagels[4]
        : ItemData(name: 'Everything Bagel', total: 10);
    bagel6 = bagels.length > 5
        ? bagels[5]
        : ItemData(name: 'Sesame Seed', total: 10);

    // Timbits
    final timbits = _dataManager.getItems('timbits');
    timbit1 = timbits.isNotEmpty
        ? timbits[0]
        : ItemData(name: 'Blueberry Cheesecake', total: 40);
    timbit2 = timbits.length > 1
        ? timbits[1]
        : ItemData(name: 'Birthday Cake', total: 40);
    timbit3 = timbits.length > 2
        ? timbits[2]
        : ItemData(name: 'Honey Dip', total: 40);
    timbit4 = timbits.length > 3
        ? timbits[3]
        : ItemData(name: 'Chocolate Glazed', total: 40);
    timbit5 = timbits.length > 4
        ? timbits[4]
        : ItemData(name: 'Filled Timbits', total: 40);
  }

  /// Get category based on item name
  String _getCategoryForItem(ItemData item) {
    // Muffins
    if (item.name.contains('Muffin')) return 'muffins';
    // Cookies
    if ([
      'Rese-mini',
      'Brownie',
      'Chocochunk Cookie',
      'Oatmeal Raisin Cookie',
      'Brookie',
      'M&M',
    ].contains(item.name))
      return 'cookies';
    // Others
    if (item.name == 'Croissant' || item.name == 'Herb and Garlic')
      return 'others';
    // Donuts
    if ([
      'Old Fashion Plain',
      'Sour Cream Glaze',
      'Apple Fritter',
      'Boston Cream',
      'Honey Dip',
      'Chocolate Dip',
      'Honey Cruller',
      'Chocolate Glazed',
    ].contains(item.name))
      return 'donuts';
    // Bagels
    if ([
      'Cinnamon Raisin',
      'Four Cheese Bagel',
      'Plain Bagel',
      '12 Grains Bagel',
      'Everything Bagel',
      'Sesame Seed',
    ].contains(item.name))
      return 'bagels';
    // Timbits
    if ([
      'Blueberry Cheesecake',
      'Birthday Cake',
      'Filled Timbits',
    ].contains(item.name))
      return 'timbits';
    // Handle overlapping names (Honey Dip, Chocolate Glazed exist in both donuts and timbits)
    // Check by total to differentiate
    if (item.total == 40) return 'timbits';
    return 'others';
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
        title: const Text('Showcase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MUFFINS SECTION
            _buildSectionHeader('Muffins'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    muffin1,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    muffin2,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    muffin3,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2, height: 32),

            // COOKIES SECTION
            _buildSectionHeader('Cookies'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    cookie1,
                    2,
                    _buildCircle,
                    defaultTotal: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    cookie2,
                    2,
                    _buildSmallRectangle,
                    defaultTotal: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    cookie3,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    cookie4,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    cookie5,
                    2,
                    _buildCircle,
                    defaultTotal: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    cookie6,
                    2,
                    _buildCircle,
                    defaultTotal: 4,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2, height: 32),

            // OTHERS SECTION
            _buildSectionHeader('Others'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    others1,
                    3,
                    _buildMoon,
                    defaultTotal: 9,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    others2,
                    5,
                    _buildSquare,
                    defaultTotal: 5,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const Divider(thickness: 2, height: 32),

            // DONUTS SECTION
            _buildSectionHeader('Donuts'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    donut1,
                    3,
                    _buildCircle,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut2,
                    3,
                    _buildDonut,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut3,
                    3,
                    _buildSmallRectangle,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut4,
                    3,
                    _buildDonut,
                    defaultTotal: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    donut5,
                    2,
                    _buildDonut,
                    defaultTotal: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut6,
                    3,
                    _buildDonut,
                    defaultTotal: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut7,
                    2,
                    _buildDonut,
                    defaultTotal: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    donut8,
                    2,
                    _buildDonut,
                    defaultTotal: 4,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2, height: 32),

            // BAGELS SECTION
            _buildSectionHeader('Bagels'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    bagel1,
                    5,
                    _buildDonut,
                    defaultTotal: 5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    bagel2,
                    5,
                    _buildDonut,
                    defaultTotal: 5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    bagel3,
                    5,
                    _buildDonut,
                    defaultTotal: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    bagel4,
                    5,
                    _buildDonut,
                    defaultTotal: 5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    bagel5,
                    5,
                    _buildDonut,
                    defaultTotal: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    bagel6,
                    5,
                    _buildDonut,
                    defaultTotal: 10,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2, height: 32),

            // TIMBITS SECTION
            _buildSectionHeader('Timbits'),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    timbit1,
                    8,
                    _buildTinyCircle,
                    defaultTotal: 40,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    timbit2,
                    8,
                    _buildTinyCircle,
                    defaultTotal: 40,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    timbit3,
                    8,
                    _buildTinyCircle,
                    defaultTotal: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInteractiveBox(
                    timbit4,
                    8,
                    _buildTinyCircle,
                    defaultTotal: 40,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInteractiveBox(
                    timbit5,
                    8,
                    _buildTinyCircle,
                    defaultTotal: 40,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
            if (item.showControls)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (item.remaining > 0) {
                          _dataManager.sellItem(
                            _getCategoryForItem(item),
                            item.name,
                          );
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
                        _showAddQuantityDialog(
                          _getCategoryForItem(item),
                          item.name,
                        );
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
              ),
            const SizedBox(height: 4),
            _buildGrid(
              item.remaining,
              shapeBuilder,
              crossAxisCount: crossAxisCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveDividedBox(
    ItemData item,
    int crossAxisCount,
    Widget Function() topShapeBuilder,
    Widget Function() bottomShapeBuilder,
    int topCount,
    int bottomCount, {
    int defaultTotal = 12,
  }) {
    int needed = item.remaining < defaultTotal
        ? defaultTotal - item.remaining
        : 0;
    int halfRemaining = (item.remaining / 2).ceil();
    int topRemaining = halfRemaining > topCount ? topCount : halfRemaining;
    int bottomRemaining = item.remaining - topRemaining;
    if (bottomRemaining < 0) bottomRemaining = 0;
    if (bottomRemaining > bottomCount) bottomRemaining = bottomCount;

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
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
            if (item.showControls)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (item.remaining > 0) {
                          _dataManager.sellItem(
                            _getCategoryForItem(item),
                            item.name,
                          );
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
                        _showAddQuantityDialog(
                          _getCategoryForItem(item),
                          item.name,
                        );
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
              ),
            const SizedBox(height: 4),
            _buildGrid(
              topRemaining,
              topShapeBuilder,
              crossAxisCount: crossAxisCount,
            ),
            const Divider(color: Colors.black, thickness: 1),
            _buildGrid(
              bottomRemaining,
              bottomShapeBuilder,
              crossAxisCount: crossAxisCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
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

  Widget _buildCircle() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.brown, width: 1),
        color: Colors.yellow[300],
      ),
    );
  }

  Widget _buildTinyCircle() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.brown, width: 0.5),
        color: Colors.orange[200],
      ),
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

  Widget _buildSquare() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown, width: 1),
        color: Colors.amber[400],
      ),
    );
  }

  Widget _buildDonut() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.brown, width: 2),
        color: Colors.pink[200],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
          ),
        ),
      ),
    );
  }

  Widget _buildMoon() {
    return ClipOval(
      child: Container(
        color: Colors.amber[300],
        child: Align(
          alignment: const Alignment(0.5, 0),
          child: Container(
            width: 15,
            height: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
          ),
        ),
      ),
    );
  }
}
