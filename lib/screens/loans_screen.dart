import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';
import '../services/screenshot_service.dart';
import 'loan_disbursement_pin_screen.dart';

class LoansScreen extends StatefulWidget {
  final String groupId;
  const LoansScreen({super.key, required this.groupId});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _groupService = GroupService();

  @override
  void initState() {
    super.initState();
    // Client-triggered due-date check (no cron on the free plan) -- runs
    // once whenever anyone opens this screen.
    _groupService.checkLoanDueDates(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestSheet(context, _groupService),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Request loan'),
      ),
      body: StreamBuilder<String?>(
        stream: _groupService.myRole(widget.groupId),
        builder: (context, roleSnap) {
          final isSecretary = roleSnap.data == 'secretary';
          return StreamBuilder<List<LoanEntry>>(
            stream: _groupService.loans(widget.groupId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText('Could not load loans: ${snap.error}', textAlign: TextAlign.center),
                  ),
                );
              }
              final loans = snap.data ?? [];
              if (loans.isEmpty) {
                return const Center(
                  child: Text('No loans yet', style: TextStyle(color: AppColors.inkMuted)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: loans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _LoanCard(
                  groupId: widget.groupId,
                  loan: loans[i],
                  isSecretary: isSecretary,
                  groupService: _groupService,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRequestSheet(BuildContext context, GroupService groupService) {
    final amountController = TextEditingController();
    final momoController = TextEditingController();
    final collateralController = TextEditingController();
    DateTime? dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final amount = int.tryParse(amountController.text.trim()) ?? 0;
          final needsCollateral = amount > GroupService.collateralThreshold;

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Request a loan', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(labelText: 'Amount (XAF)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: momoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'MoMo number to receive the loan',
                      hintText: '6XXXXXXXX',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dueDate == null
                        ? 'Select repayment due date'
                        : 'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSheetState(() => dueDate = picked);
                    },
                  ),
                  if (needsCollateral) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Loans over ${GroupService.collateralThreshold} XAF require collateral',
                        style: const TextStyle(fontSize: 12, color: AppColors.indigo),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: collateralController,
                      decoration: const InputDecoration(
                        labelText: 'Collateral',
                        hintText: 'e.g. Motorbike, land title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (amount <= 0 || dueDate == null || momoController.text.trim().length < 8) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter an amount, MoMo number, and due date')),
                        );
                        return;
                      }
                      if (needsCollateral && collateralController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Collateral is required for this amount')),
                        );
                        return;
                      }
                      await groupService.requestLoan(
                        widget.groupId,
                        amount,
                        dueDate!,
                        momoController.text.trim(),
                        collateralController.text.trim().isEmpty ? null : collateralController.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Submit request'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final String groupId;
  final LoanEntry loan;
  final bool isSecretary;
  final GroupService groupService;

  const _LoanCard({
    required this.groupId,
    required this.loan,
    required this.isSecretary,
    required this.groupService,
  });

  Color get _statusColor {
    if (loan.isOverdue) return AppColors.clay;
    switch (loan.status) {
      case 'active': return AppColors.gold;
      case 'repaid': return AppColors.green;
      case 'rejected': return AppColors.clay;
      default: return AppColors.inkMuted;
    }
  }

  Future<void> _approve(BuildContext context) async {
    final name = await groupService.memberName(loan.memberId) ?? 'the member';
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDisbursementPinScreen(
          amount: loan.amount,
          memberName: name,
          momoNumber: loan.momoNumber,
        ),
      ),
    );
    if (confirmed == true) {
      await groupService.disburseLoan(groupId, loan.id);
    }
  }

  void _addFine(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add fine for late payment'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Fine amount (XAF)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) return;
              await groupService.addLoanFine(groupId, loan.id, loan.memberId, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add fine'),
          ),
        ],
      ),
    );
  }

  void _repay(BuildContext context) {
    final controller = TextEditingController();
    final screenshotService = ScreenshotService();
    String? screenshotUrl;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record repayment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (XAF)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final file = await screenshotService.pickScreenshot();
                        if (file == null) return;
                        setDialogState(() => uploading = true);
                        try {
                          final url = await screenshotService.uploadScreenshot(file);
                          setDialogState(() {
                            screenshotUrl = url;
                            uploading = false;
                          });
                        } catch (e) {
                          setDialogState(() => uploading = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Upload failed: $e')),
                            );
                          }
                        }
                      },
                icon: uploading
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(screenshotUrl != null ? Icons.check_circle_outline : Icons.upload_file_outlined),
                label: Text(screenshotUrl != null ? 'Screenshot attached' : 'Attach payment screenshot'),
              ),
              const SizedBox(height: 4),
              const Text('Your secretary will verify before this reduces your balance.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final amount = int.tryParse(controller.text.trim());
                if (amount == null || amount <= 0) return;
                await groupService.repayLoan(groupId, loan.id, amount, screenshotUrl: screenshotUrl);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loan.isOverdue && isSecretary)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.clay.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: AppColors.clay, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('This member has failed to pay by the due date.',
                          style: TextStyle(fontSize: 12, color: AppColors.clay)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<String?>(
                    future: groupService.memberName(loan.memberId),
                    builder: (context, s) => Text(s.data ?? 'Member',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                Text('${loan.amount} XAF',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.indigo)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(loan.isOverdue ? 'overdue' : loan.status,
                      style: TextStyle(color: _statusColor, fontSize: 11)),
                ),
                if (loan.status == 'active')
                  Text('Outstanding: ${loan.outstandingBalance} XAF',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                if (loan.dueDate != null)
                  Text(
                    'Due: ${loan.dueDate!.year}-${loan.dueDate!.month.toString().padLeft(2, '0')}-${loan.dueDate!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
              ],
            ),
            if (loan.momoNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('MoMo: ${loan.momoNumber}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            ],
            if (loan.collateral != null && loan.collateral!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Collateral: ${loan.collateral}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            if (isSecretary && loan.status == 'requested')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => groupService.rejectLoan(groupId, loan.id),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(context),
                      child: const Text('Approve & disburse'),
                    ),
                  ),
                ],
              ),
            if (isSecretary && loan.isOverdue && !loan.lateFeeApplied)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addFine(context),
                  icon: const Icon(Icons.gavel_outlined, color: AppColors.clay, size: 18),
                  label: const Text('Add fine', style: TextStyle(color: AppColors.clay)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.clay)),
                ),
              ),
            if (loan.status == 'active')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _repay(context),
                    child: const Text('Record repayment'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}