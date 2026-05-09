import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_model.dart';
import '../providers/auth_provider.dart';
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
  String _selectedUnit = 'Kelapa'; // Default unit
  
  final List<String> _unitOptions = ['Kelapa', 'Galon', 'Kontrakan', 'Umum'];
  final List<String> _outlets = ['Pusat', 'Tutugan', 'Capil', 'Ciledug', 'Permata Hijau'];
  String _selectedOutlet = 'Pusat';

  // Controllers
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
        date: DateTime.now(),
        outlet: _selectedOutlet,
        description: _descCtrl.text.trim(),
      );

      await finance.addExpense(newExpense);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pengeluaran Berhasil Dicatat! 💸'),
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
                  // 1. PILIH UNIT BISNIS (Krusial untuk Laporan)
                  Text('Unit Bisnis Terkait', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: _unitOptions.map((unit) => ButtonSegment(
                      value: unit, 
                      label: Text(unit, style: const TextStyle(fontSize: 12))
                    )).toList(),
                    selected: {_selectedUnit},
                    onSelectionChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedUnit = val.first);
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2. DETAIL PENGELUARAN
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informasi Pengeluaran', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<ExpenseType>(
                            value: _selectedType,
                            decoration: _inputDeco(theme, 'Kategori Biaya'),
                            items: ExpenseType.values.map((type) => DropdownMenuItem(
                              value: type, 
                              child: Text(type.name.toUpperCase())
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
                          DropdownButtonFormField<String>(
                            value: _selectedOutlet,
                            decoration: _inputDeco(theme, 'Lokasi / Outlet'),
                            items: _outlets.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                            onChanged: (val) => setState(() => _selectedOutlet = val!),
                          ),
                          const SizedBox(height: 16),
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
                        backgroundColor: colorScheme.error, // Merah untuk pengeluaran
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitData,
                      child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SIMPAN PENGELUARAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// Re-use formatter yang sama untuk konsistensi
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    int value = int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final newText = NumberFormat.decimalPattern('id_ID').format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}