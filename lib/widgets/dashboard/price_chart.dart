import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';

class PriceChart extends ConsumerWidget {
  final String symbol;

  const PriceChart({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klines = ref.watch(klineStreamProvider(symbol));

    return klines.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: Text(
              'No market data yet. Check the Market badge or wait a few seconds.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        // Use last 50 klines for the chart
        final recentData = data.length > 50 ? data.sublist(data.length - 50) : data;
        final spots = recentData.asMap().entries.map((e) {
          final kline = e.value;
          return CandlestickSpot(
            x: e.key.toDouble(),
            open: kline.open,
            high: kline.high,
            low: kline.low,
            close: kline.close,
          );
        }).toList();

        return CandlestickChart(
          CandlestickChartData(
            candlestickSpots: spots,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => const FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              ),
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            candlestickTouchData: CandlestickTouchData(
              enabled: false,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Text(
          'Chart Error: $e',
          style: const TextStyle(color: AppColors.negative),
        ),
      ),
    );
  }
}
