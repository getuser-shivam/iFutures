import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';

class PriceChart extends ConsumerWidget {
  const PriceChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klines = ref.watch(klineStreamProvider('GALAUSDT'));

    return klines.when(
      data: (data) {
        // In a real app, we would accumulate klines over time.
        // For this demo, we'll show a simple simulated path or the latest final kline.
        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1)),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  const FlSpot(0, 1),
                  const FlSpot(1, 1.5),
                  const FlSpot(2, 1.2),
                  const FlSpot(3, 2.2),
                  const FlSpot(4, 1.8),
                  const FlSpot(5, 3),
                ],
                isCurved: true,
                color: Colors.greenAccent,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.greenAccent.withOpacity(0.1),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Chart Error: $e')),
    );
  }
}
