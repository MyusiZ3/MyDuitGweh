import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintReport({
    required List<TransactionModel> transactions,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> selectedCategories,
    required double totalIncome,
    required double totalExpense,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(startDate, endDate),
          pw.SizedBox(height: 20),
          _buildSummary(totalIncome, totalExpense),
          pw.SizedBox(height: 20),
          _buildTransactionTable(transactions),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Dicetak pada: ${dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Keuangan_${DateFormat('yyyyMMdd').format(startDate)}.pdf',
    );
  }

  static Future<void> generateAndExportCSV({
    required List<TransactionModel> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add(['Tanggal', 'Kategori', 'Catatan', 'Tipe', 'Jumlah']);

    // Data
    for (var t in transactions) {
      rows.add([
        DateFormat('dd/MM/yyyy HH:mm').format(t.date),
        t.category,
        t.note,
        t.isIncome ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/Laporan_Keuangan_${DateFormat('yyyyMMdd').format(startDate)}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename:
          'Laporan_Keuangan_${DateFormat('yyyyMMdd').format(startDate)}.csv',
    );
  }

  static pw.Widget _buildHeader(DateTime start, DateTime end) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('LAPORAN KEUANGAN',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('MyDuitGweh - Pencatatan Keuangan Pintar',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 2, color: PdfColors.blueGrey),
        pw.SizedBox(height: 12),
        pw.Text(
            'Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildSummary(double income, double expense) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Pemasukan', income, PdfColors.green700),
          _buildSummaryItem('Total Pengeluaran', expense, PdfColors.red700),
          _buildSummaryItem('Selisih', income - expense, PdfColors.blue700),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
      String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(
          CurrencyFormatter.formatCurrency(amount),
          style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(List<TransactionModel> txns) {
    final headers = ['Tanggal', 'Kategori', 'Catatan', 'Jumlah'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: txns
          .map((t) => [
                DateFormat('dd/MM/yy').format(t.date),
                t.category,
                t.note.isEmpty ? '-' : t.note,
                '${t.isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(t.amount)}',
              ])
          .toList(),
      headerStyle:
          pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 10),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
    );
  }
}
