import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/export_service.dart';
import '../models/request_model.dart';
import '../models/shop_model.dart';
import '../models/item_model.dart';
import 'package:intl/intl.dart';

class ConsolidatedItem {
  final String name;
  final String unit;
  double totalQuantity;
  final Map<String, double> shopQuantities;
  final Map<String, String> shopNotes;

  ConsolidatedItem({
    required this.name,
    required this.unit,
    this.totalQuantity = 0,
    Map<String, double>? shopQuantities,
    Map<String, String>? shopNotes,
  })  : shopQuantities = shopQuantities ?? {},
        shopNotes = shopNotes ?? {};

  void addItem(String shopId, ItemModel item) {
    shopQuantities[shopId] = item.quantity;
    if (item.note.isNotEmpty) {
      shopNotes[shopId] = item.note;
    }
    totalQuantity = shopQuantities.values.fold(0, (sum, qty) => sum + qty);
  }
}

class ConsolidatedListScreen extends StatefulWidget {
  final bool showExportOptions;

  const ConsolidatedListScreen({Key? key, this.showExportOptions = false}) : super(key: key);

  @override
  _ConsolidatedListScreenState createState() => _ConsolidatedListScreenState();
}

class _ConsolidatedListScreenState extends State<ConsolidatedListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ExportService _exportService = ExportService();
  Map<String, ShopModel> _shops = {};
  List<ConsolidatedItem> _consolidatedItems = [];
  List<RequestModel> _allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
        title: Text('Purchase List - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}'),
        actions: widget.showExportOptions
            ? [
                PopupMenuButton<String>(
                  onSelected: _handleExport,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf),
                          SizedBox(width: 8),
                          Text('Export PDF'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart),
                          SizedBox(width: 8),
                          Text('Export CSV'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
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
          _allRequests = requests;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No requests to consolidate',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Submit shop requests to generate purchase list'),
                ],
              ),
            );
          }

          _consolidatedItems = _consolidateRequests(requests);

          return Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard('Shops', '${requests.length}', Icons.store),
                    _buildSummaryCard('Items', '${_consolidatedItems.length}', Icons.inventory),
                    _buildSummaryCard('Total Qty', '${_getTotalQuantity()}', Icons.shopping_cart),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _consolidatedItems.length,
                  itemBuilder: (context, index) {
                    ConsolidatedItem item = _consolidatedItems[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            item.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Total: ${item.totalQuantity} ${item.unit}'),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${item.totalQuantity} ${item.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shop Breakdown:',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                SizedBox(height: 8),
                                ...item.shopQuantities.entries.map((entry) {
                                  String shopId = entry.key;
                                  double quantity = entry.value;
                                  ShopModel? shop = _shops[shopId];
                                  String note = item.shopNotes[shopId] ?? '';

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
                                                shop?.name ?? 'Shop $shopId',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              if (note.isNotEmpty)
                                                Text(
                                                  'Note: $note',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$quantity ${item.unit}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  List<ConsolidatedItem> _consolidateRequests(List<RequestModel> requests) {
    Map<String, ConsolidatedItem> itemsMap = {};

    for (RequestModel request in requests) {
      for (ItemModel item in request.items) {
        String key = '${item.name}_${item.unit}';
        
        if (!itemsMap.containsKey(key)) {
          itemsMap[key] = ConsolidatedItem(
            name: item.name,
            unit: item.unit,
          );
        }
        
        itemsMap[key]!.addItem(request.shopId, item);
      }
    }

    List<ConsolidatedItem> sortedItems = itemsMap.values.toList();
    sortedItems.sort((a, b) => a.name.compareTo(b.name));
    return sortedItems;
  }

  String _getTotalQuantity() {
    double total = _consolidatedItems.fold(0, (sum, item) => sum + item.totalQuantity);
    return total.toStringAsFixed(1);
  }

  Future<void> _handleExport(String format) async {
    try {
      if (format == 'pdf') {
        await _exportService.exportToPDF(_consolidatedItems, _shops, _allRequests);
      } else if (format == 'csv') {
        await _exportService.exportToCSV(_consolidatedItems, _shops);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported successfully as $format')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }
}