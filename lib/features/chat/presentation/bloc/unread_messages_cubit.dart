import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/chat_repository.dart';
import '../../domain/entities/chat_message.dart';

@injectable
class UnreadMessagesCubit extends Cubit<int> {
  final ChatRepository _repository;
  StreamSubscription<List<ChatThread>>? _subscription;

  UnreadMessagesCubit(this._repository) : super(0);

  void startListening(String userId) {
    _subscription?.cancel();
    _subscription = _repository.getChatThreads(userId).listen((threads) {
      final totalUnread = threads.fold<int>(0, (total, thread) {
        return total + (thread.unreadCount[userId] ?? 0);
      });
      emit(totalUnread);
    }, onError: (error) {
      _subscription?.cancel();
      _subscription = null;
      emit(0);
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    emit(0);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
