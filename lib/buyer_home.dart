import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/theme_provider.dart';
import 'package:smart_bites/cart_screen.dart';
import 'package:smart_bites/fortune_wheel_screen.dart';
import 'package:smart_bites/profile_screen.dart'; 

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryKey = 'all';
  String _userName = '...';
  int _cartItemCount = 0;
  bool _useRealtimeDB = true; // Start with Realtime DB by default since Firestore may not be set up

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
      'order_pending': 'طلبك قيد التجهيز الآن...',
      'order_ready': 'طلبك جاهز للاستلام!',
      'confirm_receipt': 'هل استلمت طلبك؟',
      'yes': 'نعم',
      'no': 'لا',
      'cancel': 'إلغاء',
      'add_to_cart': 'أضف للسلة',
      'total': 'الإجمالي',
      'error': 'خطأ',
      'order_received': 'تم تأكيد استلام الطلب!',
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
      'order_pending': 'Your order is being prepared...',
      'order_ready': 'Your order is ready for pickup!',
      'confirm_receipt': 'Did you receive your order?',
      'yes': 'Yes',
      'no': 'No',
      'cancel': 'Cancel',
      'add_to_cart': 'Add to Cart',
      'total': 'Total',
      'error': 'Error',
      'order_received': 'Order confirmed!',
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
    // Suppress Firestore errors since we're using Realtime Database
    _suppressFirestoreErrors();
  }

  void _suppressFirestoreErrors() {
    // Firestore may not be set up, but we use Realtime DB, so suppress errors
    // This prevents Firestore connection errors from appearing in logs
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: false,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Ignore Firestore setup errors - we're using Realtime Database
      // Firestore errors won't affect order confirmation since we use Realtime DB
    }
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
            if (status == 'Pending' || status == 'Ready' || status == 'Delivered') {
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
  
  void _onProductTapped(Map<String, dynamic> product, String productKey, String langCode, Map<String, String> loc) {
    print('Product tapped: $productKey');
    print('Product data: $product');
    
    // Show dialog with Add to Cart button
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final productName = product['name'] ?? 'Unknown Product';
        final productPrice = ((product['price'] as num?)?.toInt() ?? 0);
        final productImage = product['imageBase64'] as String? ?? product['imageUrl'] as String?;
        final productDescription = product['description'] ?? '';
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(productName, style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: _buildProductImage(productImage),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (productDescription.isNotEmpty) ...[
                  Text(productDescription, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc['total']!}:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          '$productPrice',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc['cancel'] ?? 'Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _addToCart(product, productKey, langCode, loc, [], navigateToCart: true);
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(loc['add_to_cart'] ?? 'Add to Cart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> product, String productKey, String langCode, Map<String, String> loc, List<Map<String, dynamic>> selectedSauces, {bool navigateToCart = false}) {
    print('_addToCart called for product: $productKey');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User is null, cannot add to cart');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to add items to cart')),
      );
      return;
    }
    print('User ID: ${user.uid}');
    print('User email: ${user.email}');
    print('User is authenticated: ${user.uid.isNotEmpty}');
    
    // Get price from Firestore product (price field)
    int totalPoints = ((product['price'] as num?)?.toInt() ?? 0);
    for (var sauce in selectedSauces) {
      totalPoints += (sauce['points'] as num).toInt();
    }
    
    final cartItemKey = selectedSauces.isEmpty 
        ? productKey 
        : '$productKey-${selectedSauces.map((s) => s['id']).join('-')}';

    final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}/$cartItemKey');
    final cartPath = 'carts/${user.uid}/$cartItemKey';
    print('Cart path: $cartPath');
    
    // Get product name (string in Firestore)
    final productName = product['name'] ?? 'Unknown Product';
    
    // Get category from product
    final productCategory = product['category'];
    Map<String, String> categoryMap = {'ar': 'عام', 'en': 'General'};
    if (productCategory is Map) {
      categoryMap = {
        'ar': productCategory['ar'] ?? 'عام',
        'en': productCategory['en'] ?? 'General',
      };
    } else if (productCategory is String) {
      // Find category in categoryData
      final categoryKey = _categoryData.keys.firstWhere(
        (key) => _categoryData[key]!['en'] == productCategory,
        orElse: () => 'all',
      );
      if (categoryKey != 'all') {
        categoryMap = {
          'ar': _categoryData[categoryKey]!['ar'] as String,
          'en': _categoryData[categoryKey]!['en'] as String,
        };
      }
    }
    
    // First, try to read the current cart item
    cartRef.once().then((DatabaseEvent snapshot) {
      Map<String, dynamic> cartItemData;
      
      if (snapshot.snapshot.exists) {
        // Item exists, increment quantity
        final currentData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        cartItemData = {
          ...currentData,
          'quantity': ((currentData['quantity'] as num?)?.toInt() ?? 0) + 1,
        };
      } else {
        // Item doesn't exist, create new
        cartItemData = {
          'name': {
            'ar': productName,
            'en': productName,
          },
          'points': totalPoints,
          'imageUrl': product['imageUrl'] ?? product['imageBase64'] ?? '',
          'quantity': 1,
          'category': categoryMap,
          'selectedSauces': selectedSauces,
        };
      }
      
      // Write the updated data
      return cartRef.set(cartItemData);
    }).then((_) {
      print('Product added to cart successfully');
      print('Cart item key: $cartItemKey');
      print('Cart path: carts/${user.uid}/$cartItemKey');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$productName ${loc['added_to_cart']}'),
        duration: const Duration(seconds: 1),
      ));
      
      // Navigate to cart screen if requested
      if (navigateToCart && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          }
        });
      }
    }).catchError((error) {
      print('Error adding to cart: $error');
      print('Error type: ${error.runtimeType}');
      print('Error stack: ${error.stackTrace}');
      print('Cart path attempted: $cartPath');
      print('User UID: ${user.uid}');
      
      String errorMessage = '${loc['error']!}: Failed to add to cart';
      if (error.toString().contains('permission-denied')) {
        errorMessage = '${loc['error']!}: Permission denied. Please check Firebase security rules.';
      } else {
        errorMessage = '${loc['error']!}: $error';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    });
  }

  void _confirmOrderReceived() async {
    if (_currentOrder != null && _currentOrder!['key'] != null) {
      final orderKey = _currentOrder!['key'];
      print('Confirming order receipt for order: $orderKey');
      try {
        // Use Realtime Database only - Firestore errors won't affect this
        final orderRef = _database.ref('orders/$orderKey/status');
        await orderRef.set('Completed');
        print('Order status updated to Completed successfully');
        
        if (mounted) {
          final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
          final loc = _localizations[langCode]!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc['order_received'] ?? 'Order confirmed!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Clear the current order from state after confirmation
          setState(() {
            _currentOrder = null;
          });
        }
      } catch (e) {
        print('Error confirming order receipt: $e');
        if (mounted) {
          final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
          final loc = _localizations[langCode]!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc['error']!}: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('Cannot confirm order: _currentOrder is null or missing key');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bites', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
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
                fillColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[800] 
                    : Colors.grey[200],
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
          _useRealtimeDB 
            ? StreamBuilder<DatabaseEvent>(
                stream: _database.ref('products').onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  return _buildProductsFromRealtimeDB(snapshot, langCode, loc);
                },
              )
            : StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  // If Firestore fails or takes too long, switch to Realtime DB
                  if (snapshot.hasError) {
                    print('Firestore Error: ${snapshot.error}, switching to Realtime Database...');
                    if (!_useRealtimeDB && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _useRealtimeDB = true;
                        });
                      });
                    }
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // If Firestore is stuck in waiting state for too long, switch to Realtime DB
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // After 3 seconds of waiting, switch to Realtime DB
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted && !_useRealtimeDB && snapshot.connectionState == ConnectionState.waiting) {
                        print('Firestore taking too long, switching to Realtime Database...');
                        setState(() {
                          _useRealtimeDB = true;
                        });
                      }
                    });
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(loc['no_products']!),
                          ],
                        ),
                      ),
                    );
                  }

                  // Filter products: exclude out-of-stock items, apply category and search filters
                  var filteredProducts = snapshot.data!.docs.where((doc) {
                    try {
                      final product = doc.data() as Map<String, dynamic>;
                      
                      // Filter out out-of-stock products
                      final isOutOfStock = product['isOutOfStock'] ?? false;
                      if (isOutOfStock) return false;
                      
                      // Apply category filter
                      if (_selectedCategoryKey != 'all') {
                        final productCategory = product['category'] as String? ?? '';
                        final selectedCategoryName = _categoryData[_selectedCategoryKey]!['en'] as String;
                        if (productCategory != selectedCategoryName) {
                          return false;
                        }
                      }
                      
                      // Apply search filter
                      final name = (product['name'] ?? '').toString().toLowerCase();
                      final description = (product['description'] ?? '').toString().toLowerCase();
                      final matchesSearch = _searchQuery.isEmpty || 
                          name.contains(_searchQuery.toLowerCase()) ||
                          description.contains(_searchQuery.toLowerCase());
                      
                      return matchesSearch;
                    } catch (e) {
                      print('Error filtering product ${doc.id}: $e');
                      return false;
                    }
                  }).toList();
                  
                  // Sort by createdAt if available, otherwise by document ID
                  filteredProducts.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aCreated = aData['createdAt'] as Timestamp?;
                    final bCreated = bData['createdAt'] as Timestamp?;
                    if (aCreated != null && bCreated != null) {
                      return bCreated.compareTo(aCreated); // Descending
                    }
                    return b.id.compareTo(a.id); // Fallback to document ID
                  });

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
                      final doc = filteredProducts[index];
                      final productData = doc.data() as Map<String, dynamic>;
                      final productId = doc.id;
                      return buildProductCard(productData, productId, langCode, loc);
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
    final isReady = status == 'Ready';

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
            Text(statusText, style: TextStyle(color: iconColor.withOpacity(0.8))),
            
            if (isReady) ...[
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

  Widget _buildProductImage(String? imageData) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
        ),
      );
    }

    // Check if it's a base64 data URI
    if (imageData.startsWith('data:image')) {
      try {
        final base64String = imageData.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
            ),
          ),
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
          ),
        );
      }
    } else if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      // URL image (backward compatibility)
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
          ),
        ),
      );
    } else {
      // Assume it's base64 without data URI prefix
      try {
        final bytes = base64Decode(imageData);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
            ),
          ),
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
          ),
        );
      }
    }
  }

  Widget _buildProductsFromRealtimeDB(AsyncSnapshot<DatabaseEvent> snapshot, String langCode, Map<String, String> loc) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${loc['error']!}: ${snapshot.error}'),
            ],
          ),
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(loc['no_products']!),
            ],
          ),
        ),
      );
    }

    final productsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
    print('Total products in Realtime DB: ${productsMap.length}');
    var filteredProducts = productsMap.entries.where((entry) {
      try {
        final product = entry.value as Map<dynamic, dynamic>;
        
        // Filter out unavailable products
        final isAvailable = product['isAvailable'] ?? true;
        if (!isAvailable) {
          print('Product ${entry.key} filtered out: not available');
          return false;
        }
        
        // Apply category filter
        final categoryData = product['category'];
        String productCategory = '';
        if (categoryData is Map) {
          productCategory = (categoryData['en'] ?? categoryData['ar'] ?? '').toString();
        } else if (categoryData is String) {
          productCategory = categoryData;
        }
        
        print('Product ${entry.key} category: $productCategory, Selected: $_selectedCategoryKey');
        
        // Filter by selected category
        if (_selectedCategoryKey != 'all') {
          final selectedCategoryName = _categoryData[_selectedCategoryKey]!['en'] as String;
          if (productCategory != selectedCategoryName) {
            print('Product ${entry.key} filtered out: category mismatch ($productCategory != $selectedCategoryName)');
            return false;
          }
        }
        
        // Apply search filter
        final nameData = product['name'];
        String name = '';
        if (nameData is Map) {
          name = (nameData[langCode] ?? nameData['en'] ?? nameData['ar'] ?? '').toString().toLowerCase();
        } else {
          name = (nameData ?? '').toString().toLowerCase();
        }
        
        final description = (product['description'] ?? '').toString().toLowerCase();
        final matchesSearch = _searchQuery.isEmpty || 
            name.contains(_searchQuery.toLowerCase()) ||
            description.contains(_searchQuery.toLowerCase());
        
        if (matchesSearch) {
          print('Product ${entry.key} passed all filters: $name');
        }
        
        return matchesSearch;
      } catch (e) {
        print('Error filtering product ${entry.key}: $e');
        print('Product data: ${entry.value.toString()}');
        return false;
      }
    }).toList();

    print('Filtered products count: ${filteredProducts.length}');
    
    if (filteredProducts.isEmpty) {
      if (productsMap.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(loc['no_products']!),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc['no_results']!),
            const SizedBox(height: 8),
            Text('Total products: ${productsMap.length}', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
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
        final entry = filteredProducts[index];
        final productData = Map<String, dynamic>.from(entry.value as Map);
        final productKey = entry.key;
        
        // Convert Realtime DB format to Firestore-like format for buildProductCard
        final convertedProduct = {
          'name': productData['name'] is Map 
              ? (productData['name'][langCode] ?? productData['name']['en'] ?? productData['name']['ar'] ?? '')
              : (productData['name'] ?? ''),
          'price': productData['price'] ?? productData['points'] ?? 0,
          'description': productData['description'] ?? '',
          'imageBase64': productData['imageBase64'] ?? productData['imageUrl'] ?? '',
          'imageUrl': productData['imageUrl'] ?? productData['imageBase64'] ?? '',
          'isOutOfStock': !(productData['isAvailable'] ?? true),
          'category': productData['category'], // Preserve category for cart
        };
        
        return buildProductCard(convertedProduct, productKey, langCode, loc);
      },
    );
  }

  Widget buildProductCard(Map<String, dynamic> product, String productKey, String langCode, Map<String, String> loc) {
    final bool isOutOfStock = product['isOutOfStock'] ?? false;
    final String productName = product['name'] ?? 'No Name';
    // Check for base64 first, then fallback to imageUrl for backward compatibility
    final String? imageData = product['imageBase64'] as String? ?? product['imageUrl'] as String?;
    final int price = ((product['price'] as num?)?.toInt() ?? 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      elevation: 5,
      child: Stack(
        children: [
          InkWell(
            onTap: !isOutOfStock ? () {
              print('InkWell tapped for product: $productKey, isOutOfStock: $isOutOfStock');
              _onProductTapped(product, productKey, langCode, loc);
            } : null,
            splashColor: Colors.deepOrange.withOpacity(0.3),
            highlightColor: Colors.deepOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildProductImage(imageData),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$price',
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
          
          if (isOutOfStock)
            Positioned.fill(
              child: IgnorePointer(
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
            ),
        ],
      ),
    );
  }
}


