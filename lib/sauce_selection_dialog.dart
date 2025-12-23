import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class SauceSelectionDialog extends StatefulWidget {
  final Map<dynamic, dynamic> product;
  final String productKey;

  const SauceSelectionDialog({
    super.key,
    required this.product,
    required this.productKey,
  });

  @override
  State<SauceSelectionDialog> createState() => _SauceSelectionDialogState();
}

class _SauceSelectionDialogState extends State<SauceSelectionDialog> {
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic> _allSauces = {};
  List<Map<String, dynamic>> _selectedSauces = [];
  int _totalPoints = 0;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'اختر إضافاتك',
      'total': 'الإجمالي',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد الإضافة',
      'points_suffix': 'نقطة',
    },
    'en': {
      'title': 'Choose Your Add-ons',
      'total': 'Total',
      'cancel': 'Cancel',
      'confirm': 'Confirm & Add',
      'points_suffix': 'Points',
    }
  };

  @override
  void initState() {
    super.initState();
    _totalPoints = (widget.product['points'] as num?)?.toInt() ?? 0;
    _fetchAllSauces();
  }

  void _fetchAllSauces() async {
    final snapshot = await dbRef.child('sauces').get();
    if (snapshot.exists && mounted) {
      final encodedData = jsonEncode(snapshot.value);
      final decodedData = jsonDecode(encodedData) as Map<String, dynamic>;
      setState(() {
        _allSauces = decodedData;
      });
    }
  }

  void _onSauceSelected(bool? selected, Map<String, dynamic> sauce, String sauceId) {
    setState(() {
      if (selected == true) {
        _selectedSauces.add({
          'id': sauceId,
          'name': sauce['name'],
          'points': sauce['points'],
        });
      } else {
        _selectedSauces.removeWhere((s) => s['id'] == sauceId);
      }
      _calculateTotalPoints();
    });
  }

  void _calculateTotalPoints() {
    int points = (widget.product['points'] as num?)?.toInt() ?? 0;
    for (var sauce in _selectedSauces) {
      points += (sauce['points'] as num?)?.toInt() ?? 0;
    }
    _totalPoints = points;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    final availableSauceIds = List<String>.from(widget.product['availableSauces'] ?? []);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // --- ✅ جديد: تم تغيير العنوان بالكامل ---
      title: Row(
        children: [
          Icon(Icons.add_shopping_cart, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.product['name']?[langCode] ?? loc['title']!)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _allSauces.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                itemCount: availableSauceIds.length,
                itemBuilder: (context, index) {
                  final sauceId = availableSauceIds[index];
                  final sauce = _allSauces[sauceId];
                  if (sauce == null) return const SizedBox.shrink();

                  final isSelected = _selectedSauces.any((s) => s['id'] == sauceId);
                  
                  // --- ✅ جديد: استخدام Card لتصميم أفضل ---
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: CheckboxListTile(
                      title: Text(sauce['name']?[langCode] ?? ''),
                      subtitle: Text('${sauce['points']} ${loc['points_suffix']}'),
                      value: isSelected,
                      onChanged: (selected) => _onSauceSelected(selected, sauce, sauceId),
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc['cancel']!),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(loc['total']!),
                Row(
                  children: [
                    Text('$_totalPoints', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Poppins')),
                    const SizedBox(width: 2),
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                  ],
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _selectedSauces);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
          child: Text(loc['confirm']!),
        ),
      ],
    );
  }
}
