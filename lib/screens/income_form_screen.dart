import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/income_model.dart';
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
    'Tutugan',
    'Capil',
    'Ciledug',
    'Permata Hijau',
    'Cicalengka',
    'Pa Mamat',
  ];
  String? _selectedLocation; // Menyimpan outlet yang dipilih

  // Controllers
  final _grossCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController(); // Bisa dikosongkan (0)
  final _descCtrl = TextEditingController();
  final _doorCtrl = TextEditingController(); // Untuk Kontrakan

  bool _isAutoSalary = true; // Berlaku dinamis untuk Kelapa (15%) & Galon (50%)
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
    _doorCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA ERP: KALKULASI NETTO REAL-TIME ---
  void _calculateNet() {
    double gross = _parseCurrency(_grossCtrl.text);
    double employee = 0;

    // Hitung gaji jika tipe usahanya Kelapa atau Galon
    if (_selectedType == IncomeType.kelapa ||
        _selectedType == IncomeType.galon) {
      if (_isAutoSalary) {
        // Kelapa 15%, Galon 50%
        double multiplier = _selectedType == IncomeType.kelapa ? 0.15 : 0.50;
        employee = gross * multiplier;
      } else {
        employee = _parseCurrency(_employeeCtrl.text); // Manual input
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

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    double gross = _parseCurrency(_grossCtrl.text);
    double employeeFinal = 0;

    if (_selectedType == IncomeType.kelapa ||
        _selectedType == IncomeType.galon) {
      double multiplier = _selectedType == IncomeType.kelapa ? 0.15 : 0.50;
      employeeFinal = _isAutoSalary
          ? gross * multiplier
          : _parseCurrency(_employeeCtrl.text);
    }

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
      doorNumber: _selectedType == IncomeType.kontrakan
          ? _doorCtrl.text.trim()
          : null,
    );

    try {
      await finance.addIncome(newIncome);

      if (mounted) {
        Navigator.pop(context); // Kembali ke Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi Berhasil Disimpan! ✅'),
            backgroundColor: Color(0xFF007A3D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading dialog
      // Tampilkan error jika gagal (misal: koneksi mati)
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : const Color(0xFF007A3D);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          'Input Transaksi',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  ButtonSegment(
                    value: IncomeType.kelapa,
                    icon: Icon(Icons.nature),
                    label: Text('Kelapa'),
                  ),
                  ButtonSegment(
                    value: IncomeType.galon,
                    icon: Icon(Icons.water_drop),
                    label: Text('Galon'),
                  ),
                  ButtonSegment(
                    value: IncomeType.kontrakan,
                    icon: Icon(Icons.house),
                    label: Text('Kontrak'),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<IncomeType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    _calculateNet(); // Hitung ulang netto saat pindah tab
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: primary.withOpacity(0.2),
                  selectedForegroundColor: primary,
                ),
              ),
              const SizedBox(height: 32),

              // 2. INPUT DATA UTAMA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DROPDOWN OUTLET KELAPA
                    if (_selectedType == IncomeType.kelapa) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(
                          labelText: 'Pilih Outlet Lapak',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: _kelapaOutlets.map((String outlet) {
                          return DropdownMenuItem<String>(
                            value: outlet,
                            child: Text(outlet),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLocation = newValue;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Outlet wajib dipilih' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_selectedType == IncomeType.kontrakan) ...[
                      _buildTextField(
                        label: 'Nomor Pintu / Kamar',
                        controller: _doorCtrl,
                        isCurrency: false,
                        isNumber: false,
                        primaryColor: primary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      label: 'Pendapatan Kotor (Rp)',
                      controller: _grossCtrl,
                      isCurrency: true,
                      primaryColor: primary,
                      isRequired: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. POTONGAN GAJI (Dinamis: Kelapa & Galon)
              if (_selectedType == IncomeType.kelapa ||
                  _selectedType == IncomeType.galon) ...[
                Text(
                  'Potongan Gaji Karyawan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Teks Dinamis: 15% untuk Kelapa, 50% untuk Galon
                          Text(
                            _selectedType == IncomeType.kelapa
                                ? 'Auto Potong 15%'
                                : 'Auto Potong 50%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isAutoSalary,
                            activeColor: primary,
                            onChanged: (val) {
                              setState(() {
                                _isAutoSalary = val;
                                if (val) _employeeCtrl.clear();
                                _calculateNet();
                              });
                            },
                          ),
                        ],
                      ),
                      if (!_isAutoSalary) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Kosongkan jika karyawan sudah potong gaji sendiri',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          label: 'Input Gaji Manual (Rp)',
                          controller: _employeeCtrl,
                          isCurrency: true,
                          primaryColor: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. CATATAN
              _buildTextField(
                label: 'Catatan (Opsional)',
                controller: _descCtrl,
                isCurrency: false,
                isNumber: false,
                primaryColor: primary,
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // 5. HASIL BERSIH (REALTIME)              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _submitData,
                  child: const Text(
                    'SIMPAN TRANSAKSI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24), // Jarak antara tombol simpan dan kotak netto

              // ================================================================
              // HASIL BERSIH / NETTO (Dipindah ke bawah)
              // ================================================================
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1), // Dibuat lebih soft agar tidak menyaingi tombol utama
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withOpacity(0.3)), // Tambahkan border tipis
                ),
                child: Column(
                  children: [
                    Text(
                      'PENDAPATAN BERSIH (NETTO)',
                      style: TextStyle(
                        color: primary, // Warna teks disesuaikan dengan tema utama
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_netAmount),
                      style: TextStyle(
                        color: primary, // Warna teks disesuaikan dengan tema utama
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isCurrency,
    required Color primaryColor,
    bool isNumber = true,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      inputFormatters: isCurrency
          ? [CurrencyInputFormatter()]
          : (isNumber ? [FilteringTextInputFormatter.digitsOnly] : []),
      validator: isRequired
          ? (value) =>
                value == null || value.isEmpty ? 'Form ini wajib diisi' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// --- LOGIKA FORMAT TITIK RUPIAH ---
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    int value =
        int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final newText = NumberFormat.decimalPattern('id_ID').format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
