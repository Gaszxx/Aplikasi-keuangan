import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_model.dart';
import '../providers/finance_provider.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // State Manajemen
  ExpenseType _selectedType = ExpenseType.operasional;
  String _selectedUnit = 'Kelapa'; 
  
  final List<String> _unitOptions = ['Kelapa', 'Galon', 'Kontrakan', 'Umum'];
  
  // Data Outlet Dinamis
  final List<String> _kelapaOutlets = ['Pusat', 'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau'];
  final List<String> _galonOutlets = ['Depot Utama']; // Bisa ditambah nanti
  
  String? _selectedOutlet = 'Pusat'; // Boleh null jika unitnya Kontrakan/Umum

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  }

  Future<void> _submitData() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    final amount = _parseCurrency(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengeluaran tidak valid!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final finance = context.read<FinanceProvider>();
      
      final newExpense = ExpenseModel(
        id: '',
        type: _selectedType,
        unitBisnis: _selectedUnit,
        amount: amount,
        date: DateTime.now(), // Jika Bos butuh bisa pilih tanggal, kita bisa tambahkan DatePicker
        outlet: _selectedOutlet ?? '-', // Jika null, isi dengan strip agar rapi di laporan
        description: _descCtrl.text.trim(),
      );

      await finance.addExpense(newExpense);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengeluaran $_selectedUnit Berhasil Dicatat! 💸'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mencatat pengeluaran')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- LOGIKA SMART FORM ---
  void _onUnitChanged(String newUnit) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedUnit = newUnit;
      // Reset & atur ulang outlet sesuai unit
      if (newUnit == 'Kelapa') {
        _selectedOutlet = _kelapaOutlets.first;
      } else if (newUnit == 'Galon') {
        _selectedOutlet = _galonOutlets.first;
      } else {
        _selectedOutlet = null; // Sembunyikan dropdown outlet
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. PILIH UNIT BISNIS
                  Text('Tujuan Pengeluaran', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Mencegah error lebar layar di HP kecil dengan Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _unitOptions.map((unit) {
                      final isSelected = _selectedUnit == unit;
                      return ChoiceChip(
                        label: Text(unit),
                        selected: isSelected,
                        selectedColor: colorScheme.error.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? colorScheme.error : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) _onUnitChanged(unit);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 2. DETAIL PENGELUARAN
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informasi Biaya', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<ExpenseType>(
                            value: _selectedType,
                            decoration: _inputDeco(theme, 'Kategori Biaya'),
                            items: ExpenseType.values.map((type) => DropdownMenuItem(
                              value: type, 
                              // Ubah enum operasional jadi Operasional, dll.
                              child: Text(type.name[0].toUpperCase() + type.name.substring(1))
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedType = val!),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold, fontSize: 18),
                            decoration: _inputDeco(theme, 'Nominal Pengeluaran (Rp)').copyWith(
                              prefixIcon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. LOKASI & CATATAN
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // HANYA MUNCUL JIKA UNIT KELAPA ATAU GALON
                          if (_selectedUnit == 'Kelapa' || _selectedUnit == 'Galon') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedOutlet,
                              decoration: _inputDeco(theme, 'Lokasi / Outlet'),
                              items: (_selectedUnit == 'Kelapa' ? _kelapaOutlets : _galonOutlets)
                                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedOutlet = val),
                            ),
                            const SizedBox(height: 16),
                          ],

                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 3,
                            decoration: _inputDeco(theme, 'Catatan Pengeluaran (Wajib)'),
                            validator: (v) => v == null || v.trim().length < 5 ? 'Berikan catatan yang jelas (min 5 karakter)' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. TOMBOL SIMPAN
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitData,
                      child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SIMPAN PENGELUARAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    int value = int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final newText = NumberFormat.decimalPattern('id_ID').format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}