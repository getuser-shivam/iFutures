# TODO

Last updated: 2026-03-16

## Now
- [ ] Add WebSocket auto-reconnect with exponential backoff and surface status in the UI.
- [ ] Persist trade history and risk settings to disk and reload on startup.
- [ ] Remember last selected symbol and make the symbol list configurable in Settings.

## Next
- [ ] Add a lightweight price alert system with toast notifications.
- [ ] Add a daily performance summary card (PnL, win rate, drawdown).
- [ ] Add a trade export option (CSV) for analysis.
- [ ] Add a connection health badge and latency indicator for the market stream.

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
