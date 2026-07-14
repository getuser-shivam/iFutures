class PortfolioSymbolBreakdown {
  final String symbol;
  final int closedTrades;
  final int winningTrades;
  final double realizedPnl;
  final double totalFees;
  final DateTime? latestActivityAt;
  final double? liveExposure;
  final bool isSelectedSymbol;

  const PortfolioSymbolBreakdown({
    required this.symbol,
    required this.closedTrades,
    required this.winningTrades,
    required this.realizedPnl,
    required this.totalFees,
    required this.latestActivityAt,
    required this.liveExposure,
    required this.isSelectedSymbol,
  });

  double get winRate =>
      closedTrades == 0 ? 0 : (winningTrades / closedTrades) * 100;

  double get netPnl => realizedPnl - totalFees;

  bool get hasLiveExposure => liveExposure != null && liveExposure! > 0;
}
