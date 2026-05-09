import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// --- IMPORTS ---
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/income_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart'; // Import AppStyles untuk radius
import '../widgets/shimmer_loading.dart';
import 'debt_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedFilter = 'Bulan Ini';
  final List<String> _filterOptions = ['Hari Ini', 'Bulan Ini', 'Semua'];

  String _formatRp(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // --- LOGIKA FILTER DATA ---
  List<IncomeModel> _getFilteredIncomes(List<IncomeModel> allIncomes) {
    final now = DateTime.now();
    return allIncomes.where((income) {
      if (_selectedFilter == 'Hari Ini') {
        return income.date.year == now.year && income.date.month == now.month && income.date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return income.date.year == now.year && income.date.month == now.month;
      }
      return true;
    }).toList();
  }

  // ASUMSI: Provider memiliki list expenses. Ganti tipe datanya jika berbeda.
  List<dynamic> _getFilteredExpenses(List<dynamic> allExpenses) {
    final now = DateTime.now();
    return allExpenses.where((expense) {
      if (_selectedFilter == 'Hari Ini') {
        return expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return expense.date.year == now.year && expense.date.month == now.month;
      }
      return true;
    }).toList();
  }

  double _calculateGrowth(List<IncomeModel> allIncomes) {
    final now = DateTime.now();
    final currentMonthTotal = allIncomes.where((i) => i.date.year == now.year && i.date.month == now.month).fold(0.0, (sum, i) => sum + i.amount);
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final lastMonthTotal = allIncomes.where((i) => i.date.year == prevYear && i.date.month == prevMonth).fold(0.0, (sum, i) => sum + i.amount);

    if (lastMonthTotal == 0) return 0.0;
    return ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  // --- BOTTOM SHEET PROFIL ---
  void _showProfileMenu(BuildContext context, AuthProvider auth, ThemeProvider themeProv) {
    final theme = Theme.of(context);
    final roleName = auth.currentRole?.name.toUpperCase() ?? 'USER';

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
              child: Text(roleName[0], style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(roleName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('Akses Terverifikasi', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: Icon(themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              title: Text(themeProv.isDarkMode ? 'Mode Terang' : 'Mode Gelap'),
              onTap: () {
                themeProv.toggleTheme();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text('Keluar Aplikasi', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                await auth.logout();
              },
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

    // Perhitungan Pemasukan
    final filteredIncomes = _getFilteredIncomes(finance.incomes);
    final totalIncome = filteredIncomes.fold(0.0, (sum, i) => sum + i.amount);
    
    // Perhitungan Pengeluaran (Asumsi FinanceProvider punya 'expenses'. Jika belum ada, set 0 sementara)
    // final filteredExpenses = _getFilteredExpenses(finance.expenses);
    // final totalExpense = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalExpense = 0.0; // TODO: Ganti dengan perhitungan expense asli jika sudah siap
    
    final netIncome = totalIncome - totalExpense;

    final kelapaTotal = filteredIncomes.where((i) => i.type == IncomeType.kelapa).fold(0.0, (s, i) => s + i.amount);
    final galonTotal = filteredIncomes.where((i) => i.type == IncomeType.galon).fold(0.0, (s, i) => s + i.amount);
    final kontrakanTotal = filteredIncomes.where((i) => i.type == IncomeType.kontrakan).fold(0.0, (s, i) => s + i.amount);

    final unpaidDebtsCount = finance.debts.where((d) => !d.isPaid).length;

    return Scaffold(
      body: SafeArea(
        child: Center(
          // RESPONSIVE: Mencegah tampilan melar di Tablet/Web
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
                        onTap: () => _showProfileMenu(context, auth, themeProv),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.primary.withOpacity(0.15),
                              child: Text(roleName[0], style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Selamat datang,', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text(roleName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                              Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface, size: 28),
                              if (unpaidDebtsCount > 0)
                                Positioned(
                                  right: 2, top: 2,
                                  child: Container(width: 10, height: 10, decoration: BoxDecoration(color: colorScheme.error, shape: BoxShape.circle)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- MAIN SCROLLABLE CONTENT ---
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
                              // TANGGAL & FILTER
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedFilter,
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                                        style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                        dropdownColor: colorScheme.surface,
                                        onChanged: (v) { if (v != null) setState(() => _selectedFilter = v); },
                                        items: _filterOptions.map((String value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // --- FINANCIAL SUMMARY CARD (ENTERPRISE STANDARD) ---
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kas Bersih ($_selectedFilter)', style: theme.textTheme.labelMedium),
                                      const SizedBox(height: 4),
                                      Text(_formatRp(netIncome), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildMetricMiniCard(context, 'Pemasukan', _formatRp(totalIncome), AppColors.success, Icons.arrow_downward_rounded),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildMetricMiniCard(context, 'Pengeluaran', _formatRp(totalExpense), colorScheme.error, Icons.arrow_upward_rounded),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // --- UNIT BISNIS ---
                              Text('Pendapatan Unit Bisnis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildUnitCard(context, 'Kelapa', kelapaTotal, Icons.park_rounded, AppColors.kelapa)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUnitCard(context, 'Galon', galonTotal, Icons.water_drop_rounded, AppColors.galon)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildUnitCard(context, 'Kontrakan', kontrakanTotal, Icons.holiday_village_rounded, AppColors.kontrakan)),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // --- DAFTAR UTANG ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Utang & Jatuh Tempo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  Text('Lihat Semua', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
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

  // --- SUB-WIDGETS (Extracted for Clean Code) ---

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

  Widget _buildUnitCard(BuildContext context, String title, double amount, IconData icon, Color color) {
    return Card(
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
      itemCount: unpaidDebts.length,
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