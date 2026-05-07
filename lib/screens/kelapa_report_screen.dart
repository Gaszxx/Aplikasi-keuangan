import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_colors.dart';

enum TimeFilter { hari, minggu, bulan }

class KelapaReportScreen extends StatefulWidget {
  const KelapaReportScreen({super.key});

  @override
  State<KelapaReportScreen> createState() => _KelapaReportScreenState();
}

class _KelapaReportScreenState extends State<KelapaReportScreen> {
  String _selectedOutlet = 'Semua Outlet';
  TimeFilter _selectedTime = TimeFilter.hari;
  int _selectedBarIndex = 0;

  final List<String> _outlets = [
    'Semua Outlet', 'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau', 'Cicalengka', 'Pa Mamat'
  ];

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : const Color(0xFF007A3D);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // --- 1. FILTER DATA ---
    var kelapaIncomes = finance.incomes.where((item) => item.type == IncomeType.kelapa).toList();
    var kelapaExpenses = finance.expenses.where((e) => _selectedOutlet == 'Semua Outlet' || e.outlet == _selectedOutlet).toList();

    if (_selectedOutlet != 'Semua Outlet') {
      kelapaIncomes = kelapaIncomes.where((item) => item.location == _selectedOutlet).toList();
    }

    // --- 2. LOGIKA GRAFIK DINAMIS ---
    List<String> labels = [];
    List<double> values = [];
    DateTime now = DateTime.now();

