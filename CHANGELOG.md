# Changelog

All notable changes to this project will be documented in this file.

## [1.0.6] - 2026-03-19
### Added
- Strategy parameter tuning UI in Settings with RSI presets and custom threshold inputs.
- Live strategy labeling on the dashboard so the active RSI preset is visible at a glance.
- Current screenshot refresh showing the updated Settings experience and app gallery.

## [1.0.3] - 2026-03-16
### Added
- Trade History feature: Real-time display of executed trades with price, quantity, timestamp, and strategy information.
- Trade model for storing transaction records.
- Trade history widget in dashboard showing buy/sell trades with visual indicators.
- Trading engine now records simulated trades for performance tracking.

### Fixed
- Fixed duplicate dispose method in trading engine.
- Fixed syntax error with extra closing brace.

## [1.0.2] - 2026-03-16
### Added
- Dashboard status indicators: Bot running state and Engine load/ready/error status chips.
- Improved UI feedback with real-time status display.

### Fixed
- Removed unused import in trading provider to clean up analyzer warnings.

## [1.0.1] - 2026-03-16
### Added
- Documentation improvements: updated README with feature tracking and screenshot.
- Added automated screenshot capture scripts for accurate app UI images.
- Added version tracking with pubspec version bump to `1.0.1+2`.

### Fixed
- Corrected README screenshot to show only the app window.

## [1.0.0] - Initial release
- Initial app structure and trading dashboard UI.
