import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemen_keuangan/screens/expense_form_screen.dart';
import 'package:provider/provider.dart';

// --- IMPORT PROVIDER & TEMA ---
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart'; 

// --- IMPORT SCREENS ---
import 'dashboard_screen.dart';
import 'kelapa_report_screen.dart';
import 'galon_report_screen.dart';
import 'kontrakan_report_screen.dart';
import 'income_form_screen.dart';
import 'debt_form_screen.dart'; 

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _isBottomSheetOpen = false;
  
  // --- TAMBAHAN ARSITEK: KONTROLER NAVIGASI SLIDE ---
  late PageController _pageController;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const KelapaReportScreen(),
    const GalonReportScreen(),
    const KontrakanReportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller di index awal
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    // WAJIB: Bersihkan memori saat layout dihancurkan
    _pageController.dispose();
    super.dispose();
  }

  // Fungsi saat ikon navbar di-tap
  void _onTabTapped(int index) {
    if (_currentIndex == index) return; 
    
    HapticFeedback.selectionClick(); 
    
    // Alih-alih setState manual, kita perintahkan PageController meluncur.
    // Ini akan memicu fungsi onPageChanged di PageView secara otomatis.
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300), // Kecepatan meluncur
      curve: Curves.easeInOut, // Gaya animasi mulus
    );
  }

  Future<void> _openTransactionMenu() async {
    if (_isBottomSheetOpen) return;
    
    setState(() => _isBottomSheetOpen = true);
    HapticFeedback.lightImpact();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, 
      builder: (context) => const _TransactionBottomSheet(),
    );

    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _currentIndex == 0, 
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Jika back button ditekan, meluncur kembali ke Home (Index 0)
          _onTabTapped(0);
        }
      },
      child: Scaffold(
        // --- PEROMBAKAN UTAMA: MENGGUNAKAN PAGEVIEW ---
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(), // Efek membal (bouncing) saat mentok ala iOS
          onPageChanged: (index) {
            // Fungsi ini otomatis terpanggil saat layar digeser tangan
            // atau saat _pageController.animateToPage dipanggil
            setState(() {
              _currentIndex = index;
            });
          },
          children: _pages,
        ),

        // --- TOMBOL TENGAH MELAYANG (FAB) ---
        floatingActionButton: FloatingActionButton(
          onPressed: _openTransactionMenu,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        // --- NAVBAR BAWAH (Modern Notch) ---
        bottomNavigationBar: BottomAppBar(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          elevation: 10,
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
                      _buildNavItem(icon: Icons.park_rounded, label: 'Kelapa', index: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(icon: Icons.water_drop_rounded, label: 'Galon', index: 2),
                      _buildNavItem(icon: Icons.holiday_village_rounded, label: 'Kontrak', index: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KOMPONEN ITEM NAVIGASI DENGAN ANIMASI ---
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4);

    return InkWell(
      onTap: () => _onTabTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
            child: Icon(icon, color: color, size: isSelected ? 28 : 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET TERPISAH: BOTTOM SHEET TRANSAKSI (TETAP SAMA SEPERTI SEBELUMNYA)
// ============================================================================
class _TransactionBottomSheet extends StatelessWidget {
  const _TransactionBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final authProvider = context.watch<AuthProvider>();
    final isSuperAdmin = authProvider.currentRole?.name.toLowerCase() == 'superadmin' || 
                         authProvider.currentRole?.name.toLowerCase() == 'admin';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text('Catat Transaksi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Pilih jenis pencatatan yang ingin Anda masukkan.', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        label: 'Pemasukan',
                        icon: Icons.arrow_downward_rounded,
                        color: Colors.green, 
                        onTap: () {
                          Navigator.pop(context); 
                          if (!context.mounted) return; 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const IncomeFormScreen()));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionCard(
                        label: 'Pengeluaran',
                        icon: Icons.arrow_upward_rounded,
                        color: theme.colorScheme.error, 
                        onTap: () {
                          Navigator.pop(context);
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseFormScreen()));
                        },
                      ),
                    ),
                  ],
                ),
                
                if (isSuperAdmin) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(flex: 1), 
                      Expanded(
                        flex: 2, 
                        child: _ActionCard(
                          label: 'Utang Pribadi / Cicilan',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.orange.shade700,
                          onTap: () {
                            Navigator.pop(context);
                            if (!context.mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const DebtFormScreen()));
                          },
                        ),
                      ),
                      const Spacer(flex: 1), 
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label, required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surface,
              radius: 24,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}