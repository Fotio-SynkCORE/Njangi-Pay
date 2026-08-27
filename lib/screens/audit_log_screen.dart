import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

/// Read-only history: who did what, when. Secretary-only, matching the
/// SRS's "financial records cannot be silently changed" principle --
/// every ledger write and status change lands here permanently.
class AuditLogScreen extends StatelessWidget {
  final String groupId;
  const AuditLogScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(title: const Text('Audit trail')),
      body: StreamBuilder<List<AuditLogEntry>>(
        stream: groupService.auditLog(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('Could not load: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('No activity recorded yet', style: TextStyle(color: AppColors.inkMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _AuditTile(entry: entries[i], groupService: groupService),
          );
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLogEntry entry;
  final GroupService groupService;
  const _AuditTile({required this.entry, required this.groupService});

  IconData get _icon {
    switch (entry.action) {
      case 'group_created': return Icons.flag_outlined;
      case 'ledger_entry_created': return Icons.add_circle_outline;
      case 'ledger_entry_status_changed': return Icons.published_with_changes_outlined;
      case 'plan_upgraded': return Icons.workspace_premium_outlined;
      default: return Icons.history;
    }
  }

  String get _label {
    switch (entry.action) {
      case 'group_created': return 'Group created';
      case 'ledger_entry_created': return 'Ledger entry recorded';
      case 'ledger_entry_status_changed':
        final from = entry.before?['status'] ?? '?';
        final to = entry.after?['status'] ?? '?';
        return 'Entry status: $from \u2192 $to';
      case 'plan_upgraded':
        final from = entry.before?['planTier'] ?? '?';
        final to = entry.after?['planTier'] ?? '?';
        return 'Plan changed: $from \u2192 $to';
      default: return entry.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.indigo.withOpacity(0.1),
          child: Icon(_icon, color: AppColors.indigo, size: 20),
        ),
        title: Text(_label),
        subtitle: FutureBuilder<String?>(
          future: groupService.memberName(entry.performedBy),
          builder: (context, nameSnap) {
            final who = nameSnap.data ?? 'a member';
            final when = entry.timestamp?.toString().split('.').first ?? '';
            return Text('by $who \u2022 $when', style: const TextStyle(fontSize: 12));
          },
        ),
      ),
    );
  }
}
