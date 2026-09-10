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

    // Calculate category breakdown
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};
    double categoryExpenseTotal = 0;

    for (var t in transactions) {
      if (t.isExpense) {
        categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
        categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
        categoryExpenseTotal += t.amount;
      }
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) => _buildPageHeader(startDate, endDate),
        footer: (context) => _buildPageFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildSummaryCards(totalIncome, totalExpense),
          pw.SizedBox(height: 16),
          if (sortedCategories.isNotEmpty) ...[
            _buildSectionTitle('RINGKASAN PER KATEGORI PENGELUARAN'),
            pw.SizedBox(height: 8),
            _buildCategoryBreakdownTable(sortedCategories, categoryCounts, categoryExpenseTotal),
            pw.SizedBox(height: 16),
          ],
          _buildSectionTitle('RIWAYAT TRANSAKSI (${transactions.length} Item)'),
          pw.SizedBox(height: 8),
          _buildTransactionTable(transactions),
          pw.SizedBox(height: 16),
          _buildPrintTimestamp(),
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
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    // Metadata & Summary Header in CSV
    rows.add(['LAPORAN KEUANGAN MYDUITGWEH']);
    rows.add(['Periode', '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}']);
    rows.add(['Tanggal Ekspor', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())]);
    rows.add([]);
    rows.add(['RINGKASAN KEUANGAN']);
    rows.add(['Total Pemasukan', totalIncome]);
    rows.add(['Total Pengeluaran', totalExpense]);
    rows.add(['Arus Kas Bersih', totalIncome - totalExpense]);
    rows.add(['Total Transaksi', transactions.length]);
    rows.add([]);
    rows.add(['DETAIL TRANSAKSI']);

    // Table Header
    rows.add([
      'No',
      'Tanggal',
      'Waktu',
      'Tipe',
      'Kategori',
      'Catatan',
      'Nominal (Rp)',
    ]);

    // Data Rows
    int index = 1;
    for (var t in transactions) {
      rows.add([
        index++,
        dateFormat.format(t.date),
        timeFormat.format(t.date),
        t.isIncome ? 'Pemasukan' : 'Pengeluaran',
        t.category,
        t.note.isEmpty ? '-' : t.note,
        t.isIncome ? t.amount : -t.amount,
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

  static pw.Widget _buildPageHeader(DateTime start, DateTime end) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN KEUANGAN',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'MyDuitGweh | Smart Financial Tracker',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'PERIODE LAPORAN',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  '${dateFormat.format(start)} - ${dateFormat.format(end)}',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5, color: PdfColors.black),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Container(width: 20, height: 1.2, color: PdfColors.black),
      ],
    );
  }

  static pw.Widget _buildSummaryCards(double income, double expense) {
    final net = income - expense;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildMonochromeKpiItem('Total Pemasukan', CurrencyFormatter.formatCurrency(income)),
          pw.Container(width: 0.5, height: 24, color: PdfColors.grey300),
          _buildMonochromeKpiItem('Total Pengeluaran', CurrencyFormatter.formatCurrency(expense)),
          pw.Container(width: 0.5, height: 24, color: PdfColors.grey300),
          _buildMonochromeKpiItem(
            'Arus Kas Bersih',
            '${net >= 0 ? '+' : ''}${CurrencyFormatter.formatCurrency(net)}',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMonochromeKpiItem(String title, String amount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          amount,
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCategoryBreakdownTable(
    List<MapEntry<String, double>> categoryTotals,
    Map<String, int> categoryCounts,
    double totalExpense,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['KATEGORI', 'FREKUENSI', 'TOTAL NOMINAL', 'PORSI (%)'],
      data: categoryTotals.map((e) {
        final percentage =
            totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(1) : '0';
        return [
          e.key,
          '${categoryCounts[e.key] ?? 0}x',
          CurrencyFormatter.formatCurrency(e.value),
          '$percentage%',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        fontSize: 8,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      cellHeight: 20,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 8),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
    );
  }

  static pw.Widget _buildTransactionTable(List<TransactionModel> txns) {
    final dateFormat = DateFormat('dd/MM/yy');

    return pw.TableHelper.fromTextArray(
      headers: ['NO', 'TANGGAL', 'KATEGORI', 'CATATAN', 'JENIS', 'NOMINAL'],
      data: txns.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final t = entry.value;
        final isInc = t.isIncome;
        final prefix = isInc ? '+' : '-';
        return [
          '$idx',
          dateFormat.format(t.date),
          t.category,
          t.note.isEmpty ? '-' : t.note,
          isInc ? 'Pemasukan' : 'Pengeluaran',
          '$prefix${CurrencyFormatter.formatCurrency(t.amount)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        fontSize: 8,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      cellHeight: 22,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 8),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
    );
  }

  static pw.Widget _buildPrintTimestamp() {
    final nowStr = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Dicetak otomatis pada: $nowStr WIB',
        style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  static pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MyDuitGweh | Laporan Resmi Keuangan',
            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}


