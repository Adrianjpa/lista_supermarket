import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lista_supermarket/utils/pdf_generator.dart'; // Importa o nosso novo gerador de PDF
import '../main.dart'; // Importa o main para aceder ao PremiumProvider
import '../models/shopping_list.dart';
import '../models/product.dart';

class ProductsPage extends StatefulWidget {
  final int listKey;

  const ProductsPage({super.key, required this.listKey});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final Box<Product> productsBox = Hive.box<Product>('productsBox');
  final Box<ShoppingList> listsBox = Hive.box<ShoppingList>('listsBox');
  late ShoppingList currentList;

  @override
  void initState() {
    super.initState();
    currentList = listsBox.get(widget.listKey)!;
  }

  void _updateListTimestamp() {
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

  void _deleteProduct(Product product) {
    product.delete();
    _updateListTimestamp();
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

          if (products.isEmpty) {
            return const Center(child: Text('Nenhum produto nesta lista.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final totalItemPrice = product.price * product.quantity;
              final pricePerUnit = product.price;

              return Card(
                color: product.bought
                    ? Colors.grey.shade300
                    : Theme.of(context).cardColor,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  onTap: () => _showAddOrEditProductDialog(product: product),
                  title: Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 16,
                      decoration:
                          product.bought ? TextDecoration.lineThrough : null,
                      color: product.bought
                          ? Colors.grey.shade600
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(product.description,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic)),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                            "${product.quantity} ${product.unit} - ${_formatCurrency(totalItemPrice)} (${_formatCurrency(pricePerUnit)}/${product.unit})"),
                      ),
                    ],
                  ),
                  isThreeLine: product.description.isNotEmpty,
                  leading: Checkbox(
                    value: product.bought,
                    onChanged: (_) => _toggleBought(product),
                    activeColor: color,
                  ),
                  trailing: IconButton(
                    icon:
                        Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () => _deleteProduct(product),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
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
    final List<String> units = ['un', 'kg', 'g', 'L', 'ml', 'fardo'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Novo Produto' : 'Editar Produto'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Nome do Produto*'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Campo obrigatório'
                            : null,
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
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: DropdownButton<String>(
                              value: selectedUnit,
                              isExpanded: true,
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
                        ],
                      ),
                      TextFormField(
                        controller: priceController,
                        decoration:
                            const InputDecoration(labelText: 'Preço (R\$)'),
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

                  if (product == null) {
                    _addProduct(Product(
                      name: name,
                      description: description,
                      listKey: currentList.key,
                      quantity: quantity,
                      price: price,
                      unit: selectedUnit,
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
