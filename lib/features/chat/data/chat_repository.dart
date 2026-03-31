import 'package:injectable/injectable.dart';

import '../domain/entities/chat_message.dart';
import '../../feed/domain/entities/food_listing.dart';
import 'chat_remote_data_source.dart';

@lazySingleton
class ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepository(this._remoteDataSource);

  Future<ChatThread> getOrCreateChatThread(
    String buyerId,
    String sellerId,
    FoodListing listing,
  ) {
    return _remoteDataSource.getOrCreateChatThread(buyerId, sellerId, listing);
  }

  Stream<List<ChatThread>> getChatThreads(String userId) {
    return _remoteDataSource.getChatThreads(userId);
  }

  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _remoteDataSource.getMessages(chatId);
  }

  Future<void> sendMessage(String chatId, ChatMessage message, String recipientId) {
    return _remoteDataSource.sendMessage(chatId, message, recipientId);
  }

  Future<void> markMessagesAsRead(String chatId, String userId) {
    return _remoteDataSource.markMessagesAsRead(chatId, userId);
  }
}
