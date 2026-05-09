import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/debt_model.dart';
import '../providers/finance_provider.dart';
import 'debt_form_screen.dart'; 

class DebtReportScreen extends StatelessWidget {
  const DebtReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final activeDebts = finance.debts.where((d) => !d.isPaid).toList();
    final paidDebts = finance.debts.where((d) => d.isPaid).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Hutang & Cicilan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 28),
            tooltip: 'Tambah Kewajiban',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DebtFormScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle(theme, "Hutang & Cicilan Aktif", Icons.warning_amber_rounded, Colors.orange.shade700),
                const SizedBox(height: 16),
                if (activeDebts.isEmpty)
                  _buildEmptyState(theme, "Tidak ada hutang aktif saat ini. Keuangan Anda sehat! 🎉")
                else
                  ...activeDebts.map((d) => _buildActiveDebtCard(context, theme, d)),
                
                const SizedBox(height: 40),
                
                _buildSectionTitle(theme, "Riwayat Lunas", Icons.check_circle_outline_rounded, Colors.green),
                const SizedBox(height: 16),
                if (paidDebts.isEmpty)
                  _buildEmptyState(theme, "Belum ada riwayat hutang/cicilan yang lunas.")
                else
                  ...paidDebts.map((d) => _buildPaidDebtCard(theme, d)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KOMPONEN UI ---

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
      ),
    );
  }

  // --- KARTU HUTANG AKTIF (MENGHINDARI OVERFLOW) ---
  Widget _buildActiveDebtCard(BuildContext context, ThemeData theme, DebtModel debt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(debt.dueDate.year, debt.dueDate.month, debt.dueDate.day);
    
    bool isOverdue = dueDate.isBefore(today);
    bool isDueToday = dueDate.isAtSameMomentAs(today);

    Color statusColor = isOverdue ? theme.colorScheme.error : (isDueToday ? Colors.orange.shade700 : theme.colorScheme.primary);
    String statusText = isOverdue ? "⚠️ Jatuh Tempo Terlewat!" : (isDueToday ? "🔔 Jatuh Tempo Hari Ini" : "Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(debt.dueDate)}");

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), 
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20), // Padding luas agar terhindar dari overflow
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    debt.creditorName, 
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatRp(debt.amount),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Text(debt.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Divider(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText, style: theme.textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                    if (debt.isInstallment) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text("Cicilan ke: ${debt.currentInstallment} / ${debt.totalInstallments}", style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => _confirmPayment(context, debt, statusColor),
                  child: Text(debt.isInstallment ? "Bayar Cicilan" : "Lunasi", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- KARTU HUTANG LUNAS ---
  Widget _buildPaidDebtCard(ThemeData theme, DebtModel debt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.green.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: Colors.green.withOpacity(0.2))
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.check_circle_rounded, color: Colors.green)),
        title: Text(debt.creditorName, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
        subtitle: Text(debt.description, style: const TextStyle(fontSize: 12)),
        trailing: Text("LUNAS\n${_formatRp(debt.amount)}", textAlign: TextAlign.right, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  // --- FUNGSI VALIDASI QA SEBELUM BAYAR ---
  void _confirmPayment(BuildContext context, DebtModel debt, Color statusColor) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Pembayaran"),
        content: Text(
          debt.isInstallment 
            ? "Apakah Anda yakin ingin membayar cicilan ke-${debt.currentInstallment} untuk ${debt.creditorName} sebesar ${_formatRp(debt.amount)}?"
            : "Apakah Anda yakin ingin melunasi tagihan ${debt.creditorName} sebesar ${_formatRp(debt.amount)}?"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: statusColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              context.read<FinanceProvider>().payDebt(debt);
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pembayaran ${debt.creditorName} Berhasil Dicatat! ✅'),
                  backgroundColor: Colors.green,
                )
              );
            },
            child: const Text("Ya, Bayar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatRp(double amount) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
}