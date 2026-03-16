import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';

class RiskSummaryCard extends ConsumerWidget {
  const RiskSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskAsync = ref.watch(riskSettingsProvider);

    return riskAsync.when(
      data: (risk) {
        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Risk Settings',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Paper',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _RiskTile(
                      label: 'Stop Loss',
                      value: _formatPercent(risk.stopLossPercent),
                      accent: risk.stopLossPercent > 0 ? AppColors.negative : AppColors.textMuted,
                      helper: 'Percent',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RiskTile(
                      label: 'Take Profit',
                      value: _formatPercent(risk.takeProfitPercent),
                      accent: risk.takeProfitPercent > 0 ? AppColors.positive : AppColors.textMuted,
                      helper: 'Percent',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RiskTile(
                      label: 'Quantity',
                      value: _formatQuantity(risk.tradeQuantity),
                      accent: AppColors.glowCyan,
                      helper: 'Fixed size',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AppPanel(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => AppPanel(
        accent: AppColors.negative,
        child: Text(
          'Risk settings error: $error',
          style: const TextStyle(color: AppColors.negative),
        ),
      ),
    );
  }

  static String _formatPercent(double value) {
    if (value == 0) return 'OFF';
    return '${value.toStringAsFixed(2)}%';
  }

  static String _formatQuantity(double value) {
    return value.toStringAsFixed(4);
  }
}

class _RiskTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _RiskTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
