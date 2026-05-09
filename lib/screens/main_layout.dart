import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemen_keuangan/screens/expense_form_screen.dart';
import 'package:provider/provider.dart';

// --- IMPORT PROVIDER & TEMA ---
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart'; // Aktifkan jika nanti dibutuhkan di layout

// --- IMPORT SCREENS ---
import 'dashboard_screen.dart';
import 'kelapa_report_screen.dart';
import 'galon_report_screen.dart';
import 'kontrakan_report_screen.dart';
import 'income_form_screen.dart';
import 'debt_form_screen.dart'; // Pastikan file ini ada jika ingin diarahkan

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Gunakan index untuk navigasi
  int _currentIndex = 0;
  
  // QA Check: Mencegah user spam klik tombol FAB berkali-kali
  bool _isBottomSheetOpen = false;

  // Daftar Halaman (Sesuai urutan Navbar)
  final List<Widget> _pages = [
    const DashboardScreen(),
    const KelapaReportScreen(),
    const GalonReportScreen(),
    const KontrakanReportScreen(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return; // Cegah re-render jika klik tab yang sama
    
    HapticFeedback.selectionClick(); // Getaran premium ala iOS
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openTransactionMenu() async {
    // Mencegah Double-Tap (Spam Klik)
    if (_isBottomSheetOpen) return;
    
    setState(() => _isBottomSheetOpen = true);
    HapticFeedback.lightImpact();

    // Tampilkan Bottom Sheet yang sudah dipisah menjadi komponen tersendiri
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Agar aman jika isi form nanti bertambah
      builder: (context) => const _TransactionBottomSheet(),
    );

    // Setelah Bottom Sheet ditutup, kembalikan status
    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // QA Check: PopScope untuk mencegah aplikasi langsung keluar saat tombol Back Android ditekan
    return PopScope(
      canPop: _currentIndex == 0, // Hanya bisa pop (keluar) jika di halaman Home
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Jika bukan di Home, kembalikan dulu ke Home (Index 0)
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        // IndexedStack menjaga state scroll tiap layar agar tidak reset saat pindah tab
        body: IndexedStack(
          index: _currentIndex,
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
                // Kelompok Kiri
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
                      _buildNavItem(icon: Icons.park_rounded, label: 'Kelapa', index: 1),
                    ],
                  ),
                ),
                // Ruang kosong untuk FAB di tengah
                const SizedBox(width: 48),
                // Kelompok Kanan
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
          // Animasi melompat sedikit ke atas saat dipilih
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
// WIDGET TERPISAH: BOTTOM SHEET TRANSAKSI (Clean Architecture)
// ============================================================================
class _TransactionBottomSheet extends StatelessWidget {
  const _TransactionBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // SECURITY: Ambil role user saat ini dari AuthProvider
    final authProvider = context.watch<AuthProvider>();
    final isSuperAdmin = authProvider.currentRole?.name.toLowerCase() == 'superadmin' || 
                         authProvider.currentRole?.name.toLowerCase() == 'admin';

    return SafeArea(
      child: Center(
        // RESPONSIVE: Mengunci lebar form agar tidak melar di Tablet
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
              mainAxisSize: MainAxisSize.min, // Menyesuaikan tinggi dengan isi
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Garis kecil di atas modal (Drag handle indicator)
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
                
                Text(
                  'Catat Transaksi',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih jenis pencatatan yang ingin Anda masukkan.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                
                // BARIS 1: Pemasukan & Pengeluaran Operasional (Muncul untuk semua user)
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        label: 'Pemasukan',
                        icon: Icons.arrow_downward_rounded,
                        color: Colors.green, // Warna universal untuk uang masuk
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
                        color: theme.colorScheme.error, // Warna merah untuk uang keluar
                        onTap: () {
                          Navigator.pop(context);
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseFormScreen()));
                        },
                      ),
                    ),
                  ],
                ),
                
                // BARIS 2: Utang Baru (SECURITY CHECK: Hanya muncul jika user adalah Admin)
                if (isSuperAdmin) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Ruang kosong penyeimbang di kiri
                      const Spacer(flex: 1), 
                      
                      // Tombol utama tepat di tengah
                      Expanded(
                        flex: 2, // Menggunakan rasio 2/4 agar lebarnya pas dengan tombol di atasnya
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
                      
                      // Ruang kosong penyeimbang di kanan
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

// Widget Bantuan untuk Kartu Menu di dalam Bottom Sheet
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
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}