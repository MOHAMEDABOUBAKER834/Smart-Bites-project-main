import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class TransferPointsScreen extends StatefulWidget {
  const TransferPointsScreen({super.key});

  @override
  State<TransferPointsScreen> createState() => _TransferPointsScreenState();
}

class _TransferPointsScreenState extends State<TransferPointsScreen> {
  final _recipientIdController = TextEditingController();
  final _pointsController = TextEditingController();
  final dbRef = FirebaseDatabase.instance.ref();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  static const Map<String, Map<String, String>> _localizations = {
    'ar': {
      'title': 'تحويل نقاط',
      'recipient_id': 'المعرف الرقمي للمستلم',
      'points_amount': 'عدد النقاط',
      'transfer': 'تحويل',
      'success': 'تم التحويل بنجاح!',
      'no_user': 'المستخدم غير موجود.',
      'no_points': 'رصيدك غير كافٍ.',
      'self_transfer': 'لا يمكنك التحويل لنفسك.',
      'error': 'حدث خطأ. حاول مرة أخرى.',
    },
    'en': {
      'title': 'Transfer Points',
      'recipient_id': 'Recipient Numeric ID',
      'points_amount': 'Points Amount',
      'transfer': 'Transfer',
      'success': 'Transfer successful!',
      'no_user': 'Recipient not found.',
      'no_points': 'Insufficient points balance.',
      'self_transfer': 'You cannot transfer points to yourself.',
      'error': 'An error occurred. Please try again.',
    }
  };

  void _transferPoints() async {
    setState(() => _isLoading = true);
    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;
    final loc = _localizations[langCode]!;
    
    final recipientNumericId = _recipientIdController.text.trim();
    final pointsToTransfer = int.tryParse(_pointsController.text.trim()) ?? 0;

    if (currentUser == null || recipientNumericId.isEmpty || pointsToTransfer <= 0) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final senderSnapshot = await dbRef.child('users/${currentUser!.uid}').get();
      final recipientUidSnapshot = await dbRef.child('numericId_to_uid/$recipientNumericId').get();

      if (!recipientUidSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['no_user']!), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      final recipientUid = recipientUidSnapshot.value as String;
      if (currentUser!.uid == recipientUid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['self_transfer']!), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }
      
      final recipientSnapshot = await dbRef.child('users/$recipientUid').get();
      
      final senderData = Map<String, dynamic>.from(senderSnapshot.value as Map);
      int senderPoints = (senderData['points'] as num?)?.toInt() ?? 0;

      if (senderPoints < pointsToTransfer) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['no_points']!), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      final recipientData = Map<String, dynamic>.from(recipientSnapshot.value as Map);
      int recipientPoints = (recipientData['points'] as num?)?.toInt() ?? 0;

      final Map<String, dynamic> updates = {};
      updates['/users/${currentUser!.uid}/points'] = senderPoints - pointsToTransfer;
      updates['/users/$recipientUid/points'] = recipientPoints + pointsToTransfer;
      
      final transferLogRef = dbRef.child('points_transfers').push();
      updates[transferLogRef.path] = {
        'senderId': currentUser!.uid,
        'senderNumericId': senderData['numericId'],
        'senderName': senderData['name'],
        'receiverId': recipientUid,
        'receiverNumericId': recipientData['numericId'],
        'receiverName': recipientData['name'],
        'points': pointsToTransfer,
        'timestamp': ServerValue.timestamp,
      };

      await dbRef.update(updates);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['success']!), backgroundColor: Colors.green));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc['error']!), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _recipientIdController,
              decoration: InputDecoration(labelText: loc['recipient_id']!),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pointsController,
              decoration: InputDecoration(labelText: loc['points_amount']!),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _transferPoints,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(loc['transfer']!, style: const TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}
