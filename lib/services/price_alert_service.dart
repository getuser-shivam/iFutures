import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_alert.dart';

class PriceAlertService {
  static const _keyPrefix = 'price_alerts_';
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<PriceAlert>> loadAlerts(String symbol) async {
    await init();
    final raw = _prefs?.getString('$_keyPrefix$symbol');
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final alerts = decoded
          .whereType<Map<String, dynamic>>()
          .map(PriceAlert.fromJson)
          .toList();
      return _sortAlerts(alerts);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlerts(String symbol, List<PriceAlert> alerts) async {
    await init();
    final payload = jsonEncode(_sortAlerts(alerts).map((alert) => alert.toJson()).toList());
    await _prefs?.setString('$_keyPrefix$symbol', payload);
  }

  Future<PriceAlert> addAlert({
    required String symbol,
    required double threshold,
    required PriceAlertDirection direction,
  }) async {
    final alert = PriceAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      symbol: symbol,
      direction: direction,
      threshold: threshold,
      createdAt: DateTime.now(),
    );

    final alerts = await loadAlerts(symbol);
    alerts.add(alert);
    await saveAlerts(symbol, alerts);
    return alert;
  }

  Future<void> removeAlert(String symbol, String alertId) async {
    final alerts = await loadAlerts(symbol);
    alerts.removeWhere((alert) => alert.id == alertId);
    await saveAlerts(symbol, alerts);
  }

  Future<void> rearmAlert(String symbol, String alertId) async {
    final alerts = await loadAlerts(symbol);
    final updated = alerts
        .map((alert) => alert.id == alertId ? alert.rearm() : alert)
        .toList();
    await saveAlerts(symbol, updated);
  }

  Future<List<PriceAlert>> evaluateAlerts(String symbol, double price) async {
    final alerts = await loadAlerts(symbol);
    if (alerts.isEmpty) return [];

    final triggered = <PriceAlert>[];
    final updated = <PriceAlert>[];
    final now = DateTime.now();

    for (final alert in alerts) {
      if (alert.isActive && alert.matches(price)) {
        final fired = alert.trigger(now);
        triggered.add(fired);
        updated.add(fired);
      } else {
        updated.add(alert);
      }
    }

    if (triggered.isNotEmpty) {
      await saveAlerts(symbol, updated);
    }

    return triggered;
  }

  List<PriceAlert> _sortAlerts(List<PriceAlert> alerts) {
    final sorted = List<PriceAlert>.from(alerts);
    sorted.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }

      final createdComparison = b.createdAt.compareTo(a.createdAt);
      if (createdComparison != 0) return createdComparison;

      return b.id.compareTo(a.id);
    });
    return sorted;
  }
}
