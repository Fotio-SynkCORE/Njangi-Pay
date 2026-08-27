import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// In-app notifications only -- no SMS/push, since those cost money and
/// this app runs on the free Firebase plan. Stored per-user so each
/// member sees their own list, written by whoever performs the action
/// that triggers it (e.g. the secretary verifying a contribution writes
/// into the contributor's notification list).
class NotificationService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<AppNotification>> myNotifications() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  Stream<int> unreadCount() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String notificationId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> markAllRead() async {
    final unread = await _db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Writes a notification into someone else's list -- called by
  /// GroupService when an action (like verifying a contribution) needs to
  /// notify a different member than whoever performed it.
  Future<void> notify({
    required String recipientUserId,
    required String title,
    required String body,
    String? type,
    String? groupId,
  }) {
    return _db.collection('users').doc(recipientUserId).collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'groupId': groupId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final String? groupId;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.type,
    this.groupId,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      type: d['type'],
      groupId: d['groupId'],
    );
  }
}