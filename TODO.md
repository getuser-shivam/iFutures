# TODO

Last updated: 2026-04-02

## Now
- [ ] Portfolio analytics dashboard.
- [ ] AI-to-manual ticket prefills so the latest plan can be reviewed and executed faster.

## Next
- [ ] Multi-exchange support (Binance + Coinbase).
- [ ] AI confidence backtesting and scorecards.
- [ ] Add a public web dashboard mode with clearer browser-only safety messaging.

## Done
- [x] GitHub Pages workflow for free public Flutter Web hosting on `getuser-shivam.github.io/iFutures`.
- [x] AI decision feedback memory with outcome review and confidence calibration.
- [x] Order-book trend history so AI can compare the last several minutes of spread, imbalance, and sweep cost.
- [x] Binance and AI verification workflow with `Live Connection` / `Demo Connection`, direct apply/save actions, and runtime status labels.
- [x] Trade history card now uses a bounded inner scroll and falls back to tracked-account fills when the selected symbol has no recent Binance trades.
- [x] Binance order-book execution context with spread, imbalance, and market-impact estimates for AI order-type decisions.
- [x] Multi-timeframe AI context with 1m / 5m / 15m alignment in the strategy console and AI prompt.
- [x] AI context analyzer with regime detection, portfolio/trade-review posture, and dynamic AI size scaling.
- [x] Protection engine with cooldown, loss-streak locks, drawdown locks, and manual-override-safe auto-entry blocking.
- [x] Strategy console for AI/ALGO decisions with auto-selected order types.
- [x] Strategy terminal with persistent AI mode and live activity logs.
- [x] Strategy parameter tuning UI and presets.
- [x] Market analysis card with BTC, ETH, BNB, SOL, and crypto news.
- [x] Add a trade export option (CSV) for analysis.
- [x] Backtesting engine using historical klines.
- [x] GitHub Actions CI for `flutter analyze`, `flutter test`, and a Windows build smoke check.
- [x] WebSocket auto-reconnect with exponential backoff and reconnect status in the UI.
- [x] Shared toast helper for transient in-app notifications.
- [x] Price alerts with toast notifications and rearmable dashboard cards.
- [x] Daily performance summary card with PnL, win rate, and drawdown.
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
