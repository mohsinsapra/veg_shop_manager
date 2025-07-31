import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import 'request_form_screen.dart';
import 'all_requests_screen.dart';
import 'consolidated_list_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final requestProvider = Provider.of<RequestProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        requestProvider.loadTodayRequest(authProvider.currentUser!.shopId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, RequestProvider>(
        builder: (context, authProvider, requestProvider, child) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Email: ${authProvider.currentUser?.email ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Shop ID: ${authProvider.currentUser?.shopId ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'My Shop Request',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      requestProvider.currentRequest?.submitted == true
                          ? Icons.check_circle
                          : Icons.pending,
                      color: requestProvider.currentRequest?.submitted == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      requestProvider.currentRequest?.submitted == true
                          ? 'My Request Submitted'
                          : 'My Request Pending',
                    ),
                    subtitle: Text(
                      requestProvider.currentRequest?.submitted == true
                          ? 'Items: ${requestProvider.currentRequest?.items.length ?? 0}'
                          : 'You can add/edit your shop\'s items',
                    ),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RequestFormScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Admin Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildActionCard(
                      context,
                      'My Shop Request',
                      Icons.add_shopping_cart,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestFormScreen(),
                          ),
                        );
                      },
                    ),
                    _buildActionCard(
                      context,
                      'All Shop Requests',
                      Icons.store,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllRequestsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildActionCard(
                      context,
                      'Purchase List',
                      Icons.list_alt,
                      Colors.orange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConsolidatedListScreen(),
                          ),
                        );
                      },
                    ),
                    _buildActionCard(
                      context,
                      'Export Reports',
                      Icons.download,
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConsolidatedListScreen(showExportOptions: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}