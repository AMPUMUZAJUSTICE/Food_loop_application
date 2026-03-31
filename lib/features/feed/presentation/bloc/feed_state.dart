import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/food_listing.dart';

abstract class FeedState extends Equatable {
  const FeedState();
  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<FoodListing> listings;
  final bool hasMore;
  final Map<String, dynamic> activeFilters;
  final Position? userLocation;

  const FeedLoaded(this.listings, this.hasMore, this.activeFilters, {this.userLocation});

  @override
  List<Object?> get props => [listings, hasMore, activeFilters, userLocation];
}

class FeedError extends FeedState {
  final String message;
  const FeedError(this.message);
  @override
  List<Object?> get props => [message];
}
