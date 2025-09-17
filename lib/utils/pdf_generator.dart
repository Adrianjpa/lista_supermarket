import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/product.dart';
import '../models/shopping_list.dart';

Future<void> generateAndSharePdf(
    ShoppingList list, List<Product> products) async {
  final doc = pw.Document();

  // --- LÓGICA DA LOGO REATIVADA ---
  // Carrega a imagem do ícone dos assets.
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/icon/icon.png')).buffer.asUint8List(),
  );

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  double _calculateTotalItemPrice(Product p) {
    if (p.unit == 'g' || p.unit == 'ml') {
      return (p.price * (p.quantity / 1000));
    }
    return p.price * p.quantity;
  }

  final totalValue =
      products.fold<double>(0.0, (sum, p) => sum + _calculateTotalItemPrice(p));
  final generationDate =
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- CABEÇALHO ATUALIZADO COM A LOGO ---
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('LISTA SUPERMARKET',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700)),
                      pw.SizedBox(
                        height: 50,
                        width: 50,
                        child: pw.Image(logo),
                      ),
                    ]),
                pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                pw.SizedBox(height: 10),
                pw.Text(list.name,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
              ]);
        },
        build: (pw.Context context) {
          return [
            pw.Table.fromTextArray(
                headers: ['Produto', 'Qtd.', 'Preço Unit.', 'Total Item'],
                data: products.map((p) {
                  return [
                    p.name,
                    '${p.quantity} ${p.unit}',
                    _formatCurrency(p.price),
                    _formatCurrency(_calculateTotalItemPrice(p)),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                }),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total Geral: ${_formatCurrency(totalValue)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)))
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text('Gerado em: $generationDate',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          );
        }),
  );

  await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${list.name.replaceAll(' ', '_')}.pdf');
}
