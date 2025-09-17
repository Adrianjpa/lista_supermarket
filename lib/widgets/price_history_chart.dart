import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_history.dart';

class PriceHistoryChart extends StatelessWidget {
  final List<PriceHistoryData> history;
  final String productName;

  const PriceHistoryChart({
    super.key,
    required this.history,
    required this.productName,
  });

  // Função auxiliar para determinar a cor do texto em contraste com o fundo
  Color getTextColorForBackground(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (history.isEmpty) {
      return const Center(
          child: Text('Sem histórico de preços para este produto.'));
    }

    // Lógica de cores e valores do gráfico
    final prices = history.map((h) => h.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final maxY = maxPrice * 1.3;

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceBetween,
            barGroups: history.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;

              Color barColor;
              if (history.length > 1 && data.price <= minPrice) {
                barColor = Colors.green;
              } else if (history.length > 1 && data.price >= maxPrice) {
                barColor = Colors.red;
              } else {
                barColor = Colors.blue.shade700;
              }

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: data.price,
                    color: barColor,
                    width: 35,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == 0) {
                      return const Text('');
                    }
                    return Text(formatCurrency.format(value),
                        style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < history.length) {
                      final data = history[index];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Tooltip(
                          message: data.listName,
                          child: SizedBox(
                            width: 35,
                            child: Text(
                              data.listName,
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    String text = '';
                    if (index >= 0 && index < history.length) {
                      text = formatCurrency.format(history[index].price);
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            // --- CORREÇÃO APLICADA: 'const' removido ---
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              checkToShowHorizontalLine: (value) => value != 0,
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                // --- CORREÇÃO APLICADA: Usando getTooltipColor ---
                getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final data = history[group.x];
                  return BarTooltipItem(
                    '${data.listName}\n',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(
                        text: formatCurrency.format(data.price),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
