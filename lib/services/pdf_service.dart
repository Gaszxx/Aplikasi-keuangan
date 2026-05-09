import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';

class PdfService {
  static final _formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  static Future<void> generateFinancialReport({
    required String period,
    required double totalIncome,
    required double totalExpense,
    required double netIncome,
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required List<DebtModel> debts,
  }) async {
    final pdf = pw.Document();

    // 1. HEADER & STYLE REKENING KORAN
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(period),
          pw.SizedBox(height: 20),
          
          // 2. RINGKASAN EKSEKUTIF
          _buildExecutiveSummary(totalIncome, totalExpense, netIncome),
          pw.SizedBox(height: 30),

          // 3. TABEL UNIT BISNIS
          _buildSectionTitle('PERFORMA UNIT BISNIS'),
          _buildUnitTable(incomes, expenses),
          pw.SizedBox(height: 30),

          // 4. BUKU BESAR (RIWAYAT TRANSAKSI)
          _buildSectionTitle('BUKU BESAR / RIWAYAT TRANSAKSI'),
          _buildTransactionTable(incomes, expenses),
          pw.SizedBox(height: 30),

          // 5. STATUS KEWAJIBAN (HUTANG)
          _buildSectionTitle('STATUS KEWAJIBAN & CICILAN'),
          _buildDebtTable(debts),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    // Langsung Print / Simpan
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Bidadari_ERP_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // --- KOMPONEN UI PDF ---

  static pw.Widget _buildHeader(String period) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BIDADARI ERP', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text('Sistem Manajemen Keuangan Tersentralisasi', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Outlet: Seluruh Cabang (Pusat, Tutugan, Capil)', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('REKENING KORAN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Periode: $period', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildExecutiveSummary(double inc, double exp, double net) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL PEMASUKAN', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(_formatCurrency.format(inc), style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL PENGELUARAN', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('(${_formatCurrency.format(exp)})', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900)),
            ],
          ),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SALDO BERSIH (PROFIT)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatCurrency.format(net), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: net >= 0 ? PdfColors.green900 : PdfColors.red900)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.blue800),
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

static pw.Widget _buildTransactionTable(List<IncomeModel> incs, List<ExpenseModel> exps) {
    // 1. Gabung data dan urutkan berdasarkan tanggal terbaru
    final List<dynamic> all = [...incs, ...exps];
    all.sort((a, b) => b.date.compareTo(a.date));

    return pw.TableHelper.fromTextArray(
      border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headers: ['TANGGAL', 'KETERANGAN', 'UNIT', 'KATEGORI', 'DEBET (IN)', 'KREDIT (OUT)'],
      data: all.map((item) {
        final isIncome = item is IncomeModel;
        
        // SOLUSI ERROR .NAME: Menggunakan toString() lalu di-split
        // Ini cara paling aman untuk Flutter Web agar tidak error 'NoSuchMethod'
        String getEnumName(dynamic e) => e.toString().split('.').last.toUpperCase();

        return [
          DateFormat('dd/MM/yy').format(item.date),
          item.description,
          // Kolom UNIT: Jika income pakai tipe unit, jika expense pakai unitBisnis string
          isIncome ? getEnumName(item.type) : item.unitBisnis.toUpperCase(),
          // Kolom KATEGORI
          isIncome ? 'PEMASUKAN' : getEnumName(item.type),
          // Kolom DEBET/KREDIT
          isIncome ? _formatCurrency.format(item.amount) : '-',
          !isIncome ? _formatCurrency.format(item.amount) : '-',
        ];
      }).toList(),
    );
  }

static pw.Widget _buildUnitTable(List<IncomeModel> incs, List<ExpenseModel> exps) {
    // 1. LOGIKA KALKULASI UNIT (THE BRAIN)
    List<Map<String, dynamic>> unitStats = [
      {'name': 'KELAPA', 'type': IncomeType.kelapa},
      {'name': 'GALON', 'type': IncomeType.galon},
      {'name': 'KONTRAKAN', 'type': IncomeType.kontrakan},
      {'name': 'UMUM / LAINNYA', 'type': null}, // Untuk expense yang tidak ada unit spesifik
    ];

    return pw.TableHelper.fromTextArray(
      headers: ['UNIT BISNIS', 'TOTAL MASUK', 'TOTAL KELUAR', 'MARGIN'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      data: unitStats.map((unit) {
        // Hitung Pemasukan per Unit
        double incTotal = 0;
        if (unit['type'] != null) {
          incTotal = incs.where((i) => i.type == unit['type']).fold(0.0, (sum, item) => sum + item.amount);
        }

        // Hitung Pengeluaran per Unit (Case Insensitive check)
        double expTotal = exps.where((e) {
          if (unit['type'] == null) {
            return e.unitBisnis.toLowerCase() == 'umum' || e.unitBisnis.toLowerCase() == 'lainnya';
          }
          // Mencocokkan nama unit dengan unitBisnis di expense
          return e.unitBisnis.toLowerCase() == unit['name'].toString().toLowerCase();
        }).fold(0.0, (sum, item) => sum + item.amount);

        double margin = incTotal - expTotal;

        return [
          unit['name'],
          _formatCurrency.format(incTotal),
          _formatCurrency.format(expTotal),
          _formatCurrency.format(margin),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildDebtTable(List<DebtModel> debts) {
    return pw.TableHelper.fromTextArray(
      border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      // MENAMBAHKAN KOLOM TENOR
      headers: ['KREDITUR', 'TENOR', 'JATUH TEMPO', 'NOMINAL', 'STATUS'],
      data: debts.map((d) {
        // Logika Tenor: Menampilkan "3 / 12" (Cicilan ke-3 dari 12)
        // Pastikan model DebtModel Anda memiliki field currentInstallment dan totalInstallments
        final String tenor = '${d.currentInstallment} / ${d.totalInstallments}';
        
        final daysLeft = d.dueDate.difference(DateTime.now()).inDays;
        String statusText = d.isPaid ? 'LUNAS' : (daysLeft < 0 ? 'TELAT' : 'BELUM BAYAR');

        return [
          d.creditorName.toUpperCase(),
          tenor,
          DateFormat('dd/MM/yyyy').format(d.dueDate),
          _formatCurrency.format(d.amount),
          statusText,
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    );
  }
}