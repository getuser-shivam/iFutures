enum AiServiceState { notConfigured, checking, active, attentionRequired }

class AiServiceStatus {
  final AiServiceState state;
  final String providerLabel;
  final DateTime? checkedAt;
  final String? message;

  const AiServiceStatus({
    required this.state,
    required this.providerLabel,
    this.checkedAt,
    this.message,
  });

  const AiServiceStatus.notConfigured({
    required this.providerLabel,
    this.message,
  }) : state = AiServiceState.notConfigured,
       checkedAt = null;

  const AiServiceStatus.checking({required this.providerLabel, this.message})
    : state = AiServiceState.checking,
      checkedAt = null;

  const AiServiceStatus.active({
    required this.providerLabel,
    required this.checkedAt,
    this.message,
  }) : state = AiServiceState.active;

  const AiServiceStatus.attentionRequired({
    required this.providerLabel,
    this.checkedAt,
    this.message,
  }) : state = AiServiceState.attentionRequired;
}
