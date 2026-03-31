import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../../feed/domain/entities/food_listing.dart';

class PostFoodDraft extends Equatable {
  final List<File> imageFiles;
  final List<String> imageUrls;
  final String title;
  final FoodCategory? category;
  final bool isFree;
  final double price;
  final List<String> allergenTags;
  final String description;
  final PickupLocation? pickupLocation;
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;

  const PostFoodDraft({
    this.imageFiles = const [],
    this.imageUrls = const [],
    this.title = '',
    this.category,
    this.isFree = false,
    this.price = 0.0,
    this.allergenTags = const [],
    this.description = '',
    this.pickupLocation,
    this.pickupWindowStart,
    this.pickupWindowEnd,
  });

  PostFoodDraft copyWith({
    List<File>? imageFiles,
    List<String>? imageUrls,
    String? title,
    FoodCategory? category,
    bool? isFree,
    double? price,
    List<String>? allergenTags,
    String? description,
    PickupLocation? pickupLocation,
    DateTime? pickupWindowStart,
    DateTime? pickupWindowEnd,
  }) {
    return PostFoodDraft(
      imageFiles: imageFiles ?? this.imageFiles,
      imageUrls: imageUrls ?? this.imageUrls,
      title: title ?? this.title,
      category: category ?? this.category,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      allergenTags: allergenTags ?? this.allergenTags,
      description: description ?? this.description,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupWindowStart: pickupWindowStart ?? this.pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd ?? this.pickupWindowEnd,
    );
  }

  void reset() {
     // Will be used to clear state
  }

  @override
  List<Object?> get props => [
        imageFiles, imageUrls, title, category, isFree, price,
        allergenTags, description, pickupLocation, pickupWindowStart,
        pickupWindowEnd,
      ];
}
