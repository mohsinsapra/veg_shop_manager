import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/request_provider.dart';
import '../models/item_model.dart';
import '../widgets/item_form_dialog.dart';

class RequestFormScreen extends StatefulWidget {
  @override
  _RequestFormScreenState createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Request'),
        actions: [
          Consumer<RequestProvider>(
            builder: (context, requestProvider, child) {
              bool canEdit = requestProvider.currentRequest?.submitted != true;
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  try {
                    if (value == 'save') {
                      await requestProvider.saveRequest(authProvider.currentUser!.shopId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Request saved as draft')),
                      );
                    } else if (value == 'submit') {
                      await requestProvider.saveRequest(
                        authProvider.currentUser!.shopId,
                        submit: true,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Request submitted successfully')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (canEdit) ...[
                    PopupMenuItem(
                      value: 'save',
                      child: Text('Save Draft'),
                    ),
                    PopupMenuItem(
                      value: 'submit',
                      child: Text('Submit Request'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          bool canEdit = requestProvider.currentRequest?.submitted != true;
          
          return Column(
            children: [
              if (requestProvider.currentRequest?.submitted == true)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Colors.green.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Request submitted - View only mode',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: requestProvider.currentItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No items added yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 8),
                            Text(
                              canEdit ? 'Tap + to add items' : 'No items in this request',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: requestProvider.currentItems.length,
                        itemBuilder: (context, index) {
                          ItemModel item = requestProvider.currentItems[index];
                          return Card(
                            child: ListTile(
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.quantity} ${item.unit}'),
                                  if (item.note.isNotEmpty) Text('Note: ${item.note}'),
                                ],
                              ),
                              trailing: canEdit
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit),
                                          onPressed: () => _editItem(context, index, item),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete),
                                          onPressed: () => _deleteItem(context, index),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          bool canEdit = requestProvider.currentRequest?.submitted != true;
          return canEdit
              ? FloatingActionButton(
                  onPressed: () => _addItem(context),
                  child: Icon(Icons.add),
                )
              : SizedBox.shrink();
        },
      ),
    );
  }

  void _addItem(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ItemFormDialog(),
    ).then((item) {
      if (item != null) {
        Provider.of<RequestProvider>(context, listen: false).addItem(item);
      }
    });
  }

  void _editItem(BuildContext context, int index, ItemModel item) {
    showDialog(
      context: context,
      builder: (context) => ItemFormDialog(item: item),
    ).then((updatedItem) {
      if (updatedItem != null) {
        Provider.of<RequestProvider>(context, listen: false)
            .updateItem(index, updatedItem);
      }
    });
  }

  void _deleteItem(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<RequestProvider>(context, listen: false).removeItem(index);
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}