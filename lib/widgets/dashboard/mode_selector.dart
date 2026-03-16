import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../trading/algo_strategy.dart';
import '../../trading/ai_strategy.dart';
import '../../trading/manual_strategy.dart';
import '../../theme/app_theme.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStrategy = ref.watch(currentStrategyProvider);
    if (currentStrategy == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context,
            ref,
            'ALGO',
            currentStrategy is RsiStrategy,
            () => ref.read(currentStrategyProvider.notifier).state = RsiStrategy(),
          ),
          const SizedBox(width: 6),
          _buildOption(
            context,
            ref,
            'AI',
            currentStrategy is AiStrategy,
            () => ref.read(currentStrategyProvider.notifier).state = AiStrategy(
              apiUrl: 'https://your-ai-api.com/analyze',
            ),
          ),
          const SizedBox(width: 6),
          _buildOption(
            context,
            ref,
            'MANUAL',
            currentStrategy is ManualStrategy,
            () => ref.read(currentStrategyProvider.notifier).state = ManualStrategy(),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, WidgetRef ref, String label, bool isSelected, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.glowAmber : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.glowAmber : AppColors.border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.glowAmber.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
