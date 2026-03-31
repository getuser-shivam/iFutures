enum BinanceAccountState { notConfigured, checking, active, attentionRequired }

class BinanceAccountStatus {
  final BinanceAccountState state;
  final bool isTestnet;
  final DateTime? lastSyncedAt;
  final String? message;

  const BinanceAccountStatus({
    required this.state,
    required this.isTestnet,
    this.lastSyncedAt,
    this.message,
  });

  const BinanceAccountStatus.notConfigured({
    this.isTestnet = true,
    this.message,
  }) : state = BinanceAccountState.notConfigured,
       lastSyncedAt = null;

  const BinanceAccountStatus.checking({required this.isTestnet, this.message})
    : state = BinanceAccountState.checking,
      lastSyncedAt = null;

  const BinanceAccountStatus.active({
    required this.isTestnet,
    required this.lastSyncedAt,
    this.message,
  }) : state = BinanceAccountState.active;

  const BinanceAccountStatus.attentionRequired({
    required this.isTestnet,
    this.lastSyncedAt,
    this.message,
  }) : state = BinanceAccountState.attentionRequired;
}
