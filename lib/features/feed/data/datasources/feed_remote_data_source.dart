import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/food_listing.dart';

abstract class FeedRemoteDataSource {
  Stream<List<FoodListing>> getActiveListings({
    String? category,
    bool? freeOnly,
    String? sortBy,
    DocumentSnapshot? startAfter,
  });

  Future<FoodListing?> getListingById(String id);

  Stream<List<FoodListing>> getNearbyListings(double lat, double lng, double radiusKm);
}

@LazySingleton(as: FeedRemoteDataSource)
class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final FirebaseFirestore _firestore;

  FeedRemoteDataSourceImpl(this._firestore);

  @override
  Stream<List<FoodListing>> getActiveListings({
    String? category,
    bool? freeOnly,
    String? sortBy,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .where('pickupWindowEnd', isGreaterThan: Timestamp.now());

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (freeOnly == true) {
      query = query.where('price', isEqualTo: 0);
    }

    if (sortBy == 'newest') {
      query = query.orderBy('pickupWindowEnd').orderBy('createdAt', descending: true);
    } else if (sortBy == 'price_asc') {
      query = query.orderBy('pickupWindowEnd').orderBy('price', descending: false);
    } else if (sortBy == 'price_desc') {
      query = query.orderBy('pickupWindowEnd').orderBy('price', descending: true);
    } else if (sortBy == 'expiry_soonest') {
      query = query.orderBy('pickupWindowEnd', descending: false);
    } else {
      query = query.orderBy('pickupWindowEnd').orderBy('createdAt', descending: true);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(20);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return FoodListing.fromJson(data);
      }).toList();
    });
  }

  @override
  Future<FoodListing?> getListingById(String id) async {
    final doc = await _firestore.collection('listings').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return FoodListing.fromJson(data);
  }

  @override
  Stream<List<FoodListing>> getNearbyListings(double lat, double lng, double radiusKm) {
    // Placeholder for Geohash implementation, returning active for now
    return getActiveListings();
  }
}
