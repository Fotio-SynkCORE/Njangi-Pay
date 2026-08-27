import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// SIMULATED Mobile Money payment confirmation screen, for demoing the
/// upgrade flow before real MTN/Orange Money integration exists.
/// Clearly labeled as a simulation on-screen -- this is a placeholder for
/// a real payment gateway call, not something masquerading as production
/// code. Three steps mirror what a real MoMo push-payment feels like:
/// enter number -> USSD-style PIN prompt -> confirmed.
class FakeMomoPaymentScreen extends StatefulWidget {
  final int amount;
  final String reason; // e.g. "Standard plan -- Family Njangi"

  const FakeMomoPaymentScreen({super.key, required this.amount, required this.reason});

  @override
  State<FakeMomoPaymentScreen> createState() => _FakeMomoPaymentScreenState();
}

enum _Step { number, pin, success }

class _FakeMomoPaymentScreenState extends State<FakeMomoPaymentScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  _Step _step = _Step.number;
  bool _processing = false;

  void _requestPin() {
    if (_phoneController.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Mobile Money number')),
      );
      return;
    }
    setState(() => _step = _Step.pin);
  }

  Future<void> _confirmPin() async {
    if (_pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 4-digit MoMo PIN')),
      );
      return;
    }
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2)); // simulated network delay
    if (!mounted) return;
    setState(() {
      _processing = false;
      _step = _Step.success;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true); // true = payment "succeeded"
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Money payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.number => _buildNumberStep(context),
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
                  'Demo mode: this simulates a Mobile Money payment. No real charge is made.',
                  style: TextStyle(fontSize: 12, color: AppColors.indigo),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(widget.reason, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${widget.amount} XAF',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.indigo)),
        const SizedBox(height: 28),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'MTN/Orange Money number',
            hintText: '6XXXXXXXX',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_android_outlined),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _requestPin,
          child: Text('Pay ${widget.amount} XAF'),
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
            'Njangi-Pay is requesting to withdraw ${widget.amount} XAF from your Mobile Money account. Enter your PIN to authorize.',
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
          onPressed: _processing ? null : _confirmPin,
          child: _processing
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm'),
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
        Text('Payment confirmed', style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}