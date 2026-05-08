import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/door_model.dart';
import '../models/income_model.dart';
import '../providers/finance_provider.dart';

class KontrakanReportScreen extends StatefulWidget {
  const KontrakanReportScreen({super.key});

  @override
  State<KontrakanReportScreen> createState() => _KontrakanReportScreenState();
}

class _KontrakanReportScreenState extends State<KontrakanReportScreen> {
  // Filter Bulan untuk Omset
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  void _ubahBulan(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF673AB7); 
    final textColor = isDark ? Colors.white : Colors.black;
    final now = DateTime.now();

    // --- 1. LOGIKA SORTING PINTU ---
    List<DoorModel> sortedDoors = List.from(finance.doors);
    sortedDoors.sort((a, b) {
      int numA = int.tryParse(a.roomNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int numB = int.tryParse(b.roomNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });

    // --- 2. RIWAYAT & OMSET ---
    var history = finance.incomes.where((i) => i.type == IncomeType.kontrakan).toList();
    history.sort((a, b) => b.date.compareTo(a.date));

    // Filter Omset Berdasarkan Bulan Pilihan
    var monthlyHistory = history.where((i) => i.date.month == _selectedMonth.month && i.date.year == _selectedMonth.year).toList();
    double omsetBulanPilihan = monthlyHistory.fold(0, (sum, i) => sum + i.amount);

    // --- 3. HITUNG STATISTIK POTENSI ---
    int totalPintu = sortedDoors.length;
    int terisi = sortedDoors.where((d) => !d.isEmpty).length;
    double potensiIncome = sortedDoors.where((d) => !d.isEmpty).fold(0, (sum, d) => sum + d.monthlyPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitik Kontrakan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.add_business, color: primary),
            tooltip: 'Tambah Pintu',
            onPressed: () => _showAddDoorModal(context, sortedDoors),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // HEADER
          Center(
            child: Column(
              children: [
                Icon(Icons.house_siding_rounded, size: 48, color: primary),
                const SizedBox(height: 8),
                Text('KONTRAKAN & KOST-AN', style: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const Text('Manajemen Pintu & Penagihan', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ESTIMASI TAGIHAN (POTENSI)
          _buildSummaryCard(terisi, totalPintu, potensiIncome, primary),
          const SizedBox(height: 20),

          // PENDAPATAN REAL (OMSET BULAN INI / KEBELAKANG)
          _buildOmsetCard(omsetBulanPilihan, primary, isDark),
          const SizedBox(height: 32),

          Text('Status Pintu (Bulan Ini)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),

          // GRID PINTU
          sortedDoors.isEmpty 
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Belum ada pintu.\nKlik ikon + di kanan atas.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))))
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

                  if (sudahBayarBulanIni) statusColor = Colors.green; 
                  else if (sudahLewatJatuhTempo) statusColor = Colors.red; 
                  else statusColor = Colors.orange; 
                }

                return _buildDoorBox(context, door, statusColor, isDark);
              },
            ),

          const SizedBox(height: 40),

          // RIWAYAT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Riwayat Pembayaran', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${history.length} Transaksi', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          _buildHistoryList(history, primary),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- KOMPONEN UI ---

  Widget _buildOmsetCard(double omset, Color primary, bool isDark) {
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
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _ubahBulan(-1)),
              Text(bulanStr, style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.chevron_right), 
                onPressed: (_selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year) 
                    ? null // Disable jika sudah bulan ini (tidak bisa tembus masa depan)
                    : () => _ubahBulan(1)
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Text('TOTAL PENDAPATAN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(
            NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(omset), 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int terisi, int total, double income, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Okupansi", "$terisi/$total", "Pintu Terisi"),
          _buildStatItem("Total Tagihan", NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(income), "Estimasi Kotor"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildDoorBox(BuildContext context, DoorModel door, Color color, bool isDark) {
    return GestureDetector(
      onTap: () => _showDoorActionModal(context, door),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Pintu", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            Text(door.roomNumber, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                door.isEmpty ? "KOSONG" : door.tenantName, 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)
              ),
            ),
            if(!door.isEmpty) 
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text("Tgl ${door.dueDate}", style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<IncomeModel> list, Color primary) {
    if (list.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada pembayaran', style: TextStyle(color: Colors.grey))));
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length > 10 ? 10 : list.length, 
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: primary.withOpacity(0.1), child: Icon(Icons.receipt_long, color: primary, size: 20)),
            title: Text(item.description ?? 'Sewa Kontrakan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(item.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            trailing: Text('+ ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item.amount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      },
    );
  }

  // --- MODALS ---

  // 1. Modal Tambah Pintu (Cerdas & Validasi Double)
  void _showAddDoorModal(BuildContext context, List<DoorModel> existingDoors) {
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: "1");
    bool currentEmpty = false; // Default diatur ke terisi biar cepat

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Tambah Pintu Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              TextField(
                controller: numCtrl, keyboardType: TextInputType.text, 
                decoration: InputDecoration(labelText: "Nomor Pintu", hintText: "Contoh: 1", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Kamar Kosong?", style: TextStyle(fontWeight: FontWeight.bold)),
                value: currentEmpty, 
                onChanged: (v) => setMState(() => currentEmpty = v),
              ),
              if(!currentEmpty) ...[
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Nama Penghuni", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Harga Sewa / Bulan (Rp)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: dateCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Tanggal Tagihan (1-31)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              ],
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    String newRoomNum = numCtrl.text.trim();
                    if (newRoomNum.isEmpty) return;

                    // CEK DUPLIKAT PINTU
                    bool isDuplicate = existingDoors.any((d) => d.roomNumber.toLowerCase() == newRoomNum.toLowerCase());
                    if (isDuplicate) {
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
                    Navigator.pop(ctx);
                  },
                  child: const Text("Simpan Pintu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Modal Aksi (Saat Pintu di Klik)
  void _showDoorActionModal(BuildContext context, DoorModel door) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Pintu ${door.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { Navigator.pop(ctx); _confirmDelete(context, door); }),
              ],
            ),
            if(!door.isEmpty) ...[
              Text("Penghuni: ${door.tenantName}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text("Tagihan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(door.monthlyPrice)} / Bulan", style: const TextStyle(color: Colors.grey)),
            ] else ...[
              const Text("Status: KOSONG", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 25),
            
            if(!door.isEmpty)
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
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
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil! Pintu kembali Hijau ✅"), backgroundColor: Colors.green));
                  },
                ),
              ),
            
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings), label: const Text("Ubah Setting / Ganti Penghuni"),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () { Navigator.pop(ctx); _showEditSettings(context, door); },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 3. Modal Edit Setting Pintu
  void _showEditSettings(BuildContext context, DoorModel door) {
    final nameCtrl = TextEditingController(text: door.tenantName);
    final priceCtrl = TextEditingController(text: door.monthlyPrice.toInt().toString());
    final dateCtrl = TextEditingController(text: door.dueDate.toString());
    bool currentEmpty = door.isEmpty;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Setting Pintu ${door.roomNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              SwitchListTile(
                title: const Text("Kamar Kosong", style: TextStyle(fontWeight: FontWeight.bold)),
                value: currentEmpty, 
                onChanged: (v) => setMState(() => currentEmpty = v),
              ),
              if(!currentEmpty) ...[
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Nama Penghuni", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Harga Sewa / Bulan (Rp)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: dateCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Tanggal Tagihan (1-31)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              ],
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                    Navigator.pop(ctx);
                  },
                  child: const Text("Simpan Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DoorModel door) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Pintu?"),
        content: Text("Yakin menghapus Pintu ${door.roomNumber}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { context.read<FinanceProvider>().deleteDoor(door.id); Navigator.pop(ctx); },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}