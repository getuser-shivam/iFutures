import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/kline.dart';
import '../../models/position.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../../trading/strategy.dart';
import '../common/status_pill.dart';

class PriceChart extends ConsumerStatefulWidget {
  final String symbol;

  const PriceChart({super.key, required this.symbol});

  @override
  ConsumerState<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends ConsumerState<PriceChart> {
  static const List<int> _visibleWindows = [24, 48, 96];

  int _visibleCandles = 48;
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final klines = ref.watch(klineStreamProvider(widget.symbol));
    final decisionPlan = ref.watch(decisionPlanStreamProvider(widget.symbol));
    final openPosition = ref.watch(positionStreamProvider(widget.symbol));
    final tradesAsync = ref.watch(tradeStreamProvider(widget.symbol));

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

        final recentData = _sliceVisibleData(data);
        final activeIndex = _resolvedActiveIndex(recentData.length);
        final activeCandle = recentData[activeIndex];
        final plan = decisionPlan.valueOrNull;
        final position = openPosition.valueOrNull;
        final recentTrades = tradesAsync.valueOrNull ?? const <Trade>[];
        final spots = recentData.asMap().entries.map((entry) {
          final kline = entry.value;
          return CandlestickSpot(
            x: entry.key.toDouble(),
            open: kline.open,
            high: kline.high,
            low: kline.low,
            close: kline.close,
          );
        }).toList();

        final levels = _buildLevels(plan, position);
        final visibleLow = recentData.fold<double>(
          recentData.first.low,
          (value, candle) => math.min(value, candle.low),
        );
        final visibleHigh = recentData.fold<double>(
          recentData.first.high,
          (value, candle) => math.max(value, candle.high),
        );
        final highestVolume = recentData.fold<double>(
          0,
          (value, candle) => math.max(value, candle.volume),
        );

        var minPrice = visibleLow;
        var maxPrice = visibleHigh;
        for (final level in levels) {
          if (level.price < minPrice) {
            minPrice = level.price;
          }
          if (level.price > maxPrice) {
            maxPrice = level.price;
          }
        }

        final range = (maxPrice - minPrice).abs();
        final verticalPadding = range <= 0
            ? math.max(maxPrice.abs() * 0.025, 0.000001)
            : range * 0.12;
        final chartMinY = minPrice - verticalPadding;
        final chartMaxY = maxPrice + verticalPadding;
        final volumeMax = highestVolume <= 0 ? 1.0 : highestVolume * 1.18;
        final intervalLabel = _intervalLabel(recentData);
        final priorClose = activeIndex > 0
            ? recentData[activeIndex - 1].close
            : recentData.first.open;
        final candleChange = activeCandle.close - priorClose;
        final candleChangePercent = priorClose == 0
            ? 0.0
            : (candleChange / priorClose) * 100;
        final visibleChange = recentData.last.close - recentData.first.open;
        final visibleChangePercent = recentData.first.open == 0
            ? 0.0
            : (visibleChange / recentData.first.open) * 100;
        final tradeMarkers = _buildTradeMarkers(recentData, recentTrades);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ChartMetricTile(
                  label: _hoveredIndex == null ? 'Last Price' : 'Hovered Close',
                  value: _formatPrice(activeCandle.close),
                  helper:
                      '${candleChange >= 0 ? '+' : ''}${candleChangePercent.toStringAsFixed(2)}%',
                  accent: candleChange >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
                _ChartMetricTile(
                  label: 'Range',
                  value:
                      '${_formatPrice(visibleLow)} - ${_formatPrice(visibleHigh)}',
                  helper: '${recentData.length}-bar live structure',
                  accent: AppColors.glowAmber,
                ),
                _ChartMetricTile(
                  label: 'Session Move',
                  value:
                      '${visibleChange >= 0 ? '+' : ''}${visibleChangePercent.toStringAsFixed(2)}%',
                  helper:
                      '${_formatPrice(recentData.first.open)} to ${_formatPrice(recentData.last.close)}',
                  accent: visibleChange >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
                _ChartMetricTile(
                  label: 'Volume',
                  value: _formatCompact(activeCandle.volume),
                  helper:
                      '${DateFormat('HH:mm').format(activeCandle.openTime.toLocal())} candle',
                  accent: AppColors.glowCyan,
                ),
                _ChartMetricTile(
                  label: 'Current Position',
                  value: openPosition.valueOrNull == null
                      ? 'Flat'
                      : openPosition.valueOrNull!.isLong
                      ? 'Long'
                      : 'Short',
                  helper: openPosition.valueOrNull == null
                      ? 'No live entry synced'
                      : 'Entry ${_formatPrice(openPosition.valueOrNull!.entryPrice)}',
                  accent: openPosition.valueOrNull == null
                      ? AppColors.textMuted
                      : AppColors.glowAmber,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                        label: 'Realtime $intervalLabel',
                        color: AppColors.glowCyan,
                      ),
                      if (plan != null)
                        StatusPill(
                          label: plan.isActionable
                              ? 'AI ${plan.actionLabel} | ${plan.orderTypeLabel}'
                              : 'AI waiting for trigger',
                          color: _planColor(plan),
                        ),
                      if (position != null)
                        StatusPill(
                          label:
                              'Live ${position.isLong ? 'LONG' : 'SHORT'} on chart',
                          color: AppColors.glowAmber,
                        ),
                      if (tradeMarkers.isNotEmpty)
                        StatusPill(
                          label: '${tradeMarkers.length} trade markers',
                          color: AppColors.textPrimary,
                        ),
                      for (final level in levels)
                        StatusPill(
                          label:
                              '${level.shortLabel} ${_formatPrice(level.price)}',
                          color: level.color,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final window in _visibleWindows)
                      _ChartWindowChip(
                        label: '$window bars',
                        selected: _visibleCandles == window,
                        onTap: () {
                          setState(() {
                            _visibleCandles = window;
                            _hoveredIndex = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      SizedBox(
                        height: math.max(56, constraints.maxHeight * 0.18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              _ChartMicroStat(
                                label: 'Open',
                                value: _formatPrice(activeCandle.open),
                              ),
                              _ChartMicroStat(
                                label: 'High',
                                value: _formatPrice(activeCandle.high),
                              ),
                              _ChartMicroStat(
                                label: 'Low',
                                value: _formatPrice(activeCandle.low),
                              ),
                              _ChartMicroStat(
                                label: 'Close',
                                value: _formatPrice(activeCandle.close),
                                accent: candleChange >= 0
                                    ? AppColors.positive
                                    : AppColors.negative,
                              ),
                              _ChartMicroStat(
                                label: 'Time',
                                value: DateFormat(
                                  'HH:mm:ss',
                                ).format(activeCandle.closeTime.toLocal()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              flex: 4,
                              child: LayoutBuilder(
                                builder: (context, chartConstraints) {
                                  final pricePaneHeight =
                                      chartConstraints.maxHeight;
                                  final priceAxisReservedWidth = 76.0;
                                  final plotWidth =
                                      chartConstraints.maxWidth -
                                      priceAxisReservedWidth;
                                  final zones = _buildChartZones(
                                    plan,
                                    position,
                                  );
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: CandlestickChart(
                                          CandlestickChartData(
                                            candlestickSpots: spots,
                                            candlestickPainter:
                                                DefaultCandlestickPainter(
                                                  candlestickStyleProvider:
                                                      (spot, index) {
                                                        final isBullish =
                                                            spot.close >=
                                                            spot.open;
                                                        final baseColor =
                                                            isBullish
                                                            ? AppColors.positive
                                                            : AppColors
                                                                  .negative;
                                                        return CandlestickStyle(
                                                          lineColor: baseColor,
                                                          lineWidth: 1.2,
                                                          bodyStrokeColor:
                                                              baseColor,
                                                          bodyStrokeWidth: 1.0,
                                                          bodyFillColor:
                                                              baseColor
                                                                  .withValues(
                                                                    alpha:
                                                                        isBullish
                                                                        ? 0.30
                                                                        : 0.18,
                                                                  ),
                                                          bodyWidth: 8,
                                                          bodyRadius: 2,
                                                        );
                                                      },
                                                ),
                                            minX: 0,
                                            maxX: (recentData.length - 1)
                                                .toDouble(),
                                            minY: chartMinY,
                                            maxY: chartMaxY,
                                            clipData: const FlClipData.all(),
                                            backgroundColor: Colors.transparent,
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: true,
                                              horizontalInterval: _niceStep(
                                                chartMaxY - chartMinY,
                                              ),
                                              verticalInterval: math
                                                  .max(
                                                    1,
                                                    (recentData.length / 6)
                                                        .floor(),
                                                  )
                                                  .toDouble(),
                                              getDrawingHorizontalLine:
                                                  (value) => FlLine(
                                                    color: AppColors.border
                                                        .withValues(alpha: 0.7),
                                                    strokeWidth: 1,
                                                  ),
                                              getDrawingVerticalLine: (value) =>
                                                  FlLine(
                                                    color: AppColors.border
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    strokeWidth: 1,
                                                  ),
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              bottomTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              rightTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 72,
                                                  interval: _niceStep(
                                                    chartMaxY - chartMinY,
                                                  ),
                                                  getTitlesWidget:
                                                      _buildPriceTitle,
                                                ),
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: true,
                                              border: Border.all(
                                                color: AppColors.border
                                                    .withValues(alpha: 0.65),
                                              ),
                                            ),
                                            candlestickTouchData: CandlestickTouchData(
                                              enabled: true,
                                              handleBuiltInTouches: true,
                                              touchSpotThreshold: 10,
                                              mouseCursorResolver:
                                                  (event, response) =>
                                                      SystemMouseCursors
                                                          .precise,
                                              touchCallback: (event, response) {
                                                if (!mounted) {
                                                  return;
                                                }
                                                if (!event
                                                    .isInterestedForInteractions) {
                                                  setState(() {
                                                    _hoveredIndex = null;
                                                  });
                                                  return;
                                                }
                                                final touchedIndex = response
                                                    ?.touchedSpot
                                                    ?.spotIndex;
                                                if (touchedIndex == null ||
                                                    touchedIndex < 0 ||
                                                    touchedIndex >=
                                                        recentData.length) {
                                                  return;
                                                }
                                                setState(() {
                                                  _hoveredIndex = touchedIndex;
                                                });
                                              },
                                            ),
                                          ),
                                          transformationConfig:
                                              const FlTransformationConfig(
                                                scaleAxis:
                                                    FlScaleAxis.horizontal,
                                                minScale: 1,
                                                maxScale: 6,
                                                trackpadScrollCausesScale: true,
                                              ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: Stack(
                                          children: [
                                            for (final zone in zones)
                                              Positioned(
                                                left: 0,
                                                width: plotWidth
                                                    .clamp(
                                                      0,
                                                      chartConstraints.maxWidth,
                                                    )
                                                    .toDouble(),
                                                top: math
                                                    .min(
                                                      _positionForPrice(
                                                        zone.topPrice,
                                                        minY: chartMinY,
                                                        maxY: chartMaxY,
                                                        height: pricePaneHeight,
                                                      ),
                                                      _positionForPrice(
                                                        zone.bottomPrice,
                                                        minY: chartMinY,
                                                        maxY: chartMaxY,
                                                        height: pricePaneHeight,
                                                      ),
                                                    )
                                                    .clamp(
                                                      0.0,
                                                      pricePaneHeight,
                                                    ),
                                                height:
                                                    (math.max(
                                                              _positionForPrice(
                                                                zone.topPrice,
                                                                minY: chartMinY,
                                                                maxY: chartMaxY,
                                                                height:
                                                                    pricePaneHeight,
                                                              ),
                                                              _positionForPrice(
                                                                zone.bottomPrice,
                                                                minY: chartMinY,
                                                                maxY: chartMaxY,
                                                                height:
                                                                    pricePaneHeight,
                                                              ),
                                                            ) -
                                                            math.min(
                                                              _positionForPrice(
                                                                zone.topPrice,
                                                                minY: chartMinY,
                                                                maxY: chartMaxY,
                                                                height:
                                                                    pricePaneHeight,
                                                              ),
                                                              _positionForPrice(
                                                                zone.bottomPrice,
                                                                minY: chartMinY,
                                                                maxY: chartMaxY,
                                                                height:
                                                                    pricePaneHeight,
                                                              ),
                                                            ))
                                                        .clamp(
                                                          8.0,
                                                          pricePaneHeight,
                                                        )
                                                        .toDouble(),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        zone.color.withValues(
                                                          alpha: 0.22,
                                                        ),
                                                        zone.color.withValues(
                                                          alpha: 0.08,
                                                        ),
                                                      ],
                                                    ),
                                                    border: Border(
                                                      top: BorderSide(
                                                        color: zone.color
                                                            .withValues(
                                                              alpha: 0.24,
                                                            ),
                                                      ),
                                                      bottom: BorderSide(
                                                        color: zone.color
                                                            .withValues(
                                                              alpha: 0.24,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.topLeft,
                                                    child: Text(
                                                      zone.label,
                                                      style: TextStyle(
                                                        color: zone.color,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            for (final level in levels)
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                top:
                                                    _positionForPrice(
                                                      level.price,
                                                      minY: chartMinY,
                                                      maxY: chartMaxY,
                                                      height: pricePaneHeight,
                                                    ).clamp(
                                                      4.0,
                                                      pricePaneHeight - 4.0,
                                                    ),
                                                child: Opacity(
                                                  opacity: 0.9,
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          height: 1.4,
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                level.color
                                                                    .withValues(
                                                                      alpha:
                                                                          0.0,
                                                                    ),
                                                                level.color
                                                                    .withValues(
                                                                      alpha:
                                                                          0.88,
                                                                    ),
                                                                level.color
                                                                    .withValues(
                                                                      alpha:
                                                                          0.0,
                                                                    ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .surfaceAlt
                                                              .withValues(
                                                                alpha: 0.94,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: level.color
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          level.shortLabel,
                                                          style: TextStyle(
                                                            color: level.color,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            for (final marker in tradeMarkers)
                                              Positioned(
                                                left:
                                                    (10 +
                                                            ((plotWidth - 26) *
                                                                marker
                                                                    .xFraction))
                                                        .clamp(
                                                          0.0,
                                                          chartConstraints
                                                                  .maxWidth -
                                                              20,
                                                        )
                                                        .toDouble(),
                                                top:
                                                    (_positionForPrice(
                                                              marker.price,
                                                              minY: chartMinY,
                                                              maxY: chartMaxY,
                                                              height:
                                                                  pricePaneHeight,
                                                            ) +
                                                            marker
                                                                .verticalOffset)
                                                        .clamp(
                                                          6.0,
                                                          pricePaneHeight - 22,
                                                        )
                                                        .toDouble(),
                                                child: _TradeMarkerChip(
                                                  marker: marker,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 84,
                              child: BarChart(
                                BarChartData(
                                  minY: 0,
                                  maxY: volumeMax,
                                  alignment: BarChartAlignment.spaceBetween,
                                  groupsSpace: 2,
                                  barTouchData: const BarTouchData(
                                    enabled: false,
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border(
                                      top: BorderSide(
                                        color: AppColors.border.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                      right: BorderSide(
                                        color: AppColors.border.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                      bottom: BorderSide(
                                        color: AppColors.border.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                      left: BorderSide.none,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 72,
                                        interval: volumeMax / 2,
                                        getTitlesWidget: _buildVolumeTitle,
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 24,
                                        interval: math
                                            .max(
                                              1,
                                              (recentData.length / 5).floor(),
                                            )
                                            .toDouble(),
                                        getTitlesWidget: (value, meta) =>
                                            _buildTimeTitle(
                                              value,
                                              meta,
                                              recentData,
                                            ),
                                      ),
                                    ),
                                  ),
                                  barGroups: recentData
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => BarChartGroupData(
                                          x: entry.key,
                                          barRods: [
                                            BarChartRodData(
                                              toY: entry.value.volume,
                                              width: 6,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                    topRight: Radius.circular(
                                                      4,
                                                    ),
                                                  ),
                                              color:
                                                  entry.value.close >=
                                                      entry.value.open
                                                  ? AppColors.positive
                                                        .withValues(alpha: 0.65)
                                                  : AppColors.negative
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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

  List<_ChartLevel> _buildLevels(StrategyTradePlan? plan, Position? position) {
    final levels = <_ChartLevel>[];

    if (plan != null && plan.targetEntryPrice != null) {
      levels.add(
        _ChartLevel(
          label: 'AI Entry',
          shortLabel: 'AI ENTRY',
          price: plan.targetEntryPrice!,
          color: _planColor(plan),
        ),
      );
    }
    if (plan?.takeProfitPrice != null) {
      levels.add(
        _ChartLevel(
          label: 'AI Take Profit',
          shortLabel: 'AI TP',
          price: plan!.takeProfitPrice!,
          color: AppColors.positive,
        ),
      );
    }
    if (plan?.stopLossPrice != null) {
      levels.add(
        _ChartLevel(
          label: 'AI Stop Loss',
          shortLabel: 'AI SL',
          price: plan!.stopLossPrice!,
          color: AppColors.negative,
        ),
      );
    }
    if (position != null) {
      levels.add(
        _ChartLevel(
          label: 'Current Position',
          shortLabel: position.isLong ? 'LONG POS' : 'SHORT POS',
          price: position.entryPrice,
          color: AppColors.glowAmber,
        ),
      );
      if (position.hasLiquidationPrice) {
        levels.add(
          _ChartLevel(
            label: 'Liquidation',
            shortLabel: 'LIQ',
            price: position.liquidationPrice!,
            color: const Color(0xFFFF5A5A),
          ),
        );
      }
    }

    return levels;
  }

  List<_ChartZone> _buildChartZones(
    StrategyTradePlan? plan,
    Position? position,
  ) {
    final zones = <_ChartZone>[];

    if (plan != null &&
        plan.isActionable &&
        plan.targetEntryPrice != null &&
        plan.takeProfitPrice != null &&
        plan.stopLossPrice != null) {
      if (plan.signal == TradingSignal.buy) {
        zones.add(
          _ChartZone(
            label: 'AI Target Zone',
            topPrice: plan.takeProfitPrice!,
            bottomPrice: plan.targetEntryPrice!,
            color: AppColors.positive,
          ),
        );
        zones.add(
          _ChartZone(
            label: 'AI Risk Zone',
            topPrice: plan.targetEntryPrice!,
            bottomPrice: plan.stopLossPrice!,
            color: AppColors.negative,
          ),
        );
      } else if (plan.signal == TradingSignal.sell) {
        zones.add(
          _ChartZone(
            label: 'AI Risk Zone',
            topPrice: plan.stopLossPrice!,
            bottomPrice: plan.targetEntryPrice!,
            color: AppColors.negative,
          ),
        );
        zones.add(
          _ChartZone(
            label: 'AI Target Zone',
            topPrice: plan.targetEntryPrice!,
            bottomPrice: plan.takeProfitPrice!,
            color: AppColors.positive,
          ),
        );
      }
    }

    if (position != null && position.hasLiquidationPrice) {
      zones.add(
        _ChartZone(
          label: 'Liquidation Risk',
          topPrice: position.isLong
              ? position.entryPrice
              : position.liquidationPrice!,
          bottomPrice: position.isLong
              ? position.liquidationPrice!
              : position.entryPrice,
          color: AppColors.warning,
        ),
      );
    }

    return zones;
  }

  List<_TradeMarker> _buildTradeMarkers(
    List<Kline> candles,
    List<Trade> trades,
  ) {
    if (candles.isEmpty || trades.isEmpty) {
      return const <_TradeMarker>[];
    }

    final visibleTrades =
        trades
            .where(
              (trade) =>
                  !trade.timestamp.isBefore(candles.first.openTime) &&
                  !trade.timestamp.isAfter(candles.last.closeTime),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (visibleTrades.isEmpty) {
      return const <_TradeMarker>[];
    }

    final trimmedTrades = visibleTrades.length > 8
        ? visibleTrades.sublist(visibleTrades.length - 8)
        : visibleTrades;

    return trimmedTrades.asMap().entries.map((entry) {
      final trade = entry.value;
      final candleIndex = _nearestCandleIndex(candles, trade.timestamp);
      final denominator = candles.length <= 1 ? 1 : candles.length - 1;
      final xFraction = candleIndex / denominator;
      final isEntry = trade.kind.toUpperCase() == 'ENTRY';
      final isBuy = trade.side.toUpperCase() == 'BUY';
      final verticalOffset = entry.key.isEven ? -18.0 : 8.0;

      return _TradeMarker(
        label: isEntry ? (isBuy ? 'B' : 'S') : 'X',
        tooltip:
            '${trade.side.toUpperCase()} ${trade.kind.toUpperCase()} ${_formatPrice(trade.price)}',
        price: trade.price,
        xFraction: xFraction,
        color: isEntry
            ? (isBuy ? AppColors.positive : AppColors.negative)
            : AppColors.glowAmber,
        verticalOffset: verticalOffset,
      );
    }).toList();
  }

  int _nearestCandleIndex(List<Kline> candles, DateTime timestamp) {
    var bestIndex = 0;
    var bestDistance = Duration(days: 999999);

    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final midpoint = candle.openTime.add(
        candle.closeTime.difference(candle.openTime) ~/ 2,
      );
      final distance = midpoint.difference(timestamp).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  double _positionForPrice(
    double price, {
    required double minY,
    required double maxY,
    required double height,
  }) {
    final range = maxY - minY;
    if (range <= 0) {
      return height / 2;
    }
    final normalized = ((maxY - price) / range).clamp(0.0, 1.0);
    return normalized * height;
  }

  Color _planColor(StrategyTradePlan plan) {
    return switch (plan.signal) {
      TradingSignal.buy => AppColors.positive,
      TradingSignal.sell => AppColors.glowAmber,
      TradingSignal.hold => AppColors.glowCyan,
    };
  }

  String _formatPrice(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    }
    if (value >= 100) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(3);
  }

  List<Kline> _sliceVisibleData(List<Kline> data) {
    if (data.length <= _visibleCandles) {
      return data;
    }
    return data.sublist(data.length - _visibleCandles);
  }

  int _resolvedActiveIndex(int length) {
    if (length <= 0) {
      return 0;
    }
    if (_hoveredIndex == null) {
      return length - 1;
    }
    return _hoveredIndex!.clamp(0, length - 1);
  }

  String _intervalLabel(List<Kline> candles) {
    if (candles.length < 2) {
      return 'Live';
    }
    final difference = candles[1].openTime.difference(candles[0].openTime);
    final minutes = difference.inMinutes;
    if (minutes >= 60 && minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    final seconds = difference.inSeconds;
    if (seconds > 0) {
      return '${seconds}s';
    }
    return 'Live';
  }

  double _niceStep(double range) {
    if (range <= 0 || range.isNaN || range.isInfinite) {
      return 1;
    }
    final rough = range / 5;
    final power = (math.log(rough) / math.ln10).floorToDouble();
    final magnitude = math.pow(10, power).toDouble();
    final normalized = rough / magnitude;
    final step = normalized < 1.5
        ? 1
        : normalized < 3
        ? 2
        : normalized < 7
        ? 5
        : 10;
    return step * magnitude;
  }

  Widget _buildPriceTitle(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        _formatPrice(value),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
      ),
    );
  }

  Widget _buildVolumeTitle(double value, TitleMeta meta) {
    if (value <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        _formatCompact(value),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
      ),
    );
  }

  Widget _buildTimeTitle(double value, TitleMeta meta, List<Kline> data) {
    final index = value.round();
    if (index < 0 || index >= data.length) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        DateFormat('HH:mm').format(data[index].openTime.toLocal()),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
      ),
    );
  }
}

class _ChartLevel {
  final String label;
  final String shortLabel;
  final double price;
  final Color color;

  const _ChartLevel({
    required this.label,
    required this.shortLabel,
    required this.price,
    required this.color,
  });
}

class _ChartZone {
  final String label;
  final double topPrice;
  final double bottomPrice;
  final Color color;

  const _ChartZone({
    required this.label,
    required this.topPrice,
    required this.bottomPrice,
    required this.color,
  });
}

class _TradeMarker {
  final String label;
  final String tooltip;
  final double price;
  final double xFraction;
  final Color color;
  final double verticalOffset;

  const _TradeMarker({
    required this.label,
    required this.tooltip,
    required this.price,
    required this.xFraction,
    required this.color,
    required this.verticalOffset,
  });
}

class _ChartMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _ChartMetricTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChartMicroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _ChartMicroStat({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: tabularFigures(
              TextStyle(
                color: accent ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartWindowChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChartWindowChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.glowCyan.withValues(alpha: 0.16)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.glowCyan.withValues(alpha: 0.75)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.glowCyan : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TradeMarkerChip extends StatelessWidget {
  final _TradeMarker marker;

  const _TradeMarkerChip({required this.marker});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: marker.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: marker.color.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: marker.color.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          marker.label,
          style: TextStyle(
            color: marker.color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
