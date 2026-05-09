import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/income_model.dart';
import '../models/door_model.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';

class IncomeFormScreen extends StatefulWidget {
  const IncomeFormScreen({super.key});

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // State Manajemen
  IncomeType _selectedType = IncomeType.kelapa;
  bool _isAutoSalary = true; 
  double _netAmount = 0.0;
  bool _isSubmitting = false; // QA: Mencegah Double Submit

  // Daftar Outlet
  final List<String> _kelapaOutlets = [
    'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau', 'Cicalengka', 'Pa Mamat',
  ];
  String? _selectedLocation; 
  DoorModel? _selectedDoor;

  // Controllers
  final _grossCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController(); 
  final _descCtrl = TextEditingController();

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
    // QA: Mencegah spam klik
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact(); // Getaran error
      return;
    }

    double gross = _parseCurrency(_grossCtrl.text);
    
    // QA: Validasi Anti-Nol
    if (gross <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pendapatan tidak boleh kosong atau Rp 0!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedType == IncomeType.kontrakan && _selectedDoor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih pintu kontrakan dahulu!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true); // Kunci tombol
    HapticFeedback.lightImpact();

    try {
      final auth = context.read<AuthProvider>();
      final finance = context.read<FinanceProvider>();

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
        submittedBy: auth.currentRole?.name ?? 'Unknown',
        description: _descCtrl.text.trim().isEmpty ? 'Pendapatan ${_selectedType.name}' : _descCtrl.text.trim(),
        grossAmount: gross,
        employeeCut: employeeFinal > 0 ? employeeFinal : null,
        location: _selectedType == IncomeType.kelapa ? _selectedLocation : null,
        doorNumber: _selectedType == IncomeType.kontrakan ? _selectedDoor!.roomNumber : null,
      );

      await finance.addIncome(newIncome);

      // 2. Update Status Pintu Kontrakan
      if (_selectedType == IncomeType.kontrakan && _selectedDoor != null) {
        final updatedDoor = DoorModel(
          id: _selectedDoor!.id,
          roomNumber: _selectedDoor!.roomNumber,
          tenantName: _selectedDoor!.tenantName,
          monthlyPrice: _selectedDoor!.monthlyPrice,
          dueDate: _selectedDoor!.dueDate,
          isEmpty: false, 
          lastPaymentDate: DateTime.now(),
        );
        await finance.updateDoor(updatedDoor);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Transaksi Berhasil Disimpan!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan transaksi'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false); // Buka kunci tombol jika gagal
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final activeDoors = finance.doors.where((d) => !d.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Pemasukan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        // RESPONSIVE: Memusatkan form di Tablet/Web
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. PILIH KATEGORI (Segmented Button)
                  SegmentedButton<IncomeType>(
                    segments: const [
                      ButtonSegment(value: IncomeType.kelapa, icon: Icon(Icons.park_rounded), label: Text('Kelapa')),
                      ButtonSegment(value: IncomeType.galon, icon: Icon(Icons.water_drop_rounded), label: Text('Galon')),
                      ButtonSegment(value: IncomeType.kontrakan, icon: Icon(Icons.holiday_village_rounded), label: Text('Kontrak')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<IncomeType> newSelection) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedType = newSelection.first;
                        _grossCtrl.clear();
                        _descCtrl.clear();
                        _selectedDoor = null;
                        _selectedLocation = null;
                        _calculateNet(); 
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2. INPUT DATA UTAMA (Card System)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Transaksi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),

                          if (_selectedType == IncomeType.kelapa) ...[
                            DropdownButtonFormField<String>(
                              value: _selectedLocation,
                              decoration: _inputDeco(theme, 'Pilih Outlet Lapak'),
                              items: _kelapaOutlets.map((outlet) => DropdownMenuItem(value: outlet, child: Text(outlet))).toList(),
                              onChanged: (val) => setState(() => _selectedLocation = val),
                              validator: (value) => value == null ? 'Outlet wajib dipilih' : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_selectedType == IncomeType.kontrakan) ...[
                            if (activeDoors.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                                child: Text("Belum ada pintu berpenghuni.", style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13)),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: _selectedDoor?.id,
                                isExpanded: true,
                                decoration: _inputDeco(theme, 'Pilih Pintu & Penghuni'),
                                items: activeDoors.map((door) => DropdownMenuItem(
                                  value: door.id, 
                                  child: Text("Pintu ${door.roomNumber} - ${door.tenantName}")
                                )).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDoor = activeDoors.firstWhere((d) => d.id == val);
                                    if (_selectedDoor != null) {
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

                          if (_selectedType != IncomeType.kontrakan) ...[
                            _buildTextField(label: 'Pendapatan Kotor (Rp)', controller: _grossCtrl, isCurrency: true, isRequired: true, theme: theme),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. POTONGAN GAJI
                  if (_selectedType == IncomeType.kelapa || _selectedType == IncomeType.galon) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Potongan Karyawan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    Text(_selectedType == IncomeType.kelapa ? 'Otomatis 15%' : 'Otomatis 50%', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                                  ],
                                ),
                                Switch(
                                  value: _isAutoSalary, 
                                  activeColor: colorScheme.primary,
                                  onChanged: (val) { 
                                    HapticFeedback.lightImpact();
                                    setState(() { _isAutoSalary = val; if (val) _employeeCtrl.clear(); _calculateNet(); }); 
                                  },
                                ),
                              ],
                            ),
                            if (!_isAutoSalary) ...[
                              const Divider(height: 24),
                              _buildTextField(label: 'Input Gaji Manual (Rp)', controller: _employeeCtrl, isCurrency: true, theme: theme),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. CATATAN
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildTextField(label: 'Catatan Transaksi (Opsional)', controller: _descCtrl, isCurrency: false, isNumber: false, theme: theme, maxLines: 2),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // HASIL BERSIH / NETTO (Sticky Style)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer, 
                      borderRadius: BorderRadius.circular(20), 
                      border: Border.all(color: colorScheme.primary.withOpacity(0.3))
                    ),
                    child: Column(
                      children: [
                        Text('KAS BERSIH (NETTO)', style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_netAmount), 
                          style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 32, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. TOMBOL SIMPAN
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitData,
                      child: _isSubmitting 
                          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 3))
                          : const Text('SIMPAN PEMASUKAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---
  InputDecoration _inputDeco(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: theme.colorScheme.surface,
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required bool isCurrency, required ThemeData theme, bool isNumber = true, bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller, 
      keyboardType: isNumber ? TextInputType.number : TextInputType.text, 
      maxLines: maxLines,
      inputFormatters: isCurrency ? [CurrencyInputFormatter()] : (isNumber ? [FilteringTextInputFormatter.digitsOnly] : []),
      validator: isRequired ? (value) => value == null || value.isEmpty || value == '0' ? 'Wajib diisi' : null : null,
      decoration: _inputDeco(theme, label),
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