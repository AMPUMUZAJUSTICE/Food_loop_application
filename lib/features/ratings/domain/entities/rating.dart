import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Rating extends Equatable {
  final String id;
  final String orderId;
  final String reviewerId;
  final String? reviewerName;
  final String sellerId;
  final int foodQualityRating;
  final int reliabilityRating;
  final String? comment;
  final bool isAnonymous;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    this.reviewerName,
    required this.sellerId,
    required this.foodQualityRating,
    required this.reliabilityRating,
    this.comment,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      reviewerId: json['buyerId'] as String? ?? json['reviewerId'] as String,
      reviewerName: json['reviewerName'] as String?,
      sellerId: json['sellerId'] as String,
      foodQualityRating: json['foodQualityRating'] as int,
      reliabilityRating: json['reliabilityRating'] as int,
      comment: json['comment'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'buyerId': reviewerId, // satisfy firestore rules
      if (reviewerName != null) 'reviewerName': reviewerName,
      'sellerId': sellerId,
      'foodQualityRating': foodQualityRating,
      'reliabilityRating': reliabilityRating,
      if (comment != null) 'comment': comment,
      'isAnonymous': isAnonymous,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Rating copyWith({
    String? id,
    String? orderId,
    String? reviewerId,
    String? reviewerName,
    String? sellerId,
    int? foodQualityRating,
    int? reliabilityRating,
    String? comment,
    bool? isAnonymous,
    DateTime? createdAt,
  }) {
    return Rating(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      sellerId: sellerId ?? this.sellerId,
      foodQualityRating: foodQualityRating ?? this.foodQualityRating,
      reliabilityRating: reliabilityRating ?? this.reliabilityRating,
      comment: comment ?? this.comment,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, orderId, reviewerId, reviewerName, sellerId, foodQualityRating,
        reliabilityRating, comment, isAnonymous, createdAt,
      ];
}
