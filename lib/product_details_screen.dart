import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<dynamic, dynamic> product;
  final String productKey;
  final String langCode;
  final Map<String, String> localizations;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.productKey,
    required this.langCode,
    required this.localizations,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late int _totalPoints;
  late List<dynamic> _availableSauces;
  final List<Map<String, dynamic>> _selectedSauces = [];

  @override
  void initState() {
    super.initState();
    _totalPoints = (widget.product['points'] as num).toInt();
    var saucesData = widget.product['availableSauces'];
    if (saucesData is List) {
      _availableSauces = saucesData;
    } else {
      _availableSauces = [];
    }
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

  void _onSauceSelected(bool? isSelected, Map<String, dynamic> sauce) {
    setState(() {
      if (isSelected == true) {
        _selectedSauces.add(sauce);
        _totalPoints += (sauce['points'] as num).toInt();
      } else {
        _selectedSauces.removeWhere((s) => s['id'] == sauce['id']);
        _totalPoints -= (sauce['points'] as num).toInt();
      }
    });
  }

  void _confirmAddToCart() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final cartItemKey = '${widget.productKey}-${_selectedSauces.map((s) => s['id']).join('-')}';
    final cartRef = FirebaseDatabase.instance.ref('carts/${user.uid}/$cartItemKey');
    
    cartRef.runTransaction((Object? currentData) {
      if (currentData == null) {
        return Transaction.success({
          'name': widget.product['name'],
          'points': _totalPoints,
          'imageUrl': widget.product['imageUrl'],
          'quantity': 1,
          'category': widget.product['category'],
          'selectedSauces': _selectedSauces,
        });
      } else {
        final data = Map<String, dynamic>.from(currentData as Map);
        data['quantity'] = (data['quantity'] ?? 0) + 1;
        return Transaction.success(data);
      }
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${widget.product['name'][widget.langCode]} ${widget.localizations['added_to_cart']}',
          style: _getTextStyle(widget.langCode, color: Colors.white)
        ),
        duration: const Duration(seconds: 1),
      ));
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.localizations;
    final lang = widget.langCode;

    // --- ✅ تم تعديل النص هنا ---
    final titleText = loc['select_addons'] ?? 'اختر الاضافات';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product['name'][lang] ?? 'Product Details', style: _getTextStyle(lang, weight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Image.network(
            widget.product['imageUrl'] ?? 'https://via.placeholder.com/150',
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),

          Text(titleText, style: _getTextStyle(lang, size: 20)),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _availableSauces.length,
              itemBuilder: (context, index) {
                final sauce = Map<String, dynamic>.from(_availableSauces[index] as Map);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: CheckboxListTile(
                    title: Text(sauce['name'][lang] ?? 'Unknown Sauce', style: _getTextStyle(lang, weight: FontWeight.normal)),
                    subtitle: Text('+${sauce['points']} ${loc['point']}', style: _getTextStyle(lang, weight: FontWeight.normal, color: Colors.grey)),
                    value: _selectedSauces.any((s) => s['id'] == sauce['id']),
                    onChanged: (bool? value) {
                      _onSauceSelected(value, sauce);
                    },
                    activeColor: Colors.deepOrange,
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc['total_points']!, style: _getTextStyle(lang, size: 14, color: Colors.grey, weight: FontWeight.normal)),
                    Text('$_totalPoints ${loc['point']}', style: _getTextStyle(lang, size: 20, color: Colors.deepOrange)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _confirmAddToCart,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(loc['confirm_addition']!, style: _getTextStyle(lang, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
