import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _FaqTile(
            question: 'How do I create a Njangi group?',
            answer:
                'Go to the Groups tab and tap "New group". You\'ll be added as the secretary automatically.',
          ),
          _FaqTile(
            question: 'How do I record a contribution?',
            answer:
                'Open your group, tap "Add entry", enter the amount, and submit. Your secretary will verify it.',
          ),
          _FaqTile(
            question: 'What does "Premium" unlock?',
            answer:
                'Premium groups can upload Mobile Money screenshots and have the amount extracted automatically instead of typing it in.',
          ),
          _FaqTile(
            question: 'Who can verify my contribution?',
            answer:
                'Only your group\'s secretary. You\'ll get a notification once it\'s verified or flagged.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(answer, style: const TextStyle(color: AppColors.inkMuted)),
            ),
          ),
        ],
      ),
    );
  }
}