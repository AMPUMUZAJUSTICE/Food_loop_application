import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/repositories/expiry_tracker_repository.dart';
import '../../domain/entities/expiry_item.dart';

abstract class ExpiryTrackerState extends Equatable {
  const ExpiryTrackerState();

  @override
  List<Object?> get props => [];
}

class ExpiryTrackerInitial extends ExpiryTrackerState {}

class ExpiryTrackerLoading extends ExpiryTrackerState {}

class ExpiryTrackerLoaded extends ExpiryTrackerState {
  final List<ExpiryItem> items;

  const ExpiryTrackerLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class ExpiryTrackerError extends ExpiryTrackerState {
  final String message;

  const ExpiryTrackerError(this.message);

  @override
  List<Object?> get props => [message];
}

@injectable
class ExpiryTrackerCubit extends Cubit<ExpiryTrackerState> {
  final ExpiryTrackerRepository _repository;
  StreamSubscription? _subscription;

  ExpiryTrackerCubit(this._repository) : super(ExpiryTrackerInitial());

  void loadItems(String userId) {
    emit(ExpiryTrackerLoading());
    _subscription?.cancel();
    _subscription = _repository.streamExpiryItems(userId).listen(
      (items) {
        // Sort ascending by expiry date
        items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        emit(ExpiryTrackerLoaded(items));
      },
      onError: (e) {
        emit(ExpiryTrackerError(e.toString()));
      },
    );
  }

  Future<void> addItem(ExpiryItem item) async {
    try {
      await _repository.addExpiryItem(item);
    } catch (e) {
      emit(ExpiryTrackerError('Failed to add item: $e'));
      // Reload previous state? In a real app we might handle this better.
    }
  }

  Future<void> deleteItem(String userId, String itemId) async {
    try {
      await _repository.deleteExpiryItem(userId, itemId);
    } catch (e) {
      emit(ExpiryTrackerError('Failed to delete item: $e'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
