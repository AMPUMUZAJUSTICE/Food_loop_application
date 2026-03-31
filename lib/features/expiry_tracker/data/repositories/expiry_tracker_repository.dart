import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../domain/entities/expiry_item.dart';

@lazySingleton
class ExpiryTrackerRepository {
  final FirebaseFirestore _firestore;

  ExpiryTrackerRepository(this._firestore);

  Stream<List<ExpiryItem>> streamExpiryItems(String userId) {
    return _firestore
        .collection('expiryItems')
        .doc(userId)
        .collection('items')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpiryItem.fromJson(doc.data()))
            .toList());
  }

  Future<void> addExpiryItem(ExpiryItem item) async {
    await _firestore
        .collection('expiryItems')
        .doc(item.userId)
        .collection('items')
        .doc(item.id)
        .set(item.toJson());

    await LocalNotificationService().scheduleExpiryNotifications(
      item.id,
      item.name,
      item.expiryDate,
    );
  }

  Future<void> updateExpiryItem(ExpiryItem item) async {
    await _firestore
        .collection('expiryItems')
        .doc(item.userId)
        .collection('items')
        .doc(item.id)
        .update(item.toJson());

    // Reschedule
    await LocalNotificationService().cancelNotifications(item.id);
    await LocalNotificationService().scheduleExpiryNotifications(
      item.id,
      item.name,
      item.expiryDate,
    );
  }

  Future<void> deleteExpiryItem(String userId, String itemId) async {
    await _firestore
        .collection('expiryItems')
        .doc(userId)
        .collection('items')
        .doc(itemId)
        .delete();

    await LocalNotificationService().cancelNotifications(itemId);
  }
}
