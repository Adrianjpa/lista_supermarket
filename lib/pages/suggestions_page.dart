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

  bool _isSelectionMode = false;
  final Set<int> _selectedKeys = <int>{};

  void _addSuggestion(String name) {
    if (name.trim().isEmpty) return;
    if (suggestionsBox.values
        .any((s) => s.name.toLowerCase() == name.trim().toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${name.trim()}" já existe nas suas sugestões.')));
      return;
    }

    final suggestion = CustomSuggestion(name: name.trim());
    suggestionsBox.add(suggestion);
  }

  void _editSuggestion(CustomSuggestion suggestion, String newName) {
    if (newName.trim().isEmpty || newName.trim() == suggestion.name) return;
    suggestion.name = newName.trim();
    suggestion.save();
  }

  void _deleteSuggestion(CustomSuggestion suggestion) {
    suggestion.delete();
  }

  void _deleteSelectedSuggestions() {
    for (var key in _selectedKeys.toList()) {
      suggestionsBox.delete(key);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedKeys.clear();
    });
  }

  // --- NOVA FUNÇÃO DE CONFIRMAÇÃO DE EXCLUSÃO ---
  void _showDeleteConfirmationDialog(
      {required String title,
      required String content,
      required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddOrEditSuggestionDialog({CustomSuggestion? suggestion}) {
    final controller = TextEditingController(text: suggestion?.name ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(suggestion == null ? 'Nova Sugestão' : 'Editar Sugestão'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do produto'),
          onSubmitted: (value) {
            if (suggestion == null) {
              _addSuggestion(value);
            } else {
              _editSuggestion(suggestion, value);
            }
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
              if (suggestion == null) {
                _addSuggestion(controller.text);
              } else {
                _editSuggestion(suggestion, controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedKeys.length} selecionado(s)')
            : const Text('Gerir Sugestões'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedKeys.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              // --- MELHORIA: CHAMA O DIÁLOGO DE CONFIRMAÇÃO ---
              onPressed: _selectedKeys.isEmpty
                  ? null
                  : () {
                      _showDeleteConfirmationDialog(
                        title: 'Excluir Sugestões',
                        content:
                            'Tem a certeza de que quer excluir as ${_selectedKeys.length} sugestões selecionadas?',
                        onConfirm: _deleteSelectedSuggestions,
                      );
                    },
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
              child: const Text('Selecionar'),
            ),
        ],
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
              final isSelected = _selectedKeys.contains(suggestion.key);

              return ListTile(
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedKeys.remove(suggestion.key);
                      } else {
                        _selectedKeys.add(suggestion.key as int);
                      }
                    });
                  } else {
                    _showAddOrEditSuggestionDialog(suggestion: suggestion);
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedKeys.add(suggestion.key as int);
                    });
                  }
                },
                leading: _isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedKeys.add(suggestion.key as int);
                            } else {
                              _selectedKeys.remove(suggestion.key);
                            }
                          });
                        },
                      )
                    : null,
                title: Text(suggestion.name),
                trailing: !_isSelectionMode
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showAddOrEditSuggestionDialog(
                                suggestion: suggestion),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400),
                            // --- MELHORIA: CHAMA O DIÁLOGO DE CONFIRMAÇÃO ---
                            onPressed: () {
                              _showDeleteConfirmationDialog(
                                title: 'Excluir Sugestão',
                                content:
                                    'Tem a certeza de que quer excluir "${suggestion.name}"?',
                                onConfirm: () => _deleteSuggestion(suggestion),
                              );
                            },
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddOrEditSuggestionDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
