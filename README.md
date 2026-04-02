# iFutures - Automated Trading Bot

A Flutter-based trading desk for automated cryptocurrency trading with AI, algorithmic, and manual execution workflows.

## Versioning

- **Current version:** `1.0.8+9` (see `pubspec.yaml`)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **TODOs:** [TODO.md](TODO.md)

## Application Overview

iFutures is a multi-platform trading application that connects to Binance, provides AI-driven and algorithmic trade planning, and keeps manual override close at hand. The app supports real-time market data visualization, live price monitoring, account verification, configurable symbols, persistent trade history, CSV export, resilient reconnects, historical backtesting, protection rules, and AI execution context built from candles, portfolio data, and Binance depth.

### Current Features

- **Real-time Candlestick Charts**: OHLC candlestick chart with live updates.
- **Organized Strategy Workspace**: AI, ALGO, and manual controls live in Settings while the dashboard stays focused on monitoring.
- **Strategy Terminal**: AI and ALGO publish the latest side, chosen order type, leverage, rationale, and rolling activity log before execution.
- **AI Context Engine**: AI scores market regime, portfolio posture, and recent trade review before sizing a setup.
- **Multi-Timeframe AI Alignment**: AI compares local `1m`, `5m`, and `15m` structure before choosing side and size.
- **Binance Order-Book Context**: AI reads spread, bid/ask imbalance, and estimated market sweep cost before picking execution style.
- **AI Outcome Memory**: AI now reviews recent realized exits and adjusts confidence when the latest outcomes are hot, mixed, or cooling off after losses.
- **Order-Book Trend Memory**: AI tracks the last several minute-level Binance depth snapshots to detect tightening support, worsening liquidity, or persistent ask pressure.
- **Binance Verification Workflow**: `Live Connection` / `Demo Connection` verification with clearer access checks and runtime status.
- **AI API Verification**: Settings can verify the configured AI provider and the dashboard shows the current AI Analyst health state.
- **Protection Engine**: Cooldown, pause window, loss-streak, and drawdown locks pause new auto entries while preserving manual override.
- **Bot Control**: Start or stop trading execution.
- **Configurable Symbols**: Manage the tradable symbol list from Settings.
- **RSI Strategy Presets**: Tune the algorithm with saved RSI period and threshold presets.
- **Risk Management**: Stop loss, take profit, trade quantity, leverage, and protection configuration.
- **Persistent Trade History**: Entry and exit trades are saved locally and restored on startup.
- **Account-Aware Trade History**: The trade history card can fall back to tracked Binance account fills when the selected symbol has no recent fills.
- **App Gallery**: Built-in evolution gallery with versioned screenshots and milestone notes.
- **Market Analysis Card**: Live BTC/ETH/BNB/SOL pulse from CoinGecko with Google News headlines.
- **Resilient Market Stream**: WebSocket auto-reconnect with exponential backoff.
- **Open Position Card**: Current position with SL/TP previews and unrealized PnL.
- **Daily Performance Summary**: PnL, win rate, and drawdown for the current local day.
- **Trade History**: Entry and exit trades with reasons and realized PnL in a bounded inner-scroll review panel.
- **CSV Export**: Trade history can be exported for offline analysis.
- **Backtesting Lab**: Historical candle simulation using the selected strategy and live risk rules.
- **Performance Metrics**: Win rate, total PnL, drawdown, and profit factor.
- **Status Indicators**: Bot running state, engine status, reconnect attempts, and strategy, Binance, and AI health display.
- **Price Alerts**: Threshold-based one-shot alerts with toast notifications and rearm controls.

## Screenshots

### Windows Desktop Application
![iFutures Dashboard - AI Trade Intelligence](screenshot_app_window.png)
*Current state: compact monitoring dashboard with AI strategy terminal, Binance status, and execution-aware planning tools.*

