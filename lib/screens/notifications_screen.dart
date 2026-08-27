import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => service.markAllRead(),
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.myNotifications(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No notifications yet', style: TextStyle(color: AppColors.inkMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              return Card(
                color: n.read ? Colors.white : AppColors.gold.withOpacity(0.08),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _iconColor(n.type).withOpacity(0.12),
                    child: Icon(_icon(n.type), color: _iconColor(n.type), size: 20),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w700)),
                  subtitle: Text(n.body),
                  trailing: n.createdAt != null
                      ? Text(
                          '${n.createdAt!.hour.toString().padLeft(2, '0')}:${n.createdAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                        )
                      : null,
                  onTap: () => service.markRead(n.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'ledger_verified': return Icons.check_circle_outline;
      case 'ledger_flagged': return Icons.flag_outlined;
      case 'member_added': return Icons.groups_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String? type) {
    switch (type) {
      case 'ledger_verified': return AppColors.green;
      case 'ledger_flagged': return AppColors.clay;
      case 'member_added': return AppColors.indigo;
      default: return AppColors.indigo;
    }
  }
}