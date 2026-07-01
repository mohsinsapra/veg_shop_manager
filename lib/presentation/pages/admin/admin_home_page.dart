import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../providers/firebase_auth_provider.dart';
import 'admin_dashboard_page.dart';
import 'admin_entry_page.dart';
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

  // Full section list. The first [_bottomCount] appear in the bottom bar; the
  // hamburger drawer (top-left) exposes all of them.
  static const _titles = ['Today', 'Catalog', 'Members', 'Shops', 'History'];
  static const _icons = [
    Icons.today,
    Icons.eco,
    Icons.people,
    Icons.store,
    Icons.history,
  ];
  static const _bottomCount = 3;

  Widget _body() {
    switch (_index) {
      case 0:
        return const AdminDashboardPage();
      case 1:
        return const CatalogManagementPage();
      case 2:
        return const MembersManagementPage();
      case 3:
        return const ShopsManagementPage();
      default:
        return const HistoryPage();
    }
  }

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      appBar: AppBar(
        title: Text('GreenChain — ${_titles[_index]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: context.l10n.settingsTitle,
            onPressed: () => context.beamToNamed('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Center(
                  child: Text('GreenChain',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
              for (var i = 0; i < _titles.length; i++)
                ListTile(
                  leading: Icon(_icons[i]),
                  title: Text(_titles[i]),
                  selected: _index == i,
                  onTap: () {
                    _select(i);
                    Navigator.pop(context); // close drawer
                  },
                ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
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
              selectedIndex: _index < _bottomCount ? _index : 0,
              onDestinationSelected: _select,
              destinations: [
                for (var i = 0; i < _bottomCount; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
              ],
            ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add items'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminEntryPage()),
              ),
            )
          : null,
    );
  }
}
