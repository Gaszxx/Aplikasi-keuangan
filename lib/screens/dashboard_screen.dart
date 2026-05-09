import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart'; // Untuk DateFormat (mengatur format tanggal di PDF)
import '../services/pdf_service.dart'; // Untuk memanggil mesin cetak PDF yang baru dibuat
// --- IMPORTS ---
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart'; 
import '../widgets/shimmer_loading.dart';
import 'debt_report_screen.dart';
import 'notification_screen.dart'; 
import 'kelapa_report_screen.dart'; 
import 'galon_report_screen.dart'; 
import 'kontrakan_report_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedFilter = 'Bulan Ini';
  DateTime? _selectedCustomDate;
  final List<String> _filterOptions = ['Hari Ini', 'Bulan Ini', 'Semua'];

  String _formatRp(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  // --- MENGGUNAKAN LOGIKA TANGGAL MANUAL BOS (ANTI-CRASH) ---
  String _getFormattedDate() {
    final date = _selectedCustomDate ?? DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // --- SAPAAN WAKTU OTOMATIS ---
  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Selamat Pagi,';
    if (hour >= 11 && hour < 15) return 'Selamat Siang,';
    if (hour >= 15 && hour < 19) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  // --- LOGIKA KALENDER KUSTOM ---
  Future<void> _selectCustomDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _selectedCustomDate = picked;
        _selectedFilter = 'Kustom';
      });
    }
  }

  // --- LOGIKA FILTER DATA TERINTEGRASI ---
  List<IncomeModel> _getFilteredIncomes(List<IncomeModel> allIncomes) {
    final now = DateTime.now();
    return allIncomes.where((income) {
      if (_selectedFilter == 'Kustom' && _selectedCustomDate != null) {
        return income.date.year == _selectedCustomDate!.year &&
               income.date.month == _selectedCustomDate!.month &&
               income.date.day == _selectedCustomDate!.day;
      }
      if (_selectedFilter == 'Hari Ini') {
        return income.date.year == now.year && income.date.month == now.month && income.date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return income.date.year == now.year && income.date.month == now.month;
      }
      return true;
    }).toList();
  }

  List<ExpenseModel> _getFilteredExpenses(List<ExpenseModel> allExpenses) {
    final now = DateTime.now();
    return allExpenses.where((expense) {
      if (_selectedFilter == 'Kustom' && _selectedCustomDate != null) {
        return expense.date.year == _selectedCustomDate!.year &&
               expense.date.month == _selectedCustomDate!.month &&
               expense.date.day == _selectedCustomDate!.day;
      }
      if (_selectedFilter == 'Hari Ini') {
        return expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return expense.date.year == now.year && expense.date.month == now.month;
      }
      return true;
    }).toList();
  }

  // --- GROWTH INDICATOR ---
  double _calculateGrowth(List<IncomeModel> allIncomes) {
    final now = DateTime.now();
    final currentMonthTotal = allIncomes.where((i) => i.date.year == now.year && i.date.month == now.month).fold(0.0, (sum, i) => sum + i.amount);
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final lastMonthTotal = allIncomes.where((i) => i.date.year == prevYear && i.date.month == prevMonth).fold(0.0, (sum, i) => sum + i.amount);

    if (lastMonthTotal == 0) return 0.0;
    return ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  // --- PULL TO REFRESH (DIKEMBALIKAN) ---
  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  // --- BOTTOM SHEET PROFIL ---
void _showProfileMenu(
    BuildContext context, 
    AuthProvider auth, 
    ThemeProvider themeProv,
    FinanceProvider finance,                 // Tambahan parameter
    List<IncomeModel> filteredIncomes,       // Tambahan parameter
    List<ExpenseModel> filteredExpenses,     // Tambahan parameter
    double totalIncome,                      // Tambahan parameter
    double totalExpense,                     // Tambahan parameter
    double netIncome,                        // Tambahan parameter
  ) {
    final theme = Theme.of(context);
    final roleName = auth.currentRole?.name.toUpperCase() ?? 'USER';
    final userName = auth.currentUserName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(userName[0].toUpperCase(), style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(userName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('Jabatan: $roleName', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: Icon(themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              title: Text(themeProv.isDarkMode ? 'Mode Terang' : 'Mode Gelap'),
              onTap: () { themeProv.toggleTheme(); Navigator.pop(ctx); },
            ),
            
            // TOMBOL EXPORT PDF
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue),
              title: const Text('Export Laporan (.pdf)'),
              subtitle: const Text('Rekening Koran', style: TextStyle(fontSize: 10)),
              onTap: () async {
                Navigator.pop(ctx); // Tutup bottom sheet
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sedang menyusun laporan...'), duration: Duration(seconds: 2)),
                );
                
                // Eksekusi fungsi cetak
                await PdfService.generateFinancialReport(
                  period: _selectedFilter == 'Kustom' && _selectedCustomDate != null 
                      ? DateFormat('dd MMM yyyy').format(_selectedCustomDate!)
                      : _selectedFilter,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netIncome: netIncome,
                  incomes: filteredIncomes,
                  expenses: filteredExpenses,
                  debts: finance.debts,
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text('Keluar Aplikasi', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () async { Navigator.pop(ctx); await auth.logout(); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();
    final themeProv = context.watch<ThemeProvider>();

    final isAdmin = auth.currentRole?.name.toLowerCase() == 'admin' || auth.currentRole?.name.toLowerCase() == 'superadmin';
    final roleName = auth.currentRole?.name.toUpperCase() ?? 'STAFF';
    final userName = auth.currentUserName;

    // Kalkulasi Keuangan dengan Pengeluaran Asli
    final filteredIncomes = _getFilteredIncomes(finance.incomes);
    final filteredExpenses = _getFilteredExpenses(finance.expenses);
    
    final totalIncome = filteredIncomes.fold(0.0, (sum, i) => sum + i.amount);
    final totalExpense = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final netIncome = totalIncome - totalExpense;
    
    final growth = _calculateGrowth(finance.incomes);

    final kelapaTotal = filteredIncomes.where((i) => i.type == IncomeType.kelapa).fold(0.0, (s, i) => s + i.amount);
    final galonTotal = filteredIncomes.where((i) => i.type == IncomeType.galon).fold(0.0, (s, i) => s + i.amount);
    final kontrakanTotal = filteredIncomes.where((i) => i.type == IncomeType.kontrakan).fold(0.0, (s, i) => s + i.amount);

    final unpaidDebtsCount = finance.debts.where((d) => !d.isPaid).length;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showProfileMenu(
                          context, 
                          auth, 
                          themeProv,
                          finance,            // Masukkan data finance
                          filteredIncomes,    // Masukkan list pemasukan yang sudah difilter
                          filteredExpenses,   // Masukkan list pengeluaran yang sudah difilter
                          totalIncome,        // Masukkan total pemasukan
                          totalExpense,       // Masukkan total pengeluaran
                          netIncome           // Masukkan kas bersih
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primary.withOpacity(0.15),
                              // Mengambil huruf pertama dari NAMA, bukan ROLE
                              child: Text(userName[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getTimeGreeting(), style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                // Menampilkan NAMA ASLI di bawah sapaan
                                Text(userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.receipt_long_rounded, color: colorScheme.onSurface),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtReportScreen())),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface, size: 28),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                              ),
                              if (unpaidDebtsCount > 0)
                                Positioned(
                                  right: 8, top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: colorScheme.error, shape: BoxShape.circle),
                                    child: Text(unpaidDebtsCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- MAIN SCROLLABLE CONTENT (DENGAN REFRESH INDICATOR & SHIMMER) ---
                Expanded(
                  child: finance.isLoading
                      ? _buildLoadingSkeleton()
                      : RefreshIndicator(
                          color: colorScheme.primary,
                          onRefresh: _handleRefresh,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              // TANGGAL & FILTER DENGAN IKON KALENDER
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_getFormattedDate(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      Text('Ringkasan Keuangan', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.calendar_month_rounded, color: _selectedFilter == 'Kustom' ? colorScheme.primary : Colors.grey),
                                        onPressed: () => _selectCustomDate(context),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedFilter == 'Kustom' ? null : _selectedFilter,
                                            hint: const Text('Tgl', style: TextStyle(fontSize: 14)),
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                                            style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                            dropdownColor: colorScheme.surface,
                                            onChanged: (v) { if (v != null) setState(() { _selectedFilter = v; _selectedCustomDate = null; }); },
                                            items: _filterOptions.map((String value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // --- FINANCIAL SUMMARY CARD ---
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Kas Bersih ($_selectedFilter)', style: theme.textTheme.labelMedium),
                                          if (_selectedFilter == 'Bulan Ini')
                                            Row(
                                              children: [
                                                Icon(growth >= 0 ? Icons.trending_up : Icons.trending_down, size: 16, color: growth >= 0 ? Colors.green : Colors.red),
                                                const SizedBox(width: 4),
                                                Text('${growth.toStringAsFixed(1)}%', style: TextStyle(color: growth >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_formatRp(netIncome), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(child: _buildMetricMiniCard(context, 'Pemasukan', _formatRp(totalIncome), AppColors.success, Icons.arrow_downward_rounded)),
                                          const SizedBox(width: 12),
                                          Expanded(child: _buildMetricMiniCard(context, 'Pengeluaran', _formatRp(totalExpense), colorScheme.error, Icons.arrow_upward_rounded)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // --- UNIT BISNIS BISA DITEKAN ---
                              Text('Pendapatan Unit Bisnis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildUnitCard(context, 'Kelapa', kelapaTotal, Icons.park_rounded, AppColors.kelapa, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KelapaReportScreen())))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUnitCard(context, 'Galon', galonTotal, Icons.water_drop_rounded, AppColors.galon, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GalonReportScreen())))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUnitCard(context, 'Kontrakan', kontrakanTotal, Icons.holiday_village_rounded, AppColors.kontrakan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KontrakanReportScreen())))),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // --- DAFTAR UTANG (DIKEMBALIKAN DETAILNYA) ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Utang & Jatuh Tempo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtReportScreen())),
                                    child: Text('Lihat Semua', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DebtListWidget(finance: finance, isAdmin: isAdmin),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildMetricMiniCard(BuildContext context, String title, String amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, String title, double amount, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(_formatRp(amount), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 150, height: 20), SizedBox(height: 20),
          ShimmerBox(width: double.infinity, height: 200, borderRadius: 20), SizedBox(height: 20),
          Row(children: [ Expanded(child: ShimmerBox(width: 100, height: 120)), SizedBox(width: 12), Expanded(child: ShimmerBox(width: 100, height: 120)) ]),
        ],
      ),
    );
  }
}

// --- EXTRACTED WIDGET FOR DEBTS ---
class _DebtListWidget extends StatelessWidget {
  final FinanceProvider finance;
  final bool isAdmin;
  const _DebtListWidget({required this.finance, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final unpaidDebts = finance.debts.where((d) => !d.isPaid).toList();
    if (unpaidDebts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text('✅ Kas aman, tidak ada utang berjalan!', style: Theme.of(context).textTheme.bodyMedium)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: unpaidDebts.length > 3 ? 3 : unpaidDebts.length, // Maksimal tampilkan 3 di dashboard
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final debt = unpaidDebts[index];
        final daysLeft = debt.dueDate.difference(DateTime.now()).inDays;
        final isCritical = daysLeft <= 3;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
              child: Icon(Icons.money_off_rounded, color: Theme.of(context).colorScheme.error),
            ),
            title: Text(debt.creditorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Tempo: ${DateFormat('dd MMM').format(debt.dueDate)} (${daysLeft < 0 ? "Telat ${daysLeft.abs()} hari" : "H-$daysLeft"})',
              style: TextStyle(color: isCritical ? Theme.of(context).colorScheme.error : null, fontSize: 12),
            ),
            trailing: Text(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(debt.amount),
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}