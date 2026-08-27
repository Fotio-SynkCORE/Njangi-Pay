import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 1. Added image_picker package
import '../theme/app_theme.dart';

/// Digital ledger view -- shaped against njangiGroups/{groupId}/ledger docs.
/// "Add contribution" supports manual entry or uploading a Mobile Money screenshot.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  // 2. Initialized ImagePicker instance
  static final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final entries = [
      {'type': 'contribution', 'member': 'You', 'amount': 10000, 'status': 'verified', 'date': 'Aug 10'},
      {'type': 'fine', 'member': 'Paul K.', 'amount': 1000, 'status': 'pending', 'date': 'Aug 9'},
      {'type': 'payout', 'member': 'Marie T.', 'amount': 120000, 'status': 'verified', 'date': 'Aug 3'},
      {'type': 'contribution', 'member': 'Alain N.', 'amount': 10000, 'status': 'flagged', 'date': 'Aug 3'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContributionSheet(context),
        backgroundColor: AppColors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'This round',
                    value: '80,000 XAF',
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Outstanding',
                    value: '10,000 XAF',
                    color: AppColors.clay,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _LedgerTile(entry: entries[i]),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showAddContributionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record a contribution', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: 'Amount (XAF)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              // 3. Forcing the button to pick an image asynchronously
              onPressed: () async {
                try {
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    debugPrint('Screenshot selected: ${image.path}');
                    // Here is where you can plug in Firebase Storage upload script later
                  }
                } catch (e) {
                  debugPrint('Error picking screenshot: $e');
                }
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Mobile Money screenshot'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Submit for verification'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

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
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerTile({required this.entry});

  IconData get _icon {
    switch (entry['type']) {
      case 'contribution': return Icons.arrow_downward;
      case 'payout': return Icons.arrow_upward;
      case 'fine': return Icons.warning_amber_outlined;
      default: return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(entry['status'] as String);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(_icon, color: statusColor, size: 20),
        ),
        title: Text('${entry['member']} \u2022 ${entry['type']}'),
        subtitle: Text(entry['date'] as String),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${entry['amount']} XAF', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(entry['status'] as String,
                style: TextStyle(color: statusColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
