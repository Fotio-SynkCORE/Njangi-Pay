import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

/// Real computed stats from the ledger -- nothing here is a fabricated
/// number, it's all derived from actual entries in Firestore.
class ReportsScreen extends StatelessWidget {
  final String groupId;
  const ReportsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: StreamBuilder<NjangiGroup>(
        stream: groupService.group(groupId),
        builder: (context, groupSnap) {
          if (!groupSnap.hasData) return const Center(child: CircularProgressIndicator());
          final group = groupSnap.data!;

          return StreamBuilder<List<LedgerEntry>>(
            stream: groupService.ledger(groupId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snap.data ?? [];

              final verified = entries.where((e) => e.status == 'verified').toList();
              final totalCollected = verified
                  .where((e) => e.type == 'contribution')
                  .fold<int>(0, (sum, e) => sum + e.amount);
              final flaggedCount = entries.where((e) => e.status == 'flagged').length;
              final pendingCount = entries.where((e) => e.status == 'pending').length;

              final contributedMemberIds = verified
                  .where((e) => e.type == 'contribution')
                  .map((e) => e.memberId)
                  .toSet();
              final totalMembers = group.memberIds.length;
              final completionRate = totalMembers == 0
                  ? 0.0
                  : contributedMemberIds.length / totalMembers;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total collected',
                          value: '$totalCollected XAF',
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Completion rate',
                          value: '${(completionRate * 100).toStringAsFixed(0)}%',
                          color: AppColors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Pending review',
                          value: '$pendingCount',
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Flagged',
                          value: '$flaggedCount',
                          color: AppColors.clay,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Members', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...group.memberIds.map((id) {
                    final hasContributed = contributedMemberIds.contains(id);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          hasContributed ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: hasContributed ? AppColors.green : AppColors.inkMuted,
                        ),
                        title: FutureBuilder<String?>(
                          future: groupService.memberName(id),
                          builder: (context, s) => Text(s.data ?? 'Member'),
                        ),
                        trailing: Text(
                          hasContributed ? 'Contributed' : 'No contribution yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasContributed ? AppColors.green : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
