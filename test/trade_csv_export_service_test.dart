import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/trade_csv_export_service.dart';

void main() {
  test('exports trades to a CSV file with escaped fields', () async {
    final tempDir = await Directory.systemTemp.createTemp('ifutures_csv_export_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final service = TradeCsvExportService(baseDirectoryResolver: () => tempDir);
    final trades = [
      Trade(
        symbol: 'GALAUSDT',
        side: 'BUY',
        price: 0.00335,
        quantity: 1000.0,
        timestamp: DateTime(2026, 3, 19, 9, 15),
        status: 'simulated',
        strategy: 'AI, "Model"',
        kind: 'ENTRY',
        reason: 'manual,override',
        orderId: 'ord-1',
        fee: 0.0012,
      ),
      Trade(
        symbol: 'GALAUSDT',
        side: 'SELL',
        price: 0.0035,
        quantity: 1000.0,
        timestamp: DateTime(2026, 3, 19, 10, 30),
        status: 'filled',
        strategy: 'Manual',
        kind: 'EXIT',
        realizedPnl: 0.15,
        reason: 'take_profit',
        orderId: 'ord-2',
      ),
    ];

    final exportedFile = await service.exportTrades(
      symbol: 'GALAUSDT',
      trades: trades,
    );

    expect(exportedFile.path, contains('iFutures'));
    expect(exportedFile.path, contains('exports'));
    expect(exportedFile.path, endsWith('.csv'));
    expect(exportedFile.existsSync(), isTrue);

    final exportDirectory = Directory('${tempDir.path}${Platform.pathSeparator}iFutures${Platform.pathSeparator}exports');
    expect(exportDirectory.existsSync(), isTrue);

    final lines = await exportedFile.readAsLines();
    expect(lines, hasLength(3));
    expect(
      lines.first,
      'timestamp,symbol,side,kind,price,quantity,status,strategy,realizedPnl,fee,reason,orderId',
    );
    expect(lines[1], contains('"AI, ""Model"""'));
    expect(lines[1], contains('"manual,override"'));
    expect(lines[2], contains('0.0035'));
    expect(lines[2], contains('0.15'));
  });
}
