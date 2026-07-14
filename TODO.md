# TODO

Last updated: 2026-07-14

## Priority Legend
- `P0` Critical reliability/safety and release readiness.
- `P1` High-impact feature work for near-term roadmap.
- `P2` Important quality, scalability, and UX improvements.
- `P3` Nice-to-have enhancements.

## Now (Active Sprint)
- [ ] `P1` AI confidence backtesting and scorecards.
  - Persist AI confidence vs realized outcome metrics per symbol and regime.
  - Add dashboard scorecard view for confidence calibration (hit rate, avg R, drawdown impact).
  - Add regression tests around confidence scoring math.
- [ ] `P1` Partial take-profit and staged exits.
  - Add staged TP model shared by AI and ALGO plans.
  - Update execution flow to support laddered exits and partial close accounting.
  - Validate trade-history and CSV export include staged fills correctly.

## Next (Planned)
- [ ] `P1` Explicit Futures margin-mode preflight and control.
  - Show isolated vs cross margin per symbol before enabling execution.
  - Add an opt-in isolated-margin action with exchange-state and open-order checks; never change account risk silently.
  - Add integration tests for already-isolated, already-cross, and exchange-rejection states.
- [ ] `P1` Multi-exchange abstraction (Binance + Coinbase).
  - Introduce exchange adapter interfaces and shared order/account models.
  - Keep Binance as default, then add Coinbase read-only and trade flow parity.
  - Add provider/service tests for exchange selection and fallback behavior.
- [ ] `P2` Logging and secret-redaction hardening.
  - Replace direct prints in exchange/engine flows with structured logging helpers.
  - Ensure API keys/signatures are always redacted.
  - Add tests for redaction paths in request/response logging.
- [ ] `P2` Engine modularization.
  - Split `trading_engine.dart` responsibilities into orchestration, execution, protections, and sync services.
  - Preserve existing behavior with parity tests before/after extraction.
- [ ] `P2` Settings portability and default path cleanup.
  - Remove machine-specific default automation path assumptions.
  - Add cross-platform defaults and validation messages.
- [ ] `P2` Error-observability improvements.
  - Replace broad silent catches with typed failures and user-safe status feedback.
  - Add actionable diagnostics in strategy console for recoverable errors.

## Later
- [ ] `P3` Expanded gallery timeline with per-release screenshots for each tagged version.
- [ ] `P3` Architecture docs for provider graph, strategy lifecycle, and execution flow.
- [ ] `P3` CI expansion with web smoke test against production build artifacts.

## Done
- [x] Public web safety mode blocks real-money mutations, refuses and purges production credentials, and labels Demo, Paper/Monitor, and Real-Money states explicitly.
- [x] Desktop-only automation import and CSV export are disabled in browser builds.
- [x] Installation-scoped order ownership, Windows single-instance enforcement, ambiguous-entry quarantine, and serialized STOP/submission handling.
- [x] Stop-first protection verification with emergency flattening when confirmed stop coverage cannot be established.
- [x] Futures-authoritative credential verification with optional Spot read-only diagnostics.
- [x] Recorded-exit-fee-adjusted analytics plus honestly labeled gross close-price backtests.
- [x] Pages deployment now requires passing analysis and tests before build/deploy.
- [x] ARIAUSDT-first core market set with required TRIAUSDT, SIRENUSDT, and BTCUSDT while retaining TRUUSDT.
- [x] One-click guarded Long/Short entry with Smart Maker, market option, timed arming, and gross `$5 TP / $5 SL` preset.
- [x] Binance Algo Order migration for conditional TP/SL plus separate normal/algo reconciliation.
- [x] User-data fill events, bot-order ownership, symbol handoff disarming, and ambiguous-order response reconciliation.
- [x] AI finite-number defenses and a 60% minimum confidence floor for automatic execution.
- [x] Dedicated order-book execution card with spread, imbalance, sweep slippage, and AI execution hint visibility.
- [x] Live liquidation price display in current position and portfolio snapshots from Binance position sync.
- [x] Added `TRUUSDT` to the required/default symbol list so it always stays selectable.
- [x] AI settings now let the trader force long-only, short-only, or auto direction plus a fixed leverage and max USDT margin budget.
- [x] Current position snapshot embedded in portfolio analytics with live side, entry, last price, size, exposure, and unrealized PnL.
- [x] Per-symbol portfolio contribution and exposure breakdown with a bounded inner scroll inside the portfolio analytics card.
- [x] Portfolio analytics dashboard with wallet, free margin, tracked fills, realized account performance, and AI posture context.
- [x] AI-to-manual ticket prefills so the latest plan can be reviewed and executed faster.
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
