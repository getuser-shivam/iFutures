import 'package:flutter/material.dart';
import '../widgets/gallery/screenshot_carousel.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Gallery'),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'iFutures Development Evolution',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Track the progress of our automated trading application through its various development stages.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              ScreenshotCarousel(),
              SizedBox(height: 24),
              Text(
                'Key Milestones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade400, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v$version',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '- ',
                  style: TextStyle(color: Colors.greenAccent),
                ),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

