# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- GitHub Pages deployment workflow for free public Flutter Web hosting.

### Changed
- Updated the web app metadata and README deployment instructions for the public web target.

## [1.0.8] - 2026-04-02
### Added
- Protection engine controls with cooldown, pause-window, loss-streak, and drawdown locks.
- AI context analysis that scores market regime, portfolio posture, and recent trade quality before sizing a plan.
- Multi-timeframe AI alignment using local `1m`, `5m`, and `15m` structure in the prompt and strategy console.
- Binance order-book execution context with spread, imbalance, estimated sweep cost, and execution hints.
- AI API verification and runtime health status alongside the Binance connection flow.
- Tracked-account trade history fallback and a bounded inner scroll for larger history sets.
- App gallery milestone for the `1.0.8` release.

### Changed
- Reorganized the dashboard header to surface live price, exchange status, and strategy status in a tighter top bar.
- Reworked Binance settings terminology to use `Live Connection`, `Demo Connection`, and clearer verify/apply actions.
- Refreshed README, TODO, changelog, and app gallery metadata to match the current app state.

### Fixed
- Separated spot-read verification from futures-access verification so valid read-only keys no longer look like broken credentials.
- Improved runtime Binance status handling so verified settings and running-app state are easier to distinguish.
- Ensured live Binance sync prefers real account data over stale simulated history when credentials are configured.

## [1.0.7] - 2026-03-20
### Added
- Market analysis dashboard card for BTC, ETH, BNB, and SOL.
- Live CoinGecko price pulse with Google News headlines.
- Bias note and short-watch context based on live market breadth.
- Updated app gallery with the new market analysis screenshot.

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
