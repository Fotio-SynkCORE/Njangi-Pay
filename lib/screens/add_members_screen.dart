import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/group_service.dart';

/// WhatsApp-style "add participant" flow: browse everyone with an
/// account, search by name/email, tap to add. Only reachable via the
/// secretary-only button on GroupDetailScreen.
class AddMembersScreen extends StatefulWidget {
  final String groupId;
  final List<String> currentMemberIds;
  final int nextRotationPosition;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.currentMemberIds,
    required this.nextRotationPosition,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _groupService = GroupService();
  final _searchController = TextEditingController();

  List<AppUser> _allUsers = [];
  bool _loading = true;
  final Set<String> _addingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await _groupService.browsableUsers(widget.currentMemberIds);
    if (mounted) setState(() {
      _allUsers = users;
      _loading = false;
    });
  }

  Future<void> _add(AppUser user, int index) async {
    setState(() => _addingIds.add(user.id));
    try {
      await _groupService.addMember(
        widget.groupId,
        user.id,
        widget.nextRotationPosition + index,
      );
      if (mounted) {
        setState(() => _allUsers.removeWhere((u) => u.id == user.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name.isNotEmpty ? user.name : user.email} added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _allUsers
        : _allUsers
            .where((u) =>
                u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add members')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _allUsers.isEmpty
                              ? 'No other accounts found yet'
                              : 'No matches',
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final user = filtered[i];
                          final adding = _addingIds.contains(user.id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.indigo.withOpacity(0.1),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(user.name.isNotEmpty ? user.name : user.email),
                            subtitle: user.name.isNotEmpty ? Text(user.email) : null,
                            trailing: adding
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : TextButton(
                                    onPressed: () => _add(user, i),
                                    child: const Text('Add'),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}