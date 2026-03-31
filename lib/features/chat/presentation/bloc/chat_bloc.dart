import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/chat_message.dart';
import '../../data/chat_repository.dart';

// EVENTS
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object> get props => [];
}

class LoadChatMessages extends ChatEvent {
  final String chatId;
  final String userId;
  const LoadChatMessages(this.chatId, this.userId);
  @override
  List<Object> get props => [chatId, userId];
}

class ChatMessagesUpdated extends ChatEvent {
  final List<ChatMessage> messages;
  const ChatMessagesUpdated(this.messages);
  @override
  List<Object> get props => [messages];
}

class SendMessage extends ChatEvent {
  final String chatId;
  final ChatMessage message;
  final String recipientId;

  const SendMessage(this.chatId, this.message, this.recipientId);

  @override
  List<Object> get props => [chatId, message, recipientId];
}

// STATES
abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}
class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  const ChatLoaded(this.messages);
  @override
  List<Object> get props => [messages];
}
class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);
  @override
  List<Object> get props => [message];
}

// BLOC
@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription<List<ChatMessage>>? _subscription;

  ChatBloc(this._repository) : super(ChatInitial()) {
    on<LoadChatMessages>(_onLoadChatMessages);
    on<ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<SendMessage>(_onSendMessage);
  }

  void _onLoadChatMessages(LoadChatMessages event, Emitter<ChatState> emit) {
    emit(ChatLoading());
    // Auto mark as read when opened
    _repository.markMessagesAsRead(event.chatId, event.userId);

    _subscription?.cancel();
    _subscription = _repository.getMessages(event.chatId).listen(
      (messages) {
        add(ChatMessagesUpdated(messages));
      },
      onError: (error) {
        emit(ChatError(error.toString()));
      },
    );
  }

  void _onChatMessagesUpdated(ChatMessagesUpdated event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages));
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    try {
      await _repository.sendMessage(event.chatId, event.message, event.recipientId);
    } catch (e) {
      // Could emit an error event to show a snackbar in UI, but keep it simple
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
