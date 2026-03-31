import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_loop/features/feed/domain/entities/food_listing.dart';

// Helper to convert Firebase JSON _seconds back to Timestamp
Map<String, dynamic> _convertJsonTimestamps(Map<String, dynamic> map) {
  final result = Map<String, dynamic>.from(map);
  
  Timestamp convert(dynamic val) {
    if (val is Map && val.containsKey('_seconds')) {
      return Timestamp(val['_seconds'], val['_nanoseconds']);
    }
    return val;
  }

  result['pickupWindowStart'] = convert(result['pickupWindowStart']);
  result['pickupWindowEnd'] = convert(result['pickupWindowEnd']);
  result['createdAt'] = convert(result['createdAt']);
  return result;
}

void main() {
  late Map<String, dynamic> jsonFixture;

  setUp(() {
    final file = File('test/fixtures/food_listing.json');
    final jsonStr = file.readAsStringSync();
    jsonFixture = _convertJsonTimestamps(jsonDecode(jsonStr));
  });

  group('FoodListing', () {
    test('fromJson correctly parses a Firestore document map including Timestamp fields', () {
      final listing = FoodListing.fromJson(jsonFixture);
      
      expect(listing.id, '123');
      expect(listing.sellerName, 'John Doe');
      expect(listing.price, 5000.0);
      expect(listing.category, FoodCategory.groceries);
      expect(listing.pickupLocation.address, 'Must Campus');
      expect(listing.createdAt, isA<DateTime>());
      // 1704060000 = 2024-01-01 00:00:00 UTC (approximately, exact check)
      expect(listing.createdAt.millisecondsSinceEpoch, 1704060000 * 1000);
    });

    test('toJson produces correct map', () {
      final listing = FoodListing.fromJson(jsonFixture);
      final json = listing.toJson();

      expect(json['id'], '123');
      expect(json['sellerName'], 'John Doe');
      expect(json['price'], 5000.0);
      expect(json['category'], 'groceries');
      expect(json['pickupLocation']['address'], 'Must Campus');
      expect(json['createdAt'], isA<Timestamp>());
    });

    test('copyWith works correctly', () {
      final listing = FoodListing.fromJson(jsonFixture);
      final updated = listing.copyWith(title: 'New Title', price: 6000.0);

      expect(updated.title, 'New Title');
      expect(updated.price, 6000.0);
      // Ensure others remain untouched
      expect(updated.id, listing.id);
      expect(updated.sellerName, listing.sellerName);
    });

    test('isExpired getter returns true when pickupWindowEnd is in the past', () {
      final listing = FoodListing.fromJson(jsonFixture); // end is ~Jan 2024, definitely past in 2026
      expect(listing.isExpired, isTrue);
      
      final futureListing = listing.copyWith(
        pickupWindowEnd: DateTime.now().add(const Duration(days: 1))
      );
      expect(futureListing.isExpired, isFalse);
    });

    test('isFree getter returns true when price == 0.0', () {
      final listing = FoodListing.fromJson(jsonFixture).copyWith(isFree: true, price: 0.0);
      expect(listing.isFree, isTrue);
      expect(listing.price, 0.0);
      
      final paidListing = listing.copyWith(isFree: false, price: 5000.0);
      expect(paidListing.isFree, isFalse);
    });
  });
}
