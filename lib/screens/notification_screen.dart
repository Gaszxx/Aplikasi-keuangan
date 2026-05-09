import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';
import '../providers/finance_provider.dart';
import 'debt_report_screen.dart'; // Untuk navigasi saat notif diklik

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  String _formatRp(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  // --- LOGIKA KECERDASAN BUATAN (GENERATOR NOTIFIKASI) ---
  List<NotificationModel> _generateRealNotifications(FinanceProvider finance) {
    final List<NotificationModel> dynamicNotifs = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var debt in finance.debts) {
      final dueDate = DateTime(debt.dueDate.year, debt.dueDate.month, debt.dueDate.day);
      final daysLeft = dueDate.difference(today).inDays;

      if (!debt.isPaid) {
        // 1. JIKA TELAT JATUH TEMPO (CRITICAL)
        if (daysLeft < 0) {
          dynamicNotifs.add(
            NotificationModel(
              id: 'overdue_${debt.id}',
              title: '🚨 Jatuh Tempo Terlewat!',
              body: 'Tagihan ${debt.creditorName} sebesar ${_formatRp(debt.amount)} telah telat ${daysLeft.abs()} hari! Segera lunasi.',
              timestamp: debt.dueDate,
              isRead: false,
            )
          );
        } 
        // 2. JIKA H-7 ATAU HARI INI (WARNING)
        else if (daysLeft <= 7) {
          dynamicNotifs.add(
            NotificationModel(
              id: 'warning_${debt.id}',
              title: daysLeft == 0 ? '🔔 Jatuh Tempo Hari Ini!' : '⚠️ Pengingat Jatuh Tempo',
              body: 'Siapkan dana ${_formatRp(debt.amount)} untuk ${debt.creditorName}. Jatuh tempo ${daysLeft == 0 ? "HARI INI" : "dalam $daysLeft hari"}.',
              timestamp: debt.dueDate,
              isRead: false,
            )
          );
        }
      } else {
        // 3. JIKA SUDAH LUNAS (SUCCESS)
        dynamicNotifs.add(
          NotificationModel(
            id: 'paid_${debt.id}',
            title: '✅ Pembayaran Lunas',
            body: 'Kewajiban untuk ${debt.creditorName} sebesar ${_formatRp(debt.amount)} telah diselesaikan.',
            timestamp: debt.dueDate, 
            isRead: true, // Otomatis terbaca agar warnanya meredup
          )
        );
      }
    }

    // Urutkan: Yang belum dibaca (Penting) di atas, yang sudah lunas di bawah
    dynamicNotifs.sort((a, b) {
      if (a.isRead == b.isRead) {
        return b.timestamp.compareTo(a.timestamp); // Urut tanggal terbaru
      }
      return a.isRead ? 1 : -1;
    });

    return dynamicNotifs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Tarik data riil dari Provider
    final finance = context.watch<FinanceProvider>();
    final notifications = _generateRealNotifications(finance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi Sistem', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(theme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotifCard(context, theme, notif);
              },
            ),
    );
  }

  Widget _buildNotifCard(BuildContext context, ThemeData theme, NotificationModel notif) {
    // Tentukan warna berdasarkan tipe notifikasi
    Color iconColor;
    if (notif.isRead) {
      iconColor = Colors.green; // Lunas
    } else if (notif.title.contains('🚨')) {
      iconColor = theme.colorScheme.error; // Telat
    } else {
      iconColor = Colors.orange.shade700; // H-7
    }

    return InkWell(
      onTap: () {
        // Jika notif diklik, arahkan Bos ke halaman Laporan Utang
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtReportScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead ? theme.colorScheme.surface : iconColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: notif.isRead ? theme.colorScheme.outlineVariant.withOpacity(0.5) : iconColor.withOpacity(0.3)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: notif.isRead ? Colors.green.withOpacity(0.1) : iconColor.withOpacity(0.15),
            child: Icon(
              notif.isRead ? Icons.check_circle_rounded : (notif.title.contains('🚨') ? Icons.error_rounded : Icons.warning_amber_rounded),
              color: iconColor,
            ),
          ),
          title: Text(
            notif.title,
            style: TextStyle(
              fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
              color: notif.isRead ? theme.colorScheme.onSurface : iconColor,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(notif.body, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 8),
              Text(
                'Terkait jatuh tempo: ${DateFormat('dd/MM/yyyy').format(notif.timestamp)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(Icons.notifications_active_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text('Semua Aman! 🎉', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tidak ada tagihan mendesak saat ini.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}