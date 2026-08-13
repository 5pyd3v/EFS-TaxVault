import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/reports_repository.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';

/// Line-level fields for the "Invoices" export sheet — a different shape
/// than [InvoiceSummary] (Vault's list row), so it's fetched independently
/// here rather than stretching that model to cover both uses.
class _InvoiceExportRow {
  const _InvoiceExportRow({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.supplierName,
    required this.documentType,
    required this.subtotal,
    required this.discount,
    required this.taxableAmount,
    required this.salesTax,
    required this.otherTaxes,
    required this.totalAmount,
    required this.verificationStatus,
  });

  final String invoiceNumber;
  final DateTime? invoiceDate;
  final String supplierName;
  final String documentType;
  final double subtotal;
  final double discount;
  final double taxableAmount;
  final double salesTax;
  final double otherTaxes;
  final double totalAmount;
  final String verificationStatus;

  factory _InvoiceExportRow.fromMap(Map<String, dynamic> map) {
    final supplier = map['suppliers'] as Map<String, dynamic>?;
    final dateString = map['invoice_date'] as String?;
    return _InvoiceExportRow(
      invoiceNumber: map['invoice_number'] as String? ?? '',
      invoiceDate: dateString != null ? DateTime.tryParse(dateString) : null,
      supplierName: supplier?['name'] as String? ?? 'Unknown supplier',
      documentType: map['document_type'] as String? ?? 'invoice',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      taxableAmount: (map['taxable_amount'] as num?)?.toDouble() ?? 0,
      salesTax: (map['sales_tax'] as num?)?.toDouble() ?? 0,
      otherTaxes: (map['other_taxes'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      verificationStatus:
          map['verification_status'] as String? ?? 'needs_review',
    );
  }
}

/// Builds a clean, formatted .xlsx workbook straight from live Supabase
/// data — one row per invoice (everything a user needs for filing/
/// bookkeeping), plus monthly and by-supplier summary sheets mirroring
/// what Reports shows on screen. Nothing is cached; every export reflects
/// the current database state.
class ReportExportService {
  ReportExportService(this._client, this._reportsRepository);

  final SupabaseClient _client;
  final ReportsRepository _reportsRepository;

  static final _brand = ExcelColor.fromHexString('FF1D5FE0');
  static final _altRow = ExcelColor.fromHexString('FFF1F3F6');
  static final _white = ExcelColor.fromHexString('FFFFFFFF');
  static final _dateFormat = DateFormat('d MMM yyyy');

  Future<Result<File>> exportToExcel(String organizationId) async {
    try {
      final invoices = await _fetchAllInvoices(organizationId);

      final periodsResult = await _reportsRepository.getPeriodSummaries(
        organizationId: organizationId,
        periodType: PeriodType.monthly,
      );
      final suppliersResult = await _reportsRepository.getSupplierSummaries(
        organizationId: organizationId,
      );
      final periods = periodsResult.fold(
        (p) => p,
        (_) => const <PeriodSummary>[],
      );
      final suppliers = suppliersResult.fold(
        (s) => s,
        (_) => const <SupplierSummary>[],
      );

      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      _buildInvoicesSheet(excel, invoices);
      _buildPeriodSheet(excel, periods);
      _buildSupplierSheet(excel, suppliers);

      // Drop the blank default sheet Excel.createExcel() starts with, now
      // that the real sheets exist — leaving it would show an empty extra
      // tab in the workbook.
      if (defaultSheet != null &&
          defaultSheet != 'Invoices' &&
          excel.sheets.containsKey(defaultSheet)) {
        excel.delete(defaultSheet);
      }

      final bytes = excel.encode();
      if (bytes == null) return const Result.err(UnknownFailure());

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/EFS_TaxVault_Report_$stamp.xlsx');
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

  Future<List<_InvoiceExportRow>> _fetchAllInvoices(
    String organizationId,
  ) async {
    const pageSize = 500;
    var offset = 0;
    final all = <_InvoiceExportRow>[];
    while (true) {
      final rows = await _client
          .from('invoices')
          .select(
            'invoice_number, invoice_date, subtotal, discount, taxable_amount, '
            'sales_tax, other_taxes, total_amount, verification_status, document_type, suppliers(name)',
          )
          .eq('organization_id', organizationId)
          .order('invoice_date', ascending: false)
          .range(offset, offset + pageSize - 1);
      final page = (rows as List).cast<Map<String, dynamic>>();
      all.addAll(page.map(_InvoiceExportRow.fromMap));
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  void _buildInvoicesSheet(Excel excel, List<_InvoiceExportRow> invoices) {
    final sheet = excel['Invoices'];
    _writeHeaderRow(sheet, const [
      'Invoice #',
      'Date',
      'Supplier',
      'Type',
      'Subtotal',
      'Discount',
      'Taxable Amount',
      'Sales Tax',
      'Other Taxes',
      'Total Amount',
      'Status',
    ]);

    var row = 1;
    var subtotalSum = 0.0;
    var discountSum = 0.0;
    var taxableSum = 0.0;
    var salesTaxSum = 0.0;
    var otherTaxSum = 0.0;
    var totalSum = 0.0;

    for (final invoice in invoices) {
      _writeRow(sheet, row, [
        TextCellValue(
          invoice.invoiceNumber.isEmpty ? '—' : invoice.invoiceNumber,
        ),
        invoice.invoiceDate != null
            ? TextCellValue(_dateFormat.format(invoice.invoiceDate!))
            : TextCellValue('—'),
        TextCellValue(invoice.supplierName),
        TextCellValue(_titleCase(invoice.documentType)),
        DoubleCellValue(invoice.subtotal),
        DoubleCellValue(invoice.discount),
        DoubleCellValue(invoice.taxableAmount),
        DoubleCellValue(invoice.salesTax),
        DoubleCellValue(invoice.otherTaxes),
        DoubleCellValue(invoice.totalAmount),
        TextCellValue(_titleCase(invoice.verificationStatus)),
      ], alternate: row.isEven);

      subtotalSum += invoice.subtotal;
      discountSum += invoice.discount;
      taxableSum += invoice.taxableAmount;
      salesTaxSum += invoice.salesTax;
      otherTaxSum += invoice.otherTaxes;
      totalSum += invoice.totalAmount;
      row++;
    }

    _writeRow(
      sheet,
      row,
      [
        TextCellValue('Total (${invoices.length} invoices)'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(subtotalSum),
        DoubleCellValue(discountSum),
        DoubleCellValue(taxableSum),
        DoubleCellValue(salesTaxSum),
        DoubleCellValue(otherTaxSum),
        DoubleCellValue(totalSum),
        TextCellValue(''),
      ],
      style: CellStyle(
        bold: true,
        topBorder: Border(borderStyle: BorderStyle.Thin),
      ),
    );

    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 28);
    sheet.setColumnWidth(3, 12);
    for (var c = 4; c <= 9; c++) {
      sheet.setColumnWidth(c, 15);
    }
    sheet.setColumnWidth(10, 14);
  }

  void _buildPeriodSheet(Excel excel, List<PeriodSummary> periods) {
    final sheet = excel['By Month'];
    _writeHeaderRow(sheet, const [
      'Month',
      'Invoices',
      'Purchases Total',
      'Tax Total',
      'Needs Review',
    ]);

    final sorted = [...periods]
      ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      _writeRow(sheet, i + 1, [
        TextCellValue(DateFormat('MMMM yyyy').format(p.periodStart)),
        IntCellValue(p.invoiceCount),
        DoubleCellValue(p.purchasesTotal),
        DoubleCellValue(p.taxTotal),
        IntCellValue(p.needsReviewCount),
      ], alternate: i.isOdd);
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
  }

  void _buildSupplierSheet(Excel excel, List<SupplierSummary> suppliers) {
    final sheet = excel['By Supplier'];
    _writeHeaderRow(sheet, const [
      'Supplier',
      'Invoices',
      'Purchases Total',
      'Tax Total',
      'Needs Review',
      'Last Invoice',
    ]);

    final sorted = [...suppliers]
      ..sort((a, b) => b.purchasesTotal.compareTo(a.purchasesTotal));
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      _writeRow(sheet, i + 1, [
        TextCellValue(s.supplierName),
        IntCellValue(s.invoiceCount),
        DoubleCellValue(s.purchasesTotal),
        DoubleCellValue(s.taxTotal),
        IntCellValue(s.needsReviewCount),
        s.lastInvoiceDate != null
            ? TextCellValue(_dateFormat.format(s.lastInvoiceDate!))
            : TextCellValue('—'),
      ], alternate: i.isOdd);
    }

    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);
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

  String _titleCase(String value) {
    final withSpaces = value.replaceAll('_', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
