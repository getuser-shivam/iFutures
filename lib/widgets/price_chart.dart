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
        if (data.isEmpty) return const Center(child: Text('Loading Market Data...'));
        
        // Use last 50 klines for the chart
        final recentData = data.length > 50 ? data.sublist(data.length - 50) : data;
        
        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: recentData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList(),
                isCurved: true,
                color: Colors.greenAccent,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.greenAccent.withValues(alpha: 0.1),
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
