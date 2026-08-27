import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _momoController = TextEditingController();
  final _groupService = GroupService();

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _groupService.createGroup(
        name: _nameController.text.trim(),
        contributionAmount: int.parse(_amountController.text.trim()),
        meetingSchedule: _scheduleController.text.trim(),
        momoNumber: _momoController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create group: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Njangi group')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Group name', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a group name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Contribution amount (XAF)',
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an amount';
                    if (int.tryParse(v.trim()) == null) return 'Numbers only';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _scheduleController,
                  decoration: const InputDecoration(
                      labelText: 'Meeting schedule',
                      hintText: 'e.g. Monthly, 1st Saturday',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a schedule' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _momoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Contribution MoMo number',
                      hintText: 'e.g. 6XXXXXXXX',
                      helperText: 'Members send contributions to this number',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().length < 8) ? 'Enter a valid MoMo number' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create group'),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You'll be added as the group's secretary. You can add other members after creating it.",
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}