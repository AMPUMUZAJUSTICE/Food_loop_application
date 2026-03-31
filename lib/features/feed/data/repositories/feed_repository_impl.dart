import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/food_listing.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/feed_remote_data_source.dart';

@LazySingleton(as: FeedRepository)
class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDataSource _remoteDataSource;

  FeedRepositoryImpl(this._remoteDataSource);

  @override
  Stream<Either<Failure, List<FoodListing>>> getActiveListings({
    String? category,
    bool? freeOnly,
    String? sortBy,
    DocumentSnapshot? startAfter,
  }) {
    return _remoteDataSource
        .getActiveListings(
          category: category,
          freeOnly: freeOnly,
          sortBy: sortBy,
          startAfter: startAfter,
        )
        .map<Either<Failure, List<FoodListing>>>((listings) => Right(listings))
        .handleError((error) {
      return Left(ServerFailure(error.toString()));
    });
  }

  @override
  Future<Either<Failure, FoodListing?>> getListingById(String id) async {
    try {
      final listing = await _remoteDataSource.getListingById(id);
      return Right(listing);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<FoodListing>>> getNearbyListings(double lat, double lng, double radiusKm) {
    return _remoteDataSource
        .getNearbyListings(lat, lng, radiusKm)
        .map<Either<Failure, List<FoodListing>>>((listings) => Right(listings))
        .handleError((error) {
           return Left(ServerFailure(error.toString()));
    });
  }
}
