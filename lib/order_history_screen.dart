import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_ui_database/firebase_ui_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  String? _userSchool; // Store user's school for filtering orders

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'سجل الطلبات',
      'login_prompt': 'الرجاء تسجيل الدخول لعرض طلباتك.',
      'no_orders': 'لا يوجد لديك طلبات سابقة.',
      'order_id': 'طلب رقم',
      'status': 'الحالة',
      'pending': 'قيد التجهيز',
      'delivered': 'جاهز للاستلام',
      'error': 'حدث خطأ ما!',
    },
    'en': {
      'title': 'Order History',
      'login_prompt': 'Please log in to view your orders.',
      'no_orders': 'You have no past orders.',
      'order_id': 'Order',
      'status': 'Status',
      'pending': 'Pending',
      'delivered': 'Ready for Pickup',
      'error': 'An error occurred!',
    }
  };

  TextStyle _getTextStyle(String langCode, {FontWeight? weight, double? size, Color? color}) {
    return TextStyle(
      fontFamily: langCode == 'ar' ? 'Cairo' : 'Poppins',
      fontWeight: weight ?? (langCode == 'ar' ? FontWeight.w700 : FontWeight.normal),
      fontSize: size,
      color: color,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserSchool();
  }

  Future<void> _fetchUserSchool() async {
    if (userId == null) return;
    try {
      final userRef = FirebaseDatabase.instance.ref('users/$userId');
      final snapshot = await userRef.get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userSchool = data['school']?.toString();
        });
      }
    } catch (e) {
      print('Error fetching user school: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc['title']!, style: _getTextStyle(langCode))),
        body: Center(child: Text(loc['login_prompt']!, style: _getTextStyle(langCode))),
      );
    }

    // Query orders by userId, then filter by school in the builder
    final query = FirebaseDatabase.instance
        .ref('orders')
        .orderByChild('userId')
        .equalTo(userId);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!, style: _getTextStyle(langCode, weight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: FirebaseDatabaseQueryBuilder(
        query: query,
        pageSize: 100,
        builder: (context, snapshot, _) {
          if (snapshot.isFetching) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(loc['error']!, style: _getTextStyle(langCode)));
          }
          if (snapshot.docs.isEmpty) {
            return Center(child: Text(loc['no_orders']!, style: _getTextStyle(langCode, size: 16, color: Colors.grey)));
          }

          // Filter orders by school - students only see orders from their school
          final filteredOrders = snapshot.docs.where((orderSnapshot) {
            if (_userSchool == null || _userSchool!.isEmpty) return true; // Show all if school not set
            final order = orderSnapshot.value as Map<dynamic, dynamic>;
            final orderSchool = order['school']?.toString();
            return orderSchool == _userSchool; // Only show orders from student's school
          }).toList();

          if (filteredOrders.isEmpty) {
            return Center(child: Text(loc['no_orders']!, style: _getTextStyle(langCode, size: 16, color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final orderSnapshot = filteredOrders.reversed.toList()[index];
              final order = orderSnapshot.value as Map<dynamic, dynamic>;
              // --- ✅ تم التأكيد على عرض رقم الطلب الصحيح هنا ---
              final orderId = order['orderId'] as String? ?? orderSnapshot.key;
              final status = order['status'] ?? 'Pending';
              final timestamp = order['createdAt'] ?? 0;
              final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
              final formattedDate = DateFormat('yyyy-MM-dd – hh:mm a').format(date);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Text(
                    '${loc['order_id']} #$orderId',
                    style: _getTextStyle(langCode, weight: FontWeight.bold, size: 16),
                  ),
                  subtitle: Text(
                    '${loc['status']}: ${status == 'Pending' ? loc['pending'] : loc['delivered']}',
                    style: _getTextStyle(
                      langCode,
                      color: status == 'Pending' ? Colors.orange.shade700 : Colors.green,
                      weight: FontWeight.bold,
                      size: 14
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${order['totalPoints'] ?? 0}',
                        style: _getTextStyle(langCode, size: 18, color: Colors.deepOrange)
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          ...(order['items'] as Map<dynamic, dynamic>? ?? {}).entries.map((entry) {
                            final itemData = entry.value as Map<dynamic, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("- ${itemData['name']?[langCode] ?? 'منتج'}", style: _getTextStyle(langCode, weight: FontWeight.normal)),
                                  Text("x${itemData['quantity']}", style: _getTextStyle(langCode, weight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    )
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
