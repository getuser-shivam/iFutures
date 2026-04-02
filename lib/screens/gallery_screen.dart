import 'package:flutter/material.dart';
import '../widgets/gallery/screenshot_carousel.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_panel.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Gallery')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'iFutures Development Evolution',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Track the progress of the trading experience through key releases and UI milestones.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 20),
            ScreenshotCarousel(),
            SizedBox(height: 24),
            Text(
              'Key Milestones',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16),
            _MilestoneCard(
              version: '1.0.8',
              date: '2026-04-02',
              features: [
                'Protection engine adds cooldown, loss-streak, and drawdown locks for safer auto-entry.',
                'AI now reads market regime, portfolio posture, multi-timeframe structure, and Binance order-book depth.',
                'Binance and AI settings now include clearer verification and apply flows with runtime status labels.',
                'Trade history is easier to review with a bounded inner scroll and tracked-account fallback fills.',
              ],
            ),
            _MilestoneCard(
              version: '1.0.7',
              date: '2026-03-20',
              features: [
                'Market analysis card for BTC, ETH, BNB, and SOL',
                'Live crypto news pulse from BTC and ETH feeds',
                'Dashboard market bias summary and short-watch note',
                'Updated app gallery screenshot for the new analysis view',
              ],
            ),
            _MilestoneCard(
              version: '1.0.6',
              date: '2026-03-19',
              features: [
                'RSI strategy tuning UI with preset chips and custom inputs',
                'Settings screen persists RSI period and threshold values',
                'Dashboard source label reflects the active RSI preset',
                'Current screenshot refreshed to show the Settings workflow',
              ],
            ),
            _MilestoneCard(
              version: '1.0.3',
              date: '2026-03-16',
              features: [
                'Real-time trade history with buy/sell indicators',
                'Trade tracking with price, quantity, and strategy info',
                'Enhanced dashboard with trade monitoring',
                'Versioned screenshot gallery',
              ],
            ),
            _MilestoneCard(
              version: '1.0.2',
              date: '2026-03-16',
              features: [
                'Bot and engine status indicators',
                'Real-time status chips in dashboard',
                'Improved UI feedback and monitoring',
              ],
            ),
            _MilestoneCard(
              version: '1.0.1',
              date: '2026-03-16',
              features: [
                'Basic trading dashboard with price charts',
                'Strategy selection (ALGO/AI modes)',
                'Bot start/stop controls',
                'Settings management and API configuration',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final String version;
  final String date;
  final List<String> features;

  const _MilestoneCard({
    required this.version,
    required this.date,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glowCyan),
                ),
                child: Text(
                  'v$version',
                  style: const TextStyle(
                    color: AppColors.glowCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '- ',
                    style: TextStyle(color: AppColors.glowAmber),
                  ),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
