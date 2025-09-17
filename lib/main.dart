import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_svg/flutter_svg.dart';

import 'models/shopping_list.dart';
import 'models/product.dart';
import 'models/custom_suggestion.dart';
import 'pages/products_page.dart';
import 'pages/suggestions_page.dart';
import 'pages/splash_screen.dart';

// --- (O código dos Providers não mudou) ---
class PremiumProvider with ChangeNotifier {
  bool _isPremium = false;
  bool get isPremium => _isPremium;
  PremiumProvider() {
    _loadPremiumStatus();
  }
  void _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('isPremium') ?? false;
    notifyListeners();
  }

  void togglePremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isPremium', value);
    notifyListeners();
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  ThemeProvider() {
    _loadTheme();
  }
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode');
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void toggleTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      prefs.setString('themeMode', 'light');
    } else if (mode == ThemeMode.dark) {
      prefs.setString('themeMode', 'dark');
    } else {
      prefs.setString('themeMode', 'system');
    }
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Hive.initFlutter();
  timeago.setLocaleMessages('pt_br', timeago.PtBrMessages());
  Hive.registerAdapter(ShoppingListAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(CustomSuggestionAdapter());
  await Hive.openBox<ShoppingList>('listsBox');
  await Hive.openBox<Product>('productsBox');
  await Hive.openBox<CustomSuggestion>('customSuggestionsBox');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => PremiumProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Lista Supermarket',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});
  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final Box<ShoppingList> listsBox = Hive.box<ShoppingList>('listsBox');

  void _updateListTimestamp(ShoppingList list) {
    list.updatedAt = DateTime.now();
    list.save();
  }

  void _addList(String name) {
    if (name.trim().isEmpty) return;
    listsBox.add(ShoppingList(name: name.trim()));
  }

  void _editList(ShoppingList list, String newName) {
    if (newName.trim().isEmpty) return;
    list.name = newName.trim();
    _updateListTimestamp(list);
  }

  void _setBudget(ShoppingList list, double budget) {
    list.budget = budget;
    _updateListTimestamp(list);
  }

  void _deleteList(ShoppingList list) {
    final productsBox = Hive.box<Product>('productsBox');
    final productsToDelete =
        productsBox.values.where((p) => p.listKey == list.key);
    for (var product in productsToDelete.toList()) {
      product.delete();
    }
    list.delete();
  }

  void _duplicateList(ShoppingList list) {
    final productsBox = Hive.box<Product>('productsBox');
    final newList =
        ShoppingList(name: '${list.name} (Cópia)', colorValue: list.colorValue);

    listsBox.add(newList).then((value) {
      _updateListTimestamp(newList);
      final productsToCopy =
          productsBox.values.where((p) => p.listKey == list.key).toList();
      productsToCopy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      for (var product in productsToCopy) {
        productsBox.add(Product(
            name: product.name,
            description: product.description,
            listKey: newList.key,
            quantity: product.quantity,
            price: product.price,
            unit: product.unit,
            bought: false,
            sortOrder: product.sortOrder));
      }
    });
  }

  void _changeListColor(ShoppingList list, Color color) {
    list.colorValue = color.value;
    _updateListTimestamp(list);
  }

  void _archiveList(ShoppingList list) {
    list.archived = true;
    _updateListTimestamp(list);
  }

  void _restoreList(ShoppingList list) {
    list.archived = false;
    _updateListTimestamp(list);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final premiumProvider = Provider.of<PremiumProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Listas'),
        actions: [
          IconButton(
            tooltip: 'Mudar tema',
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode_outlined
                : (themeProvider.themeMode == ThemeMode.light
                    ? Icons.light_mode_outlined
                    : Icons.brightness_auto_outlined)),
            onPressed: () {
              ThemeMode nextMode;
              String message;
              if (themeProvider.themeMode == ThemeMode.system) {
                nextMode = ThemeMode.light;
                message = 'Tema Claro Ativado';
              } else if (themeProvider.themeMode == ThemeMode.light) {
                nextMode = ThemeMode.dark;
                message = 'Tema Escuro Ativado';
              } else {
                nextMode = ThemeMode.system;
                message = 'Tema do Sistema Ativado';
              }
              themeProvider.toggleTheme(nextMode);
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 1),
                ));
            },
          ),
          IconButton(
            tooltip: 'Listas Arquivadas',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ArchivedListsPage(onRestore: _restoreList)),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.green,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/icon/icon.svg',
                      height: 60,
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 8),
                    const Text('LISTA SUPERMARKET',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                )),
            SwitchListTile(
              title: const Text('Modo Premium'),
              subtitle: const Text('Desbloqueia todas as funcionalidades'),
              value: premiumProvider.isPremium,
              secondary: Icon(Icons.star,
                  color: premiumProvider.isPremium ? Colors.amber : null),
              onChanged: (bool value) {
                premiumProvider.togglePremium(value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Gerir Sugestões'),
              subtitle: const Text('Adicione os seus produtos frequentes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SuggestionsPage()));
              },
            )
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: listsBox.listenable(),
        builder: (context, Box<ShoppingList> box, _) {
          final activeLists = box.values.where((l) => !l.archived).toList();
          activeLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (activeLists.isEmpty) {
            return const Center(
                child: Text('Crie a sua primeira lista de compras!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: activeLists.length,
            itemBuilder: (context, index) {
              final list = activeLists[index];
              return ShoppingListCard(
                list: list,
                onEdit: (newName) => _editList(list, newName),
                onDelete: () => _deleteList(list),
                onDuplicate: () => _duplicateList(list),
                onArchive: () => _archiveList(list),
                onChangeColor: (color) => _changeListColor(list, color),
                onSetBudget: (budget) => _setBudget(list, budget),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _showAddListDialog,
      ),
    );
  }

  void _showAddListDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova Lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da lista'),
          onSubmitted: (name) {
            _addList(name);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                _addList(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Adicionar')),
        ],
      ),
    );
  }
}

class ShoppingListCard extends StatelessWidget {
  final ShoppingList list;
  final Function(String) onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final Function(Color) onChangeColor;
  final Function(double) onSetBudget;

  const ShoppingListCard({
    super.key,
    required this.list,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onArchive,
    required this.onChangeColor,
    required this.onSetBudget,
  });

  Color getTextColor(Color backgroundColor) {
    if (backgroundColor == Colors.white) return Colors.black;
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(list.colorValue);
    final textColor = getTextColor(color);
    final updatedAtFormatted = timeago.format(list.updatedAt, locale: 'pt_br');

    return GestureDetector(
      onTap: () {
        // --- CORREÇÃO APLICADA AQUI ---
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductsPage(listKey: list.key)));
      },
      child: Card(
        color: color,
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ValueListenableBuilder(
            valueListenable: Hive.box<Product>('productsBox').listenable(),
            builder: (context, Box<Product> productsBox, _) {
              final products = productsBox.values
                  .where((p) => p.listKey == list.key)
                  .toList();
              final totalItems = products.length;
              final boughtItems = products.where((p) => p.bought).length;
              final progress = totalItems > 0 ? boughtItems / totalItems : 0.0;
              final totalValue = products.fold<double>(0.0, (sum, p) {
                if (p.unit == 'g' || p.unit == 'ml') {
                  return sum + (p.price * (p.quantity / 1000));
                }
                return sum + (p.price * p.quantity);
              });
              final budgetExceeded =
                  list.budget > 0 && totalValue > list.budget;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          list.name,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildPopupMenu(context, textColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Atualizada $updatedAtFormatted",
                      style: TextStyle(
                          fontSize: 12, color: textColor.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "Total: ${_formatCurrency(totalValue)}",
                        style: TextStyle(
                            fontSize: 14, color: textColor.withOpacity(0.9)),
                      ),
                      if (list.budget > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: budgetExceeded
                                    ? Colors.red.shade900.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              "de ${_formatCurrency(list.budget)}",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: textColor,
                                  fontWeight: budgetExceeded
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.black.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              budgetExceeded
                                  ? Colors.red.shade300
                                  : Theme.of(context).colorScheme.surface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "$boughtItems / $totalItems",
                        style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (value) {
        if (value == 'edit') _showEditDialog(context);
        if (value == 'budget') _showBudgetDialog(context);
        if (value == 'color') _showColorPicker(context);
        if (value == 'duplicate') onDuplicate();
        if (value == 'archive') onArchive();
        if (value == 'delete') _showDeleteConfirmation(context);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Renomear')),
        const PopupMenuItem(value: 'budget', child: Text('Definir Orçamento')),
        const PopupMenuItem(value: 'color', child: Text('Alterar Cor')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
        const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
        const PopupMenuItem(
            value: 'delete',
            child: Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear Lista'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Novo nome da lista')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                onEdit(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Salvar')),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context) {
    final controller = TextEditingController();

    if (list.budget > 0) {
      final initialValue = list.budget * 100;
      final formatter = NumberFormat("#,##0.00", "pt_BR");
      controller.text = formatter.format(initialValue / 100);
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Definir Orçamento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Valor do Orçamento (R\$)',
              hintText: '0,00',
              prefixText: 'R\$ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                final budgetText =
                    controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final budget = (double.tryParse(budgetText) ?? 0.0) / 100.0;
                onSetBudget(budget);
                Navigator.pop(context);
              },
              child: const Text('Definir')),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha uma cor'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Color(list.colorValue),
            availableColors: const [
              Colors.white,
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
              Colors.blueGrey,
            ],
            onColorChanged: (color) {
              onChangeColor(color);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Deseja realmente excluir a lista "${list.name}" e todos os seus produtos? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                onDelete();
                Navigator.pop(context);
              },
              child: const Text('Excluir')),
        ],
      ),
    );
  }
}

class ArchivedListsPage extends StatelessWidget {
  final Function(ShoppingList) onRestore;
  const ArchivedListsPage({super.key, required this.onRestore});

  Color getTextColor(Color backgroundColor, BuildContext context) {
    if (backgroundColor == Colors.white) return Colors.black;
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final Box<ShoppingList> listsBox = Hive.box<ShoppingList>('listsBox');

    return Scaffold(
      appBar: AppBar(title: const Text('Listas Arquivadas')),
      body: ValueListenableBuilder(
        valueListenable: listsBox.listenable(),
        builder: (context, Box<ShoppingList> box, _) {
          final archived = box.values.where((l) => l.archived).toList();
          archived.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (archived.isEmpty) {
            return const Center(child: Text('Nenhuma lista arquivada.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final list = archived[index];
              final color = Color(list.colorValue);
              final textColor = getTextColor(color, context);

              return Opacity(
                opacity: 0.7,
                child: Card(
                  color: color,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(list.name, style: TextStyle(color: textColor)),
                    onTap: () {
                      // --- CORREÇÃO APLICADA AQUI ---
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProductsPage(
                                  listKey: list.key, isReadOnly: true)));
                    },
                    trailing: IconButton(
                      tooltip: 'Restaurar Lista',
                      icon: Icon(Icons.unarchive, color: textColor),
                      onPressed: () => onRestore(list),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    double value = double.parse(digitsOnly);
    final formatter = NumberFormat("#,##0.00", "pt_BR");
    String newText = formatter.format(value / 100);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
