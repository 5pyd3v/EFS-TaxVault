import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';

/// Builds a clean, formatted .xlsx workbook of bank/wallet transaction
/// receipts — same approach as `report_export_service.dart` (styled header
/// row, zebra rows, a totals row), one sheet, split totals by debit/credit
/// since those aren't meaningfully summed together.
class BankTransactionExportService {
  BankTransactionExportService(this._client);

  final SupabaseClient _client;

  static final _brand = ExcelColor.fromHexString('FF1D5FE0');
  static final _altRow = ExcelColor.fromHexString('FFF1F3F6');
  static final _white = ExcelColor.fromHexString('FFFFFFFF');
  static final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

  Future<Result<File>> exportToExcel(String organizationId) async {
    try {
      final rows = await _fetchAllTransactions(organizationId);

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      _buildSheet(excel, rows);

      if (defaultSheet != null &&
          defaultSheet != 'Bank Transactions' &&
          excel.sheets.containsKey(defaultSheet)) {
        excel.delete(defaultSheet);
      }

      final bytes = excel.encode();
      if (bytes == null) return const Result.err(UnknownFailure());

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final file = File(
        '${dir.path}/EFS_TaxVault_Bank_Transactions_$stamp.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      return Result.ok(file);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllTransactions(
    String organizationId,
  ) async {
    const pageSize = 500;
    var offset = 0;
    final all = <Map<String, dynamic>>[];
    while (true) {
      final rows = await _client
          .from('bank_transactions')
          .select(
            'direction, amount, currency, transaction_date, counterparty_name, '
            'counterparty_account, bank_name, reference_number, status, verification_status',
          )
          .eq('organization_id', organizationId)
          .order('transaction_date', ascending: false)
          .range(offset, offset + pageSize - 1);
      final page = (rows as List).cast<Map<String, dynamic>>();
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  void _buildSheet(Excel excel, List<Map<String, dynamic>> rows) {
    final sheet = excel['Bank Transactions'];
    _writeHeaderRow(sheet, const [
      'Date',
      'Direction',
      'Amount',
      'Counterparty',
      'Account',
      'Bank',
      'Reference',
      'Status',
    ]);

    var rowIndex = 1;
    var debitSum = 0.0;
    var creditSum = 0.0;

    for (final row in rows) {
      final direction = row['direction'] as String? ?? 'debit';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final dateString = row['transaction_date'] as String?;
      final date = dateString != null ? DateTime.tryParse(dateString) : null;

      _writeRow(sheet, rowIndex, [
        date != null
            ? TextCellValue(_dateFormat.format(date))
            : TextCellValue('—'),
        TextCellValue(direction == 'credit' ? 'Credit' : 'Debit'),
        DoubleCellValue(amount),
        TextCellValue(
          (row['counterparty_name'] as String?)?.isEmpty ?? true
              ? '—'
              : row['counterparty_name'] as String,
        ),
        TextCellValue((row['counterparty_account'] as String?) ?? ''),
        TextCellValue((row['bank_name'] as String?) ?? ''),
        TextCellValue((row['reference_number'] as String?) ?? ''),
        TextCellValue((row['status'] as String?) ?? ''),
      ], alternate: rowIndex.isEven);

      if (direction == 'credit') {
        creditSum += amount;
      } else {
        debitSum += amount;
      }
      rowIndex++;
    }

    _writeRow(
      sheet,
      rowIndex,
      [
        TextCellValue('Total (${rows.length} transactions)'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Debit: ${debitSum.toStringAsFixed(2)}'),
        TextCellValue('Credit: ${creditSum.toStringAsFixed(2)}'),
      ],
      style: CellStyle(
        bold: true,
        topBorder: Border(borderStyle: BorderStyle.Thin),
      ),
    );

    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 24);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 20);
    sheet.setColumnWidth(7, 16);
  }

  void _writeHeaderRow(Sheet sheet, List<String> headers) {
    final style = CellStyle(
      bold: true,
      fontColorHex: _white,
      backgroundColorHex: _brand,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (var c = 0; c < headers.length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        TextCellValue(headers[c]),
        cellStyle: style,
      );
    }
    sheet.setRowHeight(0, 22);
  }

  void _writeRow(
    Sheet sheet,
    int rowIndex,
    List<CellValue?> values, {
    bool alternate = false,
    CellStyle? style,
  }) {
    final rowStyle =
        style ?? CellStyle(backgroundColorHex: alternate ? _altRow : _white);
    for (var c = 0; c < values.length; c++) {
      final value = values[c];
      if (value == null) continue;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        value,
        cellStyle: rowStyle,
      );
    }
  }
}
