import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 1)
class Product extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  bool bought;

  @HiveField(2)
  int listKey;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  String unit;

  @HiveField(5)
  double price;

  @HiveField(6)
  String description;

  @HiveField(7)
  int sortOrder; // <-- NOVO CAMPO ADICIONADO

  Product({
    required this.name,
    this.bought = false,
    required this.listKey,
    this.quantity = 1,
    this.unit = 'un',
    this.price = 0.0,
    this.description = '',
    required this.sortOrder, // <-- NOVO CAMPO NO CONSTRUTOR
  });
}
