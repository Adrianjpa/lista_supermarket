import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list.dart';
import '../models/product.dart';
import '../models/custom_suggestion.dart';

class BackupRestoreService {
  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> createBackup(BuildContext context) async {
    try {
      final listsBox = Hive.box<ShoppingList>('listsBox');
      final productsBox = Hive.box<Product>('productsBox');
      final suggestionsBox = Hive.box<CustomSuggestion>('customSuggestionsBox');

      final List<Map<String, dynamic>> listsData = listsBox.values
          .map((list) => {
                'name': list.name,
                'archived': list.archived,
                'colorValue': list.colorValue,
                'createdAt': list.createdAt.toIso8601String(),
                'updatedAt': list.updatedAt.toIso8601String(),
                'budget': list.budget,
                'key': list.key,
              })
          .toList();

      final List<Map<String, dynamic>> productsData = productsBox.values
          .map((product) => {
                'name': product.name,
                'bought': product.bought,
                'listKey': product.listKey,
                'quantity': product.quantity,
                'unit': product.unit,
                'price': product.price,
                'description': product.description,
                'sortOrder': product.sortOrder,
              })
          .toList();

      final List<Map<String, dynamic>> suggestionsData = suggestionsBox.values
          .map((suggestion) => {
                'name': suggestion.name,
              })
          .toList();

      final backupData = {
        'lists': listsData,
        'products': productsData,
        'suggestions': suggestionsData,
      };

      final backupJson = jsonEncode(backupData);
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'lista_supermarket_backup_$timestamp.json';

      // Usa o file_picker para que o utilizador escolha onde salvar.
      String? result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup',
        fileName: fileName,
        bytes: utf8.encode(backupJson),
      );

      if (result != null) {
        // ignore: use_build_context_synchronously
        _showSnackBar(context, 'Backup salvo com sucesso!');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      _showSnackBar(context, 'Erro ao criar o backup: $e', isError: true);
    }
  }

  Future<void> restoreBackup(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final backupJson = await file.readAsString();
        final backupData = jsonDecode(backupJson);

        // ignore: use_build_context_synchronously
        bool confirmed = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restaurar Backup'),
                content: const Text(
                    'Atenção! Isto irá apagar todos os seus dados atuais e substituí-los pelos dados do backup. Deseja continuar?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Restaurar',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ) ??
            false;

        if (confirmed) {
          final listsBox = Hive.box<ShoppingList>('listsBox');
          final productsBox = Hive.box<Product>('productsBox');
          final suggestionsBox =
              Hive.box<CustomSuggestion>('customSuggestionsBox');

          await listsBox.clear();
          await productsBox.clear();
          await suggestionsBox.clear();

          final Map<int, int> oldToNewKeyMap = {};

          for (var listData in backupData['lists']) {
            final oldKey = listData['key'];
            final list = ShoppingList(
              name: listData['name'],
              archived: listData['archived'],
              colorValue: listData['colorValue'],
              budget: listData['budget'],
            )
              ..createdAt = DateTime.parse(listData['createdAt'])
              ..updatedAt = DateTime.parse(listData['updatedAt']);

            final newKey = await listsBox.add(list);
            oldToNewKeyMap[oldKey] = newKey;
          }

          for (var productData in backupData['products']) {
            final oldListKey = productData['listKey'];
            final newListKey = oldToNewKeyMap[oldListKey];

            if (newListKey != null) {
              final product = Product(
                name: productData['name'],
                bought: productData['bought'],
                listKey: newListKey,
                quantity: productData['quantity'],
                unit: productData['unit'],
                price: productData['price'],
                description: productData['description'],
                sortOrder: productData['sortOrder'],
              );
              await productsBox.add(product);
            }
          }

          for (var suggestionData in backupData['suggestions']) {
            final suggestion = CustomSuggestion(name: suggestionData['name']);
            await suggestionsBox.add(suggestion);
          }

          // ignore: use_build_context_synchronously
          _showSnackBar(context, 'Backup restaurado com sucesso!');
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      _showSnackBar(context,
          'Erro ao restaurar o backup: O ficheiro pode estar corrompido ou num formato inválido.',
          isError: true);
    }
  }
}
