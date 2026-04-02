import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';

class ScreenshotCarousel extends StatefulWidget {
  const ScreenshotCarousel({super.key});

  @override
  State<ScreenshotCarousel> createState() => _ScreenshotCarouselState();
}

class _ScreenshotCarouselState extends State<ScreenshotCarousel> {
  int _currentIndex = 0;

  final List<Map<String, String>> _screenshots = [
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.8.png',
      'title': 'Version 1.0.8 - AI Trade Intelligence',
      'description':
          'Latest: protection engine, access verification, and order-book-aware AI execution',
    },
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.7.png',
      'title': 'Version 1.0.7 - Market Analysis',
      'description': 'Latest: live BTC/ETH/BNB/SOL pulse and crypto news',
    },
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.6.png',
      'title': 'Version 1.0.6 - RSI Strategy Tuning',
      'description':
          'Latest: Preset-based RSI controls in Settings and live algorithm labeling',
    },
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.3.png',
      'title': 'Version 1.0.3 - Trade History',
      'description':
          'Latest: Real-time trade tracking with buy/sell indicators',
    },
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.2.png',
      'title': 'Version 1.0.2 - Status Indicators',
      'description': 'Added bot and engine status chips',
    },
    {
      'path': 'assets/screenshots/screenshot_app_v1.0.1.png',
      'title': 'Version 1.0.1 - Initial Dashboard',
      'description': 'Basic trading dashboard with price chart and controls',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'App Evolution',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_screenshots.length}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CarouselSlider(
            options: CarouselOptions(
              height: 300,
              enlargeCenterPage: true,
              enableInfiniteScroll: false,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            items: _screenshots.map((screenshot) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 6.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: Image.asset(
                              screenshot['path']!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.surface,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: AppColors.textMuted,
                                      size: 48,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                screenshot['title']!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                screenshot['description']!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _screenshots.asMap().entries.map((entry) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == entry.key
                      ? AppColors.glowCyan
                      : AppColors.textMuted.withValues(alpha: 0.6),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
