import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/custom_suggestion.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final Box<CustomSuggestion> suggestionsBox =
      Hive.box<CustomSuggestion>('customSuggestionsBox');

  void _addSuggestion(String name) {
    if (name.trim().isEmpty) return;
    // Evita adicionar sugestões duplicadas
    if (suggestionsBox.values
        .any((s) => s.name.toLowerCase() == name.trim().toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${name.trim()}" já existe nas suas sugestões.')));
      return;
    }

    final suggestion = CustomSuggestion(name: name.trim());
    suggestionsBox.add(suggestion);
  }

  void _deleteSuggestion(CustomSuggestion suggestion) {
    suggestion.delete();
  }

  void _showAddSuggestionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova Sugestão'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'Nome do produto frequente'),
          onSubmitted: (value) {
            _addSuggestion(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _addSuggestion(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerir Sugestões'),
      ),
      body: ValueListenableBuilder(
        valueListenable: suggestionsBox.listenable(),
        builder: (context, Box<CustomSuggestion> box, _) {
          final suggestions = box.values.toList();
          if (suggestions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Adicione aqui os produtos que compra com frequência para que apareçam como sugestões rápidas!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                title: Text(suggestion.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _deleteSuggestion(suggestion),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSuggestionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
