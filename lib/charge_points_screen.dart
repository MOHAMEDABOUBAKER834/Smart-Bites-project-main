import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';
import 'package:smart_bites/payment_gateway_screen.dart';

class ChargePointsScreen extends StatefulWidget {
  const ChargePointsScreen({super.key});

  @override
  State<ChargePointsScreen> createState() => _ChargePointsScreenState();
}

class _ChargePointsScreenState extends State<ChargePointsScreen> {
  String _selectedPaymentMethod = 'Card';
  int? _selectedPackageId; // تم التغيير ليقبل قيمة null
  final _customPointsController = TextEditingController();
  int _customAmountPrice = 0;

  // --- قاموس للترجمات ---
  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'شحن نقاط',
      'select_package': 'اختر باقة شحن جاهزة',
      'custom_amount': 'أو أدخل عدد النقاط التي تريدها',
      'points_label': 'عدد النقاط',
      'price_to_pay': 'المبلغ المطلوب دفعه',
      'select_payment': 'اختر طريقة الدفع',
      'proceed_to_pay': 'الانتقال للدفع',
      'points': 'نقطة',
      'price': 'جنيه',
    },
    'en': {
      'title': 'Top-up Points',
      'select_package': 'Select a Ready Package',
      'custom_amount': 'Or enter the amount of points you want',
      'points_label': 'Number of Points',
      'price_to_pay': 'Amount to Pay',
      'select_payment': 'Select Payment Method',
      'proceed_to_pay': 'Proceed to Pay',
      'points': 'Points',
      'price': 'EGP',
    }
  };

  // --- قائمة باقات الشحن بعد تعديل الأسعار ---
  // النقطة = 2 جنيه
  final List<Map<String, dynamic>> _packages = [
    {'id': 1, 'points': 50, 'price': 100},  // 50 نقطة = 100 جنيه
    {'id': 2, 'points': 100, 'price': 200}, // 100 نقطة = 200 جنيه
    {'id': 3, 'points': 250, 'price': 500}, // 250 نقطة = 500 جنيه
  ];

  @override
  void initState() {
    super.initState();
    _customPointsController.addListener(_onCustomPointsChanged);
  }

  void _onCustomPointsChanged() {
    final points = int.tryParse(_customPointsController.text) ?? 0;
    setState(() {
      _customAmountPrice = points * 2; // النقطة بـ 2 جنيه
      if (points > 0) {
        _selectedPackageId = null; // إلغاء اختيار الباقة الجاهزة
      }
    });
  }

  @override
  void dispose() {
    _customPointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final langCode = languageProvider.currentLocale.languageCode;
    final loc = _localizations[langCode]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc['title']!),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc['select_package']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._packages.map((pkg) => Card(
              color: _selectedPackageId == pkg['id'] ? Colors.orange.shade100 : Colors.white,
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text('${pkg['points']} ${loc['points']}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                subtitle: Text('${pkg['price']} ${loc['price']}', style: const TextStyle(fontFamily: 'Poppins')),
                onTap: () {
                  setState(() {
                    _selectedPackageId = pkg['id'];
                    _customPointsController.clear(); // مسح الخانة المخصصة
                  });
                },
              ),
            )),
            const SizedBox(height: 20),
            Text(loc['custom_amount']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _customPointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: loc['points_label'],
                border: const OutlineInputBorder(),
              ),
            ),
            if (_customAmountPrice > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${loc['price_to_pay']}: $_customAmountPrice ${loc['price']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
              ),
            const SizedBox(height: 30),
            Text(loc['select_payment']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            RadioListTile<String>(
              title: const Text('Visa/Mastercard'),
              value: 'Card',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
            ),
            RadioListTile<String>(
              title: const Text('Vodafone Cash'),
              value: 'Vodafone Cash',
              onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
              groupValue: _selectedPaymentMethod,
            ),
            RadioListTile<String>(
              title: const Text('Instapay'),
              value: 'Instapay',
              groupValue: _selectedPaymentMethod,
              onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                int pointsToCharge = 0;
                int amountToPay = 0;

                if (_selectedPackageId != null) {
                  final selectedPkg = _packages.firstWhere((pkg) => pkg['id'] == _selectedPackageId);
                  pointsToCharge = selectedPkg['points'];
                  amountToPay = selectedPkg['price'];
                } else if (_customAmountPrice > 0) {
                  pointsToCharge = int.tryParse(_customPointsController.text) ?? 0;
                  amountToPay = _customAmountPrice;
                }

                if (pointsToCharge > 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentGatewayScreen(
                        pointsToCharge: pointsToCharge,
                        amountToPay: amountToPay,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              child: Text(loc['proceed_to_pay']!),
            ),
          ],
        ),
      ),
    );
  }
}
