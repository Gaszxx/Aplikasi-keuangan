import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/income_model.dart';
import '../models/door_model.dart'; // <-- Import Model Pintu
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_colors.dart';

class IncomeFormScreen extends StatefulWidget {
  const IncomeFormScreen({super.key});

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Kategori Default
  IncomeType _selectedType = IncomeType.kelapa;

  // Daftar Outlet Kelapa
  final List<String> _kelapaOutlets = [
    'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau', 'Cicalengka', 'Pa Mamat',
  ];
  String? _selectedLocation; 

  // Pintu Kontrakan yang Dipilih
  DoorModel? _selectedDoor;

  // Controllers
  final _grossCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController(); 
  final _descCtrl = TextEditingController();

  bool _isAutoSalary = true; 
  double _netAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _grossCtrl.addListener(_calculateNet);
    _employeeCtrl.addListener(_calculateNet);
  }

  @override
  void dispose() {
    _grossCtrl.dispose();
    _employeeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA ERP: KALKULASI NETTO REAL-TIME ---
  void _calculateNet() {
    double gross = _parseCurrency(_grossCtrl.text);
    double employee = 0;

    if (_selectedType == IncomeType.kelapa || _selectedType == IncomeType.galon) {
      if (_isAutoSalary) {
        double multiplier = _selectedType == IncomeType.kelapa ? 0.15 : 0.50;
        employee = gross * multiplier;
      } else {
        employee = _parseCurrency(_employeeCtrl.text); 
      }
    }

    setState(() {
      _netAmount = gross - employee;
    });
  }

  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  }

  // --- LOGIKA SIMPAN KE FIREBASE ---
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi Ekstra untuk Kontrakan
    if (_selectedType == IncomeType.kontrakan && _selectedDoor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih pintu kontrakan dahulu!'), backgroundColor: Colors.red));
      return;
    }

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    double gross = _parseCurrency(_grossCtrl.text);
    double employeeFinal = 0;

    if (_selectedType == IncomeType.kelapa || _selectedType == IncomeType.galon) {
      double multiplier = _selectedType == IncomeType.kelapa ? 0.15 : 0.50;
      employeeFinal = _isAutoSalary ? gross * multiplier : _parseCurrency(_employeeCtrl.text);
    }

    // 1. Simpan Transaksi Pemasukan (Income)
    final newIncome = IncomeModel(
      id: '',
      type: _selectedType,
      amount: _netAmount,
      date: DateTime.now(),
      submittedBy: auth.currentRole.name,
      description: _descCtrl.text.trim(),
      grossAmount: gross > 0 ? gross : null,
      employeeCut: employeeFinal > 0 ? employeeFinal : null,
      location: _selectedType == IncomeType.kelapa ? _selectedLocation : null,
      doorNumber: _selectedType == IncomeType.kontrakan ? _selectedDoor!.roomNumber : null,
    );

    try {
      await finance.addIncome(newIncome);

      // 2. Jika Kontrakan, Update Status Pintu (Jadi HIJAU di Dashboard)
      if (_selectedType == IncomeType.kontrakan && _selectedDoor != null) {
        final updatedDoor = DoorModel(
          id: _selectedDoor!.id,
          roomNumber: _selectedDoor!.roomNumber,
          tenantName: _selectedDoor!.tenantName,
          monthlyPrice: _selectedDoor!.monthlyPrice,
          dueDate: _selectedDoor!.dueDate,
          isEmpty: false, // Pasti terisi jika bayar
          lastPaymentDate: DateTime.now(), // <-- Ini yang mengubah pintu jadi Hijau
        );
        await finance.updateDoor(updatedDoor);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi Berhasil Disimpan! ✅'),
            backgroundColor: Color(0xFF007A3D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan transaksi'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : const Color(0xFF007A3D);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    // Ambil daftar pintu yang ADA PENGHUNINYA saja (Tidak kosong)
    final activeDoors = finance.doors.where((d) => !d.isEmpty).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text('Input Transaksi', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. PILIH KATEGORI
              SegmentedButton<IncomeType>(
                segments: const [
                  ButtonSegment(value: IncomeType.kelapa, icon: Icon(Icons.nature), label: Text('Kelapa')),
                  ButtonSegment(value: IncomeType.galon, icon: Icon(Icons.water_drop), label: Text('Galon')),
                  ButtonSegment(value: IncomeType.kontrakan, icon: Icon(Icons.house), label: Text('Kontrak')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<IncomeType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    // Reset isi form saat pindah tab agar data tidak nyangkut
                    _grossCtrl.clear();
                    _descCtrl.clear();
                    _selectedDoor = null;
                    _selectedLocation = null;
                    _calculateNet(); 
                  });
                },
                style: SegmentedButton.styleFrom(selectedBackgroundColor: primary.withOpacity(0.2), selectedForegroundColor: primary),
              ),
              const SizedBox(height: 32),

              // 2. INPUT DATA UTAMA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: primary.withOpacity(0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- TAMPILAN KHUSUS KELAPA ---
                    if (_selectedType == IncomeType.kelapa) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(labelText: 'Pilih Outlet Lapak', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        items: _kelapaOutlets.map((outlet) => DropdownMenuItem(value: outlet, child: Text(outlet))).toList(),
                        onChanged: (val) => setState(() => _selectedLocation = val),
                        validator: (value) => value == null ? 'Outlet wajib dipilih' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- TAMPILAN KHUSUS KONTRAKAN (SMART DROPDOWN) ---
                    if (_selectedType == IncomeType.kontrakan) ...[
                      if (activeDoors.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text("Belum ada data pintu yang berpenghuni. Silakan atur di menu Kontrakan terlebih dahulu.", style: TextStyle(color: Colors.orange, fontSize: 12)),
                        )
                      else
                        // PERBAIKAN: Ubah DoorModel menjadi String (Menyimpan ID saja)
                        DropdownButtonFormField<String>(
                          value: _selectedDoor?.id, // Gunakan ID pintu
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Pilih Pintu & Penghuni', 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                          ),
                          items: activeDoors.map((door) => DropdownMenuItem(
                            value: door.id, // Value yang disimpan adalah ID String
                            child: Text("Pintu ${door.roomNumber} - ${door.tenantName}")
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              // Cari objek pintu utuh berdasarkan ID yang dipilih
                              _selectedDoor = activeDoors.firstWhere((d) => d.id == val);
                              
                              if (_selectedDoor != null) {
                                // OTOMATIS: Tarik harga & buat deskripsi
                                _grossCtrl.text = NumberFormat.decimalPattern('id_ID').format(_selectedDoor!.monthlyPrice);
                                _descCtrl.text = "Sewa Pintu ${_selectedDoor!.roomNumber} (${_selectedDoor!.tenantName})";
                                _calculateNet();
                              }
                            });
                          },
                          validator: (value) => value == null ? 'Pintu wajib dipilih' : null,
                        ),
                      const SizedBox(height: 16),
                    ],

                    // --- PENDAPATAN KOTOR (Disembunyikan jika Kontrakan agar Bos tidak repot) ---
                    if (_selectedType != IncomeType.kontrakan) ...[
                      _buildTextField(label: 'Pendapatan Kotor (Rp)', controller: _grossCtrl, isCurrency: true, primaryColor: primary, isRequired: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. POTONGAN GAJI (Dinamis: Kelapa & Galon)
              if (_selectedType == IncomeType.kelapa || _selectedType == IncomeType.galon) ...[
                Text('Potongan Gaji Karyawan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.error.withOpacity(0.2))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedType == IncomeType.kelapa ? 'Auto Potong 15%' : 'Auto Potong 50%', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: _isAutoSalary, activeColor: primary,
                            onChanged: (val) { setState(() { _isAutoSalary = val; if (val) _employeeCtrl.clear(); _calculateNet(); }); },
                          ),
                        ],
                      ),
                      if (!_isAutoSalary) ...[
                        const SizedBox(height: 12),
                        const Text('Kosongkan jika karyawan sudah potong gaji sendiri', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 8),
                        _buildTextField(label: 'Input Gaji Manual (Rp)', controller: _employeeCtrl, isCurrency: true, primaryColor: AppColors.error),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. CATATAN
              _buildTextField(label: 'Catatan (Opsional)', controller: _descCtrl, isCurrency: false, isNumber: false, primaryColor: primary, maxLines: 2),
              const SizedBox(height: 32),

              // 5. TOMBOL SIMPAN
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                  onPressed: _submitData,
                  child: const Text('SIMPAN TRANSAKSI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 24),

              // HASIL BERSIH / NETTO
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: primary.withOpacity(0.3))),
                child: Column(
                  children: [
                    Text('PENDAPATAN BERSIH (NETTO)', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_netAmount), style: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildTextField({required String label, required TextEditingController controller, required bool isCurrency, required Color primaryColor, bool isNumber = true, bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text, maxLines: maxLines,
      inputFormatters: isCurrency ? [CurrencyInputFormatter()] : (isNumber ? [FilteringTextInputFormatter.digitsOnly] : []),
      validator: isRequired ? (value) => value == null || value.isEmpty ? 'Form ini wajib diisi' : null : null,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// --- LOGIKA FORMAT TITIK RUPIAH ---
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    int value = int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final newText = NumberFormat.decimalPattern('id_ID').format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}