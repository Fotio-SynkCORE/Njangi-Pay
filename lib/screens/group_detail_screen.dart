import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';
import '../services/screenshot_service.dart';
import 'upgrade_plan_screen.dart';
import 'pending_approvals_screen.dart';
import 'audit_log_screen.dart';
import 'add_members_screen.dart';
import 'loans_screen.dart';
import 'join_requests_screen.dart';
import 'reports_screen.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return StreamBuilder<NjangiGroup>(
      stream: groupService.group(groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntrySheet(context, group),
            backgroundColor: AppColors.indigo,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add entry'),
          ),
          body: Column(
            children: [
              _GroupActionBar(group: group, groupService: groupService),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text('${group.memberIds.length} members',
                        style: const TextStyle(color: AppColors.inkMuted)),
                    const SizedBox(width: 16),
                    Icon(Icons.payments_outlined, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text('${group.contributionAmount} ${group.currency} / round',
                        style: const TextStyle(color: AppColors.inkMuted)),
                  ],
                ),
              ),
              if (group.momoNumber.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android_outlined, size: 18, color: AppColors.indigo),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Send contributions to',
                                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                              Text(group.momoNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.indigo)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy number',
                          icon: const Icon(Icons.copy, size: 18, color: AppColors.indigo),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: group.momoNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('MoMo number copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (group.planTier == 'premium')
                StreamBuilder<String?>(
                  stream: groupService.myRole(group.id),
                  builder: (context, roleSnap) {
                    if (roleSnap.data != 'secretary') return const SizedBox.shrink();
                    return StreamBuilder<List<LoanEntry>>(
                      stream: groupService.loans(group.id),
                      builder: (context, loanSnap) {
                        final overdueCount = (loanSnap.data ?? [])
                            .where((l) => l.isOverdue)
                            .length;
                        if (overdueCount == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Material(
                            color: AppColors.clay.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LoansScreen(groupId: group.id)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_outlined, color: AppColors.clay, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '$overdueCount member(s) have failed to pay their loan by the due date. Tap to review.',
                                        style: const TextStyle(fontSize: 12, color: AppColors.clay),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.clay, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              Expanded(
                child: StreamBuilder<List<LedgerEntry>>(
                  stream: groupService.ledger(group.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SelectableText('Could not load ledger: ${snap.error}',
                              textAlign: TextAlign.center),
                        ),
                      );
                    }
                    final entries = snap.data ?? [];
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text('No ledger entries yet',
                            style: TextStyle(color: AppColors.inkMuted)),
                      );
                    }

                    // Running total: only VERIFIED entries count toward the
                    // real balance -- pending/flagged shouldn't move the
                    // number until the secretary confirms them. Money in
                    // (contributions, social fund, loan repayments, fines)
                    // adds; money out (payouts, loan disbursements)
                    // subtracts.
                    int total = 0;
                    for (final e in entries) {
                      if (e.status != 'verified') continue;
                      switch (e.type) {
                        case 'contribution':
                        case 'socialFund':
                        case 'loanRepayment':
                        case 'fine':
                          total += e.amount;
                          break;
                        case 'payout':
                        case 'loanDisbursement':
                          total -= e.amount;
                          break;
                      }
                    }

                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: (total >= 0 ? AppColors.green : AppColors.clay).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(total >= 0 ? Icons.trending_up : Icons.trending_down,
                                  color: total >= 0 ? AppColors.green : AppColors.clay),
                              const SizedBox(width: 10),
                              const Text('Group balance', style: TextStyle(color: AppColors.inkMuted)),
                              const Spacer(),
                              Text(
                                '${total >= 0 ? '' : '-'}${total.abs()} ${group.currency}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: total >= 0 ? AppColors.green : AppColors.clay,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DataTable(
                                columnSpacing: 20,
                                headingRowColor: WidgetStateProperty.all(AppColors.parchmentDeep),
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: entries.map((e) => _ledgerRow(e, groupService)).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  void _showAddEntrySheet(BuildContext context, NjangiGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddEntrySheet(group: group),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  final NjangiGroup group;
  const _AddEntrySheet({required this.group});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _amountController = TextEditingController();
  final _groupService = GroupService();
  final _screenshotService = ScreenshotService();

  bool _submitting = false;
  bool _uploading = false;
  String? _screenshotUrl;
  bool _payingForSomeone = false;
  List<AppUser> _members = [];
  AppUser? _selectedBeneficiary;

  @override
  void initState() {
    super.initState();
    _groupService.groupMembers(widget.group.id).then((m) {
      if (mounted) setState(() => _members = m);
    });
  }

  Future<void> _pickAndUpload() async {
    // Screenshot attachment is free-tier now -- it's just visual evidence
    // for the secretary to review, not an AI-gated feature.
    final file = await _screenshotService.pickScreenshot();
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final url = await _screenshotService.uploadScreenshot(file);
      setState(() => _screenshotUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_payingForSomeone && _selectedBeneficiary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who you\'re paying for')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _groupService.addLedgerEntry(
        groupId: widget.group.id,
        type: 'contribution',
        amount: amount,
        sourceScreenshotUrl: _screenshotUrl,
        onBehalfOfMemberId: _payingForSomeone ? _selectedBeneficiary!.id : null,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Record a contribution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paying for someone else', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Their name shows on the ledger, not yours', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
            value: _payingForSomeone,
            onChanged: (v) => setState(() => _payingForSomeone = v),
          ),
          if (_payingForSomeone) ...[
            DropdownButtonFormField<AppUser>(
              initialValue: _selectedBeneficiary,
              decoration: const InputDecoration(labelText: 'Paying for', border: OutlineInputBorder()),
              items: _members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.name.isNotEmpty ? m.name : m.email)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBeneficiary = v),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount (XAF)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          if (_screenshotUrl != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Image.network(_screenshotUrl!, width: 40, height: 40, fit: BoxFit.cover),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Screenshot attached \u2014 your secretary will review it',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
            label: Text(_screenshotUrl != null ? 'Replace screenshot' : 'Attach Mobile Money screenshot'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit for verification'),
          ),
        ],
      ),
    );
  }
}

/// Replaces the old cramped row of AppBar icons (which overflowed once a
/// group had enough roles/features active). A horizontally scrollable
/// row of labeled chips reads clearer than unlabeled icons crammed into
/// a title bar, and it scales to any number of actions without ever
/// overflowing again.
class _GroupActionBar extends StatelessWidget {
  final NjangiGroup group;
  final GroupService groupService;
  const _GroupActionBar({required this.group, required this.groupService});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _ActionChip(
              icon: Icons.workspace_premium_outlined,
              label: group.planTier == 'free' ? 'Upgrade' : group.planTier.toUpperCase(),
              highlighted: group.planTier != 'free',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpgradePlanScreen(
                    groupId: group.id,
                    currentTier: group.planTier,
                    groupName: group.name,
                  ),
                ),
              ),
            ),
            if (group.planTier == 'premium')
              _ActionChip(
                icon: Icons.request_quote_outlined,
                label: 'Loans',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoansScreen(groupId: group.id)),
                ),
              ),
            if (group.planTier != 'free')
              _ActionChip(
                icon: Icons.bar_chart_outlined,
                label: 'Reports',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportsScreen(groupId: group.id)),
                ),
              ),
            StreamBuilder<String?>(
              stream: groupService.myRole(group.id),
              builder: (context, roleSnap) {
                if (roleSnap.data != 'secretary') return const SizedBox.shrink();
                return Row(
                  children: [
                    _ActionChip(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Members',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMembersScreen(
                            groupId: group.id,
                            currentMemberIds: group.memberIds,
                            nextRotationPosition: group.memberIds.length,
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<List<JoinRequest>>(
                      stream: groupService.pendingJoinRequests(group.id),
                      builder: (context, reqSnap) => _ActionChip(
                        icon: Icons.how_to_reg_outlined,
                        label: 'Requests',
                        badgeCount: reqSnap.data?.length ?? 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => JoinRequestsScreen(groupId: group.id)),
                        ),
                      ),
                    ),
                    StreamBuilder<List<LedgerEntry>>(
                      stream: groupService.pendingEntries(group.id),
                      builder: (context, pendingSnap) => _ActionChip(
                        icon: Icons.fact_check_outlined,
                        label: 'Approve',
                        badgeCount: pendingSnap.data?.length ?? 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PendingApprovalsScreen(groupId: group.id)),
                        ),
                      ),
                    ),
                    _ActionChip(
                      icon: Icons.history,
                      label: 'Audit',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AuditLogScreen(groupId: group.id)),
                      ),
                    ),
                    if (group.planTier != 'free')
                      _ActionChip(
                        icon: Icons.campaign_outlined,
                        label: 'Remind',
                        onTap: () async {
                          final count = await groupService.sendContributionReminders(group.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Reminded $count member(s)')),
                            );
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool highlighted;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: highlighted ? AppColors.gold.withOpacity(0.16) : AppColors.parchmentDeep,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  label: Text('$badgeCount'),
                  isLabelVisible: badgeCount > 0,
                  child: Icon(icon, size: 17, color: AppColors.indigo),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.indigo)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DataRow _ledgerRow(LedgerEntry entry, GroupService groupService) {
  final statusColor = AppTheme.statusColor(entry.status);
  final date = entry.date;
  final dateStr = date != null
      ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
      : '';
  final timeStr = date != null
      ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
      : '';

  final typeLabels = {
    'contribution': 'Contribution',
    'fine': 'Fine',
    'socialFund': 'Social fund',
    'payout': 'Payout',
    'loanDisbursement': 'Loan taken',
    'loanRepayment': 'Loan repayment',
  };

  return DataRow(
    cells: [
      DataCell(
        FutureBuilder<String?>(
          future: groupService.memberName(entry.memberId),
          builder: (context, snap) => Text(snap.data?.isNotEmpty == true ? snap.data! : 'Member'),
        ),
      ),
      DataCell(Text(typeLabels[entry.type] ?? entry.type)),
      DataCell(Text('${entry.amount}')),
      DataCell(Text(dateStr)),
      DataCell(Text(timeStr)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(entry.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  );
}