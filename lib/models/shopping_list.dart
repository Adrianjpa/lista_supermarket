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
  DateTime createdAt; // <-- NOVO CAMPO ADICIONADO

  @HiveField(4)
  DateTime updatedAt; // <-- NOVO CAMPO ADICIONADO

  @HiveField(5)
  double budget; // <-- NOVO CAMPO ADICIONADO

  ShoppingList({
    required this.name,
    this.archived = false,
    this.colorValue = 0xFF4CAF50, // Verde padrão
    this.budget = 0.0, // Orçamento padrão é 0
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();
}
