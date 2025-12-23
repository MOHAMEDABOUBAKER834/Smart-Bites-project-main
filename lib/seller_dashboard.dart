import 'dart:convert';
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

class _SellerDashboardState extends State<SellerDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'dashboard_title': 'لوحة تحكم البائع',
      'my_products': 'منتجاتي',
      'add_new_product': 'إضافة منتج جديد',
      'no_products': 'لا توجد منتجات حتى الآن',
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
    },
    'en': {
      'dashboard_title': 'Seller Dashboard',
      'my_products': 'My Products',
      'add_new_product': 'Add New Product',
      'no_products': 'No products yet',
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
    }
  };

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
      await _firestore.collection('products').doc(productId).delete();

      // Also delete from Realtime Database
      final database = FirebaseDatabase.instance.ref();
      await database.child('products/$productId').remove();

      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['product_deleted']!)),
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
}

