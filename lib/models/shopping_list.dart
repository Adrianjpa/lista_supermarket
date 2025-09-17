import 'package:hive/hive.dart';

part 'shopping_list.g.dart';

@HiveType(typeId: 0)
class ShoppingList extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  bool archived;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  double budget;

  ShoppingList({
    required this.name,
    this.archived = false,
    // --- MELHORIA: A COR PADRÃO AGORA É BRANCA ---
    this.colorValue = 0xFFFFFFFF,
    this.budget = 0.0,
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();
}
