import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/cart_screen.dart';
import 'package:smart_bites/fortune_wheel_screen.dart';
import 'package:smart_bites/profile_screen.dart';
import 'package:smart_bites/product_details_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final productsRef = FirebaseDatabase.instance.ref('products');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryKey = 'all';
  String _userName = '...';
  int _cartItemCount = 0;

  Map<String, dynamic>? _currentOrder;
  StreamSubscription<DatabaseEvent>? _orderSubscription;


  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'welcome': 'أهلاً بك يا',
      'search_hint': 'ابحث عن وجبتك المفضلة...',
      'no_products': 'لا توجد منتجات متاحة حاليًا.',
      'no_results': 'لا توجد نتائج مطابقة.',
      'added_to_cart': 'تمت الإضافة للسلة بنجاح!',
      'categories': 'الأصناف',
      'select_sauces': 'اختر الصوصات',
      'total_points': 'إجمالي النقاط:',
      'confirm_addition': 'تأكيد الإضافة',
      'point': 'نقطة',
      'sold_out': 'نفذت الكمية',
      'order_status_title': 'حالة طلبك الحالي',
      'order_id': 'طلب رقم',
      // --- ✅ تم تعديل هذه النصوص ---
      'order_pending': 'طلبك قيد التجهيز الآن...',
      'order_ready': 'طلبك جاهز للاستلام!',
      'confirm_receipt': 'هل استلمت طلبك؟',
      'yes': 'نعم',
      'no': 'لا',
    },
    'en': {
      'welcome': 'Welcome,',
      'search_hint': 'Search for your favorite meal...',
      'no_products': 'No products available right now.',
      'no_results': 'No matching results found.',
      'added_to_cart': 'Added to cart successfully!',
      'categories': 'Categories',
      'select_sauces': 'Select Sauces',
      'total_points': 'Total Points:',
      'confirm_addition': 'Confirm Addition',
      'point': 'Point',
      'sold_out': 'Sold Out',
      'order_status_title': 'Current Order Status',
      'order_id': 'Order',
      // --- ✅ تم تعديل هذه النصوص ---
      'order_pending': 'Your order is being prepared...',
      'order_ready': 'Your order is ready for pickup!',
      'confirm_receipt': 'Did you receive your order?',
      'yes': 'Yes',
      'no': 'No',
    }
  };

  static const Map<String, Map<String, dynamic>> _categoryData = {
    'all': {'ar': 'الكل', 'en': 'All', 'icon': Icons.all_inclusive},
    'Sandwiches': {'ar': 'ساندويتشات', 'en': 'Sandwiches', 'icon': Icons.fastfood_outlined},
    'Beverages': {'ar': 'مشروبات', 'en': 'Beverages', 'icon': Icons.local_drink_outlined},
    'Snacks': {'ar': 'سناكات', 'en': 'Snacks', 'icon': Icons.icecream_outlined},
  };

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      userRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _userName = data['name']?.split(' ')[0] ?? 'User';
          });
        }
      });

      final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}');
      cartRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          final encodedData = jsonEncode(event.snapshot.value);
          final cartItems = jsonDecode(encodedData) as Map<String, dynamic>;
          setState(() {
            _cartItemCount = cartItems.values.fold<int>(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
          });
        } else if (mounted) {
          setState(() {
            _cartItemCount = 0;
          });
        }
      });

      final ordersRef = FirebaseDatabase.instance.ref('orders');
      _orderSubscription = ordersRef.orderByChild('userId').equalTo(user.uid).onValue.listen((event) {
        Map<String, dynamic>? latestActiveOrder;
        if (event.snapshot.exists) {
          final orders = Map<String, dynamic>.from(event.snapshot.value as Map);
          int latestTimestamp = 0;
          orders.forEach((key, value) {
            final orderData = Map<String, dynamic>.from(value as Map);
            final status = orderData['status'] as String?;
            if (status == 'Pending' || status == 'Delivered') {
              final timestamp = (orderData['createdAt'] as num?)?.toInt() ?? 0;
              if (timestamp > latestTimestamp) {
                latestTimestamp = timestamp;
                latestActiveOrder = orderData..['key'] = key;
              }
            }
          });
        }
        if (mounted) {
          setState(() {
            _currentOrder = latestActiveOrder;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }
  
  void _onProductTapped(Map<dynamic, dynamic> product, String productKey, String langCode, Map<String, String> loc) {
    final sauces = product['availableSauces'];
    if (sauces == null || (sauces is List && sauces.isEmpty)) {
      _addToCart(product, productKey, langCode, loc, []);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          product: product,
          productKey: productKey,
          langCode: langCode,
          localizations: loc,
        ),
      ));
    }
  }

  void _addToCart(Map<dynamic, dynamic> product, String productKey, String langCode, Map<String, String> loc, List<Map<String, dynamic>> selectedSauces) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    int totalPoints = (product['points'] as num).toInt();
    for (var sauce in selectedSauces) {
      totalPoints += (sauce['points'] as num).toInt();
    }
    
    final cartItemKey = selectedSauces.isEmpty 
        ? productKey 
        : '$productKey-${selectedSauces.map((s) => s['id']).join('-')}';

    final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}/$cartItemKey');
    
    cartRef.runTransaction((Object? currentData) {
      if (currentData == null) {
        return Transaction.success({
          'name': product['name'],
          'points': totalPoints,
          'imageUrl': product['imageUrl'],
          'quantity': 1,
          'category': product['category'],
          'selectedSauces': selectedSauces,
        });
      }
      final data = Map<String, dynamic>.from(currentData as Map);
      data['quantity'] = (data['quantity'] ?? 0) + 1;
      return Transaction.success(data);
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${product['name'][langCode]} ${loc['added_to_cart']}'),
        duration: const Duration(seconds: 1),
      ));
    });
  }

  void _confirmOrderReceived() {
    if (_currentOrder != null && _currentOrder!['key'] != null) {
      final orderKey = _currentOrder!['key'];
      FirebaseDatabase.instance.ref('orders/$orderKey/status').set('Completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bites', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
        actions: [
          Badge(
            label: Text('$_cartItemCount'),
            isLabelVisible: _cartItemCount > 0,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FortuneWheelScreen()))
          ),
          IconButton(
            icon: const Icon(Icons.person_outline), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('${loc['welcome']} $_userName 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          _buildOrderStatusCard(loc, langCode),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: loc['search_hint'],
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(loc['categories']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: _categoryData.keys.map((categoryKey) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    avatar: Icon(_categoryData[categoryKey]!['icon'] as IconData, color: _selectedCategoryKey == categoryKey ? Colors.white : Colors.black54),
                    label: Text(_categoryData[categoryKey]![langCode]!),
                    selected: _selectedCategoryKey == categoryKey,
                    onSelected: (selected) {
                      setState(() { _selectedCategoryKey = categoryKey; });
                    },
                    selectedColor: Colors.deepOrange,
                    labelStyle: TextStyle(color: _selectedCategoryKey == categoryKey ? Colors.white : Colors.black),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: productsRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return Center(child: Text(loc['no_products']!));
              }

              final productsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
              var filteredProducts = productsMap.entries.where((entry) {
                final product = entry.value as Map<dynamic, dynamic>;
                final nameData = product['name'];
                if (nameData is Map) {
                  final name = nameData[langCode]?.toString().toLowerCase() ?? '';
                  final category = product['category']?['en'] ?? '';
                  final matchesSearch = name.contains(_searchQuery.toLowerCase());
                  final matchesCategory = _selectedCategoryKey == 'all' || category == _selectedCategoryKey;
                  return matchesSearch && matchesCategory;
                }
                return false;
              }).toList();

              if (filteredProducts.isEmpty) {
                return Center(child: Text(loc['no_results']!));
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final productKey = filteredProducts[index].key;
                  final productData = filteredProducts[index].value as Map<dynamic, dynamic>;
                  return buildProductCard(productData, productKey, langCode, loc);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard(Map<String, String> loc, String langCode) {
    if (_currentOrder == null) {
      return const SizedBox.shrink();
    }

    final status = _currentOrder!['status'] ?? 'Pending';
    final isPending = status == 'Pending';

    final cardColor = isPending ? Colors.amber.shade100 : Colors.green.shade100;
    final iconColor = isPending ? Colors.amber.shade800 : Colors.green.shade800;
    final icon = isPending
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3, color: iconColor),
          )
        : Icon(Icons.check_circle, color: iconColor);
    final statusText = isPending ? loc['order_pending']! : loc['order_ready']!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: iconColor.withOpacity(0.5))
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 8),
                Text(loc['order_status_title']!, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
              ],
            ),
            const SizedBox(height: 4),
            // --- ✅ تم تعديل هذا السطر لإزالة رقم الطلب ---
            Text(statusText, style: TextStyle(color: iconColor.withOpacity(0.8))),
            
            if (!isPending) ...[
              const Divider(height: 20),
              Text(loc['confirm_receipt']!, style: TextStyle(color: iconColor)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text(loc['no']!, style: TextStyle(color: iconColor)),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: Text(loc['yes']!, style: TextStyle(fontFamily: langCode == 'ar' ? 'Cairo' : 'Poppins')),
                    onPressed: _confirmOrderReceived,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: cardColor,
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget buildProductCard(Map<dynamic, dynamic> product, String productKey, String langCode, Map<String, String> loc) {
    final bool isAvailable = product['isAvailable'] ?? true;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      elevation: 5,
      child: Stack(
        children: [
          InkWell(
            onTap: isAvailable ? () => _onProductTapped(product, productKey, langCode, loc) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.network(
                    product['imageUrl'] ?? 'https://via.placeholder.com/150',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name']?[langCode] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '${(product['points'] as num?)?.toInt() ?? 0}',
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 17, fontFamily: 'Poppins'),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (!isAvailable)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Center(
                  child: Text(
                    loc['sold_out']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: langCode == 'ar' ? 'Cairo' : 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
