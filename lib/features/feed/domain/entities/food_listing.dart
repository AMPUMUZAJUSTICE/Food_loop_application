import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum FoodCategory { cookedMeal, groceries, snacks, beverages, bakedGoods, other }
enum ListingStatus { active, sold, expired, deleted }

class PickupLocation extends Equatable {
  final String address;
  final double latitude;
  final double longitude;

  const PickupLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PickupLocation.fromJson(Map<String, dynamic> json) {
    return PickupLocation(
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  PickupLocation copyWith({String? address, double? latitude, double? longitude}) {
    return PickupLocation(
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  List<Object?> get props => [address, latitude, longitude];
}

class FoodListing extends Equatable {
  final String id;
  final String sellerId;
  final String sellerName;
  final double sellerRating;
  final String? sellerImageUrl;
  final String title;
  final FoodCategory category;
  final List<String> imageUrls;
  final double price;
  final bool isFree;
  final String? description;
  final List<String> allergenTags;
  final PickupLocation pickupLocation;
  final DateTime pickupWindowStart;
  final DateTime pickupWindowEnd;
  final ListingStatus status;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(pickupWindowEnd);


  const FoodListing({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRating,
    this.sellerImageUrl,
    required this.title,
    required this.category,
    required this.imageUrls,
    required this.price,
    required this.isFree,
    this.description,
    required this.allergenTags,
    required this.pickupLocation,
    required this.pickupWindowStart,
    required this.pickupWindowEnd,
    required this.status,
    required this.createdAt,
  });

  factory FoodListing.fromJson(Map<String, dynamic> json) {
    return FoodListing(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      sellerRating: (json['sellerRating'] as num).toDouble(),
      sellerImageUrl: json['sellerImageUrl'] as String?,
      title: json['title'] as String,
      category: FoodCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => FoodCategory.other),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      price: (json['price'] as num).toDouble(),
      isFree: json['isFree'] as bool? ?? false,
      description: json['description'] as String?,
      allergenTags: List<String>.from(json['allergenTags'] ?? []),
      pickupLocation: PickupLocation.fromJson(json['pickupLocation'] as Map<String, dynamic>),
      pickupWindowStart: (json['pickupWindowStart'] as Timestamp).toDate(),
      pickupWindowEnd: (json['pickupWindowEnd'] as Timestamp).toDate(),
      status: ListingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => ListingStatus.active),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerRating': sellerRating,
      if (sellerImageUrl != null) 'sellerImageUrl': sellerImageUrl,
      'title': title,
      'category': category.name,
      'imageUrls': imageUrls,
      'price': price,
      'isFree': isFree,
      if (description != null) 'description': description,
      'allergenTags': allergenTags,
      'pickupLocation': pickupLocation.toJson(),
      'pickupWindowStart': Timestamp.fromDate(pickupWindowStart),
      'pickupWindowEnd': Timestamp.fromDate(pickupWindowEnd),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FoodListing copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    double? sellerRating,
    String? sellerImageUrl,
    String? title,
    FoodCategory? category,
    List<String>? imageUrls,
    double? price,
    bool? isFree,
    String? description,
    List<String>? allergenTags,
    PickupLocation? pickupLocation,
    DateTime? pickupWindowStart,
    DateTime? pickupWindowEnd,
    ListingStatus? status,
    DateTime? createdAt,
  }) {
    return FoodListing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerRating: sellerRating ?? this.sellerRating,
      sellerImageUrl: sellerImageUrl ?? this.sellerImageUrl,
      title: title ?? this.title,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      price: price ?? this.price,
      isFree: isFree ?? this.isFree,
      description: description ?? this.description,
      allergenTags: allergenTags ?? this.allergenTags,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupWindowStart: pickupWindowStart ?? this.pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd ?? this.pickupWindowEnd,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, sellerId, sellerName, sellerRating, sellerImageUrl, title,
        category, imageUrls, price, isFree, description, allergenTags,
        pickupLocation, pickupWindowStart, pickupWindowEnd, status, createdAt,
      ];
}
