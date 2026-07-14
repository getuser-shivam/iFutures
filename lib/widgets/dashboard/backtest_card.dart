import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/symbols.dart';
import '../../models/kline.dart';
import '../../models/mock_test_result.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../../trading/algo_strategy.dart';
import '../common/action_button.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class BacktestCard extends ConsumerStatefulWidget {
  final String symbol;

  const BacktestCard({super.key, required this.symbol});

  @override
  ConsumerState<BacktestCard> createState() => _BacktestCardState();
}

class _BacktestCardState extends ConsumerState<BacktestCard> {
  final Set<String> _selectedSymbols = {...coreTradingSymbols};
  late final TextEditingController _balanceController;
  late final TextEditingController _feeController;
  late final TextEditingController _slippageController;
  late final TextEditingController _fundingController;

  String _interval = '5m';
  int _candleLimit = 500;
  bool _useHistoricalFunding = true;
  bool _isRunning = false;
  String? _progressMessage;
  String? _errorMessage;
  DateTime? _lastRunAt;
  MockPortfolioTestResult? _result;
  Map<String, String> _loadFailures = const {};

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(text: '1000');
    _feeController = TextEditingController(text: '0.05');
    _slippageController = TextEditingController(text: '2');
    _fundingController = TextEditingController(text: '0.01');
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _feeController.dispose();
    _slippageController.dispose();
    _fundingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbols = <String>{
      ...coreTradingSymbols,
      truusdtSymbol,
      widget.symbol.toUpperCase(),
    }.toList();

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: AppColors.glowCyan, size: 21),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Multi-Coin Mock Lab',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: _verdictLabel(_result?.verdict),
                color: _verdictColor(_result?.verdict),
              ),
              if (_lastRunAt != null)
                StatusPill(
                  label: 'Run ${DateFormat('HH:mm').format(_lastRunAt!)}',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Replay the deterministic ALGO strategy across real production Binance Futures candles. Signals fill no earlier than the next bar; results include modeled fees, adverse market slippage, funding, unfilled limits, intrabar TP/SL, cooldowns, and mark-to-market drawdown. A net-positive historical sample is not a live-profit prediction.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Coins to test',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final symbol in symbols)
                FilterChip(
                  selected: _selectedSymbols.contains(symbol),
                  label: Text(symbol),
                  onSelected: _isRunning
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSymbols.add(symbol);
                            } else {
                              _selectedSymbols.remove(symbol);
                            }
                          });
                        },
                ),
              ActionChip(
                avatar: const Icon(Icons.done_all, size: 16),
                label: const Text('CORE 4'),
                onPressed: _isRunning
                    ? null
                    : () => setState(() {
                        _selectedSymbols
                          ..clear()
                          ..addAll(coreTradingSymbols);
                      }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _CompactField(
                controller: _balanceController,
                label: 'Mock Balance',
                suffix: 'USDT',
                enabled: !_isRunning,
              ),
              _CompactField(
                controller: _feeController,
                label: 'Fee / side',
                suffix: '%',
                enabled: !_isRunning,
              ),
              _CompactField(
                controller: _slippageController,
                label: 'Market slippage',
                suffix: 'bps',
                enabled: !_isRunning,
              ),
              _CompactField(
                controller: _fundingController,
                label: 'Fallback funding / 8h',
                suffix: '%',
                enabled: !_isRunning,
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _interval,
                  decoration: const InputDecoration(labelText: 'Timeframe'),
                  items: const [
                    DropdownMenuItem(value: '1m', child: Text('1 minute')),
                    DropdownMenuItem(value: '5m', child: Text('5 minutes')),
                    DropdownMenuItem(value: '15m', child: Text('15 minutes')),
                    DropdownMenuItem(value: '1h', child: Text('1 hour')),
                  ],
                  onChanged: _isRunning
                      ? null
                      : (value) => setState(() => _interval = value ?? '5m'),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _candleLimit,
                  decoration: const InputDecoration(labelText: 'Sample bars'),
                  items: const [
                    DropdownMenuItem(value: 300, child: Text('300 bars')),
                    DropdownMenuItem(value: 500, child: Text('500 bars')),
                    DropdownMenuItem(value: 1000, child: Text('1,000 bars')),
                    DropdownMenuItem(value: 1500, child: Text('1,500 bars')),
                  ],
                  onChanged: _isRunning
                      ? null
                      : (value) => setState(() => _candleLimit = value ?? 500),
                ),
              ),
              SizedBox(
                width: 250,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Historical funding',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: const Text(
                    'Use Binance funding history when available',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  value: _useHistoricalFunding,
                  onChanged: _isRunning
                      ? null
                      : (value) =>
                            setState(() => _useHistoricalFunding = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 250,
                child: ActionButton(
                  label: _isRunning ? 'RUNNING MOCK...' : 'RUN MULTI-COIN MOCK',
                  icon: Icons.play_arrow,
                  color: AppColors.glowCyan,
                  onPressed: _isRunning ? null : _runMockTest,
                ),
              ),
              SizedBox(
                width: 150,
                child: ActionButton(
                  label: 'CLEAR',
                  icon: Icons.clear,
                  color: AppColors.textSecondary,
                  onPressed:
                      _isRunning || (_result == null && _errorMessage == null)
                      ? null
                      : _clearResult,
                ),
              ),
              if (_progressMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _progressMessage!,
                    style: const TextStyle(
                      color: AppColors.glowCyan,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.negative, fontSize: 12),
            ),
          ],
          if (_loadFailures.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Skipped: ${_loadFailures.entries.map((entry) => '${entry.key} (${entry.value})').join(', ')}',
              style: const TextStyle(color: AppColors.warning, fontSize: 11),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultSummary(result: _result!),
          ] else if (!_isRunning) ...[
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'Choose at least one coin and run a mock test.\nAI replay is intentionally excluded because live model calls are not deterministic historical evidence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runMockTest() async {
    final balance = _parseFinite(_balanceController.text);
    final fee = _parseFinite(_feeController.text);
    final slippage = _parseFinite(_slippageController.text);
    final funding = _parseFinite(_fundingController.text);
    if (_selectedSymbols.isEmpty ||
        balance == null ||
        balance <= 0 ||
        fee == null ||
        fee < 0 ||
        fee > 10 ||
        slippage == null ||
        slippage < 0 ||
        slippage > 1000 ||
        funding == null ||
        funding < 0 ||
        funding > 10) {
      setState(() {
        _errorMessage =
            'Select a coin and use finite assumptions: balance > 0, fee 0-10%, slippage 0-1000 bps, funding stress 0-10%.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _loadFailures = const {};
      _progressMessage = 'Reading production Futures history...';
    });

    try {
      final api = ref.read(historicalBinanceApiProvider);
      final serverTime = await api.getServerTime();
      final symbols = _selectedSymbols.toList()..sort();
      final outcomes = await Future.wait(
        symbols.map(
          (symbol) =>
              _loadSymbolHistory(symbol: symbol, serverTime: serverTime),
        ),
      );
      final candlesBySymbol = <String, List<Kline>>{};
      final fundingBySymbol = <String, List<MockFundingRatePoint>>{};
      final failures = <String, String>{};
      for (final outcome in outcomes) {
        if (outcome.error != null || outcome.candles.length < 2) {
          failures[outcome.symbol] = outcome.error ?? 'not enough closed bars';
          continue;
        }
        candlesBySymbol[outcome.symbol] = outcome.candles;
        if (outcome.fundingRates != null) {
          fundingBySymbol[outcome.symbol] = outcome.fundingRates!;
        }
      }
      if (candlesBySymbol.isEmpty) {
        throw StateError(
          'No selected symbol returned enough completed candles.',
        );
      }

      if (mounted) {
        setState(() {
          _progressMessage =
              'Replaying ${candlesBySymbol.length} coin${candlesBySymbol.length == 1 ? '' : 's'} without same-bar lookahead...';
        });
      }
      final riskSettings = await ref.read(riskSettingsProvider.future);
      final settings = ref.read(settingsServiceProvider);
      await settings.init();
      final result = await ref
          .read(mockPortfolioTestServiceProvider)
          .run(
            klinesBySymbol: candlesBySymbol,
            fundingBySymbol: fundingBySymbol,
            riskSettings: riskSettings,
            assumptions: MockTestAssumptions(
              startingBalanceUsdt: balance,
              feePercentPerSide: fee,
              slippageBpsPerMarketFill: slippage,
              fundingPercentPer8Hours: funding,
              useHistoricalFunding: _useHistoricalFunding,
            ),
            strategyFactory: (_) => RsiStrategy(
              period: settings.getRsiPeriod(),
              overbought: settings.getRsiOverbought(),
              oversold: settings.getRsiOversold(),
            ),
          );

      if (!mounted) return;
      setState(() {
        _result = result;
        _loadFailures = failures;
        _lastRunAt = DateTime.now();
        _progressMessage = null;
      });
      showAppToast(
        context,
        result.verdict == MockTestVerdict.netPositive
            ? 'Historical sample is net positive after modeled costs; this is not expected live profit.'
            : 'Mock test complete. Review the net result, sample size, and drawdown.',
        backgroundColor: _verdictColor(result.verdict).withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.science_outlined,
        duration: const Duration(seconds: 5),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Mock test failed: $error';
        _progressMessage = null;
      });
      showAppToast(
        context,
        'Multi-coin mock test failed',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  Future<_HistoricalLoadOutcome> _loadSymbolHistory({
    required String symbol,
    required int serverTime,
  }) async {
    try {
      final api = ref.read(historicalBinanceApiProvider);
      final raw = await api.getKlines(
        symbol: symbol,
        interval: _interval,
        limit: _candleLimit,
        endTime: serverTime,
      );
      final candles =
          raw
              .whereType<List<dynamic>>()
              .map(Kline.fromJson)
              .where(
                (candle) =>
                    candle.closeTime.millisecondsSinceEpoch <= serverTime,
              )
              .toList()
            ..sort((a, b) => a.openTime.compareTo(b.openTime));
      List<MockFundingRatePoint>? fundingRates;
      if (_useHistoricalFunding && candles.isNotEmpty) {
        try {
          final rawFunding = await api.getFundingRateHistory(
            symbol: symbol,
            startTime: candles.first.openTime.millisecondsSinceEpoch,
            endTime: serverTime,
          );
          fundingRates = rawFunding
              .whereType<Map>()
              .map((item) {
                final timestamp = int.tryParse('${item['fundingTime'] ?? ''}');
                final rate = double.tryParse('${item['fundingRate'] ?? ''}');
                if (timestamp == null || rate == null || !rate.isFinite) {
                  return null;
                }
                return MockFundingRatePoint(
                  timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
                  rate: rate,
                );
              })
              .whereType<MockFundingRatePoint>()
              .toList();
        } catch (_) {
          fundingRates = null;
        }
      }
      return _HistoricalLoadOutcome(
        symbol: symbol,
        candles: candles,
        fundingRates: fundingRates,
      );
    } catch (error) {
      return _HistoricalLoadOutcome(
        symbol: symbol,
        candles: const [],
        error: _shortError(error),
      );
    }
  }

  double? _parseFinite(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed?.isFinite == true ? parsed : null;
  }

  String _shortError(Object error) {
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 90 ? text : '${text.substring(0, 87)}...';
  }

  void _clearResult() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _loadFailures = const {};
      _lastRunAt = null;
      _progressMessage = null;
    });
  }
}

