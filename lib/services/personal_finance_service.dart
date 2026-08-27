import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalFinanceService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<FinanceEntry>> entries() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('personalFinance')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FinanceEntry.fromDoc).toList());
  }

  Future<void> addEntry({
    required String type, // income | expense
    required int amount,
    required String category,
  }) {
    return _db.collection('users').doc(_uid).collection('personalFinance').add({
      'type': type,
      'amount': amount,
      'category': category,
      'date': FieldValue.serverTimestamp(),
    });
  }
}

class FinanceEntry {
  final String id;
  final String type;
  final int amount;
  final String category;
  final DateTime? date;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
  });

  factory FinanceEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FinanceEntry(
      id: doc.id,
      type: d['type'] ?? 'expense',
      amount: (d['amount'] ?? 0) as int,
      category: d['category'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate(),
    );
  }
}
