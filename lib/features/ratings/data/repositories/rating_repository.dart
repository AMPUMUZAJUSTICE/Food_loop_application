import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

import '../../../orders/domain/entities/order.dart' as app_order;
import '../../domain/entities/rating.dart';

@lazySingleton
class RatingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  RatingRepository(this._firestore, this._functions);

  Future<app_order.Order?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    return app_order.Order.fromJson(doc.data()!);
  }

  Future<void> submitRating(Rating rating) async {
    // 1. Save rating to Firestore 'ratings' collection
    await _firestore.collection('ratings').doc(rating.id).set(rating.toJson());

    // 2. We'll mark the order as 'rated' so they can't rate twice
    await _firestore.collection('orders').doc(rating.orderId).update({
      'isRated': true,
    });

    // 3. Call Cloud Function to recalculate seller's averageRating
    try {
      // Force token refresh to ensure Function context is authenticated
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final callable = _functions.httpsCallable('updateSellerRating');
      await callable.call({
        'sellerId': rating.sellerId,
        'ratingId': rating.id,
      });
    } catch (e) {
      // If cloud function fails, it should probably be handled via a trigger anyway in production.
      // For this prototype, we'll swallow the callable error if it successfully saved the rating.
    }
  }
}
