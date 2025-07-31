import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/request_model.dart';
import 'package:intl/intl.dart';

class RequestHistoryScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Request History'),
      ),
      body: StreamBuilder<List<RequestModel>>(
        stream: _firestoreService.getShopRequests(authProvider.currentUser!.shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading requests'),
                  Text(snapshot.error.toString()),
                ],
              ),
            );
          }

          List<RequestModel> requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No requests found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Your submitted requests will appear here'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              RequestModel request = requests[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Icon(
                    request.submitted ? Icons.check_circle : Icons.pending,
                    color: request.submitted ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    'Request - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(request.date))}',
                  ),
                  subtitle: Text(
                    '${request.items.length} items • ${request.submitted ? 'Submitted' : 'Draft'}',
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Items:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SizedBox(height: 8),
                          ...request.items.map((item) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (item.note.isNotEmpty)
                                          Text(
                                            'Note: ${item.note}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} ${item.unit}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          SizedBox(height: 8),
                          Text(
                            'Created: ${DateFormat('MMM dd, yyyy at HH:mm').format(request.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}