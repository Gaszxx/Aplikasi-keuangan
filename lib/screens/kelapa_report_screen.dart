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

  // Fungsi helper untuk filter waktu yang konsisten
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
    final primary = isDark ? AppColors.primary : const Color(0xFF007A3D);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    // --- 1. FILTER & GABUNG DATA ---
    var kelapaIncomes = finance.incomes.where((i) => i.type == IncomeType.kelapa && _isWithinFilter(i.date)).toList();
    var kelapaExpenses = finance.expenses.where((e) => _isWithinFilter(e.date)).toList();

    if (_selectedOutlet != 'Semua Outlet') {
      kelapaIncomes = kelapaIncomes.where((i) => i.location == _selectedOutlet).toList();
      kelapaExpenses = kelapaExpenses.where((e) => e.outlet == _selectedOutlet).toList();
    }

    // Buat riwayat gabungan (Incomes + Expenses) untuk ditampilkan di list
    List<dynamic> combinedHistory = [...kelapaIncomes, ...kelapaExpenses];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date)); // Urutkan terbaru di atas

    // --- 2. LOGIKA GRAFIK ---
    List<String> labels = [];
    List<double> values = [];
    DateTime now = DateTime.now();

    if (_selectedTime == TimeFilter.hari) {
      labels = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];
      values = List.filled(7, 0.0);
      for (var i in kelapaIncomes) { values[i.date.weekday - 1] += (i.grossAmount ?? 0); }
    } else if (_selectedTime == TimeFilter.minggu) {
      labels = ['W1', 'W2', 'W3', 'W4'];
      values = List.filled(4, 0.0);
      for (var i in kelapaIncomes) {
        int week = ((i.date.day - 1) / 7).floor();
        if (week < 4) values[week] += (i.grossAmount ?? 0);
      }
    } else {
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      values = List.filled(12, 0.0);
      for (var i in kelapaIncomes) { values[i.date.month - 1] += (i.grossAmount ?? 0); }
    }

    double maxVal = values.fold(1, (p, c) => c > p ? c : p);

    // --- 3. KALKULASI RINGKASAN ---
    double totalKotor = kelapaIncomes.fold(0, (sum, i) => sum + (i.grossAmount ?? 0));
    double totalGaji = kelapaIncomes.fold(0, (sum, i) => sum + (i.employeeCut ?? 0));
    double totalSewa = kelapaExpenses.where((e) => e.type == ExpenseType.sewa).fold(0, (sum, e) => sum + e.amount);
    
    // Hitung Stok (Hanya untuk tampilan inventaris)
    double stokButir = kelapaExpenses
        .where((e) => e.type == ExpenseType.modal)
        .fold(0, (sum, e) => sum + (double.tryParse(e.description?.split(' ')[1] ?? '0') ?? 0));

    double labaBersihReal = totalKotor - totalGaji - totalSewa;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text('Analitik Kelapa', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: _buildOutletDropdown(cardColor, textColor, primary)),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: _buildTimeSegmented(primary)),
              ],
            ),
            const SizedBox(height: 24),
            _buildMainProfitCard(primary, labaBersihReal, totalKotor, totalGaji),
            const SizedBox(height: 20),
            if (_selectedOutlet != 'Semua Outlet')
              _buildPotensiCard(stokButir, stokButir * 8000, totalKotor, isDark),
            _buildChartSection(cardColor, textColor, primary, labels, values, maxVal),
            const SizedBox(height: 24),
            _buildActionButtons(context, primary),
            const SizedBox(height: 24),
            _buildSewaStat(totalSewa, isDark),
            const SizedBox(height: 32),
            Text('Riwayat Transaksi Terpadu', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildUnifiedHistoryList(combinedHistory, primary, textColor),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildUnifiedHistoryList(List<dynamic> list, Color primary, Color textColor) {
    if (list.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data aktivitas', style: TextStyle(color: Colors.grey))));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        bool isIncome = item is IncomeModel;
        
        IconData icon;
        Color color;
        String title;
        String subtitle;
        String trailing;

        if (isIncome) {
          icon = Icons.add_chart;
          color = Colors.green;
          title = "Penjualan: ${item.location}";
          subtitle = "Gaji: ${_formatRp(item.employeeCut ?? 0)}";
          trailing = "+ ${_formatRp(item.amount)}";
        } else {
          bool isSewa = item.type == ExpenseType.sewa;
          icon = isSewa ? Icons.vpn_key : Icons.inventory_2;
          color = isSewa ? Colors.red : Colors.blue;
          title = isSewa ? "Bayar Sewa" : "Isi Stok Kelapa";
          subtitle = item.description ?? "";
          trailing = isSewa ? "- ${_formatRp(item.amount)}" : "Stok Masuk";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 18)),
            title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(item.date), style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
              ],
            ),
            trailing: Text(trailing, style: TextStyle(color: isIncome ? Colors.green : (color == Colors.red ? Colors.red : Colors.blue), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildPotensiCard(double butir, double potensi, double realKotor, bool isDark) {
    double sisa = potensi - realKotor;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.3))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Target Inventaris', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('${butir.toInt()} Butir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ]),
          const Icon(Icons.inventory, color: Colors.orange, size: 28),
        ]),
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSmallInfo('Potensi', _formatRp(potensi)),
          _buildSmallInfo('Sisa Target', _formatRp(sisa < 0 ? 0 : sisa), color: Colors.red),
        ])
      ]),
    );
  }

  Widget _buildMainProfitCard(Color primary, double profit, double kotor, double gaji) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LABA BERSIH (SETELAH SEWA & GAJI)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_formatRp(profit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildMiniStat('Omset Kotor', _formatRp(kotor)),
          _buildMiniStat('Gaji Pegawai', _formatRp(gaji)),
        ])
      ]),
    );
  }

  Widget _buildSewaStat(double sewa, bool isDark) {
    String periode = _selectedTime == TimeFilter.hari ? "Hari Ini" : _selectedTime == TimeFilter.minggu ? "7 Hari Terakhir" : "Bulan Ini";
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Biaya Sewa ($periode)', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(_formatRp(sewa), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const Icon(Icons.calendar_today, color: Colors.red, size: 20),
      ]),
    );
  }

  // --- FUNCTIONS ---

  void _openExpenseSheet(ExpenseType type) {
    final ctrl = TextEditingController();
    double prediksi = 0;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setMState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(type == ExpenseType.modal ? 'Isi Stok Kelapa' : 'Bayar Sewa Outlet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: type == ExpenseType.modal ? 'Jumlah Butir' : 'Nominal Rp', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onChanged: (v) { if(type == ExpenseType.modal) setMState(() => prediksi = (double.tryParse(v) ?? 0) * 8000); },
          ),
          if (prediksi > 0) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Potensi Omset: ${_formatRp(prediksi)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
          const SizedBox(height: 25),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () {
            double val = double.tryParse(ctrl.text) ?? 0;
            if (val > 0) {
              context.read<FinanceProvider>().addExpense(ExpenseModel(
                id: '', type: type, amount: type == ExpenseType.modal ? 0 : val,
                date: DateTime.now(), outlet: _selectedOutlet,
                description: type == ExpenseType.modal ? 'Input $val Butir Kelapa' : 'Sewa Tempat Periode Ini',
              ));
              Navigator.pop(ctx);
            }
          }, child: const Text('Simpan Data'))),
          const SizedBox(height: 30),
        ]),
      )),
    );
  }

  // --- EXISTING HELPERS ---
  Widget _buildSmallInfo(String t, String v, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))]);
  Widget _buildMiniStat(String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10)), Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]);
  Widget _buildBtn(IconData i, String l, Color c, VoidCallback t) => ElevatedButton.icon(onPressed: t, icon: Icon(i, color: Colors.white, size: 16), label: Text(l, style: const TextStyle(color: Colors.white, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  
  Widget _buildOutletDropdown(Color cardColor, Color textColor, Color primary) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withOpacity(0.3))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedOutlet, isExpanded: true, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold), items: _outlets.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (val) => setState(() => _selectedOutlet = val!))));
  Widget _buildTimeSegmented(Color primary) => SegmentedButton<TimeFilter>(showSelectedIcon: false, segments: const [ButtonSegment(value: TimeFilter.hari, label: Text('H')), ButtonSegment(value: TimeFilter.minggu, label: Text('M')), ButtonSegment(value: TimeFilter.bulan, label: Text('B'))], selected: {_selectedTime}, onSelectionChanged: (val) => setState(() => _selectedTime = val.first));
  Widget _buildActionButtons(BuildContext context, Color primary) { bool isAll = _selectedOutlet == 'Semua Outlet'; return Row(children: [Expanded(child: _buildBtn(Icons.add_box, isAll ? 'Beli Stok' : 'Isi Kelapa', Colors.blueGrey, () => _handleBtn(context, ExpenseType.modal))), const SizedBox(width: 12), Expanded(child: _buildBtn(Icons.key, 'Bayar Sewa', Colors.brown, () => _handleBtn(context, ExpenseType.sewa)))]); }
  void _handleBtn(BuildContext context, ExpenseType type) { if (_selectedOutlet == 'Semua Outlet') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Outlet spesifik dahulu!'))); } else { _openExpenseSheet(type); } }
  Widget _buildChartSection(Color cardColor, Color textColor, Color primary, List<String> labels, List<double> values, double maxVal) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Trend Penjualan', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)), const SizedBox(height: 30), SizedBox(height: 120, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(values.length, (index) { bool isSelected = _selectedBarIndex == index; return GestureDetector(onTap: () => setState(() => _selectedBarIndex = index), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [AnimatedContainer(duration: const Duration(milliseconds: 300), width: values.length > 7 ? 16 : 25, height: values[index] > 0 ? (values[index] / maxVal) * 80 : 10, decoration: BoxDecoration(color: values[index] > 0 ? (isSelected ? primary : primary.withOpacity(0.4)) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Text(labels[index], style: TextStyle(fontSize: 9, color: isSelected ? primary : Colors.grey))])); })))],));
}