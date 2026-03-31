import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, paymentAction, handoverAction }

class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final MessageType messageType;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    required this.messageType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String? ?? '',
      text: json['text'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isRead: json['isRead'] as bool? ?? false,
      messageType: MessageType.values.firstWhere((e) => e.name == json['messageType'], orElse: () => MessageType.text),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'messageType': messageType.name,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    MessageType? messageType,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
    );
  }

  @override
  List<Object?> get props => [id, senderId, recipientId, text, timestamp, isRead, messageType];
}

class ChatThread extends Equatable {
  final String id;
  final List<String> participants;
  final String listingId;
  final String listingTitle;
  final String listingImageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;

  const ChatThread({
    required this.id,
    required this.participants,
    required this.listingId,
    required this.listingTitle,
    required this.listingImageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      participants: List<String>.from(json['participants'] ?? []),
      listingId: json['listingId'] as String,
      listingTitle: json['listingTitle'] as String,
      listingImageUrl: json['listingImageUrl'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: (json['lastMessageTime'] as Timestamp).toDate(),
      unreadCount: Map<String, int>.from(json['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImageUrl': listingImageUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
    };
  }

  ChatThread copyWith({
    String? id,
    List<String>? participants,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCount,
  }) {
    return ChatThread(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImageUrl: listingImageUrl ?? this.listingImageUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
        id, participants, listingId, listingTitle, listingImageUrl,
        lastMessage, lastMessageTime, unreadCount,
      ];
}
