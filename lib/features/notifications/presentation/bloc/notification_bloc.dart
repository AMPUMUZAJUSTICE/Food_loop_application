import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/app_notification.dart';
import '../../data/repositories/notification_repository.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object> get props => [];
}

class StartListeningToNotifications extends NotificationEvent {
  final String userId;
  const StartListeningToNotifications(this.userId);

  @override
  List<Object> get props => [userId];
}

class StopListeningToNotifications extends NotificationEvent {
  const StopListeningToNotifications();
}

class NotificationsUpdated extends NotificationEvent {
  final List<AppNotification> notifications;
  const NotificationsUpdated(this.notifications);

  @override
  List<Object> get props => [notifications];
}

class NotificationErrorEvent extends NotificationEvent {
  final String message;
  const NotificationErrorEvent(this.message);

  @override
  List<Object> get props => [message];
}

class MarkNotificationAsRead extends NotificationEvent {
  final String userId;
  final String notificationId;

  const MarkNotificationAsRead(this.userId, this.notificationId);

  @override
  List<Object> get props => [userId, notificationId];
}

class MarkAllNotificationsAsRead extends NotificationEvent {
  final String userId;

  const MarkAllNotificationsAsRead(this.userId);

  @override
  List<Object> get props => [userId];
}

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationLoaded(this.notifications)
      : unreadCount = notifications.where((n) => !n.isRead).length;

  @override
  List<Object> get props => [notifications, unreadCount];
}

class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object> get props => [message];
}

@lazySingleton
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;
  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationBloc(this._repository) : super(NotificationInitial()) {
    on<StartListeningToNotifications>(_onStartListening);
    on<StopListeningToNotifications>(_onStopListening);
    on<NotificationsUpdated>(_onNotificationsUpdated);
    on<NotificationErrorEvent>((event, emit) => emit(NotificationError(event.message)));
    on<MarkNotificationAsRead>(_onMarkAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllAsRead);
  }

  void _onStartListening(StartListeningToNotifications event, Emitter<NotificationState> emit) {
    emit(NotificationLoading());
    _subscription?.cancel();
    _subscription = _repository.getNotifications(event.userId).listen(
      (notifications) {
        add(NotificationsUpdated(notifications));
      },
      onError: (error) {
        _subscription?.cancel();
        _subscription = null;
        add(NotificationErrorEvent(error.toString()));
      },
    );
  }

  void _onStopListening(StopListeningToNotifications event, Emitter<NotificationState> emit) {
    _subscription?.cancel();
    _subscription = null;
    emit(NotificationInitial());
  }

  void _onNotificationsUpdated(NotificationsUpdated event, Emitter<NotificationState> emit) {
    emit(NotificationLoaded(event.notifications));
  }

  Future<void> _onMarkAsRead(MarkNotificationAsRead event, Emitter<NotificationState> emit) async {
    try {
      await _repository.markAsRead(event.userId, event.notificationId);
    } catch (e) {
      // Background failure silently ignored to prevent interrupting UI
    }
  }

  Future<void> _onMarkAllAsRead(MarkAllNotificationsAsRead event, Emitter<NotificationState> emit) async {
    try {
      await _repository.markAllAsRead(event.userId);
    } catch (e) {
      // Ignored
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
