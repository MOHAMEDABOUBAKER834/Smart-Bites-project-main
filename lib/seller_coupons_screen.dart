import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class SellerCouponsScreen extends StatefulWidget {
  const SellerCouponsScreen({super.key});

  @override
  State<SellerCouponsScreen> createState() => _SellerCouponsScreenState();
}

class _SellerCouponsScreenState extends State<SellerCouponsScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _coupons = [];

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'كوبونات الخصم',
      'no_coupons': 'لا توجد كوبونات حتى الآن',
      'code': 'الكود',
      'discount_percent': 'نسبة الخصم',
      'usage_limit': 'الحد الأقصى للاستخدام',
      'times_used': 'عدد مرات الاستخدام',
      'active': 'نشط',
      'expired': 'منتهي الصلاحية',
      'add_coupon': 'إضافة كوبون',
      'edit_coupon': 'تعديل كوبون',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'confirm_delete': 'هل أنت متأكد من حذف هذا الكوبون؟',
      'expires_at': 'تاريخ الانتهاء (اختياري)',
      'days_valid': 'عدد الأيام للصلاحية',
      'discount_label': 'نسبة الخصم (%)',
      'limit_label': 'الحد الأقصى للاستخدام',
    },
    'en': {
      'title': 'Discount Coupons',
      'no_coupons': 'No coupons yet',
      'code': 'Code',
      'discount_percent': 'Discount Percent',
      'usage_limit': 'Usage Limit',
      'times_used': 'Times Used',
      'active': 'Active',
      'expired': 'Expired',
      'add_coupon': 'Add Coupon',
      'edit_coupon': 'Edit Coupon',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'confirm_delete': 'Are you sure you want to delete this coupon?',
      'expires_at': 'Expires in (optional)',
      'days_valid': 'Days valid',
      'discount_label': 'Discount percent (%)',
      'limit_label': 'Maximum uses',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final ref = _database.ref('coupons/${user.uid}');
      final snapshot = await ref.get();

      if (!mounted) return;

      if (snapshot.exists) {
        final map = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> list = [];
        map.forEach((code, value) {
          final data = Map<String, dynamic>.from(value as Map);
          data['code'] = code.toString();
          list.add(data);
        });

        // Sort by createdAt desc
        list.sort((a, b) {
          final aTime = (a['createdAt'] as num?)?.toInt() ?? 0;
          final bTime = (b['createdAt'] as num?)?.toInt() ?? 0;
          return bTime.compareTo(aTime);
        });

        setState(() {
          _coupons = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _coupons = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading coupons: $e');
      if (mounted) {
        setState(() {
          _coupons = [];
          _isLoading = false;
        });
      }
    }
  }

  String _generateCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _showCouponDialog({Map<String, dynamic>? existing}) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode] ?? _localizations['en']!;

    final discountController = TextEditingController(
      text: existing != null ? ((existing['discountPercent'] as num?)?.toInt() ?? 0).toString() : '',
    );
    final limitController = TextEditingController(
      text: existing != null ? ((existing['usageLimit'] as num?)?.toInt() ?? 1).toString() : '1',
    );
    final daysController = TextEditingController();

    bool isActive = existing?['isActive'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? loc['add_coupon']! : loc['edit_coupon']!),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(labelText: loc['discount_label']),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(labelText: loc['limit_label']),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: daysController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(labelText: loc['days_valid']),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) {
                    isActive = v;
                    (context as Element).markNeedsBuild();
                  },
                  title: Text(loc['active']!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc['cancel']!),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc['save']!),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final discount = int.tryParse(discountController.text.trim()) ?? 0;
    final limit = int.tryParse(limitController.text.trim()) ?? 1;
    final days = int.tryParse(daysController.text.trim());

    if (discount <= 0 || discount > 100) return;
    if (limit <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final code = existing?['code']?.toString() ?? _generateCouponCode();
    final ref = _database.ref('coupons/${user.uid}/$code');

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = days != null && days > 0
        ? DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch
        : 0;

    final data = {
      'discountPercent': discount,
      'usageLimit': limit,
      'timesUsed': existing?['timesUsed'] ?? 0,
      'isActive': isActive,
      'createdAt': existing?['createdAt'] ?? now,
      'expiresAt': expiresAt,
    };

    await ref.set(data);
    await _loadCoupons();
  }

  Future<void> _deleteCoupon(String code) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode] ?? _localizations['en']!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc['delete']!),
        content: Text(loc['confirm_delete']!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc['cancel']!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc['delete']!),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _database.ref('coupons/${user.uid}/$code').remove();
    await _loadCoupons();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode] ?? _localizations['en']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!),
        backgroundColor: Colors.deepOrange.shade400,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCouponDialog(),
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? Center(child: Text(loc['no_coupons']!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) {
                    final c = _coupons[index];
                    final code = c['code']?.toString() ?? '';
                    final percent =
                        (c['discountPercent'] as num?)?.toInt() ?? 0;
                    final limit =
                        (c['usageLimit'] as num?)?.toInt() ?? 0;
                    final used =
                        (c['timesUsed'] as num?)?.toInt() ?? 0;
                    final isActive = c['isActive'] != false;
                    final expiresAt =
                        (c['expiresAt'] as num?)?.toInt() ?? 0;
                    final isExpired = expiresAt > 0 &&
                        DateTime.now().millisecondsSinceEpoch > expiresAt;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          code,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins'),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${loc['discount_percent']}: $percent%'),
                            Text(
                                '${loc['usage_limit']}: $used / $limit'),
                            if (isExpired)
                              Text(
                                loc['expired']!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              )
                            else
                              Text(
                                isActive ? loc['active']! : '',
                                style: TextStyle(
                                    color: isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _showCouponDialog(existing: c);
                            } else if (value == 'toggle') {
                              final user = _auth.currentUser;
                              if (user == null) return;
                              await _database
                                  .ref('coupons/${user.uid}/$code/isActive')
                                  .set(!isActive);
                              await _loadCoupons();
                            } else if (value == 'delete') {
                              await _deleteCoupon(code);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(loc['edit_coupon']!),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                isActive ? loc['active']! : loc['expired']!,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                loc['delete']!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}


