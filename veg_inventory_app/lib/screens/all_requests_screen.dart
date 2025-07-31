import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/request_model.dart';
import '../models/shop_model.dart';
import 'package:intl/intl.dart';

class AllRequestsScreen extends StatefulWidget {
  @override
  _AllRequestsScreenState createState() => _AllRequestsScreenState();
}

class _AllRequestsScreenState extends State<AllRequestsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, ShopModel> _shops = {};

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      List<ShopModel> shops = await _firestoreService.getAllShops();
      setState(() {
        _shops = {for (var shop in shops) shop.id: shop};
      });
    } catch (e) {
      print('Error loading shops: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Shop Requests - Today\'s Submissions'),
      ),
      body: StreamBuilder<List<RequestModel>>(
        stream: _firestoreService.getAllTodayRequests(),
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
                  Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No requests submitted today',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Shop requests will appear here when submitted'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              RequestModel request = requests[index];
              ShopModel? shop = _shops[request.shopId];
              
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text(
                      shop?.name.substring(0, 1).toUpperCase() ?? 'S',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    shop?.name ?? 'Shop ${request.shopId}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${request.items.length} items requested'),
                      Text(
                        'Submitted: ${DateFormat('HH:mm').format(request.createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text('${request.items.length}'),
                    backgroundColor: Colors.blue.shade100,
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shop != null) ...[
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  shop.location,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                          ],
                          Text(
                            'Requested Items:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SizedBox(height: 8),
                          ...request.items.map((item) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
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
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${item.quantity} ${item.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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