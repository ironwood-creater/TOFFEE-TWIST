/// Names of the sweet shops (20 levels each). Plain Dart so tools can use it.
const int levelsPerShop = 20;

const List<String> shopNames = [
  'Toffee Kitchen',
  'Cupcake Café',
  'Donut Diner',
  'Macaron Bakery',
  'Chocolate Factory',
  'Lollipop Lane',
  'Caramel Creek',
  'Honey Hollow',
  'Butterscotch Bay',
  'Praline Plaza',
  'Fudge Fountain',
  'Marzipan Market',
  'Nougat Nook',
  'Brittle Bridge',
  'Meringue Mill',
  'Gingerbread Grove',
  'Sherbet Shore',
  'Truffle Tower',
  'Waffle Wharf',
  'Maple Meadow',
  'Cocoa Canyon',
  'Sugarplum Square',
  'Biscuit Boulevard',
  'Cinnamon Cottage',
  'Golden Twist Palace',
];

int shopIndexForLevel(int level) => ((level - 1) ~/ levelsPerShop).clamp(0, shopNames.length - 1);
String shopNameForLevel(int level) => shopNames[shopIndexForLevel(level)];
