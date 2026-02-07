class ItemData {
  String name;
  int total;
  int sold;
  int remaining;
  bool showControls;
  int defaultStock; // Standard inventory level for low stock warnings

  ItemData({required this.name, required this.total})
    : sold = 0,
      remaining = total,
      showControls = false,
      defaultStock = total; // Initialize with the original total

  /// Create ItemData from JSON (for network data)
  factory ItemData.fromJson(Map<String, dynamic> json) {
    final item = ItemData(
      name: json['name'] as String? ?? 'Unknown',
      total: json['total'] as int? ?? 0,
    );
    item.sold = json['sold'] as int? ?? 0;
    item.remaining = json['remaining'] as int? ?? item.total;
    item.defaultStock = json['defaultStock'] as int? ?? item.total;
    return item;
  }

  /// Convert ItemData to JSON (for network transfer)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'total': total,
      'sold': sold,
      'remaining': remaining,
      'defaultStock': defaultStock,
    };
  }

  /// Update this item with data from another ItemData
  void updateFrom(ItemData other) {
    total = other.total;
    sold = other.sold;
    remaining = other.remaining;
  }
}
