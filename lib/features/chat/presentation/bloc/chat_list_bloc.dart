import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/chat_message.dart';
import '../../data/chat_repository.dart';

// EVENTS
abstract class ChatListEvent extends Equatable {
  const ChatListEvent();
  @override
  List<Object> get props => [];
}

class LoadChatThreads extends ChatListEvent {
  final String userId;
  const LoadChatThreads(this.userId);
  @override
  List<Object> get props => [userId];
}

class ChatThreadsUpdated extends ChatListEvent {
  final List<ChatThread> threads;
  const ChatThreadsUpdated(this.threads);
  @override
  List<Object> get props => [threads];
}

// STATES
abstract class ChatListState extends Equatable {
  const ChatListState();
  @override
  List<Object> get props => [];
}

class ChatListInitial extends ChatListState {}
class ChatListLoading extends ChatListState {}
class ChatListLoaded extends ChatListState {
  final List<ChatThread> threads;
  const ChatListLoaded(this.threads);
  @override
  List<Object> get props => [threads];
}
class ChatListError extends ChatListState {
  final String message;
  const ChatListError(this.message);
  @override
  List<Object> get props => [message];
}

// BLOC
@injectable
class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatRepository _repository;
  StreamSubscription<List<ChatThread>>? _subscription;

  ChatListBloc(this._repository) : super(ChatListInitial()) {
    on<LoadChatThreads>(_onLoadChatThreads);
    on<ChatThreadsUpdated>(_onChatThreadsUpdated);
  }

  void _onLoadChatThreads(LoadChatThreads event, Emitter<ChatListState> emit) {
    emit(ChatListLoading());
    _subscription?.cancel();
    _subscription = _repository.getChatThreads(event.userId).listen(
      (threads) {
        add(ChatThreadsUpdated(threads));
      },
      onError: (error) {
        emit(ChatListError(error.toString()));
      },
    );
  }

  void _onChatThreadsUpdated(ChatThreadsUpdated event, Emitter<ChatListState> emit) {
    emit(ChatListLoaded(event.threads));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
