import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/app_notification.dart';

@lazySingleton
class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository(this._firestore);

  Stream<List<AppNotification>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.data()..['id'] = doc.id))
            .toList());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }
}
