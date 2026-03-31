import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../feed/domain/entities/food_listing.dart';
import '../../data/repositories/search_repository.dart';

// --- Events ---
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchFilterChanged extends SearchEvent {
  final List<String> filters;

  const SearchFilterChanged(this.filters);

  @override
  List<Object?> get props => [filters];
}

class SearchLoadMore extends SearchEvent {}

class SearchLoadRecents extends SearchEvent {}

class SearchClearRecent extends SearchEvent {}

// --- States ---
abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {
  final List<String> recentSearches;

  const SearchInitial(this.recentSearches);

  @override
  List<Object?> get props => [recentSearches];
}

class SearchLoading extends SearchState {}

class SearchResults extends SearchState {
  final List<FoodListing> listings;
  final bool hasMore;

  const SearchResults({required this.listings, this.hasMore = false});

  @override
  List<Object?> get props => [listings, hasMore];
}

class SearchEmpty extends SearchState {}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Cubit (Using Cubit instead of Bloc for simpler state management) ---
@injectable
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _repository;
  
  String _currentQuery = '';
  List<String> _currentFilters = [];

  SearchBloc(this._repository) : super(const SearchInitial([])) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchFilterChanged>(_onFilterChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchLoadRecents>(_onLoadRecents);
    on<SearchClearRecent>(_onClearRecent);
    
    add(SearchLoadRecents());
  }

  Future<void> _onLoadRecents(SearchLoadRecents event, Emitter<SearchState> emit) async {
    final recents = await _repository.getRecentSearches();
    if (state is SearchInitial) {
      emit(SearchInitial(recents));
    }
  }

  Future<void> _onClearRecent(SearchClearRecent event, Emitter<SearchState> emit) async {
    await _repository.clearRecentSearches();
    if (_currentQuery.isEmpty && _currentFilters.isEmpty) {
      emit(const SearchInitial([]));
    }
  }

  Future<void> _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    _currentQuery = event.query;
    
    if (_currentQuery.isEmpty && _currentFilters.isEmpty) {
      final recents = await _repository.getRecentSearches();
      emit(SearchInitial(recents));
      return;
    }

    emit(SearchLoading());
    await _repository.saveRecentSearch(_currentQuery);
    
    try {
      final results = await _repository.searchListings(_currentQuery, _currentFilters);
      
      if (results.isEmpty) {
        emit(SearchEmpty());
      } else {
        emit(SearchResults(listings: results, hasMore: false));
      }
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onFilterChanged(SearchFilterChanged event, Emitter<SearchState> emit) async {
    _currentFilters = List.from(event.filters);
    
    if (_currentQuery.isEmpty && _currentFilters.isEmpty) {
      final recents = await _repository.getRecentSearches();
      emit(SearchInitial(recents));
      return;
    }

    emit(SearchLoading());
    try {
      final results = await _repository.searchListings(_currentQuery, _currentFilters);
      
      if (results.isEmpty) {
        emit(SearchEmpty());
      } else {
        emit(SearchResults(listings: results, hasMore: false));
      }
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onLoadMore(SearchLoadMore event, Emitter<SearchState> emit) async {
    // Pagination logic would go here. For the prototype, we assume limit(50) is enough
    // and just leave hasMore as false unless implementing real cursor pagination.
  }



}
