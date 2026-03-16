# iFutures - Automated Trading Bot

A Flutter-based trading bot application for automated cryptocurrency trading with AI and algorithmic strategies.

## Versioning

- **Current version:** `1.0.5+6` (see `pubspec.yaml`)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **TODOs:** [TODO.md](TODO.md)

## Application Overview

iFutures is a multi-platform trading application that connects to Binance API and provides algorithmic, AI-driven, and manual trading modes. The app supports real-time market data visualization, live price monitoring, and automated bot control.

### Current Features

- **Real-time Candlestick Charts**: OHLC candlestick chart with live updates
- **Strategy Modes**: ALGO, AI, and Manual trading modes
- **Bot Control**: Start/stop trading execution
- **Multi-Symbol Support**: Select symbols like GALAUSDT, BTCUSDT, ETHUSDT, BNBUSDT, and SOLUSDT
- **Risk Management**: Stop loss, take profit, and trade quantity configuration
- **Open Position Card**: Current position with SL/TP previews and unrealized PnL
- **Trade History**: Entry/exit trades with reasons and realized PnL
- **Performance Metrics**: Win rate, total PnL, drawdown, and profit factor
- **Status Indicators**: Bot running state and engine status display

## Screenshots

### Windows Desktop Application
![iFutures Dashboard - GALAUSDT](screenshot_app_window.png)
*Current state: App showing live price, strategy selector, controls, and trade history*

## Development Status

### Completed
- [x] Flutter Windows build setup
- [x] Real-time price display and WebSocket streaming
- [x] Candlestick chart (OHLC)
- [x] Strategy selection (ALGO/AI/Manual)
- [x] Bot control buttons (START/STOP)
- [x] Risk settings (SL/TP/quantity)
- [x] Paper trading with entry/exit and realized PnL
- [x] Trade history and performance metrics
- [x] Multi-symbol selection

### Roadmap
See [TODO.md](TODO.md) for current priorities and upcoming work.

## Building and Running

### Windows
```bash
flutter build windows
flutter run -d windows
```

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

```
lib/
|- main.dart                    # App entry point
|- models/
|  |- kline.dart                # OHLCV candlestick data model
|  |- position.dart             # Open position model
|  |- risk_settings.dart        # Risk configuration model
|  |- trade.dart                # Trade record model
|- providers/
|  |- trading_provider.dart     # Riverpod state management
|- screens/
|  |- dashboard_screen.dart     # Main trading dashboard
|  |- settings_screen.dart      # Configuration screen
|  |- gallery_screen.dart       # App gallery
|- services/
|  |- binance_api.dart          # Binance REST API client
|  |- binance_ws.dart           # Binance WebSocket connection
|  |- settings_service.dart     # Settings storage
|- trading/
|  |- strategy.dart             # Strategy interface
|  |- ai_strategy.dart          # AI-powered strategy
|  |- algo_strategy.dart        # Algorithmic strategy
|  |- manual_strategy.dart      # Manual strategy placeholder
|  |- trading_engine.dart       # Main execution engine
|- widgets/
|  |- dashboard/
|  |  |- mode_selector.dart       # Strategy mode toggle
|  |  |- open_position_card.dart  # Open position summary
|  |  |- price_chart.dart         # Candlestick chart visualization
|  |  |- performance_metrics.dart # Realized PnL metrics
|  |  |- trade_history.dart       # Trade history list
|  |- gallery/
|  |  |- screenshot_carousel.dart # App evolution carousel
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

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
