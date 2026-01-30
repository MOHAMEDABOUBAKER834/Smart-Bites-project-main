import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/checkout_screen.dart';
import 'package:smart_bites/language_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> _cartItems = {};
  int _totalPoints = 0;
  final _notesController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  late final DatabaseReference? _cartRef;
  String? _userSchool;
  String? _userSellerId;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'cart': 'السلة',
      'total': 'الإجمالي',
      'checkout': 'إتمام الشراء',
      'empty_cart': 'سلتك فارغة',
      'notes_hint': 'أضف ملاحظات للطلب (اختياري)',
      'sauces': 'الصوصات:',
    },
    'en': {
      'cart': 'Cart',
      'total': 'Total',
      'checkout': 'Checkout',
      'empty_cart': 'Your cart is empty',
      'notes_hint': 'Add order notes (optional)',
      'sauces': 'Sauces:',
    },
  };

  /// 🔒 تحويل آمن لأي خريطة
  Map<String, dynamic> safeMapConversion(dynamic input) {
    if (input is Map<String, dynamic>) return input;
    if (input is Map<Object?, Object?>) {
      return input.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Unsupported map format');
  }

  @override
  void initState() {
    super.initState();
    _fetchUserSchool();
    _setupCartListener();
  }

  void _fetchUserSchool() async {
    if (user == null) return;

    try {
      final userRef = FirebaseDatabase.instance.ref('users/${user!.uid}');
      final userSnapshot = await userRef.get();

      if (userSnapshot.exists && mounted) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final school = userData['school']?.toString();
        setState(() {
          _userSchool = school;
        });

        // Find seller ID from school name
        if (school != null && school.isNotEmpty) {
          final sellersQuery = await FirebaseDatabase.instance.ref('users').get();
          if (sellersQuery.exists) {
            final usersMap = sellersQuery.value as Map<dynamic, dynamic>;
            for (var entry in usersMap.entries) {
              final sellerData = entry.value as Map<dynamic, dynamic>;
              final role = sellerData['role']?.toString();
              final name = sellerData['name']?.toString();
              if (role == 'Seller' && name == school) {
                if (mounted) {
                  setState(() {
                    _userSellerId = entry.key.toString();
                  });
                }
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user school: $e');
    }
  }

  void _setupCartListener() {
    if (user != null) {
      _cartRef = FirebaseDatabase.instance.ref('carts/${user!.uid}');
      _cartRef!.onValue.listen((event) {
        print('Cart listener triggered: exists=${event.snapshot.exists}');
        if (event.snapshot.exists && mounted) {
          final rawData = event.snapshot.value as Map<Object?, Object?>;
          final data = rawData.map((key, value) => MapEntry(key.toString(), value));
          print('Cart items received: ${data.length} items');
          print('Cart item keys: ${data.keys.toList()}');

          // Filter cart items to only include products from user's school
          final filteredData = <String, dynamic>{};
          if (_userSellerId != null) {
            for (var entry in data.entries) {
              final item = safeMapConversion(entry.value);
              final itemSellerId = item['sellerId']?.toString();
              // Keep items without sellerId (legacy items) or items from user's school
              if (itemSellerId == null || itemSellerId == _userSellerId) {
                filteredData[entry.key] = entry.value;
              } else {
                print('Removed cart item from different school: ${entry.key}, sellerId: $itemSellerId');
                // Remove item from cart in database
                _cartRef!.child(entry.key).remove();
              }
            }
          } else {
            // If seller ID not found, keep all items (fallback)
            filteredData.addAll(data);
          }

          setState(() {
            _cartItems = filteredData;
            _calculateTotalPoints();
          });
        } else if (mounted) {
          print('Cart is empty or snapshot does not exist');
          setState(() {
            _cartItems = {};
            _totalPoints = 0;
          });
        }
      });
    }
  }

  void _calculateTotalPoints() {
    int total = 0;
    _cartItems.forEach((key, value) {
      final item = safeMapConversion(value);
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final points = (item['points'] as num?)?.toInt() ?? 0;
      total += quantity * points;
    });
    print('Total points calculated: $total');
    setState(() {
      _totalPoints = total;
    });
  }

  Widget _buildCartItemImage(dynamic imageData) {
    if (imageData == null || imageData.toString().isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
      );
    }

    final imageStr = imageData.toString();

    // Check if it's a base64 data URI
    if (imageStr.startsWith('data:image')) {
      try {
        final base64String = imageStr.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
        );
      }
    } else if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
      // URL image
      return Image.network(
        imageStr,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
        ),
      );
    } else {
      // Assume it's base64 without data URI prefix
      try {
        final bytes = base64Decode(imageStr);
        return Image.memory(
          bytes,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
          ),
        );
      } catch (e) {
        print('Error decoding base64 image (no prefix): $e');
        return Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
        );
      }
    }
  }

  void _updateQuantity(String itemKey, int newQuantity) {
    if (user == null) return;
    _cartRef!.child(itemKey).update({'quantity': newQuantity});
  }

  void _removeItem(String itemKey) {
    if (user == null) return;
    _cartRef!.child(itemKey).remove();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageProvider>(context).currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['cart']!, style: _getTextStyle(langCode, weight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: _cartItems.isEmpty
          ? Center(child: Text(loc['empty_cart']!, style: _getTextStyle(langCode, size: 18, color: Colors.grey)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final key = _cartItems.keys.elementAt(index);
                      final item = safeMapConversion(_cartItems[key]);

                      print('Cart item $index: key=$key');
                      print('Cart item data: $item');

                      // Handle name - can be Map or String
                      String name = 'No Name';
                      if (item['name'] is Map) {
                        name = item['name']?[langCode] ?? item['name']?['en'] ?? item['name']?['ar'] ?? 'No Name';
                      } else if (item['name'] is String) {
                        name = item['name'] as String;
                      }

                      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                      final points = (item['points'] as num?)?.toInt() ?? 0;

                      print('Cart item parsed: name=$name, quantity=$quantity, points=$points');

                      final selectedSaucesRaw = item['selectedSauces'];
                      final selectedSauces = selectedSaucesRaw is List
                          ? selectedSaucesRaw.map((e) => safeMapConversion(e)).toList()
                          : <Map<String, dynamic>>[];

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: _buildCartItemImage(item['imageUrl'] ?? item['imageBase64']),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: _getTextStyle(langCode, size: 16)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('${points * quantity}', style: _getTextStyle(langCode, size: 16, color: Colors.deepOrange)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.star, color: Colors.amber, size: 18),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
                                        onPressed: () {
                                          if (quantity > 1) {
                                            _updateQuantity(key, quantity - 1);
                                          } else {
                                            _removeItem(key);
                                          }
                                        },
                                      ),
                                      Text('$quantity', style: _getTextStyle(langCode, size: 16)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
                                        onPressed: () {
                                          _updateQuantity(key, quantity + 1);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (selectedSauces.isNotEmpty)
                                const SizedBox(height: 8),
                              if (selectedSauces.isNotEmpty)
                                Align(
                                  alignment: langCode == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      '${loc['sauces']} ${selectedSauces.map((sauce) => sauce['name']?[langCode]).join(', ')}',
                                      style: _getTextStyle(langCode, weight: FontWeight.normal, size: 12, color: Colors.grey[700]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // --- ✅ تصميم جديد للجزء السفلي ---
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    )
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _notesController,
                        style: _getTextStyle(langCode, weight: FontWeight.normal),
                        decoration: InputDecoration(
                          hintText: loc['notes_hint'],
                          hintStyle: _getTextStyle(langCode, weight: FontWeight.normal, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${loc['total']!}:',
                              style: _getTextStyle(langCode, size: 18)),
                          Row(
                            children: [
                              Text('$_totalPoints',
                                  style: _getTextStyle(langCode, size: 20, color: Colors.deepOrange)),
                              const SizedBox(width: 4),
                              const Icon(Icons.star, color: Colors.amber),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_cartItems.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutScreen(
                                  totalPoints: _totalPoints,
                                  notes: _notesController.text,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(loc['checkout']!, style: _getTextStyle(langCode, color: Colors.white, size: 18)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
