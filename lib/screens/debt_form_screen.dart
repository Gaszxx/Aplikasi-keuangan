import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/debt_model.dart';
import '../providers/finance_provider.dart';

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key});

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final _creditorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tenorCtrl = TextEditingController(text: '12'); // Default 12 bulan

  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 1));
  bool _isInstallment = true; // Default cicilan (karena bos seringnya cicilan)

  @override
  void dispose() {
    _creditorCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _tenorCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now(), // Tidak bisa pilih tanggal masa lalu
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 Tahun ke depan
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // Sesuai tema
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() => _selectedDueDate = picked);
    }
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
        const SnackBar(content: Text('Nominal tagihan tidak boleh Rp 0!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final finance = context.read<FinanceProvider>();
      
      final newDebt = DebtModel(
        id: '', // Di-generate oleh Firebase
        creditorName: _creditorCtrl.text.trim(),
        amount: amount,
        dueDate: _selectedDueDate,
        isInstallment: _isInstallment,
        currentInstallment: _isInstallment ? 1 : 0,
        totalInstallments: _isInstallment ? (int.tryParse(_tenorCtrl.text) ?? 1) : 0,
        isPaid: false,
        description: _descCtrl.text.trim().isEmpty ? 'Tagihan Pribadi' : _descCtrl.text.trim(),
      );
  
      await finance.addDebt(newDebt);
      try {
          // Buat ID unik dari waktu agar alarm tidak saling menimpa
          final int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
          
          await NotificationService().scheduleDebtReminder(
            id: notifId,
            creditorName: newDebt.creditorName,
            amount: newDebt.amount,
            dueDate: newDebt.dueDate,
          );
        } catch (alarmError) {
          debugPrint("Gagal mengatur alarm: $alarmError");
          // Kita tangkap errornya agar kalaupun alarm gagal disetel, 
          // data hutang tetap berhasil tersimpan di database.
        }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kewajiban Baru Berhasil Dicatat! 🔔 Sistem pengingat aktif.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan tagihan'), backgroundColor: Colors.red));
        Navigator.pop(context);
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
        title: const Text('Input Kewajiban Baru', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  // HEADER INFORMASI
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Data ini akan memicu alarm pengingat di HP Anda saat mendekati tanggal jatuh tempo.',
                            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CARD 1: INFORMASI KREDITUR
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.outlineVariant)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Tagihan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _creditorCtrl,
                            decoration: _inputDeco(theme, 'Nama Bank / Leasing / Perorangan').copyWith(prefixIcon: const Icon(Icons.account_balance_rounded)),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi (Contoh: BCA, Adira, Pak Haji)' : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                            decoration: _inputDeco(theme, 'Nominal Tagihan per Bulan (Rp)').copyWith(prefixIcon: const Icon(Icons.payments_rounded)),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 2: TANGGAL JATUH TEMPO & SISTEM CICILAN
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.outlineVariant)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengaturan Waktu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          
                          InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal Jatuh Tempo', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text(DateFormat('dd MMMM yyyy').format(_selectedDueDate), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SwitchListTile(
                            title: const Text('Ini adalah cicilan bertahap', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Aktifkan jika tagihan dibayar setiap bulan', style: TextStyle(fontSize: 11)),
                            value: _isInstallment,
                            activeColor: colorScheme.primary,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _isInstallment = val);
                            },
                          ),

                          if (_isInstallment) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _tenorCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDeco(theme, 'Berapa bulan sisa cicilannya? (Tenor)'),
                              validator: (v) => v == null || v.isEmpty ? 'Wajib diisi (Contoh: 12)' : null,
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 3: CATATAN
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.outlineVariant)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: _inputDeco(theme, 'Catatan Tambahan (Opsional)'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // TOMBOL SIMPAN
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SIMPAN & AKTIFKAN PENGINGAT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
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