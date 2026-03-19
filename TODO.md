# TODO

Last updated: 2026-03-19

## Now
- [ ] Add GitHub Actions CI for `flutter analyze`, `flutter test`, and a Windows build smoke check.
- [ ] Add WebSocket auto-reconnect with exponential backoff and surface status in the UI.

## Next
- [ ] Add a lightweight price alert system with toast notifications.
- [ ] Add a daily performance summary card (PnL, win rate, drawdown).
- [ ] Add a trade export option (CSV) for analysis.

## Later
- [ ] Backtesting engine using historical klines.
- [ ] Strategy parameter tuning UI and presets.
- [ ] Multi-exchange support (Binance + Coinbase).

## Done
- [x] Paper trading with stop-loss / take-profit and realized PnL metrics.
- [x] Manual trading controls with long/short/close actions.
- [x] Candlestick chart (OHLC) in the dashboard.
- [x] Multi-symbol selection in the app bar.
- [x] Open position card with unrealized PnL and SL/TP preview.
- [x] Unified dark theme, typography system, and dashboard card styling.
- [x] Shared `AppPanel` component moved to `lib/widgets/common`.
- [x] Settings and gallery screens updated to match the new design system.
- [x] Compact risk summary card (SL/TP/qty) for quick visibility.
- [x] Connection health badge and latency indicator for the market stream.
- [x] Manual controls visible in all modes for quick override.
- [x] Strategy signal indicator for AI/ALGO decisions.
- [x] Extract shared `ActionButton` and `StatusPill` widgets into common components.
- [x] Persist last selected symbol across restarts.
- [x] Manual controls work without auto-start (auto mode optional).
- [x] Performance header shows NO DATA when no trades exist.
- [x] Make the symbol list configurable in Settings.
- [x] Persist trade history to disk and reload on startup.
- [x] Clear trade history action from the dashboard.
