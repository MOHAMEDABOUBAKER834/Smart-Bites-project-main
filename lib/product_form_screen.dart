import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialProduct;

  const ProductFormScreen({
    super.key,
    this.productId,
    this.initialProduct,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  File? _imageFile;
  String? _existingImageBase64; // For editing existing products
  bool _isLoading = false;
  String _selectedCategory = 'Sandwiches'; // Default category

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'add_product': 'إضافة منتج جديد',
      'edit_product': 'تعديل منتج',
      'name_label': 'اسم المنتج',
      'name_hint': 'أدخل اسم المنتج',
      'price_label': 'السعر',
      'price_hint': 'أدخل السعر',
      'description_label': 'الوصف',
      'description_hint': 'أدخل وصف المنتج',
      'image_label': 'صورة المنتج',
      'pick_image': 'اختر صورة',
      'save': 'حفظ',
      'saving': 'جاري الحفظ...',
      'product_saved': 'تم حفظ المنتج بنجاح',
      'error': 'حدث خطأ',
      'name_required': 'الاسم مطلوب',
      'price_required': 'السعر مطلوب',
      'price_invalid': 'السعر يجب أن يكون رقماً',
      'image_required': 'الصورة مطلوبة',
      'category_label': 'الفئة',
      'category_hint': 'اختر فئة المنتج',
    },
    'en': {
      'add_product': 'Add New Product',
      'edit_product': 'Edit Product',
      'name_label': 'Product Name',
      'name_hint': 'Enter product name',
      'price_label': 'Price',
      'price_hint': 'Enter price',
      'description_label': 'Description',
      'description_hint': 'Enter product description',
      'image_label': 'Product Image',
      'pick_image': 'Pick Image',
      'save': 'Save',
      'saving': 'Saving...',
      'product_saved': 'Product saved successfully',
      'error': 'An error occurred',
      'name_required': 'Name is required',
      'price_required': 'Price is required',
      'price_invalid': 'Price must be a number',
      'image_required': 'Image is required',
      'category_label': 'Category',
      'category_hint': 'Select product category',
    }
  };

  static const Map<String, Map<String, String>> _categoryOptions = {
    'Sandwiches': {'ar': 'ساندويتشات', 'en': 'Sandwiches'},
    'Beverages': {'ar': 'مشروبات', 'en': 'Beverages'},
    'Snacks': {'ar': 'سناكات', 'en': 'Snacks'},
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _nameController.text = widget.initialProduct!['name'] ?? '';
      _priceController.text = widget.initialProduct!['price']?.toString() ?? '';
      _descriptionController.text = widget.initialProduct!['description'] ?? '';
      // Get category from product (check both Firestore and Realtime DB formats)
      final category = widget.initialProduct!['category'];
      if (category is Map) {
        _selectedCategory = category['en'] ?? 'Sandwiches';
      } else if (category is String) {
        _selectedCategory = category;
      }
      // Support both base64 and URL for backward compatibility
      _existingImageBase64 = widget.initialProduct!['imageBase64'] as String?;
      if (_existingImageBase64 == null) {
        // If no base64, check for URL (old format)
        final imageUrl = widget.initialProduct!['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _existingImageBase64 = imageUrl; // Will be treated as URL in display
        }
      }
    }
  }

  Widget _buildImageFromBase64(String imageData) {
    // Check if it's a base64 data URI or a URL
    if (imageData.startsWith('data:image')) {
      // Base64 image
      final base64String = imageData.split(',')[1];
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.image, size: 60),
      );
    } else if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      // URL image (backward compatibility)
      return Image.network(
        imageData,
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
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _existingImageBase64 = null; // Clear existing image
        });
      }
    } catch (e) {
      if (mounted) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        String errorMessage = e.toString();
        // Provide more user-friendly error messages
        if (errorMessage.contains('permission')) {
          errorMessage = 'Permission denied. Please allow access to photos in app settings.';
        } else if (errorMessage.contains('No such file')) {
          errorMessage = 'Image file not found. Please try selecting another image.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc['error']!}: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<String?> _encodeImageToBase64() async {
    // If no new image selected, return existing base64
    if (_imageFile == null) {
      return _existingImageBase64;
    }

    try {
      // Check if file exists
      if (!await _imageFile!.exists()) {
        throw Exception('Image file does not exist');
      }

      // Get file size to ensure it's not empty
      final fileLength = await _imageFile!.length();
      if (fileLength == 0) {
        throw Exception('Image file is empty');
      }

      // Check file size (Firestore document limit is 1MB, so we'll limit to ~700KB for base64)
      // Base64 encoding increases size by ~33%, so 700KB raw = ~930KB base64
      const maxSizeBytes = 700 * 1024; // 700KB
      if (fileLength > maxSizeBytes) {
        throw Exception('Image is too large. Please use an image smaller than 700KB.');
      }

      // Read file bytes and convert to base64
      final bytes = await _imageFile!.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Add data URI prefix for easy display
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error encoding image to base64: $e');
      throw Exception('Failed to process image: ${e.toString()}');
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageFile == null && _existingImageBase64 == null) {
      final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
      final loc = _localizations[langCode]!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc['image_required']!), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      String? imageBase64;
      try {
        imageBase64 = await _encodeImageToBase64();
      } catch (encodeError) {
        // Show specific encoding error
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        String errorMsg = encodeError.toString();
        
        // Remove "Exception: " prefix if present
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        
        // Provide user-friendly error messages
        if (errorMsg.contains('too large')) {
          errorMsg = 'Image is too large. Please use an image smaller than 700KB.';
        } else if (errorMsg.contains('does not exist') || errorMsg.contains('empty')) {
          errorMsg = 'Invalid image file. Please select a valid image.';
        } else {
          errorMsg = 'Failed to process image: $errorMsg';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc['error']!}: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      
      if (imageBase64 == null) {
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        throw Exception('${loc['image_required']!}');
      }

      final productData = {
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'imageBase64': imageBase64, // Store as base64 string in Firestore
        'category': _selectedCategory, // Store category as string for Firestore
        'sellerId': user.uid,
        'isOutOfStock': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String? firestoreProductId = widget.productId;
      bool firestoreAvailable = false;
      
      // Try Firestore with timeout to prevent hanging
      try {
        print('Saving product to Firestore...');
        if (firestoreProductId != null) {
          // Update existing product in Firestore
          print('Updating product: $firestoreProductId');
          await _firestore.collection('products').doc(firestoreProductId).update(productData)
              .timeout(const Duration(seconds: 5));
          print('Product updated successfully');
          firestoreAvailable = true;
        } else {
          // Create new product in Firestore
          productData['createdAt'] = FieldValue.serverTimestamp();
          print('Creating new product...');
          final docRef = await _firestore.collection('products').add(productData)
              .timeout(const Duration(seconds: 5));
          firestoreProductId = docRef.id;
          print('Product created with ID: $firestoreProductId');
          firestoreAvailable = true;
        }
      } on FirebaseException catch (e) {
        print('FirebaseException: ${e.code} - ${e.message}');
        firestoreAvailable = false;
        
        // Check if it's a database not found error - fallback to Realtime Database
        if (e.code == 'not-found' || 
            e.code == 'NOT_FOUND' ||
            e.message?.contains('does not exist') == true ||
            e.message?.contains('does not exist for project') == true) {
          print('Firestore not available, falling back to Realtime Database...');
        }
        // Generate a product ID if we don't have one
        if (firestoreProductId == null) {
          final newRef = _database.child('products').push();
          firestoreProductId = newRef.key;
          print('Generated Realtime DB product ID: $firestoreProductId');
          if (firestoreProductId == null) {
            throw Exception('Failed to generate product ID');
          }
        }
      } on TimeoutException catch (e) {
        print('Firestore operation timed out: $e');
        firestoreAvailable = false;
        // Generate a product ID if we don't have one
        if (firestoreProductId == null) {
          final newRef = _database.child('products').push();
          firestoreProductId = newRef.key;
          print('Generated Realtime DB product ID after timeout: $firestoreProductId');
          if (firestoreProductId == null) {
            throw Exception('Failed to generate product ID');
          }
        }
      } catch (e) {
        print('General exception during Firestore save: $e');
        firestoreAvailable = false;
        
        // Generate a product ID if we don't have one
        if (firestoreProductId == null) {
          final newRef = _database.child('products').push();
          firestoreProductId = newRef.key;
          print('Generated Realtime DB product ID after exception: $firestoreProductId');
          if (firestoreProductId == null) {
            throw Exception('Failed to generate product ID');
          }
        }
      }

      // Save to Realtime Database (primary if Firestore unavailable, sync if Firestore available)
      try {
        print('Saving to Realtime Database...');
        final isOutOfStock = productData['isOutOfStock'] as bool? ?? false;
        final rtProductData = {
          'name': {
            'ar': _nameController.text.trim(),
            'en': _nameController.text.trim(),
          },
          'points': double.parse(_priceController.text.trim()).toInt(),
          'price': double.parse(_priceController.text.trim()),
          'description': _descriptionController.text.trim(),
          'imageBase64': imageBase64, // Also store in Realtime DB for compatibility
          'imageUrl': imageBase64, // Keep imageUrl for backward compatibility
          'isAvailable': !isOutOfStock,
          'category': {
            'ar': _categoryOptions[_selectedCategory]?['ar'] ?? 'عام',
            'en': _categoryOptions[_selectedCategory]?['en'] ?? _selectedCategory,
          },
          'sellerId': user.uid,
          'createdAt': ServerValue.timestamp,
        };
        
        // Use Firestore document ID as key in Realtime Database, or generated ID if Firestore failed
        await _database.child('products/$firestoreProductId').set(rtProductData);
        print('Saved to Realtime Database successfully with ID: $firestoreProductId');
        print('Product data: ${rtProductData.toString()}');
      } catch (e) {
        print('Error saving to Realtime Database: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
          final loc = _localizations[langCode]!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc['error']!}: Failed to save product - ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      // Clear loading state and navigate immediately after Firestore save
      if (mounted) {
        // Clear loading state first
        setState(() => _isLoading = false);
        
        // Wait for the frame to render the state update
        await SchedulerBinding.instance.endOfFrame;
        
        if (!mounted) return;
        
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc['product_saved']!)),
        );
        
        // Navigate back after showing the success message
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
        final loc = _localizations[langCode]!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc['error']!}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    final isEditing = widget.productId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? loc['edit_product']! : loc['add_product']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              Text(
                loc['image_label']!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _existingImageBase64 != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImageFromBase64(_existingImageBase64!),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image, size: 60, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(loc['pick_image']!),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc['name_label']!,
                  hintText: loc['name_hint']!,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc['name_required']!;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Price field
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: loc['price_label']!,
                  hintText: loc['price_hint']!,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc['price_required']!;
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return loc['price_invalid']!;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category dropdown
              Text(
                loc['category_label']!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: loc['category_hint']!,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categoryOptions.keys.map((String category) {
                  final langCode = languageProvider.currentLocale.languageCode;
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(_categoryOptions[category]![langCode] ?? category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: loc['description_label']!,
                  hintText: loc['description_hint']!,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(loc['save']!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

