import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';
import 'fake_momo_payment_screen.dart';

/// Real upgrade flow: shows tier pricing from the SRS business model,
/// launches the (currently simulated) MoMo payment, and on success writes
/// planTier to Firestore for real via GroupService.upgradePlan.
class UpgradePlanScreen extends StatefulWidget {
  final String groupId;
  final String currentTier;
  final String groupName;

  const UpgradePlanScreen({
    super.key,
    required this.groupId,
    required this.currentTier,
    required this.groupName,
  });

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  final _groupService = GroupService();
  bool _upgrading = false;

  Future<void> _upgradeTo(String tier, int price) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FakeMomoPaymentScreen(
          amount: price,
          reason: '${tier[0].toUpperCase()}${tier.substring(1)} plan \u2014 ${widget.groupName}',
        ),
      ),
    );
    if (paid != true) return;

    setState(() => _upgrading = true);
    try {
      await _groupService.upgradePlan(widget.groupId, widget.currentTier, tier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upgraded to ${tier[0].toUpperCase()}${tier.substring(1)}')),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlanCard(
            tier: 'standard',
            title: 'Standard',
            price: 2000,
            features: const [
              'Personal finance tracking',
              'Reports & analytics',
              'Automated reminders',
            ],
            isCurrent: widget.currentTier == 'standard',
            disabled: widget.currentTier == 'premium',
            onSelect: _upgrading ? null : () => _upgradeTo('standard', 2000),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            tier: 'premium',
            title: 'Premium',
            price: 5000,
            features: const [
              'Everything in Standard',
              'Loans management',
              'Advanced audit reports',
            ],
            isCurrent: widget.currentTier == 'premium',
            disabled: false,
            highlighted: true,
            onSelect: _upgrading ? null : () => _upgradeTo('premium', 5000),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String tier;
  final String title;
  final int price;
  final List<String> features;
  final bool isCurrent;
  final bool disabled;
  final bool highlighted;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.tier,
    required this.title,
    required this.price,
    required this.features,
    required this.isCurrent,
    required this.disabled,
    required this.onSelect,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted ? AppColors.gold : AppColors.parchmentDeep,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('$price XAF/mo',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.indigo)),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(onPressed: null, child: const Text('Current plan'))
                  : ElevatedButton(
                      onPressed: disabled ? null : onSelect,
                      child: Text(disabled ? 'Included in your plan' : 'Upgrade'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}