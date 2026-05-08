import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/income_model.dart';
import '../theme/app_colors.dart';
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
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  List<IncomeModel> _getFilteredIncomes(List<IncomeModel> allIncomes) {
    final now = DateTime.now();
    return allIncomes.where((income) {
      if (_selectedFilter == 'Hari Ini') {
        return income.date.year == now.year &&
            income.date.month == now.month &&
            income.date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return income.date.year == now.year && income.date.month == now.month;
      }
      return true;
    }).toList();
  } // <--- PASTI KAN ADA TUTUP KURUNG INI SEBELUM LANJUT KE FUNGSI BERIKUTNYA

  // 2. Fungsi Hitung Pertumbuhan (BERDIRI SENDIRI)
  double _calculateGrowth(List<IncomeModel> allIncomes) {
    final now = DateTime.now();

    final currentMonthTotal = allIncomes
        .where((i) => i.date.year == now.year && i.date.month == now.month)
        .fold(0.0, (sum, i) => sum + i.amount);

    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;

    final lastMonthTotal = allIncomes
        .where((i) => i.date.year == prevYear && i.date.month == prevMonth)
        .fold(0.0, (sum, i) => sum + i.amount);

    if (lastMonthTotal == 0) return 0.0;
    return ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  void _showDeleteConfirm(
    BuildContext context,
    VoidCallback onConfirm,
    Color primaryColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Hapus'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus data ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FITUR BARU: MENU PROFIL (BOTTOM SHEET) ---
  void _showProfileMenu(
    BuildContext context,
    AuthProvider auth,
    ThemeProvider themeProv,
    Color bgColor,
    Color textColor,
  ) {
    final roleName = auth.currentRole.name.toUpperCase();
    final isDark = themeProv.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                roleName[0],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Text(
              'Akses Terverifikasi',
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.amber : Colors.blueGrey,
              ),
              title: Text(
                isDark ? 'Ganti ke Mode Terang' : 'Ganti ke Mode Gelap',
              ),
              onTap: () {
                themeProv.toggleTheme();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Keluar Aplikasi',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await auth.logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = context.watch<FinanceProvider>();
    final themeProv = context.watch<ThemeProvider>();

    final isAdmin = auth.currentRole == UserRole.admin;
    final roleName = auth.currentRole.name.toUpperCase();

    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final textSubColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final Color dynamicPrimary = isDark
        ? AppColors.primary
        : const Color(0xFF007A3D);

    final filteredIncomes = _getFilteredIncomes(finance.incomes);
    final filteredIncomeTotal = filteredIncomes.fold(
      0.0,
      (sum, i) => sum + i.amount,
    );

    double kelapaTotal = filteredIncomes
        .where((i) => i.type == IncomeType.kelapa)
        .fold(0, (s, i) => s + i.amount);
    double galonTotal = filteredIncomes
        .where((i) => i.type == IncomeType.galon)
        .fold(0, (s, i) => s + i.amount);
    double kontrakanTotal = filteredIncomes
        .where((i) => i.type == IncomeType.kontrakan)
        .fold(0, (s, i) => s + i.amount);

    final unpaidDebtsCount = finance.debts.where((d) => !d.isPaid).length;
    final growthPercentage = _calculateGrowth(finance.incomes);
    final isPositiveGrowth = growthPercentage >= 0;

    final boxDecoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER TERBARU (AVATAR & NOTIFIKASI) ---
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sisi Kiri: Avatar & Sapaan
                  GestureDetector(
                    onTap: () => _showProfileMenu(
                      context,
                      auth,
                      themeProv,
                      cardColor,
                      textColor,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: dynamicPrimary.withOpacity(0.2),
                          child: Text(
                            roleName[0],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dynamicPrimary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selamat datang,',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSubColor,
                              ),
                            ),
                            Text(
                              roleName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Sisi Kanan: Lonceng Pintar
                  // Sisi Kanan: Ikon Tema & Lonceng Pintar
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.menu_book_rounded,
                              color: textColor,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DebtReportScreen(),
                                ),
                              );
                            },
                          ),
                          // Titik merah muncul jika ada hutang telat (hasOverdueDebt)
                          if (finance.hasOverdueDebt)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.error, // Warna merah
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // --- TOMBOL GANTI TEMA ---
                      IconButton(
                        icon: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: isDark ? Colors.amber : Colors.blueGrey,
                        ),
                        onPressed: () => themeProv.toggleTheme(),
                      ),
                      const SizedBox(
                        width: 8,
                      ), // Jarak antara matahari dan lonceng
                      // --- LONCENG NOTIFIKASI ---
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            color: textColor,
                            size: 28,
                          ),
                          if (unpaidDebtsCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- KONTEN SCROLL & REFRESH ---
            Expanded(
              child: finance.isLoading
                  ? _buildLoadingSkeleton()
                  : RefreshIndicator(
                      color: dynamicPrimary,
                      onRefresh: _handleRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getFormattedDate(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Semangat buat harinya <3',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: dynamicPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dynamicPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFilter,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: dynamicPrimary,
                                      ),
                                      style: TextStyle(
                                        color: dynamicPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      dropdownColor: cardColor,
                                      onChanged: (String? newValue) {
                                        if (newValue != null)
                                          setState(
                                            () => _selectedFilter = newValue,
                                          );
                                      },
                                      items: _filterOptions
                                          .map<DropdownMenuItem<String>>((
                                            String value,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24.0),
                              decoration: boxDecoration.copyWith(
                                border: Border.all(
                                  color: dynamicPrimary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Pemasukan ($_selectedFilter)',
                                    style: TextStyle(
                                      color: textSubColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatRp(filteredIncomeTotal),
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: dynamicPrimary,
                                    ),
                                  ),
                                  if (growthPercentage != 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (isPositiveGrowth
                                                      ? dynamicPrimary
                                                      : AppColors.error)
                                                  .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPositiveGrowth
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: isPositiveGrowth
                                                  ? dynamicPrimary
                                                  : AppColors.error,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${isPositiveGrowth ? "Naik" : "Turun"} ${growthPercentage.abs().toStringAsFixed(1)}% dari bulan lalu',
                                              style: TextStyle(
                                                color: isPositiveGrowth
                                                    ? dynamicPrimary
                                                    : AppColors.error,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  _buildHorizontalChart(
                                    kelapaTotal,
                                    galonTotal,
                                    kontrakanTotal,
                                    borderColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            Text(
                              'Rincian Pemasukan Bisnis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCategoryCard(
                                    'Kelapa',
                                    kelapaTotal,
                                    Icons.nature,
                                    Colors.orangeAccent,
                                    boxDecoration,
                                    textColor,
                                    textSubColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCategoryCard(
                                    'Galon',
                                    galonTotal,
                                    Icons.water_drop,
                                    Colors.lightBlueAccent,
                                    boxDecoration,
                                    textColor,
                                    textSubColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCategoryCard(
                                    'Kontrakan',
                                    kontrakanTotal,
                                    Icons.house,
                                    Colors.purpleAccent,
                                    boxDecoration,
                                    textColor,
                                    textSubColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            _buildSectionHeader(
                              'Utang & Kewajiban',
                              dynamicPrimary,
                            ),
                            const SizedBox(height: 12),
                            _buildDebtsSection(
                              finance,
                              isAdmin,
                              boxDecoration,
                              textColor,
                              textSubColor,
                              dynamicPrimary,
                            ),
                            const SizedBox(height: 32),

                            _buildSectionHeader(
                              'Riwayat Pemasukan',
                              dynamicPrimary,
                            ),
                            const SizedBox(height: 12),
                            _buildRecentIncomes(
                              filteredIncomes,
                              finance,
                              isAdmin,
                              cardColor,
                              textColor,
                              textSubColor,
                              dynamicPrimary,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        InkWell(
          onTap: () {},
          child: Text(
            'Lihat Semua >',
            style: TextStyle(
              fontSize: 12,
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalChart(
    double kelapa,
    double galon,
    double kontrakan,
    Color emptyColor,
  ) {
    final total = kelapa + galon + kontrakan;
    if (total == 0)
      return Container(
        height: 8,
        width: double.infinity,
        decoration: BoxDecoration(
          color: emptyColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (kelapa > 0)
              Expanded(
                flex: (kelapa / total * 100).toInt(),
                child: Container(color: Colors.orangeAccent),
              ),
            if (galon > 0)
              Expanded(
                flex: (galon / total * 100).toInt(),
                child: Container(color: Colors.lightBlueAccent),
              ),
            if (kontrakan > 0)
              Expanded(
                flex: (kontrakan / total * 100).toInt(),
                child: Container(color: Colors.purpleAccent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    BoxDecoration baseDeco,
    Color textColor,
    Color subColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: baseDeco.copyWith(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: subColor)),
          const SizedBox(height: 4),
          Text(
            _formatRp(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsSection(
    FinanceProvider finance,
    bool isAdmin,
    BoxDecoration baseDeco,
    Color textColor,
    Color subColor,
    Color primaryColor,
  ) {
    final unpaidDebts = finance.debts.where((d) => !d.isPaid).toList();
    if (unpaidDebts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: baseDeco,
        child: Text(
          '✅ Bersih dari utang!',
          textAlign: TextAlign.center,
          style: TextStyle(color: subColor),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: unpaidDebts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final debt = unpaidDebts[index];
        final daysLeft = debt.dueDate.difference(DateTime.now()).inDays;
        return Container(
          decoration: baseDeco,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.error.withOpacity(0.15),
              child: const Icon(Icons.money_off, color: AppColors.error),
            ),
            title: Text(
              debt.creditorName,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            subtitle: Text(
              'Tempo: ${DateFormat('dd MMM yyyy').format(debt.dueDate)}\n${daysLeft < 0 ? "Terlambat ${daysLeft.abs()} hari" : "H-$daysLeft"}',
              style: TextStyle(
                color: daysLeft <= 3 ? AppColors.error : subColor,
                height: 1.4,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatRp(debt.amount),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isAdmin)
                          InkWell(
                            onTap: () =>
                                finance.toggleDebtStatus(debt.id, debt.isPaid),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        if (isAdmin) const SizedBox(width: 8),
                        if (isAdmin)
                          InkWell(
                            onTap: () => _showDeleteConfirm(
                              context,
                              () => finance.deleteDebt(debt.id),
                              primaryColor,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.delete,
                                size: 16,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentIncomes(
    List<IncomeModel> sourceIncomes,
    FinanceProvider finance,
    bool isAdmin,
    Color cardColor,
    Color textColor,
    Color subColor,
    Color primaryColor,
  ) {
    if (sourceIncomes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Belum ada transaksi di periode ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subColor),
        ),
      );
    }

    final recentIncomes = sourceIncomes.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentIncomes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final income = recentIncomes[index];
          IconData catIcon;
          Color catColor;
          if (income.type == IncomeType.kelapa) {
            catIcon = Icons.nature;
            catColor = Colors.orangeAccent;
          } else if (income.type == IncomeType.galon) {
            catIcon = Icons.water_drop;
            catColor = Colors.lightBlueAccent;
          } else {
            catIcon = Icons.house;
            catColor = Colors.purpleAccent;
          }

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(catIcon, color: catColor),
            ),
            title: Text(
              income.type.name.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              DateFormat('dd MMM yyyy, HH:mm').format(income.date),
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+ ${_formatRp(income.amount)}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () => _showDeleteConfirm(
                      context,
                      () => finance.deleteIncome(income.id),
                      primaryColor,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 250, height: 30), // Skeleton Tanggal
          const SizedBox(height: 8),
          const ShimmerBox(width: 150, height: 15), // Skeleton Sapaan
          const SizedBox(height: 24),
          const ShimmerBox(
            width: double.infinity,
            height: 180,
            borderRadius: 24,
          ), // Skeleton Kartu Utama
          const SizedBox(height: 32),
          const ShimmerBox(width: 200, height: 20), // Judul Bisnis
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: ShimmerBox(width: 100, height: 100),
              ), // Box Kelapa
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: 100, height: 100)), // Box Galon
              SizedBox(width: 12),
              Expanded(
                child: ShimmerBox(width: 100, height: 100),
              ), // Box Kontrakan
            ],
          ),
          const SizedBox(height: 32),
          const ShimmerBox(width: 180, height: 20), // Judul Utang
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 80), // List Utang 1
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 80), // List Utang 2
        ],
      ),
    );
  }
}
