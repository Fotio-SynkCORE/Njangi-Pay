import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'notifications_screen.dart';

/// Two tabs: the groups you belong to, and a public directory of every
/// group on the platform so people can discover and request to join one
/// instead of only ever seeing their own.
class NjangiGroupsScreen extends StatefulWidget {
  const NjangiGroupsScreen({super.key});

  @override
  State<NjangiGroupsScreen> createState() => _NjangiGroupsScreenState();
}

class _NjangiGroupsScreenState extends State<NjangiGroupsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();
    final notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Njangi-Pay'),
        actions: [
          StreamBuilder<int>(
            stream: notificationService.unreadCount(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
                icon: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.notifications_outlined, color: Colors.white),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Groups'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyGroupsTab(groupService: groupService),
          _DiscoverTab(groupService: groupService),
        ],
      ),
    );
  }
}

class _MyGroupsTab extends StatelessWidget {
  final GroupService groupService;
  const _MyGroupsTab({required this.groupService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NjangiGroup>>(
      stream: groupService.myGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Could not load groups: ${snap.error}\n\nTip: long-press this text to select and copy any link above into your browser.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final groups = snap.data ?? [];
        if (groups.isEmpty) return const _EmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: groups.length,
          itemBuilder: (context, i) => _GroupCard(group: groups[i]),
        );
      },
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  final GroupService groupService;
  const _DiscoverTab({required this.groupService});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<NjangiGroup>>(
      stream: groupService.allGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Could not load groups: ${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }
        final groups = (snap.data ?? []).where((g) => !g.memberIds.contains(uid)).toList();
        if (groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No other groups to discover yet', style: TextStyle(color: AppColors.inkMuted)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: groups.length,
          itemBuilder: (context, i) => _DiscoverCard(group: groups[i], groupService: groupService),
        );
      },
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final NjangiGroup group;
  final GroupService groupService;
  const _DiscoverCard({required this.group, required this.groupService});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(group.name, style: Theme.of(context).textTheme.titleLarge)),
                if (group.planTier != 'free')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(group.planTier.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.indigo)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text('${group.memberIds.length} members', style: const TextStyle(color: AppColors.inkMuted)),
                const SizedBox(width: 16),
                const Icon(Icons.payments_outlined, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text('${group.contributionAmount} ${group.currency} / round',
                    style: const TextStyle(color: AppColors.inkMuted)),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<bool>(
              stream: groupService.hasPendingJoinRequest(group.id),
              builder: (context, reqSnap) {
                final pending = reqSnap.data ?? false;
                return SizedBox(
                  width: double.infinity,
                  child: pending
                      ? OutlinedButton(onPressed: null, child: const Text('Request sent'))
                      : ElevatedButton.icon(
                          onPressed: () async {
                            await groupService.requestToJoin(group.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Request sent to the secretary')),
                              );
                            }
                          },
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('Request to join'),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final NjangiGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final isPaidTier = group.planTier != 'free';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (isPaidTier)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(group.planTier.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.indigo)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: 4),
                  Text('${group.memberIds.length} members', style: const TextStyle(color: AppColors.inkMuted)),
                  const SizedBox(width: 16),
                  const Icon(Icons.payments_outlined, size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: 4),
                  Text('${group.contributionAmount} ${group.currency} / round',
                      style: const TextStyle(color: AppColors.inkMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 56, color: AppColors.inkMuted),
            const SizedBox(height: 16),
            Text('No groups yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Tap "New group" to create one, or check the Discover tab to join an existing group.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}