# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-07-14
### Added
- ARIAUSDT-first one-click Futures desk with required ARIAUSDT, TRIAUSDT, SIRENUSDT, and BTCUSDT markets while retaining TRUUSDT.
- Guarded 30-second one-click Long/Short arming, Smart Maker post-only entry, optional market entry, and gross `$5 TP / $5 SL` preset.
- Dynamic Binance Futures contract/filter validation for both limit and market quantities.
- Authenticated Binance user-data event handling for immediate fill, account, and Algo Order reconciliation.
- Absolute USDT profit/loss planning controls with explicit gross-estimate labeling.
- GitHub Pages deployment workflow for free public Flutter Web hosting.
- Portfolio analytics dashboard card with wallet, margin, exposure, realized PnL, and AI posture context.
- Per-symbol contribution breakdown with its own bounded scroll inside the portfolio analytics dashboard.
- Current position snapshot embedded inside portfolio analytics for side, entry, last price, size, exposure, and unrealized PnL.
- Dedicated order-book execution dashboard card with live Binance depth, slippage, and AI execution hints.
- Live liquidation price display sourced from Binance position sync.
- Added `TRUUSDT` to the default and required symbol set.
- AI-to-manual ticket prefills from the latest plan.
- AI trader controls for allowed direction, leverage, and max USDT margin budget.

### Changed
- Migrated Futures STOP_MARKET / TAKE_PROFIT_MARKET protection to Binance's current `/fapi/v1/algoOrder` workflow.
- Made stop replacement install-first and cancellation-verified to avoid an unprotected refresh gap.
- Made symbol, strategy-mode, Binance, AI, and risk-setting changes disarm and reconcile the previous runtime before rebuilding providers.
- Scoped exchange-order ownership to a durable installation ID and made the Windows runner single-instance so separate app copies cannot manage one another's orders.
- Serialized entry submission, account reconciliation, and STOP handling; uncertain entries stay quarantined until exchange absence is proven.
- Added stop-first protection verification, emergency flattening when stop coverage cannot be confirmed, user-data retry/backoff, and foreign-position isolation.
- Added a five-minute symbol-rule cache while retaining force-refresh checks for one-click maker pricing.
- Added a 60% confidence floor for AI auto execution and finite-number validation for model/settings payloads.
- Made per-symbol engines auto-dispose and symbol switching disarm/cancel bot-owned entries before handoff.
- Gated GitHub Pages deployment on successful analysis and tests; public web blocks and purges production credentials as well as real-money mutations.
- Added timeout/5xx unknown-outcome classification and client-order reconciliation without blind order retries.
- Made Futures access the authoritative Binance verification result so an unavailable optional Spot check does not reject a valid Futures key.
- Made performance, per-symbol win rates, and AI outcome summaries account for recorded exit commissions; drawdown is reported honestly as absolute USDT without inventing starting equity, and backtests are labeled as gross close-price simulations that omit live execution costs.
- Updated the web app metadata and README deployment instructions for the public web target.
- Reworked `TODO.md` into a prioritized, actionable roadmap (`Now`, `Next`, `Later`) with explicit `P0`-`P3` severity markers.
- Synced `README.md` roadmap priorities with the latest TODO state.
- Updated App Gallery content to reflect current screenshot availability and roadmap-oriented milestone messaging.

### Fixed
- Corrected the requested primary symbol from AIRAUSDT to ARIAUSDT.
- Prevented STOP AUTO from locally pretending an exchange position was closed and from leaving known bot entry orders working.
- Blocked live routing when Binance position mode is Hedge or cannot be confirmed.
- Prevented browser builds from invoking desktop-only automation import or CSV file-export APIs.
- Rejected non-finite risk, alert, strategy, and manual-ticket values instead of allowing invalid calculations into execution.
- Prevented symbol changes from proceeding when old-symbol order cancellation cannot be verified.
- Clarified paper-simulation controls and visible-depth limitations so monitoring states cannot be mistaken for verified live routing or whale intent.

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
