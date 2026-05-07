import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'income_form_screen.dart';
import 'kelapa_report_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Index 0 sekarang adalah Home (Dashboard)
  int _currentIndex = 0;

  // Daftar halaman berdasarkan urutan index (Maksimal 4 ikon)
final List<Widget> _pages = [
    const DashboardScreen(), // Index 0 (HOME)
    const KelapaReportScreen(), // <--- INI KITA GANTI (Index 1)
    const PlaceholderScreen(
      title: 'Rekap Galon',
      icon: Icons.water_drop,
      color: Colors.lightBlueAccent,
    ), // Index 2
    const PlaceholderScreen(
      title: 'Rekap Kontrakan',
      icon: Icons.house,
      color: Colors.purpleAccent,
    ), // Index 3
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // --- FUNGSI MUNCULKAN MENU "TAMBAH TRANSAKSI" ---
  void _showAddTransactionMenu(
    BuildContext context,
    Color bgColor,
    Color primaryColor,
    Color textColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Jenis Transaksi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildActionMenuBtn(
                      context,
                      'Pemasukan',
                      Icons.arrow_downward,
                      primaryColor,
                      () {
                        Navigator.pop(context); // Tutup menu
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const IncomeFormScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionMenuBtn(
                      context,
                      'Utang Baru',
                      Icons.arrow_upward,
                      AppColors.error,
                      () {
                        Navigator.pop(context); // Tutup menu
                        debugPrint("Arahkan ke Form Utang");
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionMenuBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color dynamicPrimary = isDark
        ? AppColors.primary
        : const Color(0xFF007A3D);
    final unselectedIconColor = isDark ? Colors.white54 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: _pages),

      // TOMBOL TENGAH: TAMBAH (+)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionMenu(
          context,
          surfaceColor,
          dynamicPrimary,
          textColor,
        ),
        backgroundColor: dynamicPrimary,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

// NAVBAR BAWAH
      bottomNavigationBar: BottomAppBar(
        color: surfaceColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // KELOMPOK KIRI
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                        icon: Icons.home_filled, 
                        label: 'Home', 
                        index: 0, 
                        primaryColor: dynamicPrimary, 
                        unselectedColor: unselectedIconColor), // <-- Tambahkan ini
                    _buildNavItem(
                        icon: Icons.nature, 
                        label: 'Kelapa', 
                        index: 1, 
                        primaryColor: dynamicPrimary, 
                        unselectedColor: unselectedIconColor), // <-- Tambahkan ini
                  ],
                ),
              ),
              // RUANG KOSONG UNTUK TOMBOL (+) TENGAH
              const SizedBox(width: 48), 
              // KELOMPOK KANAN
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                        icon: Icons.water_drop, 
                        label: 'Galon', 
                        index: 2, 
                        primaryColor: dynamicPrimary, 
                        unselectedColor: unselectedIconColor), // <-- Tambahkan ini
                    _buildNavItem(
                        icon: Icons.house, 
                        label: 'Kontrak', 
                        index: 3, 
                        primaryColor: dynamicPrimary, 
                        unselectedColor: unselectedIconColor), // <-- Tambahkan ini
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color primaryColor,
    required Color unselectedColor,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? primaryColor : unselectedColor;

    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// --- LAYAR SEMENTARA (Placeholder) ---
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: color.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            'Halaman $title\nSegera Hadir',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
