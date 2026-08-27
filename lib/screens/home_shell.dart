import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'njangi_groups_screen.dart';
import 'account_screen.dart';
import 'personal_finance_screen.dart';

/// Home shell managing the main application tabs: Groups, Finance, and Account.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Inserted PersonalFinanceScreen in the middle (index 1)
  final _screens = const [
    NjangiGroupsScreen(),
    PersonalFinanceScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index, 
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.gold.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: AppColors.indigo),
            label: 'Groups',
          ),
          // Added Finance destination in the middle
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.indigo),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.indigo),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
