import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../models/protection_status.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class RiskSummaryCard extends ConsumerWidget {
  const RiskSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(selectedSymbolProvider);
    final riskAsync = ref.watch(riskSettingsProvider);
    final protectionAsync = ref.watch(protectionStatusProvider(symbol));

    return riskAsync.when(
      data: (risk) {
        final protectionStatus = protectionAsync.maybeWhen(
          data: (status) => status,
          orElse: () => const ProtectionStatus.ready(),
        );
        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Risk & Protections',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const StatusPill(
                        label: 'Paper',
                        color: AppColors.textSecondary,
                      ),
                      StatusPill(
                        label: _protectionLabel(protectionStatus),
                        color: _protectionColor(protectionStatus.state),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 3 : 2;
                  final spacing = 12.0;
                  final tileWidth =
                      (constraints.maxWidth - (spacing * (columns - 1))) /
                      columns;
                  final tiles = [
                    _RiskTile(
                      label: 'Stop Loss',
                      value: _formatPercent(risk.stopLossPercent),
                      accent: risk.stopLossPercent > 0
                          ? AppColors.negative
                          : AppColors.textMuted,
                      helper: 'Percent',
                    ),
                    _RiskTile(
                      label: 'Take Profit',
                      value: _formatPercent(risk.takeProfitPercent),
                      accent: risk.takeProfitPercent > 0
                          ? AppColors.positive
                          : AppColors.textMuted,
                      helper: 'Percent',
                    ),
                    _RiskTile(
                      label: 'Quantity',
                      value: _formatQuantity(risk.tradeQuantity),
                      accent: AppColors.glowCyan,
                      helper: 'Fixed size',
                    ),
                    _RiskTile(
                      label: 'Cooldown',
                      value: _formatMinutes(risk.cooldownMinutes),
                      accent: risk.hasCooldown
                          ? AppColors.glowAmber
                          : AppColors.textMuted,
                      helper: 'After any exit',
                    ),
                    _RiskTile(
                      label: 'Loss Streak Lock',
                      value: risk.maxConsecutiveLosses <= 0
                          ? 'OFF'
                          : '${risk.maxConsecutiveLosses} losses',
                      accent: risk.hasLossStreakProtection
                          ? AppColors.warning
                          : AppColors.textMuted,
                      helper: _protectionPauseLabel(
                        risk.protectionPauseMinutes,
                      ),
                    ),
                    _RiskTile(
                      label: 'Drawdown Lock',
                      value: _formatPercent(risk.maxDrawdownPercent),
                      accent: risk.hasDrawdownProtection
                          ? AppColors.negative
                          : AppColors.textMuted,
                      helper: _protectionPauseLabel(
                        risk.protectionPauseMinutes,
                      ),
                    ),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final tile in tiles)
                        SizedBox(width: tileWidth, child: tile),
                    ],
                  );
                },
              ),
              if ((protectionStatus.message ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  protectionStatus.message!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () =>
          const AppPanel(child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => AppPanel(
        accent: AppColors.negative,
        child: Text(
          'Risk settings error: $error',
          style: const TextStyle(color: AppColors.negative),
        ),
      ),
    );
  }

  static String _protectionLabel(ProtectionStatus status) {
    return switch (status.state) {
      ProtectionState.ready => 'Protection: Clear',
      ProtectionState.cooldown => 'Protection: Cooldown',
      ProtectionState.locked => 'Protection: Locked',
    };
  }

  static Color _protectionColor(ProtectionState state) {
    return switch (state) {
      ProtectionState.ready => AppColors.positive,
      ProtectionState.cooldown => AppColors.glowAmber,
      ProtectionState.locked => AppColors.warning,
    };
  }

  static String _protectionPauseLabel(int minutes) {
    if (minutes <= 0) {
      return 'Pause off';
    }
    return 'Pause ${minutes}m';
  }

  static String _formatMinutes(int value) {
    if (value <= 0) return 'OFF';
    return '${value}m';
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
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
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
