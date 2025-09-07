import 'package:hive/hive.dart';

part 'shopping_list.g.dart';

@HiveType(typeId: 0)
class ShoppingList extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  bool archived;

  @HiveField(2)
  int colorValue; // Cor do card

  ShoppingList({
    required this.name,
    this.archived = false,
    this.colorValue = 0xFF4CAF50, // Um verde padrão mais moderno
  });
}

