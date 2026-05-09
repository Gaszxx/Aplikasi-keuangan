import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // DATA DUMMY (Nanti kita hubungkan ke Provider/Database)
    final List<NotificationModel> notifications = [
      NotificationModel(
        id: '1',
        title: '⚠️ Pengingat Cicilan',
        body: 'Cicilan Pa Mamat jatuh tempo 7 hari lagi sebesar Rp 5.000.000',
        timestamp: DateTime.now(),
      ),
      NotificationModel(
        id: '2',
        title: '✅ Pembayaran Berhasil',
        body: 'Pembayaran cicilan ke-3 Tutugan telah dicatat.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {}, // Logika tandai semua terbaca
            child: const Text('Tandai Dibaca'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(theme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotifCard(theme, notif);
              },
            ),
    );
  }

  Widget _buildNotifCard(ThemeData theme, NotificationModel notif) {
    return Container(
      decoration: BoxDecoration(
        color: notif.isRead ? theme.colorScheme.surface : theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: notif.isRead ? Colors.grey.shade200 : theme.colorScheme.primary,
          child: Icon(
            notif.title.contains('⚠️') ? Icons.warning_amber_rounded : Icons.notifications_active,
            color: notif.isRead ? Colors.grey : Colors.white,
          ),
        ),
        title: Text(
          notif.title,
          style: TextStyle(
            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notif.body, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM, HH:mm').format(notif.timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        onTap: () {
          // Logika ketika notif ditekan
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Belum ada notifikasi baru', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}