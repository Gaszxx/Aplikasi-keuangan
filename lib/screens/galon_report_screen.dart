import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Tema Warna Khusus Galon (Biru Air) yang menyesuaikan Light/Dark Mode
    final galonColor = theme.brightness == Brightness.dark ? Colors.lightBlueAccent : Colors.blue.shade700;

    // --- 1. FILTER DATA GALON (QA SECURED) ---
    // WAJIB: Pastikan HANYA unit bisnis 'Galon' yang ditarik!
    var galonIncomes = finance.incomes.where((i) => i.type == IncomeType.galon && _isWithinFilter(i.date)).toList();
    var galonExpenses = finance.expenses.where((e) => e.unitBisnis == 'Galon' && _isWithinFilter(e.date)).toList();

    List<dynamic> combinedHistory = [...galonIncomes, ...galonExpenses];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date));

    // --- 2. LOGIKA GRAFIK DINAMIS ---
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

    // --- 3. KALKULASI KEUANGAN GALON (50:50) ---
    double totalKotor = galonIncomes.fold(0, (sum, i) => sum + (i.grossAmount ?? 0));
    double totalGaji = galonIncomes.fold(0, (sum, i) => sum + (i.employeeCut ?? 0));
    double totalOperasional = galonExpenses.fold(0, (sum, e) => sum + e.amount);
    
    // Laba Bersih = Omset Kotor - Bagi Hasil Karyawan - Operasional Kendaraan
    double labaBersihReal = totalKotor - totalGaji - totalOperasional;

    // ESTIMASI GALON (Berdasarkan Harga Rp 5.000 / Galon)
    int estimasiTotalGalon = (totalKotor / 5000).floor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Galon', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // --- HEADER NAMA DEPOT BIDADARI ---
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.water_drop_rounded, size: 48, color: galonColor),
                      const SizedBox(height: 8),
                      Text('DEPOT BIDADARI', style: TextStyle(color: galonColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      const SizedBox(height: 4),
                      Text('Laporan Keuangan & Performa', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // FILTER WAKTU FULL WIDTH
                SegmentedButton<TimeFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TimeFilter.hari, label: Text('Hari Ini')),
                    ButtonSegment(value: TimeFilter.minggu, label: Text('7 Hari')),
                    ButtonSegment(value: TimeFilter.bulan, label: Text('Bulan Ini')),
                  ],
                  selected: {_selectedTime},
                  onSelectionChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTime = val.first);
                  },
                ),
                const SizedBox(height: 24),

                // KARTU UTAMA LABA BERSIH
                _buildMainProfitCard(galonColor, labaBersihReal, totalKotor, totalGaji, totalOperasional),
                const SizedBox(height: 24),

                // GRAFIK TREND (Warna Biru + Estimasi Galon)
                _buildChartSection(theme, galonColor, labels, values, maxVal, estimasiTotalGalon),
                const SizedBox(height: 24),

                // TOMBOL PENGELUARAN KENDARAAN
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _openExpenseSheet(galonColor);
                    },
                    icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white),
                    label: const Text('Input Biaya Operasional', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text('Riwayat Transaksi Depot', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildHistoryList(combinedHistory, theme, galonColor),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildMainProfitCard(Color galonColor, double profit, double kotor, double gaji, double ops) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [galonColor, galonColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: galonColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('LABA BERSIH DEPOT (NETTO)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(_formatRp(profit), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _buildMiniStat('Omset Kotor', _formatRp(kotor)),
              _buildMiniStat('Gaji (50%)', _formatRp(gaji)),
              _buildMiniStat('Beban Ops', _formatRp(ops)),
            ]
          )
        ]
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, Color galonColor, List<String> labels, List<double> values, double maxVal, int estimasiTotal) {
    int currentGalon = values[_selectedBarIndex] > 0 ? (values[_selectedBarIndex] / 5000).floor() : 0;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trend Penjualan Galon', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Total: ~ $estimasiTotal Galon', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: galonColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(values[_selectedBarIndex] == 0 ? 'Kosong' : '~ $currentGalon Galon', style: TextStyle(color: galonColor, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 140, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                crossAxisAlignment: CrossAxisAlignment.end, 
                children: List.generate(values.length, (index) {
                  bool isSelected = _selectedBarIndex == index;
                  bool hasData = values[index] > 0;
                  double barHeight = hasData ? (values[index] / maxVal) * 90 : 12.0;
                  if (hasData && barHeight < 12.0) barHeight = 12.0;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBarIndex = index);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end, 
                      children: [
                        if (isSelected) 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              hasData ? '~ ${(values[index]/5000).floor()}' : '0', 
                              style: TextStyle(fontSize: 10, color: hasData ? galonColor : Colors.grey, fontWeight: FontWeight.bold)
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: values.length > 7 ? 16 : 28,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: hasData ? (isSelected ? galonColor : galonColor.withOpacity(0.4)) : theme.colorScheme.surfaceContainerHighest, 
                            borderRadius: BorderRadius.circular(6)
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(labels[index], style: theme.textTheme.labelSmall?.copyWith(color: isSelected ? galonColor : theme.colorScheme.onSurfaceVariant)),
                      ]
                    ),
                  );
                })
              )
            ),
          ]
        ),
      ),
    );
  }

  void _openExpenseSheet(Color galonColor) {
    final ctrlNominal = TextEditingController();
    String selectedKategori = 'Beli Bensin';
    final List<String> kategoriList = ['Beli Bensin', 'Ganti Oli', 'Tambal Ban / Servis', 'Uang Makan', 'Lainnya'];

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setMState) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                
                Text('Biaya Operasional Kendaraan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  value: selectedKategori,
                  decoration: InputDecoration(labelText: 'Kategori Biaya', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: kategoriList.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setMState(() => selectedKategori = v!),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: ctrlNominal, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Nominal Biaya (Rp)', prefixIcon: const Icon(Icons.payments_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity, height: 55, 
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      double val = double.tryParse(ctrlNominal.text) ?? 0;
                      if (val > 0) {
                        context.read<FinanceProvider>().addExpense(ExpenseModel(
                          id: '', 
                          type: ExpenseType.operasional, 
                          unitBisnis: 'Galon', // QA: KEAMANAN DATA MUTLAK
                          amount: val,
                          date: DateTime.now(), 
                          outlet: 'Depot Utama', 
                          description: selectedKategori,
                        ));
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      }
                    }, 
                    child: const Text('Simpan Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                  )
                ),
              ]
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHistoryList(List<dynamic> list, ThemeData theme, Color galonColor) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20), 
          child: Text('Belum ada transaksi', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
        )
      );
    }
    
    return ListView.builder(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        bool isIncome = item is IncomeModel;
        
        IconData icon = isIncome ? Icons.water_drop_rounded : Icons.build_circle_rounded;
        Color color = isIncome ? galonColor : theme.colorScheme.error;
        String title = isIncome ? "Penjualan Galon" : "Biaya: ${item.description}";
        String subtitle = isIncome ? "Gaji Karyawan (50%): ${_formatRp(item.employeeCut ?? 0)}" : "Operasional Depot";
        String trailing = isIncome ? "+ ${_formatRp(item.amount)}" : "- ${_formatRp(item.amount)}";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: color.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.2))),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 20)),
            title: Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(item.date), style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey, fontSize: 9)),
              ]
            ),
            trailing: Text(trailing, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 4), Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]);
  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
}