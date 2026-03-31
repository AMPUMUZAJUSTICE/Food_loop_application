import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../orders/domain/entities/order.dart' as app_order;
import '../../domain/entities/rating.dart';
import '../../data/repositories/rating_repository.dart';

// --- Events ---
abstract class RatingEvent extends Equatable {
  const RatingEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrderToRate extends RatingEvent {
  final String orderId;

  const LoadOrderToRate(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class SubmitRatingEvent extends RatingEvent {
  final String orderId;
  final String reviewerId;
  final String? reviewerName;
  final String sellerId;
  final int foodQualityRating;
  final int reliabilityRating;
  final String? comment;
  final bool isAnonymous;

  const SubmitRatingEvent({
    required this.orderId,
    required this.reviewerId,
    this.reviewerName,
    required this.sellerId,
    required this.foodQualityRating,
    required this.reliabilityRating,
    this.comment,
    required this.isAnonymous,
  });

  @override
  List<Object?> get props => [
        orderId, reviewerId, reviewerName, sellerId, foodQualityRating,
        reliabilityRating, comment, isAnonymous,
      ];
}

// --- States ---
abstract class RatingState extends Equatable {
  const RatingState();

  @override
  List<Object?> get props => [];
}

class RatingInitial extends RatingState {}

class RatingLoading extends RatingState {}

class RatingOrderLoaded extends RatingState {
  final app_order.Order order;

  const RatingOrderLoaded(this.order);

  @override
  List<Object?> get props => [order];
}

class RatingSubmitting extends RatingState {}

class RatingSuccess extends RatingState {}

class RatingError extends RatingState {
  final String message;

  const RatingError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Bloc ---
@injectable
class RatingBloc extends Bloc<RatingEvent, RatingState> {
  final RatingRepository _repository;

  RatingBloc(this._repository) : super(RatingInitial()) {
    on<LoadOrderToRate>(_onLoadOrderToRate);
    on<SubmitRatingEvent>(_onSubmitRating);
  }

  Future<void> _onLoadOrderToRate(LoadOrderToRate event, Emitter<RatingState> emit) async {
    emit(RatingLoading());
    try {
      final order = await _repository.getOrder(event.orderId);
      if (order != null) {
        emit(RatingOrderLoaded(order));
      } else {
        emit(const RatingError('Order not found'));
      }
    } catch (e) {
      emit(RatingError(e.toString()));
    }
  }

  Future<void> _onSubmitRating(SubmitRatingEvent event, Emitter<RatingState> emit) async {
    emit(RatingSubmitting());
    try {
      final rating = Rating(
        id: const Uuid().v4(),
        orderId: event.orderId,
        reviewerId: event.reviewerId,
        reviewerName: event.reviewerName,
        sellerId: event.sellerId,
        foodQualityRating: event.foodQualityRating,
        reliabilityRating: event.reliabilityRating,
        comment: event.comment,
        isAnonymous: event.isAnonymous,
        createdAt: DateTime.now(),
      );

      await _repository.submitRating(rating);
      emit(RatingSuccess());
    } catch (e) {
      emit(RatingError(e.toString()));
    }
  }
}
