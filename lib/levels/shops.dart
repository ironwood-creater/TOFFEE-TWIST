import 'package:flutter/painting.dart';

import 'shop_names.dart';

export 'shop_names.dart';

/// Levels are grouped into sweet shops of 20 levels each on the map.
class Shop {
  const Shop(this.name, this.color, this.accent);
  final String name;
  final Color color;
  final Color accent;
}

const List<Shop> shops = [
  Shop('Toffee Kitchen', Color(0xFFF2C27A), Color(0xFFB86E14)),
  Shop('Cupcake Café', Color(0xFFF9C4D8), Color(0xFFD94A86)),
  Shop('Donut Diner', Color(0xFFB9DBFA), Color(0xFF2F78C9)),
  Shop('Macaron Bakery', Color(0xFFC3F0D8), Color(0xFF2E9E6A)),
  Shop('Chocolate Factory', Color(0xFFD9B79A), Color(0xFF6B3A1E)),
  Shop('Lollipop Lane', Color(0xFFE4CCF7), Color(0xFF8A3FC8)),
  Shop('Caramel Creek', Color(0xFFF7D3A0), Color(0xFFC0761C)),
  Shop('Honey Hollow', Color(0xFFFCE7A2), Color(0xFFC79A0A)),
  Shop('Butterscotch Bay', Color(0xFFF8DDB0), Color(0xFFB8801E)),
  Shop('Praline Plaza', Color(0xFFE8CDB4), Color(0xFF8C5A30)),
  Shop('Fudge Fountain', Color(0xFFD6B9A8), Color(0xFF5C3320)),
  Shop('Marzipan Market', Color(0xFFF5E1C8), Color(0xFFB07A3A)),
  Shop('Nougat Nook', Color(0xFFF1E6D2), Color(0xFF9C7448)),
  Shop('Brittle Bridge', Color(0xFFF3D19A), Color(0xFFA9660E)),
  Shop('Meringue Mill', Color(0xFFF7EEF3), Color(0xFFC07A9E)),
  Shop('Gingerbread Grove', Color(0xFFE2BC92), Color(0xFF8A4E1E)),
  Shop('Sherbet Shore', Color(0xFFFFD9C2), Color(0xFFE8703A)),
  Shop('Truffle Tower', Color(0xFFD3BFB3), Color(0xFF4E2A1C)),
  Shop('Waffle Wharf', Color(0xFFF5D7A0), Color(0xFFB3781C)),
  Shop('Maple Meadow', Color(0xFFF2C9A0), Color(0xFFB4501E)),
  Shop('Cocoa Canyon', Color(0xFFDDB9A0), Color(0xFF7A3E1E)),
  Shop('Sugarplum Square', Color(0xFFE7CDEF), Color(0xFF9A4CB0)),
  Shop('Biscuit Boulevard', Color(0xFFF3DDB8), Color(0xFFA06A2C)),
  Shop('Cinnamon Cottage', Color(0xFFEFC8A8), Color(0xFFA0461E)),
  Shop('Golden Twist Palace', Color(0xFFFFE8A0), Color(0xFFD49A00)),
];

Shop shopForLevel(int level) => shops[shopIndexForLevel(level)];