class _ResultSummary extends StatelessWidget {
  final MockPortfolioTestResult result;

  const _ResultSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = _verdictColor(result.verdict);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _verdictLabel(result.verdict),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.verdict == MockTestVerdict.insufficientSample
                    ? 'Only ${result.summary.totalTrades}/${result.requiredClosedTrades} required closed trades were generated. Increase bars or test another timeframe before interpreting the sign of P&L.'
                    : 'This label describes this historical sample after the assumptions below. It does not establish future or live profitability.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricTile(
              label: 'Net P&L after costs',
              value: _money(result.netPnl),
              helper:
                  '${result.returnPercent.toStringAsFixed(2)}% | End ${_money(result.endingBalance)}',
              color: result.netPnl >= 0
                  ? AppColors.positive
                  : AppColors.negative,
            ),
            _MetricTile(
              label: 'Portfolio drawdown',
              value: '${result.maxDrawdownPercent.toStringAsFixed(2)}%',
              helper: 'Mark-to-market equity path',
              color: AppColors.warning,
            ),
            _MetricTile(
              label: 'Closed trades',
              value: result.summary.totalTrades.toString(),
              helper:
                  '${result.summary.winningTrades} wins | ${result.summary.losingTrades} losses',
              color: AppColors.glowCyan,
            ),
            _MetricTile(
              label: 'Profit factor',
              value: result.summary.profitFactor.isInfinite
                  ? 'INF'
                  : result.summary.profitFactor.toStringAsFixed(2),
              helper:
                  '${result.profitableSymbols}/${result.symbolResults.length} coins net positive',
              color: result.summary.profitFactor > 1
                  ? AppColors.positive
                  : AppColors.warning,
            ),
            _MetricTile(
              label: 'Fees + funding',
              value: _money(-(result.totalFees + result.totalFunding)),
              helper:
                  'Fees ${_money(result.totalFees)} | Funding ${_money(result.totalFunding)}',
              color: AppColors.negative,
            ),
            _MetricTile(
              label: 'Slippage stress',
              value: _money(-result.estimatedSlippageCost),
              helper:
                  'Estimated adverse fill impact | ${result.unfilledLimitSignals} limits unfilled',
              color: AppColors.glowAmber,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MockEquityChart(result: result),
        const SizedBox(height: 14),
        const Text(
          'Per-coin contribution',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final symbolResult in result.symbolResults)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SymbolResultRow(result: symbolResult),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label:
                  '${DateFormat('MMM d HH:mm').format(result.periodStart.toLocal())} - ${DateFormat('MMM d HH:mm').format(result.periodEnd.toLocal())}',
              color: AppColors.textSecondary,
            ),
            StatusPill(
              label: 'Fee ${result.assumptions.feePercentPerSide}% / side',
              color: AppColors.textSecondary,
            ),
            StatusPill(
              label:
                  'Slippage ${result.assumptions.slippageBpsPerMarketFill} bps / market fill',
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final warning in result.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $warning',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

class _MockEquityChart extends StatelessWidget {
  final MockPortfolioTestResult result;

  const _MockEquityChart({required this.result});

  @override
  Widget build(BuildContext context) {
    final curve = result.equityCurve;
    if (curve.length < 2) return const SizedBox.shrink();
    final values = curve.map((point) => point.equity).toList();
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final rawRange = maximum - minimum;
    final padding = rawRange <= 0
        ? math.max(maximum.abs() * 0.01, 1.0)
        : rawRange * 0.12;
    final minY = minimum - padding;
    final maxY = maximum + padding;
    final positive = result.netPnl >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;
    final middle = (curve.length - 1) ~/ 2;

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio mock equity (mark-to-market)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (curve.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineTouchData: const LineTouchData(enabled: true),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.55),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 58,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index != 0 &&
                            index != middle &&
                            index != curve.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat(
                              'MM/dd HH:mm',
                            ).format(curve[index].timestamp.toLocal()),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: curve
                        .asMap()
                        .entries
                        .map(
                          (entry) =>
                              FlSpot(entry.key.toDouble(), entry.value.equity),
                        )
                        .toList(),
                    isCurved: false,
                    barWidth: 2,
                    color: color,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            helper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _SymbolResultRow extends StatelessWidget {
  final MockSymbolTestResult result;

  const _SymbolResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.netPnl >= 0 ? AppColors.positive : AppColors.negative;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              result.symbol,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money(result.netPnl),
            style: tabularFigures(
              TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${result.returnPercent.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            '${result.closedTrades} exits',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            'DD ${result.maxDrawdownPercent.toStringAsFixed(2)}%',
            style: const TextStyle(color: AppColors.warning, fontSize: 11),
          ),
          Text(
            'Costs ${_money(result.totalFees + result.totalFunding)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool enabled;

  const _CompactField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }
}

class _HistoricalLoadOutcome {
  final String symbol;
  final List<Kline> candles;
  final List<MockFundingRatePoint>? fundingRates;
  final String? error;

  const _HistoricalLoadOutcome({
    required this.symbol,
    required this.candles,
    this.fundingRates,
    this.error,
  });
}

String _verdictLabel(MockTestVerdict? verdict) {
  return switch (verdict) {
    MockTestVerdict.netPositive => 'HISTORICAL SAMPLE NET POSITIVE',
    MockTestVerdict.netNegative => 'HISTORICAL SAMPLE NET NEGATIVE',
    MockTestVerdict.insufficientSample => 'INSUFFICIENT SAMPLE',
    null => 'READY — NO RESULT',
  };
}

Color _verdictColor(MockTestVerdict? verdict) {
  return switch (verdict) {
    MockTestVerdict.netPositive => AppColors.positive,
    MockTestVerdict.netNegative => AppColors.negative,
    MockTestVerdict.insufficientSample => AppColors.warning,
    null => AppColors.textMuted,
  };
}

String _money(double value) {
  final amount = value.abs().toStringAsFixed(2);
  return value < 0 ? '-\$$amount' : '\$$amount';
}
