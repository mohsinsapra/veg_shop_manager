import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/firebase_auth_provider.dart';
import 'admin_dashboard_page.dart';
import 'history_page.dart';
import 'shops_management_page.dart';
import 'catalog_management_page.dart';
import 'members_management_page.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  int _index = 0;

  static const _titles = ['Today', 'History', 'Shops', 'Catalog', 'Members'];
  static const _icons = [
    Icons.today,
    Icons.history,
    Icons.store,
    Icons.eco,
    Icons.people,
  ];

  Widget _body() {
    switch (_index) {
      case 0:
        return const AdminDashboardPage();
      case 1:
        return const HistoryPage();
      case 2:
        return const ShopsManagementPage();
      case 3:
        return const CatalogManagementPage();
      default:
        return const MembersManagementPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      appBar: AppBar(
        title: Text('GreenChain — ${_titles[_index]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_titles[i]),
                  ),
              ],
            ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
              ],
            ),
    );
  }
}
