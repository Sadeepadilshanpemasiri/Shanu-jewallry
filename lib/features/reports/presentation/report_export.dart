import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

import '../../inventory/presentation/inventory_format.dart';
import '../domain/business_report.dart';
import 'report_tables.dart';

const reportBasis =
    'Revenue uses the billed total of orders currently delivered, grouped by delivery date. '
    'Gross profit subtracts merchandise discounts and recorded product cost, excluding delivery charges and expenses. '
    'Order outcomes use the placement date and current status. Courier outcomes use the last dispatch date.';

String reportFilename(BusinessReport report) =>
    'jewellery-report-${reportDate(report.window.start)}-to-${reportDate(report.window.end)}';

Uint8List reportCsv(BusinessReport report) {
  String cell(Object value) {
    if (value is num) return value.toString();
    var text = value.toString();
    if (RegExp(r'^\s*[=+\-@]|^[\t\r\n]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final output = StringBuffer('\ufeff');
  void write(List<Object> columns) =>
      output.write('${columns.map(cell).join(',')}\r\n');
  write(['Jewellery Business Manager']);
  write([
    'From',
    reportDate(report.window.start),
    'To',
    reportDate(report.window.end),
    'Asia/Colombo',
  ]);
  write(['Orders placed', report.placed, 'Delivered orders', report.delivered]);
  write([
    'Delivered revenue (LKR)',
    report.revenue / 100,
    'Gross profit (LKR)',
    report.profit / 100,
  ]);
  write([
    'Cancellation rate',
    rateLabel(report.cancellationRate),
    'Return rate',
    rateLabel(report.returnRate),
  ]);
  write([reportBasis]);
  for (final table in reportTables(report, csv: true)) {
    write([]);
    write([table.title]);
    write(table.columns);
    for (final row in table.rows) {
      write(row);
    }
  }
  return Uint8List.fromList(utf8.encode(output.toString()));
}

Future<Uint8List> reportPdf(
  BusinessReport report, {
  pdf.ThemeData? fonts,
}) async {
  final document = pdf.Document(title: reportFilename(report));
  final theme =
      fonts ??
      pdf.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        fontFallback: [await PdfGoogleFonts.notoSansSinhalaRegular()],
      );
  document.addPage(
    pdf.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 300,
      theme: theme,
      margin: const pdf.EdgeInsets.all(28),
      footer: (context) => pdf.Align(
        alignment: pdf.Alignment.centerRight,
        child: pdf.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
      ),
      build: (_) => [
        pdf.Text(
          'Jewellery Business Manager',
          style: const pdf.TextStyle(fontSize: 21),
        ),
        pdf.Text(
          'Business report · ${reportDate(report.window.start)} to ${reportDate(report.window.end)} · Asia/Colombo',
        ),
        pdf.SizedBox(height: 12),
        pdf.Text('Placed: ${report.placed}   Delivered: ${report.delivered}'),
        pdf.Text(
          'Delivered revenue: ${lkr(report.revenue)}   Gross profit: ${lkr(report.profit)}',
        ),
        pdf.Text(
          'Cancellation rate: ${rateLabel(report.cancellationRate)}   Return rate: ${rateLabel(report.returnRate)}',
        ),
        pdf.SizedBox(height: 8),
        pdf.Text(reportBasis, style: const pdf.TextStyle(fontSize: 9)),
        for (final table in reportTables(report)) ...[
          pdf.SizedBox(height: 14),
          pdf.Text(table.title, style: const pdf.TextStyle(fontSize: 14)),
          if (table.rows.isEmpty)
            pdf.Text('No records for this period.')
          else
            pdf.TableHelper.fromTextArray(
              headers: table.columns,
              data: table.rows,
              cellStyle: const pdf.TextStyle(fontSize: 8),
              headerStyle: const pdf.TextStyle(fontSize: 8),
            ),
        ],
      ],
    ),
  );
  return document.save();
}
