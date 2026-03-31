import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum TransactionType { topUp, withdrawal, paymentSent, paymentReceived, feeDeducted }

class WalletTransaction extends Equatable {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final String? paymentRef;
  final DateTime timestamp;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    this.paymentRef,
    required this.timestamp,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: TransactionType.values.firstWhere((e) => e.name == json['type'], orElse: () => TransactionType.paymentSent),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      paymentRef: (json['paymentRef'] ?? json['seerbitRef']) as String?,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      if (paymentRef != null) 'paymentRef': paymentRef,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  WalletTransaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    double? amount,
    String? description,
    DateTime? timestamp,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      paymentRef: paymentRef ?? this.paymentRef,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, amount, description, paymentRef, timestamp];
}
