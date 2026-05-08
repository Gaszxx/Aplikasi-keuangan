import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt_model.dart';
import '../providers/finance_provider.dart';

class DebtReportScreen extends StatelessWidget {
  const DebtReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Pisahkan data
    final activeDebts = finance.debts.where((d) => !d.isPaid).toList();
    final paidDebts = finance.debts.where((d) => d.isPaid).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Hutang & Cicilan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddDebtForm(context),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle("Hutang & Cicilan Aktif", Icons.warning_amber_rounded, Colors.orange),
          const SizedBox(height: 10),
          activeDebts.isEmpty 
            ? const Center(child: Text("Tidak ada hutang aktif"))
            : Column(children: activeDebts.map((d) => _buildDebtCard(context, d, false)).toList()),
          
          const SizedBox(height: 40),
          const Divider(),
          _buildSectionTitle("Riwayat Lunas", Icons.check_circle_outline, Colors.green),
          const SizedBox(height: 10),
          paidDebts.isEmpty 
            ? const Center(child: Text("Belum ada riwayat lunas"))
            : Column(children: paidDebts.map((d) => _buildDebtCard(context, d, true)).toList()),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtModel debt, bool isPaid) {
    final now = DateTime.now();
    bool isOverdue = !isPaid && debt.dueDate.isBefore(DateTime(now.year, now.month, now.day));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(debt.creditorName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(debt.description),
            Text(
              "Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(debt.dueDate)}",
              style: TextStyle(color: isOverdue ? Colors.red : Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(debt.amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (debt.isInstallment && !isPaid)
              Text("${debt.currentInstallment}/${debt.totalInstallments}", style: const TextStyle(fontSize: 10)),
            if (!isPaid)
              TextButton(
                onPressed: () => context.read<FinanceProvider>().payDebt(debt),
                child: Text(debt.isInstallment ? "Bayar" : "Lunas"),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddDebtForm(BuildContext context) {
    // Implementasi Form Tambah Hutang di sini
  }
}