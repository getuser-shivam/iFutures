import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trade.dart';

class TradeHistoryService {
  static const _keyPrefix = 'trade_history_';
  static const _maxTrades = 500;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<Trade>> loadTrades(String symbol) async {
    await init();
    final raw = _prefs?.getString(_keyPrefix + symbol);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Trade.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTrades(String symbol, List<Trade> trades) async {
    await init();
    final trimmed = trades.length > _maxTrades
        ? trades.sublist(trades.length - _maxTrades)
        : trades;
    final payload = jsonEncode(trimmed.map((t) => t.toJson()).toList());
    await _prefs?.setString(_keyPrefix + symbol, payload);
  }

  Future<void> clearTrades(String symbol) async {
    await init();
    await _prefs?.remove(_keyPrefix + symbol);
  }
}
