import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum OrderStatus { pending, escrowHeld, pickedUp, completed, cancelled, disputed }

class Order extends Equatable {
  final String id;
  final String listingId;
  final String listingTitle;
  final String listingImageUrl;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final double amount;
  final double platformFee;
  final OrderStatus status;
  final String? pickupOTP;
  final String? flutterwaveRef;
  final String? flutterwaveTransactionId;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Order({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingImageUrl,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.amount,
    required this.platformFee,
    required this.status,
    this.pickupOTP,
    this.flutterwaveRef,
    this.flutterwaveTransactionId,
    required this.createdAt,
    this.completedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      listingId: json['listingId'] as String,
      listingTitle: json['listingTitle'] as String,
      listingImageUrl: json['listingImageUrl'] as String,
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      status: OrderStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => OrderStatus.pending),
      pickupOTP: json['pickupOTP'] as String?,
      flutterwaveRef: json['flutterwaveRef'] as String?,
      flutterwaveTransactionId: json['flutterwaveTransactionId'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      completedAt: json['completedAt'] != null ? (json['completedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImageUrl': listingImageUrl,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'amount': amount,
      'platformFee': platformFee,
      'status': status.name,
      if (pickupOTP != null) 'pickupOTP': pickupOTP,
      if (flutterwaveRef != null) 'flutterwaveRef': flutterwaveRef,
      if (flutterwaveTransactionId != null) 'flutterwaveTransactionId': flutterwaveTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  Order copyWith({
    String? id,
    String? listingId,
    String? listingTitle,
    String? listingImageUrl,
    String? buyerId,
    String? buyerName,
    String? sellerId,
    String? sellerName,
    double? amount,
    double? platformFee,
    OrderStatus? status,
    String? pickupOTP,
    String? flutterwaveRef,
    String? flutterwaveTransactionId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Order(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImageUrl: listingImageUrl ?? this.listingImageUrl,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      amount: amount ?? this.amount,
      platformFee: platformFee ?? this.platformFee,
      status: status ?? this.status,
      pickupOTP: pickupOTP ?? this.pickupOTP,
      flutterwaveRef: flutterwaveRef ?? this.flutterwaveRef,
      flutterwaveTransactionId: flutterwaveTransactionId ?? this.flutterwaveTransactionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, listingId, listingTitle, listingImageUrl, buyerId, buyerName,
        sellerId, sellerName, amount, platformFee, status, pickupOTP,
        flutterwaveRef, flutterwaveTransactionId, createdAt, completedAt,
      ];
}
