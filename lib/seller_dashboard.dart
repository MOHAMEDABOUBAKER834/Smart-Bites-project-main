import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'package:smart_bites/product_form_screen.dart';
import 'package:smart_bites/seller_profile_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late TabController _tabController;
  Stream<DatabaseEvent>? _ordersStream;
  String? _sellerSchoolName; // Store seller's school name (seller's name is the school name)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Create a broadcast stream to avoid "Stream has already been listened to" error
    // Use onValue without orderByChild to avoid index requirements
    _ordersStream = _database.ref('orders').onValue.asBroadcastStream();
    _fetchSellerSchoolName();
  }

  Future<void> _fetchSellerSchoolName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Get seller's name (which is the school name) from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        final name = userDoc.data()?['name']?.toString();
        setState(() {
          _sellerSchoolName = name;
        });
      }
      
      // Also try Realtime Database
      if (_sellerSchoolName == null || _sellerSchoolName!.isEmpty) {
        final userRef = _database.ref('users/${user.uid}');
        final snapshot = await userRef.get();
        if (snapshot.exists && mounted) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _sellerSchoolName = data['name']?.toString();
          });
        }
      }
    } catch (e) {
      print('Error fetching seller school name: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'dashboard_title': 'لوحة تحكم البائع',
      'my_products': 'منتجاتي',
      'orders': 'الطلبات',
      'add_new_product': 'إضافة منتج جديد',
      'no_products': 'لا توجد منتجات حتى الآن',
      'no_orders': 'لا توجد طلبات حتى الآن',
      'edit': 'تعديل',
      'delete': 'حذف',
      'out_of_stock': 'نفذت الكمية',
      'in_stock': 'متوفر',
      'delete_confirmation': 'هل أنت متأكد من حذف هذا المنتج؟',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'product_deleted': 'تم حذف المنتج بنجاح',
      'product_updated': 'تم تحديث حالة المنتج',
      'error': 'حدث خطأ',
      'order_id': 'طلب رقم',
      'status': 'الحالة',
      'pending': 'قيد التجهيز',
      'ready': 'جاهز',
      'completed': 'مكتمل',
      'mark_ready': 'تم التجهيز',
      'mark_ready_confirmation': 'هل أنت متأكد من أن الطلب جاهز؟',
      'order_ready_success': 'تم تحديث حالة الطلب إلى جاهز',
      'total_points': 'إجمالي النقاط',
      'customer': 'العميل',
      'items': 'العناصر',
      'notes': 'ملاحظات',
      'created_at': 'تاريخ الطلب',
    },
    'en': {
      'dashboard_title': 'Seller Dashboard',
      'my_products': 'My Products',
      'orders': 'Orders',
      'add_new_product': 'Add New Product',
      'no_products': 'No products yet',
      'no_orders': 'No orders yet',
      'edit': 'Edit',
      'delete': 'Delete',
      'out_of_stock': 'Out of Stock',
      'in_stock': 'In Stock',
      'delete_confirmation': 'Are you sure you want to delete this product?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'product_deleted': 'Product deleted successfully',
      'product_updated': 'Product status updated',
      'error': 'An error occurred',
      'order_id': 'Order',
      'status': 'Status',
      'pending': 'Pending',
      'ready': 'Ready',
      'completed': 'Completed',
      'mark_ready': 'Mark as Ready',
      'mark_ready_confirmation': 'Are you sure the order is ready?',
      'order_ready_success': 'Order status updated to Ready',
      'total_points': 'Total Points',
      'customer': 'Customer',
      'items': 'Items',
      'notes': 'Notes',
      'created_at': 'Order Date',
    }
  };

  Widget _buildProductsTab(Map<String, String> loc, user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductFormScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(loc['add_new_product']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              loc['my_products']!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('products')
                .where('sellerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    loc['no_products']!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final product = doc.data() as Map<String, dynamic>;
                  final productId = doc.id;
                  final isOutOfStock = product['isOutOfStock'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12.0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildProductImage(product),
                      ),
                      title: Text(
                        product['name'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${loc['in_stock']!}: ${product['price'] ?? 0} ${loc['in_stock']!.contains('Points') ? '' : 'EGP'}'),
                          if (product['description'] != null)
                            Text(
                              product['description'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isOutOfStock,
                            onChanged: (value) {
                              _updateProductStatus(productId, value);
                            },
                            activeColor: Colors.red,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductFormScreen(
                                    productId: productId,
                                    initialProduct: product,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(context, productId, loc),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(Map<String, String> loc, user) {
    if (_ordersStream == null) {
      return Center(
        child: Text(
          loc['error']!,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Orders stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${loc['error']!}: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _ordersStream = _database.ref('orders').onValue.asBroadcastStream();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          print('No orders data found');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  loc['no_orders']!,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final rawValue = snapshot.data!.snapshot.value;
        if (rawValue == null) {
          return Center(
            child: Text(
              loc['no_orders']!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final ordersMap = Map<String, dynamic>.from(
          rawValue as Map,
        );
        
        print('Orders fetched: ${ordersMap.length} orders found');

        // Filter orders by status (Pending and Ready) and by school
        final activeOrders = ordersMap.entries.where((entry) {
          try {
            final order = entry.value as Map<dynamic, dynamic>;
            
            // Filter by school: sellers only see orders from their school
            if (_sellerSchoolName != null && _sellerSchoolName!.isNotEmpty) {
              final orderSchool = order['school']?.toString();
              if (orderSchool != _sellerSchoolName) {
                return false; // Order is not from seller's school
              }
            }
            
            final status = order['status'] as String? ?? 'Pending';
            return status == 'Pending' || status == 'Ready' || status == 'Completed';
          } catch (e) {
            print('Error filtering order ${entry.key}: $e');
            return false;
          }
        }).toList();

        print('Active orders after filtering: ${activeOrders.length}');

        // Sort by createdAt descending
        activeOrders.sort((a, b) {
          try {
            final aTime = (a.value as Map)['createdAt'] as num? ?? 0;
            final bTime = (b.value as Map)['createdAt'] as num? ?? 0;
            return bTime.compareTo(aTime);
          } catch (e) {
            return 0;
          }
        });

        if (activeOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  loc['no_orders']!,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total orders in database: ${ordersMap.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final entry = activeOrders[index];
            final orderKey = entry.key;
            final order = Map<String, dynamic>.from(entry.value as Map);
            final orderId = order['orderId'] ?? orderKey;
            final status = order['status'] as String? ?? 'Pending';
            final totalPoints = order['totalPoints'] ?? 0;
            final userId = order['userId'] as String? ?? '';
            final items = order['items'] as Map<dynamic, dynamic>? ?? {};
            final notes = order['notes'] as String? ?? '';
            final timestamp = order['createdAt'] as num? ?? 0;
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  '${loc['order_id']!} #$orderId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'Pending' 
                                ? Colors.orange.shade100 
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'Pending' ? loc['pending']! : loc['ready']!,
                            style: TextStyle(
                              color: status == 'Pending' 
                                  ? Colors.orange.shade800 
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$totalPoints',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notes.isNotEmpty) ...[
                          Text(
                            '${loc['notes']!}: $notes',
                            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          '${loc['created_at']!}: ${date.toString().substring(0, 16)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc['items']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...items.entries.map((itemEntry) {
                          final item = Map<String, dynamic>.from(itemEntry.value as Map);
                          final itemName = item['name'] is Map
                              ? (item['name']['en'] ?? item['name']['ar'] ?? 'Unknown')
                              : (item['name'] ?? 'Unknown');
                          final quantity = item['quantity'] ?? 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• $itemName',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  'x$quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        if (status == 'Pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _markOrderAsReady(orderKey, loc),
                              icon: const Icon(Icons.check_circle),
                              label: Text(loc['mark_ready']!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
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
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    // Check for base64 first, then fallback to imageUrl for backward compatibility
    final String? imageData = product['imageBase64'] as String? ?? product['imageUrl'] as String?;
    
    if (imageData == null || imageData.isEmpty) {
      return const Icon(Icons.image, size: 60);
    }

    // Check if it's a base64 data URI
    if (imageData.startsWith('data:image')) {
      try {
        final base64String = imageData.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.image, size: 60),
        );
      } catch (e) {
        return const Icon(Icons.image, size: 60);
      }
    } else if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      // URL image (backward compatibility)
      return Image.network(
        imageData,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.image, size: 60),
      );
    } else {
      // Assume it's base64 without data URI prefix
      try {
        final bytes = base64Decode(imageData);
        return Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.image, size: 60),
        );
      } catch (e) {
        return const Icon(Icons.image, size: 60);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['dashboard_title']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SellerProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            tabs: [
              Tab(text: loc['my_products']!),
              Tab(text: loc['orders']!),
            ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
                          children: [
                _buildProductsTab(loc, user),
                _buildOrdersTab(loc, user),
                          ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateProductStatus(String productId, bool isOutOfStock) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'isOutOfStock': isOutOfStock,
      });

      // Also update Realtime Database for buyer compatibility
      final database = FirebaseDatabase.instance.ref();
      await database.child('products/$productId').update({
        'isAvailable': !isOutOfStock,
      });

      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['product_updated']!)),
        );
      }
    } catch (e) {
      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc['error']!}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String productId, Map<String, String> loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['delete']!),
        content: Text(loc['delete_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteProduct(productId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['confirm']!),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(String productId) async {
    try {
      // Delete from Firestore with timeout to prevent hanging
      try {
        await _firestore.collection('products').doc(productId).delete().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Firestore product delete timed out after 5 seconds');
            throw TimeoutException('Firestore operation timed out');
          },
        );
        print('Product deleted from Firestore successfully');
      } on TimeoutException {
        print('Firestore delete timed out - continuing with Realtime Database deletion');
      } catch (firestoreError) {
        print('Firestore delete error: $firestoreError');
        // Continue with Realtime Database deletion even if Firestore fails
      }

      // Delete from Realtime Database
      try {
        final database = FirebaseDatabase.instance.ref();
        await database.child('products/$productId').remove();
        print('Product deleted from Realtime Database successfully');
      } catch (dbError) {
        print('Realtime Database delete error: $dbError');
        // Show error but don't fail completely
      }

      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['product_deleted']!)),
        );
      }
    } catch (e) {
      print('Error in _deleteProduct: $e');
      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc['error']!}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markOrderAsReady(String orderKey, Map<String, String> loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['mark_ready']!),
        content: Text(loc['mark_ready_confirmation']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(loc['confirm']!),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _database.ref('orders/$orderKey/status').set('Ready');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc['order_ready_success']!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc['error']!}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

