import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lista_supermarket/utils/pdf_generator.dart';
import 'package:lista_supermarket/widgets/price_history_chart.dart';
import '../main.dart';
import '../models/shopping_list.dart';
import '../models/product.dart';
import '../models/custom_suggestion.dart';
import '../models/product_history.dart';

class ProductsPage extends StatefulWidget {
  final int listKey;
  final bool isReadOnly;

  const ProductsPage({
    super.key,
    required this.listKey,
    this.isReadOnly = false,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final Box<Product> productsBox = Hive.box<Product>('productsBox');
  final Box<ShoppingList> listsBox = Hive.box<ShoppingList>('listsBox');
  final Box<CustomSuggestion> suggestionsBox =
      Hive.box<CustomSuggestion>('customSuggestionsBox');
  late ShoppingList currentList;

  @override
  void initState() {
    super.initState();
    currentList = listsBox.get(widget.listKey)!;
  }

  void _updateListTimestamp() {
    if (widget.isReadOnly) return;
    currentList.updatedAt = DateTime.now();
    currentList.save();
  }

  void _addProduct(Product newProduct) {
    productsBox.add(newProduct);
    _updateListTimestamp();
  }

  void _updateProduct(Product product, String name, String description,
      double quantity, String unit, double price) {
    product.name = name;
    product.description = description;
    product.quantity = quantity;
    product.unit = unit;
    product.price = price;
    product.save();
    _updateListTimestamp();
  }

  void _toggleBought(Product product) {
    product.bought = !product.bought;
    product.save();
    _updateListTimestamp();
  }

  void _deleteProduct(Product product, {bool showUndo = false}) {
    if (showUndo) {
      final productCopy = Product(
        name: product.name,
        listKey: product.listKey,
        sortOrder: product.sortOrder,
        bought: product.bought,
        description: product.description,
        price: product.price,
        quantity: product.quantity,
        unit: product.unit,
      );
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.name} removido.'),
            action: SnackBarAction(
              label: 'DESFAZER',
              onPressed: () {
                _addProduct(productCopy);
              },
            ),
          ),
        );
    }
    product.delete();
    _updateListTimestamp();
  }

  void _onReorder(int oldIndex, int newIndex, List<Product> products) {
    if (widget.isReadOnly) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final Product item = products.removeAt(oldIndex);
    products.insert(newIndex, item);

    for (int i = 0; i < products.length; i++) {
      products[i].sortOrder = i;
      products[i].save();
    }
    _updateListTimestamp();
  }

  double _calculateTotalItemPrice(Product product) {
    if (product.unit == 'g' || product.unit == 'ml') {
      return (product.quantity / 1000) * product.price;
    }
    return product.quantity * product.price;
  }

  List<PriceHistoryData> _getPriceHistory(Product currentProduct) {
    final List<PriceHistoryData> history = [];
    final allProducts = productsBox.values.where(
        (p) => p.name.toLowerCase() == currentProduct.name.toLowerCase());

    for (var product in allProducts) {
      final list = listsBox.get(product.listKey);
      if (list != null) {
        history.add(PriceHistoryData(
            price: product.price, date: list.updatedAt, listName: list.name));
      }
    }
    history.sort((a, b) => a.date.compareTo(b.date));
    return history;
  }

  Color getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(currentList.colorValue);
    final textColor = getTextColor(color);
    final isPremium = Provider.of<PremiumProvider>(context).isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentList.name),
        backgroundColor: color,
        foregroundColor: textColor,
        actions: [
          IconButton(
            tooltip: 'Gerar PDF da Lista',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              if (isPremium) {
                final products = productsBox.values
                    .where((p) => p.listKey == currentList.key)
                    .toList();
                products.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                generateAndSharePdf(currentList, products);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Esta é uma funcionalidade Premium! Ative no menu lateral.'),
                    backgroundColor: Colors.amber,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: productsBox.listenable(),
        builder: (context, Box<Product> box, _) {
          final products =
              box.values.where((p) => p.listKey == currentList.key).toList();

          products.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          if (products.isEmpty) {
            return const Center(child: Text('Nenhum produto nesta lista.'));
          }

          final totalValue = products.fold<double>(
              0.0, (sum, p) => sum + _calculateTotalItemPrice(p));

          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.withOpacity(0.2)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total da Lista:',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(_formatCurrency(totalValue),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 150, top: 8),
                  itemCount: products.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(oldIndex, newIndex, products),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductItem(
                        product, isPremium, index, Key('${product.key}'));
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton.extended(
              backgroundColor: color,
              foregroundColor: textColor,
              icon: const Icon(Icons.add),
              label: const Text("Novo Produto"),
              onPressed: () {
                _showAddOrEditProductDialog();
              },
            ),
    );
  }

  Widget _buildProductItem(
      Product product, bool isPremium, int index, Key key) {
    final totalItemPrice = _calculateTotalItemPrice(product);
    final pricePerUnit = product.price;
    String priceUnitLabel = product.unit;
    if (product.unit == 'g') priceUnitLabel = 'kg';
    if (product.unit == 'ml') priceUnitLabel = 'L';

    final formattedQuantity = (product.quantity == product.quantity.truncate())
        ? product.quantity.toInt().toString()
        : product.quantity.toString();

    return AbsorbPointer(
      key: key,
      absorbing: widget.isReadOnly,
      child: Dismissible(
        key: ValueKey('dismiss_${product.key}'),
        background: Container(
          color: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: const Icon(Icons.check, color: Colors.white),
        ),
        secondaryBackground: Container(
          color: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          child: const Icon(Icons.delete_forever, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _toggleBought(product);
            return false;
          } else {
            _deleteProduct(product, showUndo: true);
            return true;
          }
        },
        child: Card(
          color: product.bought
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade300)
              : Theme.of(context).cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            onTap: () {
              if (!widget.isReadOnly)
                _showAddOrEditProductDialog(product: product);
            },
            leading: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle,
                  color: widget.isReadOnly ? Colors.transparent : null),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$formattedQuantity ${product.unit} - ${product.name}',
                  style: TextStyle(
                    fontSize: 16,
                    decoration:
                        product.bought ? TextDecoration.lineThrough : null,
                    color: product.bought
                        ? Colors.grey.shade600
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (product.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      product.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPremium) _buildPriceComparisonBadge(product),
                const SizedBox(width: 4),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(totalItemPrice),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    if (product.price > 0)
                      Text(
                        '${_formatCurrency(pricePerUnit)}/$priceUnitLabel',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceComparisonBadge(Product product) {
    if (product.price == 0) return const SizedBox.shrink();

    final fullHistory = _getPriceHistory(product);
    if (fullHistory.length < 2) return const SizedBox.shrink();

    final currentIndex = fullHistory.indexWhere(
        (h) => h.date == currentList.updatedAt && h.price == product.price);

    if (currentIndex == -1) return const SizedBox.shrink();

    // Compara sempre com a compra imediatamente anterior.
    if (currentIndex == 0) return const SizedBox.shrink();

    final priceToCompare = fullHistory[currentIndex - 1].price;
    final currentPrice = product.price;
    final difference = currentPrice - priceToCompare;

    IconData icon;
    Color color;
    String diffText;

    if (difference < -0.001) {
      icon = Icons.arrow_downward;
      color = Colors.green;
      diffText = _formatCurrency(difference.abs());
    } else if (difference > 0.001) {
      icon = Icons.arrow_upward;
      color = Colors.red;
      diffText = '+${_formatCurrency(difference.abs())}';
    } else {
      icon = Icons.remove;
      color = Colors.grey;
      diffText = _formatCurrency(0.0);
    }

    return InkWell(
      onTap: () => _showPriceHistoryDialog(product, fullHistory),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 2),
            Text(
              diffText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceHistoryDialog(
      Product product, List<PriceHistoryData> history) {
    final displayHistory =
        history.length > 5 ? history.sublist(history.length - 5) : history;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Histórico de Preços: ${product.name}',
                  style: const TextStyle(fontSize: 18)),
              const Text(
                'Comparação baseada nas últimas 5 compras',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: PriceHistoryChart(
              history: displayHistory,
              productName: product.name,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _showAddOrEditProductDialog({Product? product}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name);
    final descController = TextEditingController(text: product?.description);
    final quantityController =
        TextEditingController(text: product?.quantity.toString() ?? '');
    final priceController = TextEditingController();

    if (product != null && product.price > 0) {
      final initialPriceValue = product.price * 100;
      final formatter = NumberFormat("#,##0.00", "pt_BR");
      priceController.text = formatter.format(initialPriceValue / 100);
    }

    String selectedUnit = product?.unit ?? 'un';
    final List<String> units = ['un', 'kg', 'g', 'L', 'ml', 'pct', 'fardo'];

    final List<String> defaultSuggestions = [
      'Arroz',
      'Feijão',
      'Lentilha',
      'Grão-de-bico',
      'Milho para pipoca',
      'Farinha de Trigo',
      'Farinha de Mandioca',
      'Farinha de Rosca',
      'Aveia',
      'Macarrão Espaguete',
      'Macarrão Parafuso',
      'Macarrão Penne',
      'Lasanha',
      'Carne Bovina',
      'Frango',
      'Peixe',
      'Carne de Porco',
      'Linguiça',
      'Salsicha',
      'Ovos',
      'Presunto',
      'Queijo Mussarela',
      'Queijo Prato',
      'Requeijão',
      'Leite',
      'Iogurte',
      'Manteiga',
      'Margarina',
      'Creme de Leite',
      'Pão de Forma',
      'Pão Francês',
      'Biscoito Cream Cracker',
      'Biscoito Recheado',
      'Torrada',
      'Óleo de Soja',
      'Azeite',
      'Vinagre',
      'Sal',
      'Açúcar',
      'Café',
      'Filtro de Café',
      'Achocolatado',
      'Maionese',
      'Ketchup',
      'Mostarda',
      'Molho de Tomate',
      'Extrato de Tomate',
      'Milho em conserva',
      'Ervilha em conserva',
      'Atum em lata',
      'Sardinha em lata',
      'Alho',
      'Cebola',
      'Batata',
      'Cenoura',
      'Tomate',
      'Alface',
      'Brócolis',
      'Couve-flor',
      'Abobrinha',
      'Berinjela',
      'Limão',
      'Laranja',
      'Banana',
      'Maçã',
      'Mamão',
      'Uva',
      'Água Mineral',
      'Refrigerante',
      'Suco de caixinha',
      'Cerveja',
      'Detergente',
      'Sabão em pó',
      'Amaciante',
      'Água Sanitária',
      'Desinfetante',
      'Limpador Multiuso',
      'Esponja de aço',
      'Saco de lixo',
      'Sabonete',
      'Shampoo',
      'Condicionador',
      'Creme dental',
      'Escova de dentes',
      'Papel higiênico',
      'Desodorizante',
    ];
    final customSuggestions = suggestionsBox.values.map((s) => s.name).toList();
    final allSuggestions =
        {...customSuggestions, ...defaultSuggestions}.toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Novo Produto' : 'Editar Produto'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              String priceLabel = 'Preço (R\$)';
              if (selectedUnit == 'g') priceLabel = 'Preço (R\$/kg)';
              if (selectedUnit == 'ml') priceLabel = 'Preço (R\$/L)';

              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<String>(
                        initialValue:
                            TextEditingValue(text: product?.name ?? ''),
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          nameController.text = controller.text;
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                                labelText: 'Nome do Produto*'),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                    ? 'Campo obrigatório'
                                    : null,
                            onChanged: (text) => nameController.text = text,
                          );
                        },
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return allSuggestions.where((String option) {
                            return option
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          nameController.text = selection;
                        },
                      ),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                            labelText: 'Descrição (opcional)'),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration:
                                  const InputDecoration(labelText: 'Unid.'),
                              items: units.map((String value) {
                                return DropdownMenuItem<String>(
                                    value: value, child: Text(value));
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  selectedUnit = newValue!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: quantityController,
                              decoration: const InputDecoration(
                                  labelText: 'Quantidade'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: priceController,
                        decoration: InputDecoration(labelText: priceLabel),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text;
                  final description = descController.text;
                  final quantity = double.tryParse(
                          quantityController.text.replaceAll(',', '.')) ??
                      1.0;
                  final priceText =
                      priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final price = (double.tryParse(priceText) ?? 0.0) / 100.0;

                  final currentProducts = productsBox.values
                      .where((p) => p.listKey == currentList.key)
                      .toList();
                  final newSortOrder = currentProducts.length;

                  if (product == null) {
                    _addProduct(Product(
                      name: name,
                      description: description,
                      listKey: currentList.key,
                      quantity: quantity,
                      price: price,
                      unit: selectedUnit,
                      sortOrder: newSortOrder,
                    ));
                  } else {
                    _updateProduct(product, name, description, quantity,
                        selectedUnit, price);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
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
