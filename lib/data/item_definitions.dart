/// Centralized item definitions for both sender and receiver
class ItemDefinitions {
  // Breakfast & Lunch items
  static const List<ItemDef> breakfastLunchItems = [
    ItemDef(name: 'Hashbrowns', total: 12, category: 'breakfast_lunch'),
    ItemDef(name: 'Sausage', total: 12, category: 'breakfast_lunch'),
    ItemDef(name: 'Eggs', total: 12, category: 'breakfast_lunch'),
    ItemDef(name: 'Omelet Bites 1', total: 4, category: 'breakfast_lunch'),
    ItemDef(name: 'Omelet Bites 2', total: 4, category: 'breakfast_lunch'),
    ItemDef(name: 'Scrambled Eggs', total: 10, category: 'breakfast_lunch'),
  ];

  // Showcase - Muffins
  static const List<ItemDef> muffins = [
    ItemDef(name: 'Blueberry Muffin', total: 6, category: 'muffins'),
    ItemDef(name: 'Chocochip Muffin', total: 6, category: 'muffins'),
    ItemDef(name: 'Hazelnut Muffin', total: 6, category: 'muffins'),
  ];

  // Showcase - Cookies
  static const List<ItemDef> cookies = [
    ItemDef(name: 'Rese-mini', total: 4, category: 'cookies'),
    ItemDef(name: 'Brownie', total: 4, category: 'cookies'),
    ItemDef(name: 'Chocochunk Cookie', total: 6, category: 'cookies'),
    ItemDef(name: 'Oatmeal Raisin Cookie', total: 6, category: 'cookies'),
    ItemDef(name: 'Brookie', total: 4, category: 'cookies'),
    ItemDef(name: 'M&M', total: 4, category: 'cookies'),
  ];

  // Showcase - Others
  static const List<ItemDef> others = [
    ItemDef(name: 'Croissant', total: 9, category: 'others'),
    ItemDef(name: 'Herb and Garlic', total: 5, category: 'others'),
  ];

  // Showcase - Donuts
  static const List<ItemDef> donuts = [
    ItemDef(name: 'Old Fashion Plain', total: 6, category: 'donuts'),
    ItemDef(name: 'Sour Cream Glaze', total: 6, category: 'donuts'),
    ItemDef(name: 'Apple Fritter', total: 6, category: 'donuts'),
    ItemDef(name: 'Boston Cream', total: 6, category: 'donuts'),
    ItemDef(name: 'Honey Dip', total: 4, category: 'donuts'),
    ItemDef(name: 'Chocolate Dip', total: 6, category: 'donuts'),
    ItemDef(name: 'Honey Cruller', total: 4, category: 'donuts'),
    ItemDef(name: 'Chocolate Glazed', total: 4, category: 'donuts'),
  ];

  // Showcase - Bagels
  static const List<ItemDef> bagels = [
    ItemDef(name: 'Cinnamon Raisin', total: 5, category: 'bagels'),
    ItemDef(name: 'Four Cheese Bagel', total: 5, category: 'bagels'),
    ItemDef(name: 'Plain Bagel', total: 5, category: 'bagels'),
    ItemDef(name: '12 Grains Bagel', total: 5, category: 'bagels'),
    ItemDef(name: 'Everything Bagel', total: 10, category: 'bagels'),
    ItemDef(name: 'Sesame Seed', total: 10, category: 'bagels'),
  ];

  // Showcase - Timbits
  static const List<ItemDef> timbits = [
    ItemDef(name: 'Blueberry Cheesecake', total: 40, category: 'timbits'),
    ItemDef(name: 'Birthday Cake', total: 40, category: 'timbits'),
    ItemDef(name: 'Honey Dip', total: 40, category: 'timbits'),
    ItemDef(name: 'Chocolate Glazed', total: 40, category: 'timbits'),
    ItemDef(name: 'Filled Timbits', total: 40, category: 'timbits'),
  ];

  // All showcase items combined
  static List<ItemDef> get allShowcaseItems => [
    ...muffins,
    ...cookies,
    ...others,
    ...donuts,
    ...bagels,
    ...timbits,
  ];

  // All items
  static List<ItemDef> get allItems => [
    ...breakfastLunchItems,
    ...allShowcaseItems,
  ];
}

/// Item definition (constant data)
class ItemDef {
  final String name;
  final int total;
  final String category;

  const ItemDef({
    required this.name,
    required this.total,
    required this.category,
  });
}
