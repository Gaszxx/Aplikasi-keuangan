import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/door_model.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';

class KontrakanReportScreen extends StatefulWidget {
  const KontrakanReportScreen({super.key});

  @override
  State<KontrakanReportScreen> createState() => _KontrakanReportScreenState();
}

class _KontrakanReportScreenState extends State<KontrakanReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _searchQuery = '';
  String _filterType = 'Semua';
  final List<String> _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  void _ubahBulan(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Tema Warna Khusus Kontrakan (Ungu)
    final kontrakanColor = theme.brightness == Brightness.dark ? Colors.deepPurpleAccent : Colors.deepPurple;
    final now = DateTime.now();

    // --- 1. LOGIKA SORTING PINTU ---
    List<DoorModel> sortedDoors = List.from(finance.doors);
    sortedDoors.sort((a, b) {
      int numA = int.tryParse(a.roomNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int numB = int.tryParse(b.roomNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });

    // --- 2. FILTER DATA (QA SECURED) ---
    var kontrakanIncomes = finance.incomes.where((i) => i.type == IncomeType.kontrakan).toList();
    var kontrakanExpenses = finance.expenses.where((e) => e.unitBisnis == 'Kontrakan').toList();

    // Filter Berdasarkan Bulan Pilihan
    var monthlyIncomes = kontrakanIncomes.where((i) => i.date.month == _selectedMonth.month && i.date.year == _selectedMonth.year).toList();
    var monthlyExpenses = kontrakanExpenses.where((e) => e.date.month == _selectedMonth.month && e.date.year == _selectedMonth.year).toList();

    double omsetBulanIni = monthlyIncomes.fold(0.0, (sum, i) => sum + i.amount);
    double pengeluaranBulanIni = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);
    double labaBersihBulanIni = omsetBulanIni - pengeluaranBulanIni;

    // Riwayat Gabungan
    List<dynamic> combinedHistory = [...kontrakanIncomes, ...kontrakanExpenses];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date));
    var monthlyHistory = combinedHistory.where((item) => item.date.month == _selectedMonth.month && item.date.year == _selectedMonth.year).toList();
    // --- TAMBAHAN: LOGIKA PENCARIAN & FILTER ---
    var filteredHistory = monthlyHistory.where((item) {
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
    
    // --- 3. HITUNG STATISTIK POTENSI ---
    int totalPintu = sortedDoors.length;
    int terisi = sortedDoors.where((d) => !d.isEmpty).length;
    double potensiIncome = sortedDoors.where((d) => !d.isEmpty).fold(0.0, (sum, d) => sum + d.monthlyPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Kontrakan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_home_work_rounded, color: kontrakanColor),
            tooltip: 'Tambah Pintu',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAddDoorModal(context, sortedDoors);
            },
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // HEADER
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.holiday_village_rounded, size: 48, color: kontrakanColor),
                      const SizedBox(height: 8),
                      Text('KONTRAKAN BIDADARI', style: TextStyle(color: kontrakanColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('Pemantauan Pintu & Penagihan', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // KARTU ESTIMASI TAGIHAN (POTENSI)
                _buildSummaryCard(terisi, totalPintu, potensiIncome, kontrakanColor),
                const SizedBox(height: 20),

                // KARTU PENDAPATAN REAL (NETTO)
                _buildOmsetCard(theme, omsetBulanIni, pengeluaranBulanIni, labaBersihBulanIni, kontrakanColor),
                const SizedBox(height: 24),

                // TOMBOL PENGELUARAN (Token Listrik, Sedot WC, dll)
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _openExpenseSheet(kontrakanColor);
                    },
                    icon: const Icon(Icons.handyman_rounded, color: Colors.white),
                    label: const Text('Input Biaya Perbaikan / Ops', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text('Status Pintu (Bulan Ini)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // GRID PINTU
                sortedDoors.isEmpty 
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40), 
                      child: Text("Belum ada data pintu.\nKlik ikon + di kanan atas untuk menambah.", textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
                    )
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
                    ),
                    itemCount: sortedDoors.length,
                    itemBuilder: (context, index) {
                      final door = sortedDoors[index];
                      
                      Color statusColor = Colors.grey; 
                      if (!door.isEmpty) {
                        bool sudahBayarBulanIni = door.lastPaymentDate != null && 
                                                  door.lastPaymentDate!.month == now.month && 
                                                  door.lastPaymentDate!.year == now.year;
                        bool sudahLewatJatuhTempo = now.day > door.dueDate;

                        if (sudahBayarBulanIni) {
                          statusColor = Colors.green; 
                        } else if (sudahLewatJatuhTempo) {
                          statusColor = colorScheme.error; 
                        } else {
                          statusColor = Colors.orange; 
                        }
                      }

                      return _buildDoorBox(context, theme, door, statusColor);
                    },
                  ),

                const SizedBox(height: 40),

                // RIWAYAT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Riwayat Transaksi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${monthlyHistory.length} Transaksi', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                  ],
                ),
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
                _buildUnifiedHistoryList(monthlyHistory, theme, kontrakanColor,isSuperAdmin),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KOMPONEN UI ---

  Widget _buildOmsetCard(ThemeData theme, double kotor, double ops, double bersih, Color primary) {
    String bulanStr = "${_namaBulan[_selectedMonth.month - 1]} ${_selectedMonth.year}";
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _ubahBulan(-1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(bulanStr, style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded), 
                onPressed: (_selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year) 
                    ? null 
                    : () => _ubahBulan(1)
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('KAS BERSIH BULAN INI (NETTO)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(bersih), 
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primary)
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(theme, 'Uang Masuk', _formatRp(kotor), Colors.green),
              Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3)),
              _buildMiniStat(theme, 'Uang Keluar', _formatRp(ops), theme.colorScheme.error),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int terisi, int total, double income, Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Okupansi", "$terisi/$total", "Pintu Terisi"),
          _buildStatItem("Total Tagihan", _formatRp(income), "Estimasi Uang Masuk"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildDoorBox(BuildContext context, ThemeData theme, DoorModel door, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoorActionModal(context, door);
      },
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), 
          side: BorderSide(color: color.withOpacity(0.5), width: 2) // <-- QA Fixed: Menggunakan BorderSide
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Pintu", style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            Text(door.roomNumber, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                door.isEmpty ? "KOSONG" : door.tenantName, 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)
              ),
            ),
            if(!door.isEmpty) 
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text("Tgl ${door.dueDate}", style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

Widget _buildUnifiedHistoryList(List<dynamic> list, ThemeData theme, Color kontrakanColor, bool isSuperAdmin) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20), 
          child: Text('Belum ada transaksi di bulan ini', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
        )
      );
    }
    
    return ListView.builder(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length > 15 ? 15 : list.length, 
      itemBuilder: (context, index) {
        final item = list[index];
        bool isIncome = item is IncomeModel;
        
        IconData icon = isIncome ? Icons.receipt_long_rounded : Icons.handyman_rounded;
        Color color = isIncome ? Colors.green : theme.colorScheme.error;
        String title = isIncome ? (item.description ?? 'Sewa Kontrakan') : "Perbaikan: ${item.description}";
        String trailing = isIncome ? "+ ${_formatRp(item.amount)}" : "- ${_formatRp(item.amount)}";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: color.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.2))),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 20)),
            title: Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(item.date), style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey, fontSize: 10)),
            // --- BAGIAN TONG SAMPAH ---
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trailing, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                
                // MUNCULKAN TONG SAMPAH HANYA JIKA SUPERADMIN
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
  
  Widget _buildMiniStat(ThemeData theme, String t, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(t, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)), const SizedBox(height: 4), Text(v, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: c))]);
  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);

  // --- MODALS ---

  void _openExpenseSheet(Color primaryColor) {
    final ctrlNominal = TextEditingController();
    String selectedKategori = 'Token Listrik';
    final List<String> kategoriList = ['Token Listrik', 'Sedot WC', 'Perbaikan Bangunan', 'Kebersihan/Sampah', 'Lainnya'];

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
                
                Text('Biaya Operasional Kosan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      double val = double.tryParse(ctrlNominal.text) ?? 0;
                      if (val > 0) {
                        context.read<FinanceProvider>().addExpense(ExpenseModel(
                          id: '', 
                          type: ExpenseType.operasional, 
                          unitBisnis: 'Kontrakan', // QA: KEAMANAN DATA MUTLAK
                          amount: val,
                          date: DateTime.now(), 
                          outlet: 'Pusat', 
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

  void _showAddDoorModal(BuildContext context, List<DoorModel> existingDoors) {
    // Implementasi Modal Tambah Pintu yang disempurnakan (sama dengan milik Anda, ditambah haptic dan UI match)
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: "1");
    bool currentEmpty = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) {
          final theme = Theme.of(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  const Text("Tambah Pintu Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(controller: numCtrl, keyboardType: TextInputType.text, decoration: InputDecoration(labelText: "Nomor Pintu (Contoh: 1)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text("Kamar Kosong?", style: TextStyle(fontWeight: FontWeight.bold)),
                    value: currentEmpty, 
                    activeColor: theme.colorScheme.primary,
                    onChanged: (v) { HapticFeedback.lightImpact(); setMState(() => currentEmpty = v); },
                  ),
                  if(!currentEmpty) ...[
                    const SizedBox(height: 10),
                    TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Nama Penghuni", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Harga Sewa / Bulan (Rp)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: dateCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Tanggal Tagihan (1-31)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ],
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        String newRoomNum = numCtrl.text.trim();
                        if (newRoomNum.isEmpty) return;

                        if (existingDoors.any((d) => d.roomNumber.toLowerCase() == newRoomNum.toLowerCase())) {
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal! Pintu nomor tersebut sudah ada."), backgroundColor: Colors.red));
                          return;
                        }

                        final newDoor = DoorModel(
                          id: '', roomNumber: newRoomNum,
                          tenantName: currentEmpty ? "" : nameCtrl.text.trim(),
                          monthlyPrice: double.tryParse(priceCtrl.text) ?? 0,
                          dueDate: int.tryParse(dateCtrl.text) ?? 1,
                          isEmpty: currentEmpty,
                        );
                        context.read<FinanceProvider>().addDoor(newDoor);
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text("Simpan Pintu", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _showDoorActionModal(BuildContext context, DoorModel door) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Pintu ${door.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                  IconButton(icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error), onPressed: () { Navigator.pop(ctx); _confirmDelete(context, door); }),
                ],
              ),
              if(!door.isEmpty) ...[
                Text("Penghuni: ${door.tenantName}", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text("Tagihan: ${_formatRp(door.monthlyPrice)} / Bulan", style: const TextStyle(color: Colors.grey)),
              ] else ...[
                const Text("Status: KOSONG", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 25),
              
              if(!door.isEmpty)
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: const Text("TERIMA BAYAR SEKARANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final income = IncomeModel(
                        id: '', type: IncomeType.kontrakan, amount: door.monthlyPrice, 
                        date: DateTime.now(), submittedBy: 'Owner', description: "Sewa Pintu ${door.roomNumber} (${door.tenantName})", doorNumber: door.roomNumber,
                      );
                      context.read<FinanceProvider>().addIncome(income);
                      final updatedDoor = DoorModel(
                        id: door.id, roomNumber: door.roomNumber, tenantName: door.tenantName,
                        monthlyPrice: door.monthlyPrice, dueDate: door.dueDate, isEmpty: false, lastPaymentDate: DateTime.now(),
                      );
                      context.read<FinanceProvider>().updateDoor(updatedDoor);
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil! Pintu kembali Hijau ✅"), backgroundColor: Colors.green));
                    },
                  ),
                ),
              
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings_rounded), label: const Text("Ubah Setting / Ganti Penghuni"),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(ctx); _showEditSettings(context, door); },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEditSettings(BuildContext context, DoorModel door) {
    // ... Implementasi edit dengan modal modern yang sama seperti di atas
    final nameCtrl = TextEditingController(text: door.tenantName);
    final priceCtrl = TextEditingController(text: door.monthlyPrice.toInt().toString());
    final dateCtrl = TextEditingController(text: door.dueDate.toString());
    bool currentEmpty = door.isEmpty;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) {
          final theme = Theme.of(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  Text("Setting Pintu ${door.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text("Kamar Kosong", style: TextStyle(fontWeight: FontWeight.bold)),
                    value: currentEmpty, 
                    activeColor: theme.colorScheme.primary,
                    onChanged: (v) { HapticFeedback.lightImpact(); setMState(() => currentEmpty = v); },
                  ),
                  if(!currentEmpty) ...[
                    const SizedBox(height: 10),
                    TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Nama Penghuni", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Harga Sewa / Bulan (Rp)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextField(controller: dateCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Tanggal Tagihan (1-31)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ],
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        final updated = DoorModel(
                          id: door.id, roomNumber: door.roomNumber,
                          tenantName: currentEmpty ? "" : nameCtrl.text.trim(),
                          monthlyPrice: double.tryParse(priceCtrl.text) ?? 0,
                          dueDate: int.tryParse(dateCtrl.text) ?? 1,
                          isEmpty: currentEmpty,
                          lastPaymentDate: currentEmpty ? null : door.lastPaymentDate,
                        );
                        context.read<FinanceProvider>().updateDoor(updated);
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text("Simpan Data", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _confirmDelete(BuildContext context, DoorModel door) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Pintu?"),
        content: Text("Yakin menghapus Pintu ${door.roomNumber} beserta datanya?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { 
              context.read<FinanceProvider>().deleteDoor(door.id); 
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx); 
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}