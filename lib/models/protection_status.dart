enum ProtectionState { ready, cooldown, locked }

class ProtectionStatus {
  final ProtectionState state;
  final DateTime? until;
  final String? message;

  const ProtectionStatus({required this.state, this.until, this.message});

  const ProtectionStatus.ready({this.message})
    : state = ProtectionState.ready,
      until = null;

  const ProtectionStatus.cooldown({required this.until, this.message})
    : state = ProtectionState.cooldown;

  const ProtectionStatus.locked({required this.until, this.message})
    : state = ProtectionState.locked;

  bool get isBlocking => state != ProtectionState.ready;
}
