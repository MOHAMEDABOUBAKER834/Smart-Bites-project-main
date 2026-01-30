import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/verification_pending_screen.dart';

class SellerVerificationPage extends StatefulWidget {
  const SellerVerificationPage({super.key});

  @override
  State<SellerVerificationPage> createState() => _SellerVerificationPageState();
}

class _SellerVerificationPageState extends State<SellerVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  String? _errorMessage;

  static const Map<String, Map<String, String>> _localizations = {
    'en': {
      'title': 'Restaurant Verification',
      'subtitle': 'Upload an image of your restaurant inside the school',
      'select_image': 'Select Image',
      'upload': 'Upload',
      'uploading': 'Uploading...',
      'success': 'Image uploaded successfully!',
      'error': 'Error uploading image',
      'image_required': 'Please select an image',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'cancel': 'Cancel',
    },
    'ar': {
      'title': 'التحقق من المطعم',
      'subtitle': 'قم برفع صورة لمطعمك داخل المدرسة',
      'select_image': 'اختر صورة',
      'upload': 'رفع',
      'uploading': 'جاري الرفع...',
      'success': 'تم رفع الصورة بنجاح!',
      'error': 'حدث خطأ أثناء رفع الصورة',
      'image_required': 'الرجاء اختيار صورة',
      'camera': 'الكاميرا',
      'gallery': 'المعرض',
      'cancel': 'إلغاء',
    },
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(loc['select_image']!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(loc['camera']!),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(loc['gallery']!),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final langCode = languageProvider.currentLocale.languageCode;
      final loc = _localizations[langCode]!;

      setState(() {
        _errorMessage = loc['image_required']!;
      });
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // Convert image to base64
      final base64Image = await _convertImageToBase64(_selectedImage!);
      
      // Get user data to get school name
      final userRef = _database.ref('users/${user.uid}');
      final userSnapshot = await userRef.get();
      String schoolName = '';
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        schoolName = userData['name']?.toString() ?? '';
      }

      // Save verification data to Realtime Database
      final verificationData = {
        'userId': user.uid,
        'schoolName': schoolName,
        'email': user.email,
        'verificationImage': base64Image,
        'status': 'pending',
        'submittedAt': ServerValue.timestamp,
      };

      await _database.ref('sellerVerifications/${user.uid}').set(verificationData);
      
      // Also update user's verification status
      await _database.ref('users/${user.uid}/verificationStatus').set('pending');

      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final langCode = languageProvider.currentLocale.languageCode;
        final loc = _localizations[langCode]!;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['success']!),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to VerificationPendingScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const VerificationPendingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Error: $e';
        });

        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final langCode = languageProvider.currentLocale.languageCode;
        final loc = _localizations[langCode]!;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc['error']!}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.deepOrange.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              loc['subtitle']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[400]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loc['select_image']!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isUploading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(loc['uploading']!),
                      ],
                    )
                  : Text(
                      loc['upload']!,
                      style: const TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

