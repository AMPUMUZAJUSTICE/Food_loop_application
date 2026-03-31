import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ExpiryItem extends Equatable {
  final String id;
  final String userId;
  final String name;
  final DateTime expiryDate;
  final bool isSharedToFeed;
  final String? sharedListingId;
  final DateTime createdAt;

  const ExpiryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.expiryDate,
    required this.isSharedToFeed,
    this.sharedListingId,
    required this.createdAt,
  });

  factory ExpiryItem.fromJson(Map<String, dynamic> json) {
    return ExpiryItem(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      expiryDate: (json['expiryDate'] as Timestamp).toDate(),
      isSharedToFeed: json['isSharedToFeed'] as bool? ?? false,
      sharedListingId: json['sharedListingId'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'isSharedToFeed': isSharedToFeed,
      if (sharedListingId != null) 'sharedListingId': sharedListingId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ExpiryItem copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? expiryDate,
    bool? isSharedToFeed,
    String? sharedListingId,
    DateTime? createdAt,
  }) {
    return ExpiryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      isSharedToFeed: isSharedToFeed ?? this.isSharedToFeed,
      sharedListingId: sharedListingId ?? this.sharedListingId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, name, expiryDate, isSharedToFeed,
        sharedListingId, createdAt,
      ];
}
