import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/feed_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';

@injectable
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final FeedRepository _feedRepository;
  StreamSubscription? _feedSubscription;
  
  String? _category;
  bool? _freeOnly;
  String? _sortBy;
  Position? _userLocation;

  FeedBloc(this._feedRepository) : super(FeedInitial()) {
    on<FeedLoadRequested>(_onLoadRequested);
    on<FeedLocationChanged>(_onLocationChanged);
    on<FeedFilterChanged>(_onFilterChanged);
    on<FeedPaginationRequested>(_onPaginationRequested);
    on<FeedRefreshRequested>(_onRefreshRequested);
    on<FeedUpdated>(_onFeedUpdated);
    on<FeedErrorEvent>(_onFeedError);
  }

  void _onLoadRequested(FeedLoadRequested event, Emitter<FeedState> emit) {
    emit(FeedLoading());
    _subscribeToFeed();
  }

  void _onLocationChanged(FeedLocationChanged event, Emitter<FeedState> emit) {
    _userLocation = event.position;
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;
      emit(FeedLoaded(
        currentState.listings,
        currentState.hasMore,
        currentState.activeFilters,
        userLocation: _userLocation,
      ));
    }
  }

  void _onFilterChanged(FeedFilterChanged event, Emitter<FeedState> emit) {
    _category = event.category;
    _freeOnly = event.freeOnly;
    _sortBy = event.sortBy;
    
    emit(FeedLoading());
    _subscribeToFeed();
  }

  void _onRefreshRequested(FeedRefreshRequested event, Emitter<FeedState> emit) {
    _subscribeToFeed();
  }

  void _onPaginationRequested(FeedPaginationRequested event, Emitter<FeedState> emit) {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;
      if (!currentState.hasMore) return;
    }
  }

  void _onFeedUpdated(FeedUpdated event, Emitter<FeedState> emit) {
    emit(FeedLoaded(
      event.listings,
      false,
      {
        'category': _category,
        'freeOnly': _freeOnly,
        'sortBy': _sortBy,
      },
      userLocation: _userLocation,
    ));
  }

  void _onFeedError(FeedErrorEvent event, Emitter<FeedState> emit) {
    emit(FeedError(event.message));
  }

  void _subscribeToFeed() {
    _feedSubscription?.cancel();
    _feedSubscription = _feedRepository.getActiveListings(
      category: _category,
      freeOnly: _freeOnly,
      sortBy: _sortBy,
    ).listen((result) {
      result.fold(
        (failure) => add(FeedErrorEvent(failure.message)),
        (listings) => add(FeedUpdated(listings)),
      );
    });
  }

  @override
  Future<void> close() {
    _feedSubscription?.cancel();
    return super.close();
  }
}
