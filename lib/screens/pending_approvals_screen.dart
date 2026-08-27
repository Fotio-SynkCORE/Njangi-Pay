import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

/// Secretary-only screen: review pending ledger entries and approve or
/// flag them. Firestore rules are the real gate on who can call
/// setEntryStatus -- this screen just gives the secretary somewhere to
/// do it from.
class PendingApprovalsScreen extends StatelessWidget {
  final String groupId;
  const PendingApprovalsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(title: const Text('Pending approvals')),
      body: StreamBuilder<List<LedgerEntry>>(
        stream: groupService.pendingEntries(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Could not load pending entries: ${snap.error}\n\nLong-press to copy any link above into your browser.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.task_alt, size: 48, color: AppColors.green),
                    const SizedBox(height: 12),
                    Text('All caught up', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    const Text('No entries waiting for review.',
                        style: TextStyle(color: AppColors.inkMuted)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _PendingCard(
              groupId: groupId,
              entry: entries[i],
              groupService: groupService,
            ),
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final String groupId;
  final LedgerEntry entry;
  final GroupService groupService;

  const _PendingCard({
    required this.groupId,
    required this.entry,
    required this.groupService,
  });

  void _viewScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, String status) async {
    try {
      await groupService.setEntryStatus(groupId, entry.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'verified' ? 'Entry verified' : 'Entry flagged')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<String?>(
                    future: groupService.memberName(entry.memberId),
                    builder: (context, nameSnap) => Text(
                      nameSnap.data ?? 'Member',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                Text('${entry.amount} XAF',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.indigo, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(entry.type, style: const TextStyle(color: AppColors.inkMuted)),
            if (entry.paidBy != null) ...[
              const SizedBox(height: 4),
              FutureBuilder<String?>(
                future: groupService.memberName(entry.paidBy!),
                builder: (context, s) => Text(
                  'Paid by ${s.data ?? 'another member'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.indigo, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (entry.sourceScreenshotUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _viewScreenshot(context, entry.sourceScreenshotUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    entry.sourceScreenshotUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      height: 80,
                      color: AppColors.parchmentDeep,
                      alignment: Alignment.center,
                      child: const Text('Could not load screenshot',
                          style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Tap to view full screenshot before approving',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _act(context, 'flagged'),
                    icon: const Icon(Icons.flag_outlined, color: AppColors.clay, size: 18),
                    label: const Text('Flag', style: TextStyle(color: AppColors.clay)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.clay)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _act(context, 'verified'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}