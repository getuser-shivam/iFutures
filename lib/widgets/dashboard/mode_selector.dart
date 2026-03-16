import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../trading/algo_strategy.dart';
import '../../trading/ai_strategy.dart';
import '../../trading/manual_strategy.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStrategy = ref.watch(currentStrategyProvider);
    if (currentStrategy == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 12),
          _buildOption(
            context,
            ref,
            'AI',
            currentStrategy is AiStrategy,
            () => ref.read(currentStrategyProvider.notifier).state = AiStrategy(
              apiUrl: 'https://your-ai-api.com/analyze',
            ),
          ),
          const SizedBox(width: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orangeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.orangeAccent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