### App Gallery
![iFutures App Gallery - Release Timeline](screenshot_app_gallery.png)
*Current state: App Gallery highlighting the `1.0.8` release slide and milestone card.*

## Development Status

### Completed
- [x] Flutter Windows build setup
- [x] Real-time price display and WebSocket streaming
- [x] Candlestick chart (OHLC)
- [x] Strategy selection (ALGO/AI/Manual)
- [x] Bot control buttons (START/STOP)
- [x] Risk settings (SL/TP/quantity/leverage)
- [x] Paper trading with entry/exit and realized PnL
- [x] Trade history and performance metrics
- [x] Historical backtesting engine
- [x] Multi-symbol selection
- [x] Configurable symbol list in Settings
- [x] RSI strategy presets and tuning controls in Settings
- [x] Market analysis card with BTC, ETH, BNB, SOL, and crypto news
- [x] Persist trade history to disk and reload on startup
- [x] Clear trade history action from the dashboard
- [x] Binance and AI access verification workflow with clearer runtime status labels
- [x] Strategy signal indicator for AI/ALGO decisions
- [x] Strategy terminal with chosen order type, leverage, rationale, refresh action, and rolling activity log for AI/ALGO plans
- [x] Protection engine with cooldown, loss-streak, and drawdown locks for auto-entry safety
- [x] AI context analyzer with regime detection, portfolio/trade-review posture, and dynamic AI size scaling
- [x] Multi-timeframe AI alignment with `1m` / `5m` / `15m` context in the strategy console and prompt
- [x] Binance order-book execution context with spread, imbalance, and estimated market slippage for AI order-type decisions
- [x] AI decision memory that reviews recent realized exits and feeds that bias back into plan sizing
- [x] Order-book trend memory that compares the latest several Binance depth snapshots before AI chooses execution
- [x] Bounded trade history review with tracked-account fill fallback
- [x] WebSocket auto-reconnect with exponential backoff and reconnect status in the UI
- [x] Price alerts with toast notifications and rearmable dashboard cards
- [x] Daily performance summary card with PnL, win rate, and drawdown
- [x] GitHub Actions CI for `flutter analyze`, `flutter test`, and a Windows build smoke check

### Roadmap
See [TODO.md](TODO.md) for current priorities and upcoming work.

## Building and Running

### Windows
```bash
flutter build windows
flutter run -d windows
```

### Web
```bash
flutter build web --release --base-href /iFutures/ --no-wasm-dry-run
flutter run -d chrome
```

## Free Public Web Hosting

This repo is now set up for free public hosting with GitHub Pages.

- **Workflow:** [deploy_web.yml](.github/workflows/deploy_web.yml)
- **Public URL after deployment:** `https://getuser-shivam.github.io/iFutures/`
- **Hosting cost:** free on GitHub Pages for a public repository

### One-time GitHub setup

1. Push `main` to GitHub.
2. Open the repository Settings.
3. Go to `Pages`.
4. Set the source to `GitHub Actions`.

After that, each push to `main` will build Flutter Web and deploy the site automatically.

### Important Web Note

The web build is fine for public monitoring, charting, and demo access. For real live trading, a browser-hosted app is a weaker place to handle Binance and AI secrets than a desktop build or backend service, so treat the public web site as a public client, not a private trading terminal.

### macOS
```bash
flutter build macos
flutter run -d macos
```

### Linux
```bash
flutter build linux
flutter run -d linux
```

## Project Structure

