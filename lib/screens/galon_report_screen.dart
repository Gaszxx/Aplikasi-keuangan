import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../providers/finance_provider.dart';

enum TimeFilter { hari, minggu, bulan }

class GalonReportScreen extends StatefulWidget {
  const GalonReportScreen({super.key});

  @override
  State<GalonReportScreen> createState() => _GalonReportScreenState();
}

class _GalonReportScreenState extends State<GalonReportScreen> {
  TimeFilter _selectedTime = TimeFilter.hari;
  int _selectedBarIndex = 0;

  // Tema warna khusus Depot Galon
  final Color galonColor = const Color(0xFF0288D1); // Light Blue Darker

  bool _isWithinFilter(DateTime date) {
    final now = DateTime.now();
    if (_selectedTime == TimeFilter.hari) {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (_selectedTime == TimeFilter.minggu) {
      return now.difference(date).inDays <= 7;
    } else {
      return date.year == now.year && date.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // --- FILTER DATA GALON ---
    var galonIncomes = finance.incomes.where((i) => i.type == IncomeType.galon && _isWithinFilter(i.date)).toList();
    var galonExpenses = finance.expenses.where((e) => e.outlet == 'Depot Utama' && _isWithinFilter(e.date)).toList();

    List<dynamic> combinedHistory = [...galonIncomes, ...galonExpenses];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date));

    // --- LOGIKA GRAFIK DINAMIS ---
    List<String> labels = [];
    List<double> values = [];
    DateTime now = DateTime.now();

    if (_selectedTime == TimeFilter.hari) {
      labels = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];
      values = List.filled(7, 0.0);
      for (var i in galonIncomes) { values[i.date.weekday - 1] += (i.grossAmount ?? 0); }
    } else if (_selectedTime == TimeFilter.minggu) {
      labels = ['W1', 'W2', 'W3', 'W4'];
      values = List.filled(4, 0.0);
      for (var i in galonIncomes) {
        int week = ((i.date.day - 1) / 7).floor();
        if (week < 4) values[week] += (i.grossAmount ?? 0);
      }
    } else {
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      values = List.filled(12, 0.0);
      for (var i in galonIncomes) { values[i.date.month - 1] += (i.grossAmount ?? 0); }
    }

    double maxVal = values.fold(1, (p, c) => c > p ? c : p);
    if (_selectedBarIndex >= values.length) _selectedBarIndex = 0;

    // --- KALKULASI KEUANGAN GALON (50:50) ---
    double totalKotor = galonIncomes.fold(0, (sum, i) => sum + (i.grossAmount ?? 0));
    double totalGaji = galonIncomes.fold(0, (sum, i) => sum + (i.employeeCut ?? 0));
    double totalOperasional = galonExpenses.fold(0, (sum, e) => sum + e.amount);
    
    // Laba Bersih = Omset Kotor - Bagi Hasil Karyawan - Operasional Kendaraan
    double labaBersihReal = totalKotor - totalGaji - totalOperasional;

