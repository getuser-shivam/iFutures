import 'dart:io';

import 'package:intl/intl.dart';

import '../models/trade.dart';

class TradeCsvExportService {
  final Directory Function()? _baseDirectoryResolver;

  TradeCsvExportService({Directory Function()? baseDirectoryResolver})
      : _baseDirectoryResolver = baseDirectoryResolver;

  Future<File> exportTrades({
    required String symbol,
    required List<Trade> trades,
  }) async {
    final exportDirectory = await _resolveExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeSymbol = _sanitizeFileComponent(symbol);
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}trade_history_${safeSymbol}_$timestamp.csv',
    );

    final orderedTrades = List<Trade>.from(trades)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    await file.writeAsString(_buildCsv(orderedTrades), flush: true);
    return file;
  }

  Future<Directory> _resolveExportDirectory() async {
    final baseDirectory = _baseDirectoryResolver?.call() ?? _defaultBaseDirectory();
    final exportDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}iFutures${Platform.pathSeparator}exports',
    );
    await exportDirectory.create(recursive: true);
    return exportDirectory;
  }

  Directory _defaultBaseDirectory() {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home${Platform.pathSeparator}Documents',
      );
    }

    return Directory.current;
  }

  String _buildCsv(List<Trade> trades) {
    final lines = <String>[
      'timestamp,symbol,side,kind,price,quantity,status,strategy,realizedPnl,fee,reason,orderId',
      ...trades.map(
        (trade) => [
          _csvField(trade.timestamp.toIso8601String()),
          _csvField(trade.symbol),
          _csvField(trade.side),
          _csvField(trade.kind),
          _csvField(trade.price),
          _csvField(trade.quantity),
          _csvField(trade.status),
          _csvField(trade.strategy),
          _csvField(trade.realizedPnl),
          _csvField(trade.fee),
          _csvField(trade.reason),
          _csvField(trade.orderId),
        ].join(','),
      ),
    ];

    return lines.join('\n');
  }

  String _csvField(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _sanitizeFileComponent(String value) {
    return value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