    if (_selectedTime == TimeFilter.hari) {
      labels = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];
      values = List.filled(7, 0.0);
      for (var i in kelapaIncomes) {
        if (now.difference(i.date).inDays < 7) {
          values[i.date.weekday - 1] += (i.grossAmount ?? 0);
        }
      }
    } else if (_selectedTime == TimeFilter.minggu) {
      labels = ['W1', 'W2', 'W3', 'W4'];
      values = List.filled(4, 0.0);
      for (var i in kelapaIncomes) {
        if (i.date.month == now.month) {
          int week = ((i.date.day - 1) / 7).floor();
          if (week < 4) values[week] += (i.grossAmount ?? 0);
        }
      }
    } else {
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      values = List.filled(12, 0.0);
      for (var i in kelapaIncomes) {
        if (i.date.year == now.year) {
          values[i.date.month - 1] += (i.grossAmount ?? 0);
        }
      }
    }

    double maxVal = values.fold(1, (p, c) => c > p ? c : p);
    if (_selectedBarIndex >= values.length) _selectedBarIndex = 0;

    // --- 3. KALKULASI RINGKASAN ---
    double totalKotor = kelapaIncomes.fold(0, (sum, item) => sum + (item.grossAmount ?? 0));
    double totalGaji = kelapaIncomes.fold(0, (sum, item) => sum + (item.employeeCut ?? 0));
    double totalSewa = kelapaExpenses.where((e) => e.type == ExpenseType.sewa).fold(0, (sum, e) => sum + e.amount);
    
    // JUMLAH KELAPA DIISI (STOK)
    double jumlahKelapaDiisi = kelapaExpenses
        .where((e) => e.type == ExpenseType.modal)
        .fold(0, (sum, e) => sum + (double.tryParse(e.description?.split(' ')[1] ?? '0') ?? 0));
    
    double potensiPendapatan = jumlahKelapaDiisi * 8000;

    // LABA BERSIH: Hanya dipotong Gaji & Sewa (Stok tidak memotong laba sesuai permintaan)
    double labaBersihReal = totalKotor - totalGaji - totalSewa;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Analitik Kelapa', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // AREA FILTER
            Row(
              children: [
                Expanded(flex: 3, child: _buildOutletDropdown(cardColor, textColor, primary)),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: _buildTimeSegmented(primary)),
              ],
            ),
            const SizedBox(height: 24),

            // KARTU UTAMA LABA BERSIH
            _buildMainProfitCard(primary, labaBersihReal, totalKotor, totalGaji),
            const SizedBox(height: 20),

            // KARTU POTENSI PENDAPATAN (DARI ISI KELAPA)
            if (_selectedOutlet != 'Semua Outlet')
              _buildPotensiCard(jumlahKelapaDiisi, potensiPendapatan, totalKotor, isDark),
            
            const SizedBox(height: 20),

            // GRAFIK TREND
            _buildChartSection(cardColor, textColor, primary, labels, values, maxVal),
            const SizedBox(height: 24),

            // TOMBOL ACTION
            _buildActionButtons(context, primary),
            const SizedBox(height: 24),

            // STATISTIK OPERASIONAL (Hanya Sewa yang tampil sebagai pengeluaran)
            _buildSewaStat(totalSewa, isDark),
            const SizedBox(height: 32),

            Text('Riwayat Terakhir', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTransactionList(kelapaIncomes, primary, textColor),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildPotensiCard(double butir, double potensi, double realKotor, bool isDark) {
    double sisaTarget = potensi - realKotor;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Target Setoran (Inventaris)', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('${butir.toInt()} Butir Kelapa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              ]),
                const Icon(Icons.inventory, color: Colors.orange, size: 30),            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallInfo('Harus Diperoleh', _formatRp(potensi)),
              _buildSmallInfo('Sisa Target', _formatRp(sisaTarget < 0 ? 0 : sisaTarget), color: Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String t, String v, {Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _buildMainProfitCard(Color primary, double profit, double kotor, double gaji) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LABA BERSIH (MASUK KAS)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_formatRp(profit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Omset Kotor', _formatRp(kotor)),
              _buildMiniStat('Potongan Gaji', _formatRp(gaji)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primary) {
    bool isAll = _selectedOutlet == 'Semua Outlet';
    return Row(
      children: [
        Expanded(child: _buildBtn(Icons.add_box, isAll ? 'Beli Stok' : 'Isi Kelapa', Colors.blueGrey, () => _handleBtn(context, ExpenseType.modal))),
        const SizedBox(width: 12),
        Expanded(child: _buildBtn(Icons.key, 'Bayar Sewa', Colors.brown, () => _handleBtn(context, ExpenseType.sewa))),
      ],
    );
  }

  void _handleBtn(BuildContext context, ExpenseType type) {
    if (_selectedOutlet == 'Semua Outlet') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Outlet spesifik dahulu!')));
    } else {
      _openExpenseSheet(type);
    }
  }

  void _openExpenseSheet(ExpenseType type) {
    final ctrl = TextEditingController();
    double prediksi = 0;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(type == ExpenseType.modal ? 'Input Stok Kelapa' : 'Input Sewa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: type == ExpenseType.modal ? 'Berapa Butir?' : 'Nominal Rp', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: (v) {
                if(type == ExpenseType.modal) setMState(() => prediksi = (double.tryParse(v) ?? 0) * 8000);
              },
            ),
            if (prediksi > 0) Padding(padding: const EdgeInsets.only(top: 15), child: Text('Prediksi Kotor: ${_formatRp(prediksi)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
            const SizedBox(height: 25),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () {
              double val = double.tryParse(ctrl.text) ?? 0;
              if (val > 0) {
                context.read<FinanceProvider>().addExpense(ExpenseModel(
                  id: '', type: type, amount: type == ExpenseType.modal ? 0 : val, // Amount 0 jika Stok agar tidak potong laba
                  date: DateTime.now(), outlet: _selectedOutlet,
                  description: type == ExpenseType.modal ? 'Stok $val Butir' : 'Sewa Tempat',
                ));
                Navigator.pop(ctx);
              }
            }, child: const Text('Simpan Data'))),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  // --- WIDGET STANDAR (DROP, SEGMENT, CHART, LIST) ---
  Widget _buildOutletDropdown(Color cardColor, Color textColor, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withOpacity(0.3))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: _selectedOutlet, isExpanded: true,
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
        items: _outlets.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (val) => setState(() => _selectedOutlet = val!),
      )),
    );
  }

  Widget _buildTimeSegmented(Color primary) {
    return SegmentedButton<TimeFilter>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: TimeFilter.hari, label: Text('H')),
        ButtonSegment(value: TimeFilter.minggu, label: Text('M')),
        ButtonSegment(value: TimeFilter.bulan, label: Text('B')),
      ],
      selected: {_selectedTime},
      onSelectionChanged: (val) => setState(() => _selectedTime = val.first),
    );
  }

  Widget _buildChartSection(Color cardColor, Color textColor, Color primary, List<String> labels, List<double> values, double maxVal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Trend Penjualan', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        SizedBox(height: 120, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (index) {
          bool isSelected = _selectedBarIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedBarIndex = index),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: values.length > 7 ? 16 : 25,
                height: values[index] > 0 ? (values[index] / maxVal) * 80 : 10,
                decoration: BoxDecoration(color: values[index] > 0 ? (isSelected ? primary : primary.withOpacity(0.4)) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 8),
              Text(labels[index], style: TextStyle(fontSize: 9, color: isSelected ? primary : Colors.grey)),
            ]),
          );
        }))),
      ]),
    );
  }

  Widget _buildSewaStat(double sewa, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.brown.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.brown.withOpacity(0.2))),
      child: Column(children: [
        const Text('Total Biaya Sewa Tempat', style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text(_formatRp(sewa), style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  Widget _buildTransactionList(List<IncomeModel> list, Color primary, Color textColor) {
    if (list.isEmpty) return const Center(child: Text('Kosong', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length > 3 ? 3 : list.length,
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: primary.withOpacity(0.1), child: const Icon(Icons.nature, size: 18)),
        title: Text(list[index].location ?? 'Outlet', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        trailing: Text('+ ${_formatRp(list[index].amount)}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBtn(IconData i, String l, Color c, VoidCallback t) {
    return ElevatedButton.icon(onPressed: t, icon: Icon(i, color: Colors.white, size: 16), label: Text(l, style: const TextStyle(color: Colors.white, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Widget _buildMiniStat(String t, String v) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ]);
  }

  String _formatRp(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }
}