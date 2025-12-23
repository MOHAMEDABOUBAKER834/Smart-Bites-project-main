import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_bites/language_provider.dart';

class RecentTransfersScreen extends StatefulWidget {
  const RecentTransfersScreen({super.key});

  @override
  State<RecentTransfersScreen> createState() => _RecentTransfersScreenState();
}

class _RecentTransfersScreenState extends State<RecentTransfersScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref('points_transfers');
  List<Map<String, dynamic>> _allTransfers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllTransfers();
  }

  void _fetchAllTransfers() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // جلب كل التحويلات ثم فلترتها داخل التطبيق
      final snapshot = await dbRef.get();
      
      final List<Map<String, dynamic>> transfers = [];
      if (snapshot.exists) {
        final allTransfersMap = Map<String, dynamic>.from(snapshot.value as Map);
        allTransfersMap.forEach((key, value) {
          final transferData = Map<String, dynamic>.from(value);
          // الفلترة هنا للتأكد من جلب كل التحويلات المتعلقة بالمستخدم
          if (transferData['senderId'] == currentUser!.uid || transferData['receiverId'] == currentUser!.uid) {
            transfers.add(transferData);
          }
        });
      }
      
      // ترتيب القائمة النهائية من الأحدث للأقدم
      transfers.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      if (mounted) {
        setState(() {
          _allTransfers = transfers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching transfers: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'سجل التحويلات' : 'Transfer History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTransfers.isEmpty
              ? Center(child: Text(isArabic ? 'لا توجد تحويلات.' : 'No transfers found.'))
              : ListView.builder(
                  itemCount: _allTransfers.length,
                  itemBuilder: (context, index) {
                    final transfer = _allTransfers[index];
                    final isSent = transfer['senderId'] == currentUser!.uid;
                    final dateTime = DateTime.fromMillisecondsSinceEpoch(transfer['timestamp']);
                    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSent ? Colors.redAccent : Colors.green,
                          child: Icon(
                            isSent ? Icons.arrow_upward : Icons.arrow_downward,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          isSent
                              ? (isArabic ? 'تحويل إلى: ${transfer['receiverName']}' : 'To: ${transfer['receiverName']}')
                              : (isArabic ? 'استلام من: ${transfer['senderName']}' : 'From: ${transfer['senderName']}'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isArabic ? 'التاريخ: $formattedDate' : 'Date: $formattedDate'),
                            Text(
                              isArabic
                                  ? 'معرف الشخص: ${isSent ? transfer['receiverNumericId'] : transfer['senderNumericId']}'
                                  : 'User ID: ${isSent ? transfer['receiverNumericId'] : transfer['senderNumericId']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${isSent ? '-' : '+'}${transfer['points']}',
                          style: TextStyle(
                            color: isSent ? Colors.redAccent : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
