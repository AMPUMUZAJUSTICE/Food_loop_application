import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/food_listing.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class FeedLoadRequested extends FeedEvent {}

class FeedLocationChanged extends FeedEvent {
  final Position position;
  const FeedLocationChanged(this.position);
  @override
  List<Object?> get props => [position];
}

class FeedFilterChanged extends FeedEvent {
  final String? category;
  final bool? freeOnly;
  final String? sortBy;

  const FeedFilterChanged({this.category, this.freeOnly, this.sortBy});

  @override
  List<Object?> get props => [category, freeOnly, sortBy];
}

class FeedPaginationRequested extends FeedEvent {}

class FeedRefreshRequested extends FeedEvent {}

class FeedUpdated extends FeedEvent {
  final List<FoodListing> listings;
  const FeedUpdated(this.listings);
  @override
  List<Object?> get props => [listings];
}

class FeedErrorEvent extends FeedEvent {
  final String message;
  const FeedErrorEvent(this.message);
  @override
  List<Object?> get props => [message];
}
