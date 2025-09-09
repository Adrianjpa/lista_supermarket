import 'package:hive/hive.dart';

part 'custom_suggestion.g.dart';

@HiveType(typeId: 2)
class CustomSuggestion extends HiveObject {
  @HiveField(0)
  String name;

  CustomSuggestion({
    required this.name,
  });
}
