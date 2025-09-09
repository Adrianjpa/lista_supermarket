// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_suggestion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomSuggestionAdapter extends TypeAdapter<CustomSuggestion> {
  @override
  final int typeId = 2;

  @override
  CustomSuggestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomSuggestion(
      name: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CustomSuggestion obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomSuggestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
