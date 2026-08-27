import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

class JoinRequestsScreen extends StatelessWidget {
  final String groupId;
  const JoinRequestsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(title: const Text('Join requests')),
      body: StreamBuilder<List<JoinRequest>>(
        stream: groupService.pendingJoinRequests(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snap.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Text('No pending requests', style: TextStyle(color: AppColors.inkMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final req = requests[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: groupService.memberName(req.memberId),
                          builder: (context, s) => Text(s.data ?? 'A member',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => groupService.respondToJoinRequest(groupId, req.memberId, false),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => groupService.respondToJoinRequest(groupId, req.memberId, true),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}