    // ESTIMASI GALON (Berdasarkan Harga Rp 5.000 / Galon)
    int estimasiTotalGalon = (totalKotor / 5000).floor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text('Analitik Galon', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // --- HEADER NAMA DEPOT BIDADARI ---
            Center(
              child: Column(
                children: [
                  Icon(Icons.water_drop, size: 48, color: galonColor),
                  const SizedBox(height: 8),
                  Text('DEPOT BIDADARI', style: TextStyle(color: galonColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                  const SizedBox(height: 4),
                  const Text('Laporan Keuangan & Performa', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // KARENA HANYA 1 OUTLET, KITA FULL-KAN TOMBOL FILTER WAKTU
            SegmentedButton<TimeFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TimeFilter.hari, label: Text('Hari Ini')),
                ButtonSegment(value: TimeFilter.minggu, label: Text('7 Hari')),
                ButtonSegment(value: TimeFilter.bulan, label: Text('Bulan Ini')),
              ],
              selected: {_selectedTime},
              onSelectionChanged: (val) => setState(() => _selectedTime = val.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: galonColor.withOpacity(0.2), selectedForegroundColor: galonColor),
            ),
            const SizedBox(height: 24),

            // KARTU UTAMA LABA BERSIH
            _buildMainProfitCard(labaBersihReal, totalKotor, totalGaji, totalOperasional),
            const SizedBox(height: 20),

            // GRAFIK TREND (Warna Biru + Estimasi Galon)
            _buildChartSection(cardColor, textColor, labels, values, maxVal, estimasiTotalGalon),
            const SizedBox(height: 24),

            // TOMBOL PENGELUARAN KENDARAAN
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _openExpenseSheet(),
                icon: const Icon(Icons.two_wheeler, color: Colors.white),
                label: const Text('Input Biaya Operasional', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
            const SizedBox(height: 32),

            Text('Riwayat Depot Bidadari', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildHistoryList(combinedHistory, textColor),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildMainProfitCard(double profit, double kotor, double gaji, double ops) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [galonColor, galonColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: galonColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LABA BERSIH DEPOT (BOS)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_formatRp(profit), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildMiniStat('Omset Kotor', _formatRp(kotor)),
          _buildMiniStat('Gaji (50%)', _formatRp(gaji)),
          _buildMiniStat('Beban Ops', _formatRp(ops)),
        ])
      ]),
    );
  }

  Widget _buildChartSection(Color cardColor, Color textColor, List<String> labels, List<double> values, double maxVal, int estimasiTotal) {
    int currentGalon = values[_selectedBarIndex] > 0 ? (values[_selectedBarIndex] / 5000).floor() : 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trend Penjualan Galon', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Total: ~ $estimasiTotal Galon', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: galonColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(values[_selectedBarIndex] == 0 ? 'Kosong' : '~ $currentGalon Galon', style: TextStyle(color: galonColor, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        const SizedBox(height: 30),
        SizedBox(height: 140, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (index) {
          bool isSelected = _selectedBarIndex == index;
          bool hasData = values[index] > 0;
          double barHeight = hasData ? (values[index] / maxVal) * 90 : 12.0;
          if (hasData && barHeight < 12.0) barHeight = 12.0;

          return GestureDetector(
            onTap: () => setState(() => _selectedBarIndex = index),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (isSelected) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    hasData ? '~ ${(values[index]/5000).floor()}' : '0', 
                    style: TextStyle(fontSize: 10, color: hasData ? galonColor : Colors.grey, fontWeight: FontWeight.bold)
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: values.length > 7 ? 16 : 28,
                height: barHeight,
                decoration: BoxDecoration(
                  color: hasData ? (isSelected ? galonColor : galonColor.withOpacity(0.4)) : Colors.grey.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(6)
                ),
              ),
              const SizedBox(height: 8),
              Text(labels[index], style: TextStyle(fontSize: 9, color: isSelected ? galonColor : Colors.grey)),
            ]),
          );
        }))),
      ]),
    );
  }

  void _openExpenseSheet() {
    final ctrlNominal = TextEditingController();
    String selectedKategori = 'Beli Bensin';
    final List<String> kategoriList = ['Beli Bensin', 'Ganti Oli', 'Tambal Ban / Servis', 'Uang Makan', 'Lainnya'];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setMState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Input Pengeluaran Operasional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedKategori,
            decoration: InputDecoration(labelText: 'Kategori Biaya', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: kategoriList.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
            onChanged: (v) => setMState(() => selectedKategori = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrlNominal, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Nominal Rp', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 25),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              double val = double.tryParse(ctrlNominal.text) ?? 0;
              if (val > 0) {
                context.read<FinanceProvider>().addExpense(ExpenseModel(
                  id: '', type: ExpenseType.operasional, amount: val,
                  date: DateTime.now(), outlet: 'Depot Utama', description: selectedKategori,
                ));
                Navigator.pop(ctx);
              }
            }, 
            child: const Text('Simpan Pengeluaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )),
          const SizedBox(height: 30),
        ]),
      )),
    );
  }

  Widget _buildHistoryList(List<dynamic> list, Color textColor) {
    if (list.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data', style: TextStyle(color: Colors.grey))));
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        bool isIncome = item is IncomeModel;
        
        IconData icon = isIncome ? Icons.water_drop : Icons.build;
        Color color = isIncome ? galonColor : Colors.orange;
        String title = isIncome ? "Penjualan Galon" : "Biaya: ${item.description}";
        String subtitle = isIncome ? "Gaji (50%): ${_formatRp(item.employeeCut ?? 0)}" : "Operasional Depot";
        String trailing = isIncome ? "+ ${_formatRp(item.amount)}" : "- ${_formatRp(item.amount)}";

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 18)),
            title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(DateFormat('dd MMM yyyy, HH:mm').format(item.date), style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
            ]),
            trailing: Text(trailing, style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 4), Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]);
  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
}