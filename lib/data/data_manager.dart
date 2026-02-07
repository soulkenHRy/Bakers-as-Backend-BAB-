import 'dart:async';
import '../item_data.dart';
import '../services/network_service.dart';

/// Global data manager for receiver mode
/// Manages all item data and broadcasts updates
class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal() {
    _initializeItems();
    _listenToNetwork();
  }

  final NetworkService _networkService = NetworkService();

  // All items organized by category
  final Map<String, List<ItemData>> _items = {};

  // Stream controller for data updates
  final _updateController = StreamController<DataUpdate>.broadcast();
  Stream<DataUpdate> get updateStream => _updateController.stream;

  void _initializeItems() {
    // Breakfast & Lunch
    _items['breakfast_lunch'] = [
      ItemData(name: 'Hashbrowns', total: 12),
      ItemData(name: 'Sausage', total: 12),
      ItemData(name: 'Eggs', total: 12),
      ItemData(name: 'Omelet Bites 1', total: 4),
      ItemData(name: 'Omelet Bites 2', total: 4),
      ItemData(name: 'Scrambled Eggs', total: 10),
    ];

    // Muffins
    _items['muffins'] = [
      ItemData(name: 'Blueberry Muffin', total: 6),
      ItemData(name: 'Chocochip Muffin', total: 6),
      ItemData(name: 'Hazelnut Muffin', total: 6),
    ];

    // Cookies
    _items['cookies'] = [
      ItemData(name: 'Rese-mini', total: 4),
      ItemData(name: 'Brownie', total: 4),
      ItemData(name: 'Chocochunk Cookie', total: 6),
      ItemData(name: 'Oatmeal Raisin Cookie', total: 6),
      ItemData(name: 'Brookie', total: 4),
      ItemData(name: 'M&M', total: 4),
    ];

    // Others
    _items['others'] = [
      ItemData(name: 'Croissant', total: 9),
      ItemData(name: 'Herb and Garlic', total: 5),
    ];

    // Donuts
    _items['donuts'] = [
      ItemData(name: 'Old Fashion Plain', total: 6),
      ItemData(name: 'Sour Cream Glaze', total: 6),
      ItemData(name: 'Apple Fritter', total: 6),
      ItemData(name: 'Boston Cream', total: 6),
      ItemData(name: 'Honey Dip', total: 4),
      ItemData(name: 'Chocolate Dip', total: 6),
      ItemData(name: 'Honey Cruller', total: 4),
      ItemData(name: 'Chocolate Glazed', total: 4),
    ];

    // Bagels
    _items['bagels'] = [
      ItemData(name: 'Cinnamon Raisin', total: 5),
      ItemData(name: 'Four Cheese Bagel', total: 5),
      ItemData(name: 'Plain Bagel', total: 5),
      ItemData(name: '12 Grains Bagel', total: 5),
      ItemData(name: 'Everything Bagel', total: 10),
      ItemData(name: 'Sesame Seed', total: 10),
    ];

    // Timbits
    _items['timbits'] = [
      ItemData(name: 'Blueberry Cheesecake', total: 40),
      ItemData(name: 'Birthday Cake', total: 40),
      ItemData(name: 'Honey Dip', total: 40),
      ItemData(name: 'Chocolate Glazed', total: 40),
      ItemData(name: 'Filled Timbits', total: 40),
    ];
  }

  void _listenToNetwork() {
    _networkService.dataStream.listen((data) {
      _handleNetworkData(data);
    });
  }

  void _handleNetworkData(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    if (type == 'sold') {
      final category = data['category'] as String?;
      final itemName = data['itemName'] as String?;
      final quantity = data['quantity'] as int? ?? 1;

      if (category != null && itemName != null) {
        sellItem(category, itemName, quantity: quantity);
      }
    } else if (type == 'bulk_update') {
      // Handle bulk updates if needed
    }
  }

  /// Get items for a category
  List<ItemData> getItems(String category) {
    return _items[category] ?? [];
  }

  /// Get all showcase items
  List<ItemData> get showcaseItems {
    return [
      ..._items['muffins'] ?? [],
      ..._items['cookies'] ?? [],
      ..._items['others'] ?? [],
      ..._items['donuts'] ?? [],
      ..._items['bagels'] ?? [],
      ..._items['timbits'] ?? [],
    ];
  }

  /// Find an item by name across all categories
  ItemData? findItem(String itemName) {
    for (final category in _items.values) {
      for (final item in category) {
        if (item.name == itemName) {
          return item;
        }
      }
    }
    return null;
  }

  /// Sell an item (decrement remaining)
  void sellItem(String category, String itemName, {int quantity = 1}) {
    final items = _items[category];
    if (items == null) return;

    for (final item in items) {
      if (item.name == itemName) {
        item.sold += quantity;
        item.remaining = item.total - item.sold;
        if (item.remaining < 0) item.remaining = 0;

        _updateController.add(
          DataUpdate(category: category, itemName: itemName, item: item),
        );
        break;
      }
    }
  }

  /// Add stock to an item (increment total and remaining)
  void addStock(String category, String itemName, {int quantity = 1}) {
    final items = _items[category];
    if (items == null) return;

    for (final item in items) {
      if (item.name == itemName) {
        item.total += quantity;
        item.remaining += quantity;

        _updateController.add(
          DataUpdate(category: category, itemName: itemName, item: item),
        );
        break;
      }
    }
  }

  /// Reset an item
  void resetItem(String category, String itemName) {
    final items = _items[category];
    if (items == null) return;

    for (final item in items) {
      if (item.name == itemName) {
        item.sold = 0;
        item.remaining = item.total;

        _updateController.add(
          DataUpdate(category: category, itemName: itemName, item: item),
        );
        break;
      }
    }
  }

  /// Reset all items in a category
  void resetCategory(String category) {
    final items = _items[category];
    if (items == null) return;

    for (final item in items) {
      item.sold = 0;
      item.remaining = item.total;
    }

    _updateController.add(
      DataUpdate(category: category, itemName: null, item: null),
    );
  }

  /// Reset all categories to default state
  void resetAll() {
    _items.forEach((category, items) {
      for (final item in items) {
        item.sold = 0;
        item.remaining = item.total;
      }
    });

    _updateController.add(
      DataUpdate(category: 'all', itemName: null, item: null),
    );
  }

  /// Get all items that are below 50% stock
  List<LowStockItem> getLowStockItems() {
    final List<LowStockItem> lowStockItems = [];

    _items.forEach((category, items) {
      for (final item in items) {
        final percentage = (item.remaining / item.defaultStock) * 100;
        if (percentage < 50 && percentage >= 0) {
          lowStockItems.add(
            LowStockItem(
              name: item.name,
              category: category,
              remaining: item.remaining,
              defaultStock: item.defaultStock,
              totalMade: item.total,
              percentage: percentage,
            ),
          );
        }
      }
    });

    // Sort by percentage (lowest first)
    lowStockItems.sort((a, b) => a.percentage.compareTo(b.percentage));
    return lowStockItems;
  }

  void dispose() {
    _updateController.close();
  }
}

/// Data update notification
class DataUpdate {
  final String category;
  final String? itemName;
  final ItemData? item;

  DataUpdate({required this.category, this.itemName, this.item});
}

/// Low stock item notification
class LowStockItem {
  final String name;
  final String category;
  final int remaining;
  final int defaultStock; // Standard inventory level
  final int totalMade; // Total made/stocked for the day
  final double percentage;

  LowStockItem({
    required this.name,
    required this.category,
    required this.remaining,
    required this.defaultStock,
    required this.totalMade,
    required this.percentage,
  });
}
