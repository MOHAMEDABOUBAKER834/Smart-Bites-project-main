import 'dart:convert';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final int totalPoints;
  final String notes;

  const CheckoutScreen({
    super.key,
    required this.totalPoints,
    required this.notes,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _userPoints = 0;
  bool _isLoading = false;
  final _couponController = TextEditingController();
  int _discountPoints = 0;
  bool _isCouponApplied = false;
  Map<String, dynamic> _cartItems = {};

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'إتمام الشراء',
      'summary': 'ملخص الطلب',
      'your_balance': 'رصيدك الحالي',
      'order_cost': 'تكلفة الطلب',
      'remaining_balance': 'الرصيد المتبقي',
      'confirm_purchase': 'تأكيد الشراء',
      'insufficient_points': 'رصيدك من النقاط غير كافٍ!',
      'error': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
      'your_order': 'طلبك',
      'coupon_hint': 'أدخل كود الخصم',
      'apply': 'تطبيق',
      'coupon_success': 'تم تطبيق الخصم بنجاح!',
      'coupon_fail': 'كود الخصم غير صالح أو مستخدم.',
      'subtotal': 'المجموع الفرعي',
      'discount': 'الخصم',
      'total': 'الإجمالي',
      'empty_cart_error': 'سلة التسوق فارغة! لا يمكن إتمام الطلب.'
    },
    'en': {
      'title': 'Checkout',
      'summary': 'Order Summary',
      'your_balance': 'Your Current Balance',
      'order_cost': 'Order Cost',
      'remaining_balance': 'Remaining Balance',
      'confirm_purchase': 'Confirm Purchase',
      'insufficient_points': 'Insufficient points balance!',
      'error': 'An error occurred. Please try again.',
      'your_order': 'Your Order',
      'coupon_hint': 'Enter discount code',
      'apply': 'Apply',
      'coupon_success': 'Coupon applied successfully!',
      'coupon_fail': 'Invalid or already used coupon.',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'total': 'Total',
      'empty_cart_error': 'Your cart is empty! Cannot place order.'
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndCart();
  }

  // --- ✅ جديد: دالة لتطبيق ستايل الخطوط المخصصة ---
  TextStyle _getTextStyle(String langCode, {FontWeight? weight, double? size, Color? color}) {
    return TextStyle(
      fontFamily: langCode == 'ar' ? 'Cairo' : 'Poppins',
      fontWeight: weight ?? (langCode == 'ar' ? FontWeight.w700 : FontWeight.normal),
      fontSize: size,
      color: color,
    );
  }

  void _fetchUserDataAndCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}');
      
      final userSnapshot = await userRef.get();
      final cartSnapshot = await cartRef.get();

      if (userSnapshot.exists && mounted) {
        final data = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userPoints = (data['points'] as num?)?.toInt() ?? 0;
        });
      }
      if (cartSnapshot.exists && mounted) {
        final encodedData = jsonEncode(cartSnapshot.value);
        setState(() {
          _cartItems = jsonDecode(encodedData) as Map<String, dynamic>;
        });
      }
    }
  }
  
  void _applyCoupon() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode] ?? _localizations['en']!;
    final code = _couponController.text.trim().toUpperCase();

    if (code.isEmpty || _isCouponApplied) return;

    final couponRef = FirebaseDatabase.instance.ref('coupons/$code');
    final snapshot = await couponRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final limit = (data['usageLimit'] as num?)?.toInt() ?? 1;
      final used = (data['timesUsed'] as num?)?.toInt() ?? 0;

      if (used < limit) {
        setState(() {
          _discountPoints = (data['discountPoints'] as num?)?.toInt() ?? 0;
          _isCouponApplied = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['coupon_success']!, style: _getTextStyle(langCode, color: Colors.white)), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['coupon_fail']!, style: _getTextStyle(langCode, color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc['coupon_fail']!, style: _getTextStyle(langCode, color: Colors.white)), backgroundColor: Colors.red),
      );
    }
  }

  String _generateReadableOrderId() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final randomPart = String.fromCharCodes(Iterable.generate(
        4, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
        
    return '$day$month-$randomPart';
  }

  Future<String> _generateUniqueOrderId() async {
    final dbRef = FirebaseDatabase.instance.ref('orders');
    String orderId;
    while (true) {
        orderId = _generateReadableOrderId();
        final snapshot = await dbRef.child(orderId).get();
        if (!snapshot.exists) {
            break;
        }
    }
    return orderId;
  }

  void _placeOrder() async {
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode] ?? _localizations['en']!;
    
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}');
      
      final userSnapshot = await userRef.get();
      final cartSnapshot = await cartRef.get();

      if (!userSnapshot.exists || !cartSnapshot.exists) {
        throw Exception(loc['empty_cart_error']);
      }

      final latestUserData = userSnapshot.value as Map<dynamic, dynamic>;
      final latestUserPoints = (latestUserData['points'] as num?)?.toInt() ?? 0;
      final userSchool = latestUserData['school']?.toString() ?? '';
      
      final encodedData = jsonEncode(cartSnapshot.value);
      final latestCartItems = jsonDecode(encodedData) as Map<String, dynamic>;

      if (latestCartItems.isEmpty) {
        throw Exception(loc['empty_cart_error']);
      }

      // IMPORTANT: Filter cart items to only include products from user's school
      // Get user's school seller ID
      String? userSellerId;
      try {
        // Try to find seller ID from school name
        final sellersQuery = await FirebaseDatabase.instance.ref('users').get();
        if (sellersQuery.exists) {
          final usersMap = sellersQuery.value as Map<dynamic, dynamic>;
          for (var entry in usersMap.entries) {
            final userData = entry.value as Map<dynamic, dynamic>;
            final role = userData['role']?.toString();
            final name = userData['name']?.toString();
            if (role == 'Seller' && name == userSchool) {
              userSellerId = entry.key.toString();
              break;
            }
          }
        }
      } catch (e) {
        print('Error finding seller ID: $e');
      }

      // Filter cart items - remove products from other schools
      final filteredCartItems = <String, dynamic>{};
      if (userSellerId != null) {
        for (var entry in latestCartItems.entries) {
          final item = entry.value as Map<dynamic, dynamic>;
          // Check if item has sellerId field (from product)
          // If not, we need to get it from the product key or product data
          // For now, we'll keep items that don't have sellerId (legacy items)
          // But remove items that clearly have a different sellerId
          final itemSellerId = item['sellerId']?.toString();
          if (itemSellerId == null || itemSellerId == userSellerId) {
            filteredCartItems[entry.key] = entry.value;
          } else {
            print('Removed cart item from different school: ${entry.key}, sellerId: $itemSellerId');
          }
        }
      } else {
        // If we can't find seller ID, keep all items (fallback)
        filteredCartItems.addAll(latestCartItems);
      }

      if (filteredCartItems.isEmpty) {
        throw Exception(loc['empty_cart_error'] ?? 'Cart is empty or contains items from other schools');
      }
      
      int recalculatedSubtotal = filteredCartItems.values.fold<int>(0, (sum, item) {
        final itemPoints = (item['points'] as num?)?.toInt() ?? 0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        return sum + (itemPoints * quantity);
      });

      final finalTotal = recalculatedSubtotal - _discountPoints;
      
      if (latestUserPoints < finalTotal) {
        throw Exception(loc['insufficient_points']);
      }

      final String orderId = await _generateUniqueOrderId();
      final dbRef = FirebaseDatabase.instance.ref();
      final Map<String, dynamic> updates = {};

      updates['/orders/$orderId'] = {
        'orderId': orderId,
        'userId': user.uid,
        'school': userSchool, // Add school field to separate orders by school
        'items': filteredCartItems, // Use filtered items (only from user's school)
        'subTotalPoints': recalculatedSubtotal,
        'discountPoints': _discountPoints,
        'couponCode': _isCouponApplied ? _couponController.text.trim().toUpperCase() : null,
        'totalPoints': finalTotal,
        'notes': widget.notes,
        'status': 'Pending',
        'createdAt': ServerValue.timestamp,
      };

      updates['/users/${user.uid}/points'] = ServerValue.increment(-finalTotal);

      if (_isCouponApplied && _couponController.text.isNotEmpty) {
        updates['/coupons/${_couponController.text.trim().toUpperCase()}/timesUsed'] = ServerValue.increment(1);
      }

      updates['/carts/${user.uid}'] = null;

      await dbRef.update(updates);
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => OrderSuccessScreen(orderId: orderId)),
          (route) => false,
        );
      }

    } catch (e) {
      print('Error placing order: $e'); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: _getTextStyle(langCode, color: Colors.white)
          ), 
          backgroundColor: Colors.red
        ),
      );
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    int currentSubtotal = _cartItems.values.fold<int>(0, (sum, item) {
        final itemPoints = (item['points'] as num?)?.toInt() ?? 0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        return sum + (itemPoints * quantity);
    });
    final finalTotal = currentSubtotal - _discountPoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!, style: _getTextStyle(langCode, weight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc['your_order']!, style: _getTextStyle(langCode, size: 20)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  final key = _cartItems.keys.elementAt(index);
                  final item = _cartItems[key];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        item['imageUrl'] ?? 'https://via.placeholder.com/150', 
                        width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (c, o, s) => const Icon(Icons.fastfood, size: 40),
                      ),
                    ),
                    title: Text(item['name']?[langCode] ?? 'No Name', style: _getTextStyle(langCode, size: 16)),
                    trailing: Text("x${item['quantity'] ?? 1}", style: _getTextStyle(langCode, size: 16, color: Colors.deepOrange, weight: FontWeight.bold)),
                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _couponController,
              enabled: !_isCouponApplied,
              style: _getTextStyle(langCode),
              decoration: InputDecoration(
                labelText: loc['coupon_hint'],
                labelStyle: _getTextStyle(langCode, color: Colors.grey.shade600, weight: FontWeight.normal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: TextButton(
                  onPressed: _isCouponApplied ? null : _applyCoupon,
                  child: Text(loc['apply']!, style: _getTextStyle(langCode, weight: FontWeight.bold, color: _isCouponApplied ? Colors.grey : Colors.deepOrange)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow(langCode, loc['your_balance']!, _userPoints),
                    const SizedBox(height: 8),
                    _buildSummaryRow(langCode, loc['subtotal']!, currentSubtotal),
                    if (_isCouponApplied)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildSummaryRow(langCode, loc['discount']!, _discountPoints, isDiscount: true),
                      ),
                    const Divider(height: 30, thickness: 1),
                    _buildSummaryRow(langCode, loc['total']!, finalTotal, isTotal: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : Text(loc['confirm_purchase']!, style: _getTextStyle(langCode, size: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String langCode, String title, int points, {bool isDiscount = false, bool isTotal = false}) {
    final double titleSize = isTotal ? 18 : 16;
    final double pointsSize = isTotal ? 22 : 18;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: _getTextStyle(langCode, size: titleSize, weight: isTotal ? FontWeight.bold : FontWeight.normal, color: Colors.black87)),
        Row(
          children: [
            Text(
              '${isDiscount ? '-' : ''}$points',
              style: _getTextStyle(langCode,
                size: pointsSize,
                weight: FontWeight.bold,
                color: isDiscount ? Colors.green.shade600 : (isTotal ? Colors.deepOrange : Colors.black87),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.star, color: Colors.amber, size: pointsSize),
          ],
        ),
      ],
    );
  }
}