```text
lib/
|- main.dart                         # App entry point
|- constants/
|  |- symbols.dart                   # Default tradable symbols
|- models/
|  |- ai_context_snapshot.dart       # AI market and portfolio posture snapshot
|  |- ai_service_status.dart         # AI provider health state
|  |- ai_timeframe_snapshot.dart     # Multi-timeframe AI context model
|  |- backtest_result.dart           # Backtest result data model
|  |- binance_account_status.dart    # Binance account sync state
|  |- connection_status.dart         # Market connection state model
|  |- kline.dart                     # OHLCV candlestick data model
|  |- market_analysis.dart           # Market analysis data models and formatting helpers
|  |- order_book_snapshot.dart       # Binance order-book execution summary
|  |- performance_summary.dart       # Performance summary data model
|  |- position.dart                  # Open position model
|  |- price_alert.dart               # Price alert model and formatting helpers
|  |- protection_status.dart         # Auto-entry protection state model
|  |- risk_settings.dart             # Risk and protection configuration model
|  |- rsi_strategy_preset.dart       # RSI preset definitions and helpers
|  |- trade.dart                     # Trade record model
|- providers/
|  |- trading_provider.dart          # Riverpod state management
|- screens/
|  |- dashboard_screen.dart          # Main trading dashboard
|  |- gallery_screen.dart            # App gallery
|  |- settings_screen.dart           # Configuration screen
|- services/
|  |- ai_context_analyzer.dart       # Local AI market and portfolio posture analyzer
|  |- ai_multi_timeframe_analyzer.dart # 1m / 5m / 15m AI alignment helper
|  |- backtest_service.dart          # Historical strategy simulation engine
|  |- binance_api.dart               # Binance REST API client
|  |- binance_ws.dart                # Binance WebSocket connection
|  |- market_analysis_service.dart   # Live BTC/ETH/BNB/SOL analysis and crypto news feed
|  |- order_book_analyzer.dart       # Spread, slippage, and imbalance analysis for execution planning
|  |- performance_summary_calculator.dart # Shared performance summary logic
|  |- price_alert_service.dart       # Persistent alert storage and evaluation
|  |- reconnect_backoff.dart         # Exponential retry delay helper
|  |- reconnecting_websocket.dart    # Resilient WebSocket wrapper
|  |- settings_service.dart          # Settings storage
|  |- trade_csv_export_service.dart  # CSV export helper for trade history
|  |- trade_history_service.dart     # Local trade history persistence
|- trading/
|  |- ai_strategy.dart               # AI-powered strategy
|  |- algo_strategy.dart             # Algorithmic strategy
|  |- manual_strategy.dart           # Manual strategy placeholder
|  |- strategy.dart                  # Strategy interfaces and trade-plan models
|  |- trading_engine.dart            # Main execution engine
|- widgets/
|  |- common/
|  |  |- action_button.dart          # Reusable dashboard button
|  |  |- app_panel.dart              # Shared panel container
|  |  |- app_toast.dart              # Shared floating snackbar helper
|  |  |- status_pill.dart            # Compact status badge
|  |- dashboard/
|  |  |- daily_performance_card.dart # Daily realized PnL summary
|  |  |- market_analysis_card.dart   # Live BTC/ETH/BNB/SOL analysis and crypto news
|  |  |- open_position_card.dart     # Open position summary
|  |  |- performance_metrics.dart    # Realized PnL metrics
|  |  |- price_alert_listener.dart   # Dashboard alert toast listener
|  |  |- price_alerts_card.dart      # Alert creation and management card
|  |  |- price_chart.dart            # Candlestick chart visualization
|  |  |- risk_summary_card.dart      # Compact risk and protection overview
|  |  |- strategy_console_card.dart  # AI/ALGO decision console with order-type plan
|  |  |- trade_history.dart          # Trade history list
|  |- gallery/
|  |  |- screenshot_carousel.dart    # App evolution carousel
```

## Dependencies

Key packages used:
- **flutter_riverpod**: State management
- **http & dio**: HTTP clients for API calls
- **web_socket_channel**: WebSocket connections
- **fl_chart**: Financial charts
- **flutter_secure_storage**: Secure credential storage
- **shared_preferences**: Local settings storage
- **intl**: Internationalization
- **crypto**: Cryptographic functions for API signing

## Getting Started

This project requires Flutter 3.x and Dart 3.x.

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.
