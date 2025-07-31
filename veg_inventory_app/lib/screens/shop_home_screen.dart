import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import 'request_form_screen.dart';
import 'request_history_screen.dart';

class ShopHomeScreen extends StatefulWidget {
  @override
  _ShopHomeScreenState createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends State<ShopHomeScreen> {
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
        title: Text('Shop Dashboard'),
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
          if (requestProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

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
                          'Welcome!',
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
                  'Today\'s Request Status',
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
                          ? 'Request Submitted'
                          : 'Request Pending',
                    ),
                    subtitle: Text(
                      requestProvider.currentRequest?.submitted == true
                          ? 'Items: ${requestProvider.currentRequest?.items.length ?? 0}'
                          : 'You can still add/edit items',
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
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestFormScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Add Request'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestHistoryScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.history),
                        label: Text('View History'),
                      ),
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
}