import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/food_listing.dart';

abstract class FeedRepository {
  Stream<Either<Failure, List<FoodListing>>> getActiveListings({
    String? category,
    bool? freeOnly,
    String? sortBy,
    DocumentSnapshot? startAfter,
  });

  Future<Either<Failure, FoodListing?>> getListingById(String id);

  Stream<Either<Failure, List<FoodListing>>> getNearbyListings(double lat, double lng, double radiusKm);
}
