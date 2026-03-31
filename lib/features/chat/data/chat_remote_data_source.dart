import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../domain/entities/chat_message.dart';
import '../../feed/domain/entities/food_listing.dart';

@lazySingleton
class ChatRemoteDataSource {
  final FirebaseFirestore _firestore;

  ChatRemoteDataSource(this._firestore);

  /// Generates a deterministic chatId from participants + listingId
  String _buildChatId(String buyerId, String sellerId, String listingId) {
    final sorted = [buyerId, sellerId]..sort();
    return '${sorted.join('_')}_$listingId';
  }

  Future<ChatThread> getOrCreateChatThread(
    String buyerId,
    String sellerId,
    FoodListing listing,
  ) async {
    final chatId = _buildChatId(buyerId, sellerId, listing.id);
    final ref = _firestore.collection('chats').doc(chatId);
    final doc = await ref.get();

    if (doc.exists) {
      return ChatThread.fromJson(doc.data()!);
    }

    final thread = ChatThread(
      id: chatId,
      participants: [buyerId, sellerId],
      listingId: listing.id,
      listingTitle: listing.title,
      listingImageUrl: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : '',
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      unreadCount: {buyerId: 0, sellerId: 0},
    );

    await ref.set(thread.toJson());
    return thread;
  }

  Stream<List<ChatThread>> getChatThreads(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final threads = snap.docs.map((d) => ChatThread.fromJson(d.data())).toList();
          // Sort locally to avoid needing a composite Firestore index
          threads.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return threads;
        });
  }

  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromJson(d.data())).toList());
  }

  Future<void> sendMessage(String chatId, ChatMessage message, String recipientId) async {
    final batch = _firestore.batch();

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id);

    batch.set(msgRef, message.toJson());

    final threadRef = _firestore.collection('chats').doc(chatId);
    batch.update(threadRef, {
      'lastMessage': message.text,
      'lastMessageTime': Timestamp.fromDate(message.timestamp),
      'unreadCount.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$userId': 0,
    });
  }
}
