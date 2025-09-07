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

  // Carrega a imagem da logo dos assets.
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/icon/icon.png')).buffer.asUint8List(),
  );

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  final totalValue =
      products.fold<double>(0.0, (sum, p) => sum + (p.price * p.quantity));
  final generationDate =
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now());

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        // O layout principal é uma Coluna para separar o conteúdo do rodapé.
        return pw.Column(
          children: [
            // Expanded ocupa todo o espaço disponível, empurrando o rodapé para o fundo.
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- CABEÇALHO ATUALIZADO ---
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('LISTA SUPERMARKET',
                            style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green700)),
                        pw.SizedBox(
                          height: 50,
                          width: 50,
                          child: pw.Image(logo),
                        ),
                      ]),
                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: 20),

                  // --- INFORMAÇÕES DA LISTA ---
                  pw.Text(list.name,
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),

                  // --- TABELA DE PRODUTOS ---
                  pw.Table.fromTextArray(
                      headers: ['Produto', 'Qtd.', 'Preço Unit.', 'Total Item'],
                      data: products
                          .map((p) => [
                                p.name,
                                '${p.quantity} ${p.unit}',
                                _formatCurrency(p.price),
                                _formatCurrency(p.price * p.quantity),
                              ])
                          .toList(),
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

                  // --- TOTAL GERAL ---
                  pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                          'Total Geral: ${_formatCurrency(totalValue)}',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)))
                ],
              ),
            ),
            // --- RODAPÉ ATUALIZADO ---
            // Agora, este é o último item na Coluna principal, por isso ficará no fundo.
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado em: $generationDate',
                  style:
                      const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            ),
          ],
        );
      },
    ),
  );

  // Abre a janela de partilha do sistema operativo para o PDF gerado.
  await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${list.name.replaceAll(' ', '_')}.pdf');
}
