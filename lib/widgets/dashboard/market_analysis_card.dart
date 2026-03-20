import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/symbols.dart';
import '../../models/market_analysis.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class MarketAnalysisCard extends ConsumerWidget {
  final String symbol;

  const MarketAnalysisCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(marketAnalysisProvider);

    return AppPanel(
      child: analysisAsync.when(
        loading: () => _LoadingState(symbol: symbol),
        error: (error, stackTrace) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(marketAnalysisProvider),
        ),
        data: (snapshot) => _AnalysisState(
          symbol: symbol,
          snapshot: snapshot,
          onRefresh: () => ref.invalidate(marketAnalysisProvider),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String symbol;

  const _LoadingState({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderSkeleton(),
        const SizedBox(height: 12),
        Text(
          'Loading BTC, ETH, BNB, and SOL context...',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selected symbol: $symbol',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.insights_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Market Analysis',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Retry market analysis',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Could not load the live market pulse right now.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          style: const TextStyle(color: AppColors.negative, fontSize: 11),
        ),
      ],
    );
  }
}

class _AnalysisState extends StatelessWidget {
  final String symbol;
  final MarketAnalysisSnapshot snapshot;
  final VoidCallback onRefresh;

  const _AnalysisState({
    required this.symbol,
    required this.snapshot,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = DateFormat('HH:mm').format(snapshot.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.insights_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Market Analysis',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh market pulse',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'BTC, ETH, BNB, and SOL live pulse with recent crypto headlines.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: 'Bias: ${snapshot.bias.label}',
              color: _biasColor(snapshot.bias),
            ),
            StatusPill(label: 'Updated $dateLabel', color: AppColors.textMuted),
            StatusPill(
              label: 'Selected: ${_displayName(symbol)}',
              color: AppColors.glowAmber,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 640
                ? 2
                : 1;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.42,
              children: snapshot.assets.map(_buildAssetTile).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _biasColor(snapshot.bias).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Analysis Note',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.summary,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                snapshot.shortWatch,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.newspaper_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'News Pulse',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            StatusPill(
              label: '${snapshot.news.length} headlines',
              color: snapshot.news.isEmpty
                  ? AppColors.textMuted
                  : AppColors.glowCyan,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (snapshot.news.isEmpty)
          const Text(
            'No recent headlines were returned.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          )
        else
          Column(
            children: snapshot.news
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NewsTile(item: item),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAssetTile(MarketAssetSnapshot asset) {
    final color = asset.isPositive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                asset.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              StatusPill(label: asset.changeLabel, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            asset.priceLabel,
            style: tabularFigures(
              TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Range: ${asset.rangeLabel}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vol: ${_formatCompactNumber(asset.volume)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _displayName(String value) {
    return value.replaceAll('USDT', '');
  }

  Color _biasColor(MarketBias bias) {
    return switch (bias) {
      MarketBias.bullish => AppColors.positive,
      MarketBias.neutral => AppColors.glowAmber,
      MarketBias.bearish => AppColors.negative,
    };
  }

  String _formatCompactNumber(double value) {
    final compact = NumberFormat.compact(locale: 'en_US');
    return compact.format(value);
  }
}

class _NewsTile extends StatelessWidget {
  final MarketNewsItem item;

  const _NewsTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.feedLabel == 'BTC'
        ? AppColors.glowCyan
        : AppColors.glowAmber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(label: item.feedLabel, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.insights_outlined,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Market Analysis',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: null,
          icon: const Icon(Icons.refresh),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}
