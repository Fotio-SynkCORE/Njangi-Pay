import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// SIMULATED MoMo withdrawal confirmation -- the secretary enters her own
/// MoMo number, then her PIN, to authorize sending the loan amount,
/// mirroring the real-world flow of a Njangi secretary actually
/// withdrawing and sending money. Like FakeMomoPaymentScreen, this is a
/// clearly-labeled placeholder for real Mobile Money API integration,
/// not something pretending to move real money.
class LoanDisbursementPinScreen extends StatefulWidget {
  final int amount;
  final String memberName;
  final String momoNumber; // recipient's (the borrower's) MoMo number

  const LoanDisbursementPinScreen({
    super.key,
    required this.amount,
    required this.memberName,
    required this.momoNumber,
  });

  @override
  State<LoanDisbursementPinScreen> createState() => _LoanDisbursementPinScreenState();
}

enum _Step { secretaryNumber, pin, success }

class _LoanDisbursementPinScreenState extends State<LoanDisbursementPinScreen> {
  final _secretaryNumberController = TextEditingController();
  final _pinController = TextEditingController();
  _Step _step = _Step.secretaryNumber;
  bool _processing = false;

  void _goToPin() {
    if (_secretaryNumberController.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your MoMo number')),
      );
      return;
    }
    setState(() => _step = _Step.pin);
  }

  Future<void> _confirm() async {
    if (_pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 4-digit MoMo PIN')),
      );
      return;
    }
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _step = _Step.success;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disburse loan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.secretaryNumber => _buildNumberStep(context),
            _Step.pin => _buildPinStep(context),
            _Step.success => _buildSuccess(context),
          },
        ),
      ),
    );
  }

  Widget _buildNumberStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.indigo),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo mode: simulates you withdrawing and sending the loan via your Mobile Money. No real transfer happens.',
                  style: TextStyle(fontSize: 12, color: AppColors.indigo),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Send to ${widget.memberName}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text('Their MoMo: ${widget.momoNumber}',
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Text('${widget.amount} XAF',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.indigo)),
        const SizedBox(height: 28),
        TextField(
          controller: _secretaryNumberController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Your MoMo number (sending from)',
            hintText: '6XXXXXXXX',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_android_outlined),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _goToPin,
          child: Text('Send ${widget.amount} XAF'),
        ),
      ],
    );
  }

  Widget _buildPinStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.parchmentDeep,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Confirm sending ${widget.amount} XAF from ${_secretaryNumberController.text.trim()} to ${widget.memberName}. Enter your PIN to authorize.',
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 12),
          decoration: const InputDecoration(
            labelText: 'MoMo PIN',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _processing ? null : _confirm,
          child: _processing
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Confirm & send ${widget.amount} XAF'),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.green.withOpacity(0.15),
          child: const Icon(Icons.check, color: AppColors.green, size: 36),
        ),
        const SizedBox(height: 20),
        Text('Loan disbursed', style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}