import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';

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
  String _searchQuery = '';
  String _filterType = 'Semua';

  final List<String> _outlets = [
    'Semua Outlet', 'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau', 'Cicalengka', 'Pa Mamat'
  ];

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

    // --- 1. FILTER & GABUNG DATA (QA SECURED) ---
    // Pastikan HANYA data Kelapa yang masuk ke laporan ini!
    var kelapaIncomes = finance.incomes.where((i) => i.type == IncomeType.kelapa && _isWithinFilter(i.date)).toList();
    var kelapaExpenses = finance.expenses.where((e) => e.unitBisnis == 'Kelapa' && _isWithinFilter(e.date)).toList();

    if (_selectedOutlet != 'Semua Outlet') {
      kelapaIncomes = kelapaIncomes.where((i) => i.location == _selectedOutlet).toList();
      kelapaExpenses = kelapaExpenses.where((e) => e.outlet == _selectedOutlet).toList();
    }

    List<dynamic> combinedHistory = [...kelapaIncomes, ...kelapaExpenses];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date)); 
    var filteredHistory = combinedHistory.where((item) {
      bool isIncome = item is IncomeModel;
      
      // 1. Cek Filter Dropdown
      if (_filterType == 'Pemasukan' && !isIncome) return false;
      if (_filterType == 'Pengeluaran' && isIncome) return false;

      // 2. Cek Kolom Pencarian (Search)
      String deskripsi = (item.description ?? '').toLowerCase();
      if (_searchQuery.isNotEmpty && !deskripsi.contains(_searchQuery)) return false;

      return true;
    }).toList();
    
    // Cek Jabatan (Role) untuk memunculkan Tong Sampah
    final auth = context.watch<AuthProvider>();
    final isSuperAdmin = auth.currentRole?.name.toLowerCase() == 'superadmin';

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
    
    // Ekstraksi aman untuk hitung jumlah stok butir kelapa
    double stokButir = kelapaExpenses
        .where((e) => e.type == ExpenseType.modal && e.description.contains('Stok:'))
        .fold(0, (sum, e) {
          final parts = e.description.split(' ');
          if (parts.length > 1) return sum + (double.tryParse(parts[1]) ?? 0);
          return sum;
        });

    double totalBiayaStok = kelapaExpenses.where((e) => e.type == ExpenseType.modal).fold(0, (sum, e) => sum + e.amount);
    double labaBersihReal = totalKotor - totalGaji - totalSewa - totalBiayaStok;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Kelapa', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildOutletDropdown(theme)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: _buildTimeSegmented(theme)),
                  ],
                ),
                const SizedBox(height: 24),
                
                _buildMainProfitCard(colorScheme, labaBersihReal, totalKotor, totalGaji),
                const SizedBox(height: 20),
                
                if (_selectedOutlet != 'Semua Outlet')
                  _buildPotensiCard(theme, stokButir, stokButir * 8000, totalKotor),
                  
                _buildChartSection(theme, labels, values, maxVal),
                const SizedBox(height: 24),
                
                _buildActionButtons(context, theme),
                const SizedBox(height: 24),
                
                _buildSewaStat(theme, totalSewa),
                const SizedBox(height: 32),
                
                Text('Riwayat Transaksi Terpadu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari transaksi...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          items: ['Semua', 'Pemasukan', 'Pengeluaran'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setState(() => _filterType = val!),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                _buildUnifiedHistoryList(filteredHistory, theme, isSuperAdmin),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

 Widget _buildUnifiedHistoryList(List<dynamic> list, ThemeData theme, bool isSuperAdmin) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20), 
          child: Text('Belum ada data aktivitas', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
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
        
        IconData icon; Color color; String title; String subtitle; String trailing;

        if (isIncome) {
          icon = Icons.add_chart_rounded;
          color = theme.colorScheme.primary; // Hijau/Teal
          title = "Penjualan: ${item.location}";
          subtitle = "Gaji: ${_formatRp(item.employeeCut ?? 0)}";
          trailing = "+ ${_formatRp(item.amount)}";
        } else {
          bool isSewa = item.type == ExpenseType.sewa;
          icon = isSewa ? Icons.vpn_key_rounded : Icons.inventory_2_rounded;
          color = isSewa ? theme.colorScheme.error : Colors.blue;
          title = isSewa ? "Bayar Sewa" : "Belanja Stok Kelapa";
          subtitle = item.description;
          trailing = "- ${_formatRp(item.amount)}";
        }

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
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trailing, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                
                // MUNCULKAN TONG SAMPAH HANYA JIKA SUPERADMIN (BAGAS SUJIWO)
                if (isSuperAdmin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text("Hapus Transaksi?"),
                          content: const Text("Data akan dihapus permanen dari sistem. Lanjutkan?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
                              onPressed: () {
                                if (isIncome) {
                                  context.read<FinanceProvider>().deleteIncome(item.id);
                                } else {
                                  context.read<FinanceProvider>().deleteExpense(item.id);
                                }
                                HapticFeedback.heavyImpact();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil dihapus!')));
                              },
                              child: const Text("Ya, Hapus", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        )
                      );
                    },
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPotensiCard(ThemeData theme, double butir, double potensi, double realKotor) {
    double sisa = potensi - realKotor;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.orange.withOpacity(0.3))
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text('Target Inventaris Tersedia', style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text('${butir.toInt()} Butir', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ]
              ),
              const Icon(Icons.inventory_2_rounded, color: Colors.orange, size: 32),
            ]
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _buildSmallInfo(theme, 'Potensi Omset', _formatRp(potensi)),
              _buildSmallInfo(theme, 'Sisa Target', _formatRp(sisa < 0 ? 0 : sisa), color: theme.colorScheme.error),
            ]
          )
        ]
      ),
    );
  }

  Widget _buildMainProfitCard(ColorScheme colorScheme, double profit, double kotor, double gaji) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text('LABA BERSIH (NETTO)', style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(_formatRp(profit), style: TextStyle(color: colorScheme.onPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _buildMiniStat(colorScheme, 'Omset Kotor', _formatRp(kotor)),
              _buildMiniStat(colorScheme, 'Gaji Pegawai', _formatRp(gaji)),
            ]
          )
        ]
      ),
    );
  }

  Widget _buildSewaStat(ThemeData theme, double sewa) {
    String periode = _selectedTime == TimeFilter.hari ? "Hari Ini" : _selectedTime == TimeFilter.minggu ? "7 Hari Terakhir" : "Bulan Ini";
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.2))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text('Biaya Sewa Lapak ($periode)', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_formatRp(sewa), style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            ]
          ),
          Icon(Icons.calendar_month_rounded, color: theme.colorScheme.error, size: 24),
        ]
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, List<String> labels, List<double> values, double maxVal) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text('Trend Penjualan Kotor', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            SizedBox(
              height: 120, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                crossAxisAlignment: CrossAxisAlignment.end, 
                children: List.generate(values.length, (index) { 
                  bool isSelected = _selectedBarIndex == index; 
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBarIndex = index);
                    }, 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end, 
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300), 
                          curve: Curves.easeOutCubic,
                          width: values.length > 7 ? 16 : 28, 
                          height: values[index] > 0 ? (values[index] / maxVal) * 90 : 10, 
                          decoration: BoxDecoration(
                            color: values[index] > 0 ? (isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3)) : theme.colorScheme.surfaceContainerHighest, 
                            borderRadius: BorderRadius.circular(6)
                          )
                        ), 
                        const SizedBox(height: 8), 
                        Text(labels[index], style: theme.textTheme.labelSmall?.copyWith(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant))
                      ]
                    )
                  ); 
                })
              )
            )
          ]
        ),
      ),
    );
  }

  // --- ACTIONS & MODALS ---

  void _openExpenseSheet(ExpenseType type) {
    final amountCtrl = TextEditingController();
    final butirCtrl = TextEditingController();
    
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
                
                Text(type == ExpenseType.modal ? 'Belanja Stok Kelapa' : 'Bayar Sewa Outlet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                if (type == ExpenseType.modal) ...[
                  TextField(
                    controller: butirCtrl, 
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Jumlah Butir', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.inventory_2_rounded)),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: amountCtrl, 
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Total Biaya (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.payments_rounded)),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity, height: 55, 
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      double amount = double.tryParse(amountCtrl.text) ?? 0;
                      String butir = butirCtrl.text;
                      
                      if (amount > 0) {
                        context.read<FinanceProvider>().addExpense(ExpenseModel(
                          id: '', 
                          type: type, 
                          unitBisnis: 'Kelapa', // WAJIB
                          amount: amount,
                          date: DateTime.now(), 
                          outlet: _selectedOutlet,
                          description: type == ExpenseType.modal ? 'Stok: $butir butir' : 'Sewa Lapak $_selectedOutlet',
                        ));
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      }
                    }, 
                    child: const Text('Simpan Pengeluaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  )
                ),
              ]
            ),
          ),
        );
      }),
    );
  }

  // --- HELPERS ---
  Widget _buildSmallInfo(ThemeData theme, String t, String v, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)), const SizedBox(height: 4), Text(v, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color))]);
  Widget _buildMiniStat(ColorScheme colorScheme, String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 4), Text(v, style: TextStyle(color: colorScheme.onPrimary, fontSize: 14, fontWeight: FontWeight.bold))]);
  Widget _buildBtn(IconData i, String l, Color c, VoidCallback t) => ElevatedButton.icon(onPressed: t, icon: Icon(i, color: Colors.white, size: 18), label: Text(l, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: c, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  
  Widget _buildOutletDropdown(ThemeData theme) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedOutlet, isExpanded: true, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold), items: _outlets.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (val) { HapticFeedback.selectionClick(); setState(() => _selectedOutlet = val!); })));
  Widget _buildTimeSegmented(ThemeData theme) => SegmentedButton<TimeFilter>(showSelectedIcon: false, segments: const [ButtonSegment(value: TimeFilter.hari, label: Text('Hari')), ButtonSegment(value: TimeFilter.minggu, label: Text('Mgg')), ButtonSegment(value: TimeFilter.bulan, label: Text('Bln'))], selected: {_selectedTime}, onSelectionChanged: (val) { HapticFeedback.selectionClick(); setState(() => _selectedTime = val.first); });
  Widget _buildActionButtons(BuildContext context, ThemeData theme) { bool isAll = _selectedOutlet == 'Semua Outlet'; return Row(children: [Expanded(child: _buildBtn(Icons.inventory_2_rounded, 'Beli Stok', Colors.blue, () => _handleBtn(context, ExpenseType.modal))), const SizedBox(width: 12), Expanded(child: _buildBtn(Icons.vpn_key_rounded, 'Bayar Sewa', theme.colorScheme.error, () => _handleBtn(context, ExpenseType.sewa)))]); }
  void _handleBtn(BuildContext context, ExpenseType type) { if (_selectedOutlet == 'Semua Outlet') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Outlet spesifik dahulu dari menu di atas!'), backgroundColor: Colors.orange)); HapticFeedback.heavyImpact(); } else { _openExpenseSheet(type); } }
}